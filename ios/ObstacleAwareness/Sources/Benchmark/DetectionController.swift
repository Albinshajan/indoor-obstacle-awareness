import AVFoundation
import CoreImage
import CoreML
import UIKit

/// Live camera -> Core ML detection pipeline for Objective 1's on-device
/// latency benchmark. Deliberately separate from `Capture/ARCaptureController`
/// (ARKit, for tape-measured ground truth) -- CLAUDE.md section 5 specifies
/// the *inference* path goes through `AVCaptureSession`, matching how the
/// real product pipeline would actually run, not through ARKit.
///
/// "capture" and "preprocess" are two separate timed render passes rather
/// than one fused operation, on purpose: CLAUDE.md's whole point about "pixel
/// buffer conversion done accidentally on the CPU per frame" is a cost this
/// logger exists to keep visible, which only works if the YpCbCr->BGRA
/// conversion and the letterbox resize are timed as distinct stages.
final class DetectionController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "detection.processing")
    private let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        }
        return CIContext()
    }()

    private static let modelInputSize = 640
    private static let letterboxFill = CIColor(red: 114.0 / 255, green: 114.0 / 255, blue: 114.0 / 255)

    @Published private(set) var isRunning = false
    @Published private(set) var frameCount = 0
    @Published private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var lastTopClass: String?
    @Published private(set) var lastTopConfidence: Float = 0
    @Published var selectedModel: DetectorVariant = .yolov8n {
        didSet { loadModel() }
    }

    private var mlModel: MLModel?
    private var classNames: [Int: String] = [:]
    private var logger: LatencyLogger?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged),
                                                name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }

    func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()
        loadModel()
    }

    func start(logDirectory: URL, feedbackMode: String = "none") {
        logger = try? LatencyLogger(modelName: selectedModel.rawValue, feedbackMode: feedbackMode, outputDirectory: logDirectory)
        frameCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        processingQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
        isRunning = true
    }

    func stop() {
        session.stopRunning()
        logger?.flush()
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
    }

    private func loadModel() {
        guard let url = Bundle.main.url(forResource: selectedModel.rawValue, withExtension: "mlmodelc") else {
            print("DetectionController: could not find \(selectedModel.rawValue).mlmodelc in the app bundle")
            mlModel = nil
            return
        }
        do {
            mlModel = try MLModel(contentsOf: url)
            classNames = readClassNames(from: mlModel)
        } catch {
            print("DetectionController: failed to load \(selectedModel.rawValue): \(error)")
            mlModel = nil
        }
    }

    /// The exported `.mlpackage`'s raw `confidence` output is a fixed 80 columns
    /// wide (an Ultralytics CoreML NMS-export artifact, confirmed 2026-09-11 --
    /// see CLAUDE.md section 8) regardless of how many classes the model
    /// actually has. Only the first `names.count` columns are meaningful; the
    /// rest is near-zero padding. Always slice by the metadata's own class
    /// count, never assume the array width equals the class count.
    private func readClassNames(from model: MLModel?) -> [Int: String] {
        guard let raw = model?.modelDescription.metadata[.creatorDefinedKey] as? [String: String],
              let namesString = raw["names"] else { return [:] }
        // namesString looks like "{0: 'person', 1: 'chair', ...}" -- parse without a full Python-literal parser.
        var result: [Int: String] = [:]
        let cleaned = namesString.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        for pair in cleaned.components(separatedBy: ",") {
            let parts = pair.components(separatedBy: ":")
            guard parts.count == 2,
                  let idx = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            let name = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " '\""))
            result[idx] = name
        }
        return result
    }

    @objc private func thermalStateChanged() {
        thermalState = ProcessInfo.processInfo.thermalState
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRunning, let logger, let mlModel,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        logger.beginFrame()

        guard let oriented = logger.measure(.capture, { orientToPortrait(pixelBuffer) }) else {
            logger.endFrame()
            return
        }
        guard let modelInput = logger.measure(.preprocess, { letterbox(oriented, to: Self.modelInputSize) }) else {
            logger.endFrame()
            return
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "image": MLFeatureValue(pixelBuffer: modelInput),
            "iouThreshold": MLFeatureValue(double: 0.45),
            "confidenceThreshold": MLFeatureValue(double: 0.25),
        ]) else {
            logger.endFrame()
            return
        }

        logger.startStage(.detect)
        let result = try? mlModel.prediction(from: provider)
        logger.endStage(.detect)

        if let result {
            updateLiveDisplay(from: result)
        }

        logger.endFrame()
        DispatchQueue.main.async { [weak self] in self?.frameCount += 1 }
    }

    private func updateLiveDisplay(from result: MLFeatureProvider) {
        guard let confidence = result.featureValue(for: "confidence")?.multiArrayValue,
              confidence.shape.count == 2 else { return }
        let numDetections = confidence.shape[0].intValue
        let numClasses = classNames.count
        guard numDetections > 0, numClasses > 0 else {
            DispatchQueue.main.async { [weak self] in self?.lastTopClass = nil }
            return
        }

        var bestScore: Float = -1
        var bestClass = 0
        for d in 0..<numDetections {
            for c in 0..<numClasses {
                let v = confidence[[d, c] as [NSNumber]].floatValue
                if v > bestScore {
                    bestScore = v
                    bestClass = c
                }
            }
        }
        let name = classNames[bestClass]
        DispatchQueue.main.async { [weak self] in
            self?.lastTopClass = name
            self?.lastTopConfidence = bestScore
        }
    }

    /// Back camera + portrait device holding: the raw sensor buffer is native
    /// landscape, matching the same `.right` convention already established
    /// and verified in `Capture/FrameWriter.swift` for the ARKit path.
    private func orientToPortrait(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let normalized = ciImage.transformed(by: CGAffineTransform(translationX: -ciImage.extent.origin.x, y: -ciImage.extent.origin.y))
        return render(normalized, width: Int(normalized.extent.width), height: Int(normalized.extent.height))
    }

    /// Standard YOLO letterbox: scale to fit, pad with grey (114,114,114) to a square.
    private func letterbox(_ pixelBuffer: CVPixelBuffer, to size: Int) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let w = ciImage.extent.width
        let h = ciImage.extent.height
        guard w > 0, h > 0 else { return nil }

        let scale = CGFloat(size) / max(w, h)
        let scaledW = w * scale
        let scaledH = h * scale
        let padX = (CGFloat(size) - scaledW) / 2
        let padY = (CGFloat(size) - scaledH) / 2

        let transform = CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: padX, y: padY))
        let foreground = ciImage.transformed(by: transform)
        let background = CIImage(color: Self.letterboxFill).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        let composited = foreground.composited(over: background)

        return render(composited, width: size, height: size)
    }

    private func render(_ image: CIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        guard let buffer else { return nil }
        ciContext.render(image, to: buffer)
        return buffer
    }
}
