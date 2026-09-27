import Foundation

/// Per-frame, per-pipeline-stage latency logging for Objective 1's on-device
/// benchmark and Objective 3/RQ3's thermal-confound check.
///
/// Never compare Core ML timings taken on a Mac against these -- macOS
/// prediction runs on the Mac's Neural Engine and says nothing about the
/// A15 (CLAUDE.md section 8). Everything this logs must come from a run on
/// the phone.
///
/// `sessionPhase` exists because sustained camera + ANE use throttles the
/// A15 within roughly 10-15 minutes: reporting cold and sustained latency
/// separately (rather than one averaged number) keeps that visible instead
/// of hidden inside a mean. `feedbackMode` is recorded per frame, not just
/// per session, so a post-hoc check can confirm RQ3's audio/haptic
/// comparison isn't actually just measuring which condition happened to run
/// while the phone was hotter -- counterbalance condition order across
/// participants regardless.
final class LatencyLogger {

    enum Stage: String, CaseIterable {
        case capture       // CVPixelBuffer conversion/resize/letterbox -- the stage most likely to hide accidental CPU work
        case preprocess    // remaining letterbox/normalisation once on the correctly-oriented buffer
        case detect        // detector forward pass
        case depthSample   // ARKit sceneDepth lookup or monocular depth sample inside the detected box
        case feedback      // urgency scoring + haptic/audio dispatch
    }

    enum SessionPhase: String {
        case cold       // first `coldThreshold` seconds -- caches/ANE not yet warmed up
        case warm       // between coldThreshold and sustainedThreshold
        case sustained  // past sustainedThreshold -- thermal throttling risk window
    }

    private let sessionStart = Date()
    private let csvURL: URL
    private let modelName: String
    private let feedbackMode: String
    private let coldThreshold: TimeInterval
    private let sustainedThreshold: TimeInterval

    private let flushThreshold = 200
    private var buffer: [String] = []
    private var frameIndex = 0
    private var stageStarts: [Stage: CFAbsoluteTime] = [:]
    private var currentStageTimings: [Stage: TimeInterval] = [:]

    /// - Parameters:
    ///   - modelName: which detector variant this session is benchmarking (e.g. "yolo11n"), recorded on every row.
    ///   - feedbackMode: "audio", "haptic", or "both" -- the RQ3 condition active for this session.
    ///   - outputDirectory: writable directory (e.g. Documents) the CSV is written into.
    ///   - coldThreshold: seconds after session start still considered "cold". Default 60s.
    ///   - sustainedThreshold: seconds after which the session is considered "sustained". Default 300s (5 min).
    init(modelName: String,
         feedbackMode: String,
         outputDirectory: URL,
         coldThreshold: TimeInterval = 60,
         sustainedThreshold: TimeInterval = 300) throws {
        self.modelName = modelName
        self.feedbackMode = feedbackMode
        self.coldThreshold = coldThreshold
        self.sustainedThreshold = sustainedThreshold

        let timestamp = Int(Date().timeIntervalSince1970)
        self.csvURL = outputDirectory.appendingPathComponent("latency_\(modelName)_\(feedbackMode)_\(timestamp).csv")
        try writeHeaderIfNeeded()
    }

    func beginFrame() {
        frameIndex += 1
        currentStageTimings.removeAll(keepingCapacity: true)
    }

    func startStage(_ stage: Stage) {
        stageStarts[stage] = CFAbsoluteTimeGetCurrent()
    }

    func endStage(_ stage: Stage) {
        guard let start = stageStarts.removeValue(forKey: stage) else { return }
        currentStageTimings[stage] = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
    }

    /// Times `block` as `stage` and returns its result.
    func measure<T>(_ stage: Stage, _ block: () throws -> T) rethrows -> T {
        startStage(stage)
        defer { endStage(stage) }
        return try block()
    }

    func endFrame() {
        let elapsed = Date().timeIntervalSince(sessionStart)
        let phase: SessionPhase = elapsed < coldThreshold ? .cold : (elapsed < sustainedThreshold ? .warm : .sustained)
        let total = Stage.allCases.reduce(0.0) { $0 + (currentStageTimings[$1] ?? 0.0) }

        var fields = [
            String(frameIndex),
            modelName,
            feedbackMode,
            String(format: "%.3f", elapsed),
            phase.rawValue,
            thermalStateString(),
        ]
        for stage in Stage.allCases {
            fields.append(String(format: "%.3f", currentStageTimings[stage] ?? 0.0))
        }
        fields.append(String(format: "%.3f", total))
        buffer.append(fields.joined(separator: ","))

        if buffer.count >= flushThreshold {
            flush()
        }
    }

    func flush() {
        guard !buffer.isEmpty else { return }
        let text = buffer.joined(separator: "\n") + "\n"
        buffer.removeAll()
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: csvURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }

    deinit {
        flush()
    }

    private func thermalStateString() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private func writeHeaderIfNeeded() throws {
        guard !FileManager.default.fileExists(atPath: csvURL.path) else { return }
        let header = (
            ["frame_index", "model", "feedback_mode", "session_elapsed_s", "session_phase", "thermal_state"]
            + Stage.allCases.map { "\($0.rawValue)_ms" }
            + ["total_ms"]
        ).joined(separator: ",")
        try (header + "\n").write(to: csvURL, atomically: true, encoding: .utf8)
    }
}
