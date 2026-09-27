import SwiftUI

struct CaptureView: View {
    @StateObject private var arController = ARCaptureController()
    @StateObject private var store = CaptureStore()

    @State private var selectedClass: ObstacleClass = .door
    @State private var selectedLighting: LightingCondition = .bright
    @State private var distanceText: String = ""
    @State private var lastSavedMessage: String?
    @State private var saveErrorMessage: String?
    @State private var showingExporter = false

    var body: some View {
        ZStack {
            ARPreviewView(session: arController.session)
                .ignoresSafeArea()

            Reticle()

            VStack {
                statusBar
                Spacer()
                controlPanel
            }
            .padding()
        }
        .onAppear { arController.start() }
        .onDisappear { arController.stop() }
        .alert("Save failed", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK") { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .sheet(isPresented: $showingExporter) {
            DirectoryExporterView(directoryURL: store.outputDirectory)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Label(arController.sceneDepthSupported ? "LiDAR ready" : "No sceneDepth",
                  systemImage: arController.sceneDepthSupported ? "checkmark.circle" : "xmark.circle")

            Text(String(format: "pitch %.0f° (Δ%.0f°)", arController.pitchDegrees, arController.pitchDeviationDegrees))
                .foregroundStyle(arController.pitchDeviationDegrees > arController.pitchWarningThresholdDegrees ? Color.yellow : Color.white)

            Spacer()

            Text("thermal: \(thermalStateLabel)")
        }
        .font(.caption)
        .padding(8)
        .background(.black.opacity(0.55))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            CoverageGrid(counts: store.coverageCounts(for: selectedClass))

            Picker("Class", selection: $selectedClass) {
                ForEach(ObstacleClass.allCases) { objectClass in
                    Text(objectClass.displayName).tag(objectClass)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                TextField("Distance (mm)", text: $distanceText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                Picker("Lighting", selection: $selectedLighting) {
                    ForEach(LightingCondition.allCases) { lighting in
                        Text(lighting.rawValue.capitalized).tag(lighting)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button(action: capture) {
                Label("Capture", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(Int(distanceText) == nil)

            if let message = lastSavedMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            Button("Export captures") { showingExporter = true }
                .font(.caption)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var thermalStateLabel: String {
        switch arController.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private func capture() {
        guard let mm = Int(distanceText), mm > 0 else {
            saveErrorMessage = CaptureError.missingMeasurement.errorDescription
            return
        }
        guard let frame = arController.latestFrame else { return }

        do {
            let stem = try store.save(frame: frame, objectClass: selectedClass, distanceMM: mm,
                                       lighting: selectedLighting, thermalState: arController.thermalState)
            lastSavedMessage = "Saved \(stem)"
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

private struct Reticle: View {
    var body: some View {
        ZStack {
            Circle().stroke(Color.white, lineWidth: 2).frame(width: 40, height: 40)
            Rectangle().fill(Color.white).frame(width: 2, height: 12)
            Rectangle().fill(Color.white).frame(width: 12, height: 2)
        }
        .shadow(radius: 2)
    }
}

#Preview {
    CaptureView()
}
