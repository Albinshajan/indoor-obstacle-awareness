import ARKit
import CoreImage
import CoreML
import UIKit

/// Objective 3's prototype: live detection, LiDAR depth sampling, the derived
/// feature layer, and dual audio/haptic feedback, running end to end on the
/// phone.
///
/// **Why this matters more than it looks.** With the participant evaluation
/// descoped on methodological grounds (n=5 across two conditions cannot answer
/// RQ3), this controller *is* the evidence that Objective 3 was delivered.
/// There is no questionnaire to fall back on.
///
/// **Why ARKit here and `AVCaptureSession` in `Benchmark/`.** Objective 1's
/// benchmark deliberately uses `AVCaptureSession` so that the buffer-conversion
/// cost stays visible as its own timed stage. This path needs RGB and depth
/// from the *same instant*, already mutually registered, which is exactly what
/// an `ARFrame` is. Re-deriving that registration from two independent capture
/// streams would add error to the depth reading for no benefit. The two paths
/// are kept separate rather than merged for that reason.
///
/// **Privacy.** Nothing here writes a frame to disk. `person` stays in the
/// taxonomy because a person genuinely is an indoor obstacle, and the standing
/// rule that no frame containing a person is ever persisted is satisfied
/// trivially by this mode persisting no frames at all -- only the latency CSV,
/// which holds timings and class names, never pixels.
final class AssistController: NSObject, ObservableObject, ARSessionDelegate {

    /// RQ3's three conditions, switchable at runtime so the comparison the
    /// ethics approval covers is built in rather than bolted on later. The
    /// study was not run, but the instrument it required exists.
    enum FeedbackMode: String, CaseIterable, Identifiable {
        case audio
        case haptic
        case both

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .audio: return "Audio only"
            case .haptic: return "Haptic only"
            case .both: return "Both"
            }
        }
        var usesAudio: Bool { self != .haptic }
        var usesHaptics: Bool { self != .audio }
    }

    // MARK: Published state

    let session = ARSession()

    @Published private(set) var obstacles: [Obstacle] = []
    @Published private(set) var isRunning = false
    @Published private(set) var frameCount = 0
    @Published private(set) var processedFPS: Double = 0
    @Published private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var depthSupported = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastFeedbackMilliseconds: Double = 0

    @Published var mode: FeedbackMode = .both {
        didSet { applyMode() }
    }
    /// yolo26n by default: Objective 1's outright winner on accuracy, size and
    /// sustained latency, and the detector Objective 2's distance numbers were
    /// produced with. Left switchable so the prototype can be demonstrated
    /// against the other two.
    @Published var model: DetectorVariant = .yolo26n {
        didSet { loadModel() }
    }

    // MARK: Collaborators

    private let tracker = ObstacleTracker()
    private let haptics = HapticFeedbackEngine()
    private let audio = AudioFeedbackEngine()
    private var logger: LatencyLogger?

    private var mlModel: MLModel?
    private var classNames: [Int: String] = [:]

    private let processingQueue = DispatchQueue(label: "assist.processing", qos: .userInitiated)
    private let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() { return CIContext(mtlDevice: device) }
        return CIContext()
    }()

    private static let modelInputSize = 640
    private static let letterboxFill = CIColor(red: 114.0 / 255, green: 114.0 / 255, blue: 114.0 / 255)
    private static let confidenceThreshold = 0.30
    private static let iouThreshold = 0.45

    /// Detection is capped below ARKit's 60 Hz on purpose. A walking pace is
    /// roughly half a second, so 30 Hz already oversamples the thing being
    /// tracked, while halving the detector's duty cycle directly halves the
    /// sustained Neural Engine load -- and thermal state was measured reaching
    /// `serious` inside three minutes on this pipeline
    /// (`results/objective3/latency_findings.md`), so the headroom is real.
    ///
    /// 30 ms rather than the 33.3 ms that "30 Hz" implies, and the 3 ms
    /// matters. ARKit delivers on a 16.7 ms clock, so a threshold set to
    /// exactly twice that period sits right on a delivery boundary: ordinary
    /// jitter puts a delivery a fraction under it, the frame is skipped, and
    /// the next candidate is a full 16.7 ms later. The first live run showed
    /// exactly that -- inter-frame intervals came out bimodal at 33 ms and
    /// 50 ms, and the session averaged 22.8 fps against a 30 Hz cap, losing a
    /// quarter of the achievable rate to aliasing rather than to any real
    /// cost. Setting the threshold just inside the boundary accepts every
    /// second ARKit frame reliably, and still never accepts two in a row.
    private static let minimumFrameInterval: TimeInterval = 0.030

    private var lastProcessedAt: TimeInterval = 0
    private var lastEarconAt: TimeInterval = 0
    private var fpsWindowStart: TimeInterval = 0
    private var fpsWindowCount = 0

    // MARK: Lifecycle

    override init() {
        super.init()
        session.delegate = self
        // ARKit delivers frames on this queue. Keeping it off the main thread
        // matters because detection plus depth sampling is several
        // milliseconds of work per frame and would otherwise compete with
        // SwiftUI for the main run loop, making the UI stutter in a way that
        // looks like pipeline latency but is not.
        session.delegateQueue = processingQueue
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        loadModel()
    }

    func start(logDirectory: URL) {
        depthSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        guard depthSupported else {
            statusMessage = "This device does not provide sceneDepth. The assist pipeline needs LiDAR."
            return
        }
        guard mlModel != nil else {
            statusMessage = "Detector \(model.rawValue) is not in the app bundle."
            return
        }

        tracker.reset()
        frameCount = 0
        fpsWindowCount = 0
        fpsWindowStart = CFAbsoluteTimeGetCurrent()
        lastProcessedAt = 0
        lastEarconAt = 0
        logger = try? LatencyLogger(modelName: model.rawValue,
                                    feedbackMode: mode.rawValue,
                                    outputDirectory: logDirectory)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = []
        config.frameSemantics.insert(.sceneDepth)
        session.run(config, options: [.resetTracking, .removeExistingAnchors])

        applyMode()
        UIApplication.shared.isIdleTimerDisabled = true
        isRunning = true
        statusMessage = nil
    }

    func stop() {
        session.pause()
        haptics.stop()
        audio.stop()
        logger?.flush()
        logger = nil
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
        obstacles = []
    }

    /// Speak the most urgent obstacle's identity. Bound to a button, never to
    /// the frame loop -- see `AudioFeedbackEngine`'s note on why speech cannot
    /// live in the measured path.
    func announceTopObstacle() {
        guard let top = obstacles.filter({ $0.isConfirmed && $0.distance != nil })
            .max(by: { $0.urgency < $1.urgency }) else {
            audio.speak("Nothing detected")
            return
        }
        audio.speak(AudioFeedbackEngine.phrase(for: top))
    }

    private func applyMode() {
        if mode.usesHaptics {
            haptics.start()
            if let error = haptics.lastError { statusMessage = error }
        } else {
            haptics.stop()
        }
        if mode.usesAudio {
            audio.start()
            if let error = audio.lastError { statusMessage = error }
        } else {
            audio.stop()
        }
    }

    private func loadModel() {
        guard let url = Bundle.main.url(forResource: model.rawValue, withExtension: "mlmodelc") else {
            mlModel = nil
            return
        }
        do {
            mlModel = try MLModel(contentsOf: url)
            classNames = Self.readClassNames(from: mlModel)
        } catch {
            mlModel = nil
            statusMessage = "Could not load \(model.rawValue): \(error.localizedDescription)"
        }
    }

    @objc private func thermalStateChanged() {
        let state = ProcessInfo.processInfo.thermalState
        DispatchQueue.main.async { [weak self] in self?.thermalState = state }
    }

    // MARK: The per-frame pipeline

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRunning, let logger, let mlModel else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessedAt >= Self.minimumFrameInterval else { return }
        lastProcessedAt = now

        logger.beginFrame()

        guard let upright = logger.measure(.capture, { orientToPortrait(frame.capturedImage) }) else {
            logger.endFrame(); return
        }
        guard let modelInput = logger.measure(.preprocess, { letterbox(upright, to: Self.modelInputSize) }) else {
            logger.endFrame(); return
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "image": MLFeatureValue(pixelBuffer: modelInput),
            "iouThreshold": MLFeatureValue(double: Self.iouThreshold),
            "confidenceThreshold": MLFeatureValue(double: Self.confidenceThreshold),
        ]) else {
            logger.endFrame(); return
        }

        logger.startStage(.detect)
        let prediction = try? mlModel.prediction(from: provider)
        logger.endStage(.detect)

        let frameAspect = Double(CVPixelBufferGetWidth(upright)) / Double(CVPixelBufferGetHeight(upright))
        let detections = prediction.map { parseDetections(from: $0, frameAspect: frameAspect) } ?? []

        // Depth: one median per detection, over the box's lower third.
        logger.startStage(.depthSample)
        var distances: [Double?] = []
        if let sceneDepth = frame.sceneDepth {
            for detection in detections {
                let portraitROI = FrameGeometry.lowerThird(of: detection.box)
                let landscapeROI = FrameGeometry.landscapeROI(forPortrait: portraitROI)
                distances.append(DepthSampler.medianDepth(depthMap: sceneDepth.depthMap,
                                                          confidenceMap: sceneDepth.confidenceMap,
                                                          roi: landscapeROI))
            }
        } else {
            distances = Array(repeating: nil, count: detections.count)
        }
        logger.endStage(.depthSample)

        // Tracking, scoring, gating and dispatch: one timed stage, because
        // from the user's point of view it is one thing -- the time between
        // the detector producing a box and something being felt or heard.
        logger.startStage(.feedback)
        let timestamp = now
        let scored = tracker.update(detections: detections, distances: distances, timestamp: timestamp)
        let actionable = scored.filter { $0.isConfirmed && $0.distance != nil }
        let top = actionable.max { $0.urgency < $1.urgency }
        dispatchFeedback(top: top, timestamp: timestamp)
        logger.endStage(.feedback)

        // Record what was decided, not just how long deciding took. `top` is
        // the obstacle that actually drove feedback, so a log row says both
        // what the user felt and what the pipeline thought it was looking at.
        logger.annotate(.init(trackCount: scored.count,
                              confirmedCount: scored.filter(\.isConfirmed).count,
                              topClass: top?.className ?? "",
                              topConfidence: top?.confidence ?? 0,
                              topDistance: top?.distance,
                              topUrgency: top?.urgency ?? 0,
                              topLevel: top?.level.spokenName ?? ""))
        logger.endFrame()

        // FPS over a one-second window, and the obstacle list for the UI.
        fpsWindowCount += 1
        let elapsed = now - fpsWindowStart
        let fps = elapsed >= 1.0 ? Double(fpsWindowCount) / elapsed : nil
        if fps != nil { fpsWindowStart = now; fpsWindowCount = 0 }

        let ranked = scored.sorted { $0.urgency > $1.urgency }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.obstacles = ranked
            self.frameCount += 1
            if let fps { self.processedFPS = fps }
        }
    }

    /// Route the winning obstacle to whichever channels the current condition
    /// enables. Only one obstacle drives feedback at a time: two simultaneous
    /// haptic patterns are indistinguishable through a single actuator, and two
    /// overlapping earcons are worse than one.
    private func dispatchFeedback(top: Obstacle?, timestamp: TimeInterval) {
        guard let top, top.level != .none else {
            haptics.silence()
            return
        }

        if mode.usesHaptics {
            haptics.update(urgency: top.urgency)
        }

        if mode.usesAudio {
            // Earcon cadence rises with the urgency band, mirroring the haptic
            // pulse rate so the two channels agree rather than beating against
            // each other when both are on.
            let interval: TimeInterval
            switch top.level {
            case .high: interval = 0.45
            case .medium: interval = 1.0
            case .low: interval = 2.0
            case .none: return
            }
            if timestamp - lastEarconAt >= interval {
                audio.play(level: top.level, bearing: top.bearing)
                lastEarconAt = timestamp
            }
        }

        let ms = (CFAbsoluteTimeGetCurrent() - timestamp) * 1000
        DispatchQueue.main.async { [weak self] in self?.lastFeedbackMilliseconds = ms }
    }

    // MARK: Model output parsing

    /// Ultralytics' Core ML NMS export emits `coordinates` as centre-form
    /// `(x, y, w, h)` normalised to the square model input, and `confidence`
    /// as a fixed **80**-column array regardless of the model's real class
    /// count (confirmed 2026-09-11, CLAUDE.md section 8). Columns past the
    /// metadata's own class count are near-zero padding -- reading the full
    /// width, or assuming the width equals the class count, silently breaks
    /// the argmax. Always slice by `classNames.count`.
    private func parseDetections(from prediction: MLFeatureProvider, frameAspect: Double) -> [Detection] {
        guard let confidence = prediction.featureValue(for: "confidence")?.multiArrayValue,
              let coordinates = prediction.featureValue(for: "coordinates")?.multiArrayValue,
              confidence.shape.count == 2, coordinates.shape.count == 2 else { return [] }

        let count = min(confidence.shape[0].intValue, coordinates.shape[0].intValue)
        let numClasses = classNames.count
        guard count > 0, numClasses > 0 else { return [] }

        var result: [Detection] = []
        for d in 0..<count {
            var bestScore: Double = -1
            var bestClass = 0
            for c in 0..<numClasses {
                let v = Double(confidence[[d, c] as [NSNumber]].floatValue)
                if v > bestScore { bestScore = v; bestClass = c }
            }
            guard bestScore >= Self.confidenceThreshold, let name = classNames[bestClass] else { continue }

            let cx = Double(coordinates[[d, 0] as [NSNumber]].floatValue)
            let cy = Double(coordinates[[d, 1] as [NSNumber]].floatValue)
            let w = Double(coordinates[[d, 2] as [NSNumber]].floatValue)
            let h = Double(coordinates[[d, 3] as [NSNumber]].floatValue)

            var box = FrameGeometry.unletterbox(center: (cx, cy, w, h), frameAspect: frameAspect)
            // Clamp into the frame: undoing the letterbox can place an edge
            // slightly outside, and an out-of-frame ROI would otherwise clip
            // to nothing and read as "no depth available".
            box = box.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
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

    /// Rotate the native landscape sensor buffer to the upright display frame.
    ///
    /// This is the live counterpart of `tools/orientation.py`, and it is not
    /// optional. Measured offline on real capture output: the detector found
    /// **0 boxes in 4 object-aimed frames as stored, and 4 of 4 once rotated**,
    /// a chair going from nothing to 0.96 confidence. The training corpus is
    /// upright indoor photography, so a sideways scene is simply out of
    /// distribution. Removing this rotation does not throw -- it just stops
    /// finding obstacles.
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
