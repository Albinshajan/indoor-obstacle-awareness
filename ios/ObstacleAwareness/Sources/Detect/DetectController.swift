import ARKit
import CoreImage
import CoreML
import UIKit

/// Detection only: the fine-tuned detector's raw per-frame output, with no
/// depth, tracking, confirmation gate or feedback between the model and the
/// screen.
///
/// **Why a separate mode when Assist already runs this detector.** Assist
/// shows what survives the decision layer. A detection only becomes a track
/// after association, only drives anything after 3 of 5 confirmations and a
/// valid depth sample, and the screen is organised around the single most
/// urgent obstacle. That is right for the prototype and wrong for asking what
/// the *detector itself* sees. Objective 2 found detector coverage, not depth
/// accuracy, to be the binding constraint -- a box in only 38 of 102 frames
/// (§4.2.1) -- and coverage is exactly what the decision layer hides. This mode
/// shows every box the model returns above an adjustable threshold, frame by
/// frame, so a miss looks like a miss.
///
/// **Why ARKit with orientation tracking only.** It delivers the same
/// 1920x1440 `capturedImage` Assist detects on, through the same rotation and
/// letterbox, so a box seen here is the box Assist would receive. But
/// `AROrientationTrackingConfiguration` needs no LiDAR and runs no world
/// tracking, so this mode works on any ARKit iPhone and does not spend the
/// thermal budget that §4.3.4 measured the full pipeline exhausting in minutes.
///
/// **Not a measurement instrument.** Nothing is logged. The inference time on
/// screen is a glance, not a result: Objective 1's latency figures come from
/// `Benchmark/`, which times capture, preprocessing and inference as separate
/// stages and which this mode does not reproduce.
///
/// **Privacy.** Nothing here writes to disk -- no frames, no log -- so the rule
/// that no frame containing a person is ever persisted holds trivially.
///
/// The image preparation and output parsing below mirror `AssistController`
/// deliberately rather than sharing code with it. Assist is the instrument
/// behind §4.3's measurements, and it is not refactored after the fact to
/// serve a viewer.
final class DetectController: NSObject, ObservableObject, ARSessionDelegate {

    // MARK: Published state

    let session = ARSession()

    /// This frame's detections, most confident first. No identity carries
    /// between frames -- there is no tracker in this path, by design.
    @Published private(set) var detections: [Detection] = []
    @Published private(set) var isRunning = false
    @Published private(set) var processedFPS: Double = 0
    @Published private(set) var inferenceMilliseconds: Double = 0
    @Published private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var statusMessage: String?
    /// Width / height of the upright frame the detector sees. Published rather
    /// than assumed, so the preview is sized to exactly what was detected on.
    @Published private(set) var frameAspect: Double = 3.0 / 4.0
    /// The loaded model's own class list, in index order, from its metadata.
    @Published private(set) var classNames: [String] = []

    /// yolo26n by default, matching Assist: Objective 1's winner, and the
    /// detector behind Objective 2's distance figures.
    @Published var model: DetectorVariant = .yolo26n {
        didSet { loadModel() }
    }

    /// Adjustable at runtime, unlike Assist's fixed 0.30. Dropping it shows
    /// what the detector *almost* found, which is the quickest way to tell a
    /// class it cannot see from one it sees weakly.
    @Published var confidenceThreshold: Double = 0.30 {
        didSet {
            let value = confidenceThreshold
            processingQueue.async { [weak self] in self?.activeThreshold = value }
        }
    }

    // MARK: Collaborators

    private var mlModel: MLModel?
    private var classIndex: [Int: String] = [:]
    private let audio = AudioFeedbackEngine()

    private let processingQueue = DispatchQueue(label: "detect.processing", qos: .userInitiated)
    private let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() { return CIContext(mtlDevice: device) }
        return CIContext()
    }()

    private static let modelInputSize = 640
    private static let letterboxFill = CIColor(red: 114.0 / 255, green: 114.0 / 255, blue: 114.0 / 255)
    private static let iouThreshold = 0.45
    /// The same 30 Hz cap as Assist, for the same reason: exactly twice ARKit's
    /// 16.7 ms delivery period aliases and loses a quarter of the frame rate.
    /// See `AssistController.minimumFrameInterval`.
    private static let minimumFrameInterval: TimeInterval = 0.030

    /// Owned by `processingQueue`; `confidenceThreshold` is its main-thread face.
    private var activeThreshold = 0.30
    private var lastProcessedAt: TimeInterval = 0
    private var fpsWindowStart: TimeInterval = 0
    private var fpsWindowCount = 0

    // MARK: Lifecycle

    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = processingQueue
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        loadModel()
    }

    func start() {
        guard AROrientationTrackingConfiguration.isSupported else {
            statusMessage = "This device cannot run an ARKit camera session."
            return
        }
        guard mlModel != nil else {
            statusMessage = "Detector \(model.rawValue) is not in the app bundle."
            return
        }

        let config = AROrientationTrackingConfiguration()
        // Prefer a 4:3 format so the frame matches Assist's. The preview reads
        // the real aspect back from each frame, so a device offering only 16:9
        // still draws correctly -- it just detects on a different crop.
        if let fourByThree = AROrientationTrackingConfiguration.supportedVideoFormats.first(where: {
            abs($0.imageResolution.width / $0.imageResolution.height - 4.0 / 3.0) < 0.01
        }) {
            config.videoFormat = fourByThree
        }

        processingQueue.async { [weak self] in
            self?.lastProcessedAt = 0
            self?.fpsWindowCount = 0
            self?.fpsWindowStart = CFAbsoluteTimeGetCurrent()
        }
        session.run(config, options: [.resetTracking])
        UIApplication.shared.isIdleTimerDisabled = true
        isRunning = true
        statusMessage = nil
    }

    func stop() {
        session.pause()
        audio.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
        detections = []
        processedFPS = 0
        inferenceMilliseconds = 0
    }

    /// Speak what is in view. Bound to a button, never to the frame loop --
    /// see `AudioFeedbackEngine` on why speech cannot live in the per-frame
    /// path. Its audio session mixes with others, so VoiceOver keeps talking.
    func announceDetections() {
        audio.start()
        audio.speak(Self.summary(of: detections, threshold: confidenceThreshold))
    }

    /// The one sentence this mode speaks, and the status card's VoiceOver
    /// label. Most confident first, capped so the sentence ends before the
    /// scene has changed.
    static func summary(of detections: [Detection], threshold: Double) -> String {
        guard !detections.isEmpty else {
            return String(format: "Nothing detected above %.0f percent.", threshold * 100)
        }
        let listed = detections.prefix(4).map { detection in
            String(format: "%@ %@, %.0f percent",
                   detection.className.replacingOccurrences(of: "_", with: " "),
                   BearingZone.from(centroidX: detection.box.midX).spokenName,
                   detection.confidence * 100)
        }
        let count = detections.count == 1 ? "1 object" : "\(detections.count) objects"
        let more = detections.count > listed.count ? " And \(detections.count - listed.count) more." : ""
        return "\(count). " + listed.joined(separator: ". ") + "." + more
    }

    private func loadModel() {
        guard let url = Bundle.main.url(forResource: model.rawValue, withExtension: "mlmodelc") else {
            mlModel = nil
            classIndex = [:]
            classNames = []
            return
        }
        do {
            mlModel = try MLModel(contentsOf: url)
            classIndex = Self.readClassNames(from: mlModel)
            classNames = classIndex.keys.sorted().compactMap { classIndex[$0] }
        } catch {
            mlModel = nil
            statusMessage = "Could not load \(model.rawValue): \(error.localizedDescription)"
        }
    }

    @objc private func thermalStateChanged() {
        let state = ProcessInfo.processInfo.thermalState
        DispatchQueue.main.async { [weak self] in self?.thermalState = state }
    }

    // MARK: The per-frame path

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRunning, let mlModel else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessedAt >= Self.minimumFrameInterval else { return }
        lastProcessedAt = now

        guard let upright = orientToPortrait(frame.capturedImage),
              let modelInput = letterbox(upright, to: Self.modelInputSize) else { return }

        let threshold = activeThreshold
        guard let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "image": MLFeatureValue(pixelBuffer: modelInput),
            "iouThreshold": MLFeatureValue(double: Self.iouThreshold),
            "confidenceThreshold": MLFeatureValue(double: threshold),
        ]) else { return }

        let inferenceStart = CFAbsoluteTimeGetCurrent()
        let prediction = try? mlModel.prediction(from: provider)
        let inferenceMs = (CFAbsoluteTimeGetCurrent() - inferenceStart) * 1000

        let aspect = Double(CVPixelBufferGetWidth(upright)) / Double(CVPixelBufferGetHeight(upright))
        let found = prediction.map { parseDetections(from: $0, frameAspect: aspect, threshold: threshold) } ?? []
        let ranked = found.sorted { $0.confidence > $1.confidence }

        fpsWindowCount += 1
        let elapsed = now - fpsWindowStart
        let fps = elapsed >= 1.0 ? Double(fpsWindowCount) / elapsed : nil
        if fps != nil { fpsWindowStart = now; fpsWindowCount = 0 }

        DispatchQueue.main.async { [weak self] in
            // A frame already in flight when Stop was pressed must not repaint
            // boxes onto a stopped screen.
            guard let self, self.isRunning else { return }
            self.detections = ranked
            self.inferenceMilliseconds = inferenceMs
            if self.frameAspect != aspect { self.frameAspect = aspect }
            if let fps { self.processedFPS = fps }
        }
    }

    // MARK: Model output parsing

    /// As `AssistController.parseDetections`: centre-form coordinates
    /// normalised to the square model input, and a `confidence` array that is
    /// a fixed 80 columns wide whatever the real class count. Only the first
    /// `classIndex.count` columns mean anything -- slice by the metadata,
    /// never by the array's width.
    private func parseDetections(from prediction: MLFeatureProvider,
                                 frameAspect: Double,
                                 threshold: Double) -> [Detection] {
        guard let confidence = prediction.featureValue(for: "confidence")?.multiArrayValue,
              let coordinates = prediction.featureValue(for: "coordinates")?.multiArrayValue,
              confidence.shape.count == 2, coordinates.shape.count == 2 else { return [] }

        let count = min(confidence.shape[0].intValue, coordinates.shape[0].intValue)
        let numClasses = classIndex.count
        guard count > 0, numClasses > 0 else { return [] }

        var result: [Detection] = []
        for d in 0..<count {
            var bestScore: Double = -1
            var bestClass = 0
            for c in 0..<numClasses {
                let v = Double(confidence[[d, c] as [NSNumber]].floatValue)
                if v > bestScore { bestScore = v; bestClass = c }
            }
            guard bestScore >= threshold, let name = classIndex[bestClass] else { continue }

            let cx = Double(coordinates[[d, 0] as [NSNumber]].floatValue)
            let cy = Double(coordinates[[d, 1] as [NSNumber]].floatValue)
            let w = Double(coordinates[[d, 2] as [NSNumber]].floatValue)
            let h = Double(coordinates[[d, 3] as [NSNumber]].floatValue)

            let box = FrameGeometry.unletterbox(center: (cx, cy, w, h), frameAspect: frameAspect)
                .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !box.isNull, box.width > 0.01, box.height > 0.01 else { continue }

            result.append(Detection(className: name, confidence: bestScore, box: box))
        }
        return result
    }

    private static func readClassNames(from model: MLModel?) -> [Int: String] {
        guard let raw = model?.modelDescription.metadata[.creatorDefinedKey] as? [String: String],
              let namesString = raw["names"] else { return [:] }
        var result: [Int: String] = [:]
        let cleaned = namesString.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        for pair in cleaned.components(separatedBy: ",") {
            let parts = pair.components(separatedBy: ":")
            guard parts.count == 2,
                  let idx = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            result[idx] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " '\""))
        }
        return result
    }

    // MARK: Image preparation

    /// Rotate the landscape sensor buffer upright. Not optional: the detector
    /// found 0 boxes in 4 object-aimed frames as stored and 4 of 4 rotated
    /// (`tools/orientation.py`; `AssistController.orientToPortrait`).
    private func orientToPortrait(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let normalised = image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x,
                                                                 y: -image.extent.origin.y))
        return render(normalised, width: Int(normalised.extent.width), height: Int(normalised.extent.height))
    }

    private func letterbox(_ pixelBuffer: CVPixelBuffer, to size: Int) -> CVPixelBuffer? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let w = image.extent.width
        let h = image.extent.height
        guard w > 0, h > 0 else { return nil }

        let scale = CGFloat(size) / max(w, h)
        let padX = (CGFloat(size) - w * scale) / 2
        let padY = (CGFloat(size) - h * scale) / 2
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: padX, y: padY))

        let background = CIImage(color: Self.letterboxFill)
            .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        return render(image.transformed(by: transform).composited(over: background), width: size, height: size)
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
