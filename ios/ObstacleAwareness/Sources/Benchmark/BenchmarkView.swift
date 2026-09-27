import SwiftUI

/// Objective 1's on-device latency benchmark screen. Separate from
/// `CaptureView` (ground-truth capture) -- this is the live detection
/// pipeline whose per-stage timings `LatencyLogger` records.
///
/// Deliberately does not measure depthSample/feedback here -- those columns
/// will read 0 in the CSV. Objective 1 is about the detector comparison;
/// pipeline stages beyond detection belong to Objective 3's decision layer,
/// not built yet.
struct BenchmarkView: View {
    @StateObject private var controller = DetectionController()
    @State private var showingExporter = false
    @State private var sessionStart: Date?

    private let logDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Benchmarks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    var body: some View {
        ZStack {
            BenchmarkPreviewView(session: controller.session)
                .ignoresSafeArea()

            VStack {
                statusBar
                Spacer()
                controlPanel
            }
            .padding()
        }
        .onAppear { controller.configureSessionIfNeeded() }
        .onDisappear { if controller.isRunning { controller.stop() } }
        .sheet(isPresented: $showingExporter) {
            DirectoryExporterView(directoryURL: logDirectory)
        }
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("frames: \(controller.frameCount)")
                Spacer()
                Text("thermal: \(thermalLabel)")
                    .foregroundStyle(thermalColor)
            }
            if let elapsed = sessionStart.map({ Date().timeIntervalSince($0) }) {
                Text(String(format: "elapsed: %.0fs", elapsed))
            }
            if let cls = controller.lastTopClass {
                Text(String(format: "top detection: %@ (%.2f)", cls, controller.lastTopConfidence))
            } else {
                Text("top detection: none")
            }
        }
        .font(.caption.monospacedDigit())
        .padding(8)
        .background(.black.opacity(0.55))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            Picker("Model", selection: $controller.selectedModel) {
                ForEach(DetectorVariant.allCases) { variant in
                    Text(variant.displayName).tag(variant)
                }
            }
            .pickerStyle(.segmented)
            .disabled(controller.isRunning)

            Button(action: toggleRunning) {
                Label(controller.isRunning ? "Stop" : "Start benchmark",
                      systemImage: controller.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(controller.isRunning ? .red : .accentColor)

            Text("Runs continuously until stopped. For real cold/sustained data, run each model for 15+ minutes (CLAUDE.md: thermal throttling sets in around then).")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Export benchmark logs") { showingExporter = true }
                .font(.caption)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var thermalLabel: String {
        switch controller.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private var thermalColor: Color {
        switch controller.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious, .critical: return .red
        @unknown default: return .white
        }
    }

    private func toggleRunning() {
        if controller.isRunning {
            controller.stop()
            sessionStart = nil
        } else {
            sessionStart = Date()
            controller.start(logDirectory: logDirectory)
        }
    }
}

#Preview {
    BenchmarkView()
}
