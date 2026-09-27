import SwiftUI

/// The detection-only screen: every box the detector returns, labelled with
/// class and confidence, and a list of the same in words.
///
/// Built to the same rules as `AssistView`, for the same reasons: the status
/// card is one VoiceOver element speaking one sentence; the preview, its boxes
/// and the telemetry are hidden from the reader because the card and the list
/// carry all of it in words; box colour distinguishes classes at a glance but
/// every box also carries its class name, so nothing is communicated by hue
/// alone.
///
/// **The preview is sized to the frame, not to the screen.** Assist fills a
/// fixed-height strip and crops whatever does not fit. Here the preview takes
/// the detected frame's own aspect ratio, so the whole image the model saw is
/// on screen edge to edge -- a detection near the frame edge is drawn rather
/// than cropped away, which matters in a mode whose purpose is to show what
/// the detector does and does not find.
struct DetectView: View {
    @StateObject private var controller = DetectController()
    @State private var showClasses = false

    @ScaledMetric(relativeTo: .largeTitle) private var readoutSize: CGFloat = 54

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                preview
                    .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.56)
                    .background(Theme.night)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.depthLine).frame(height: 1)
                    }
                ScrollView {
                    VStack(spacing: 12) {
                        statusCard
                        controls
                        if let message = controller.statusMessage {
                            noticeCard(message)
                        }
                        detectionsPanel
                        thresholdPanel
                        classesPanel
                        detectorPanel
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Theme.night.ignoresSafeArea())
        .onDisappear { controller.stop() }
    }

    // MARK: Camera preview

    private var preview: some View {
        ZStack(alignment: .topLeading) {
            Theme.night
            ARPreviewView(session: controller.session)
            // `ARSCNView` is opaque and white until a feed arrives, so the idle
            // state is an overlay, as in Assist.
            if !controller.isRunning {
                ZStack {
                    Theme.night
                    VStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(Theme.icon(22, .regular))
                            .foregroundStyle(Theme.depthLine)
                        Text("Camera preview")
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.creamFaint)
                        Text("Every object the detector finds is boxed here once running.")
                            .font(Theme.data(11))
                            .foregroundStyle(Theme.creamFaint)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityHidden(true)
            }
            GeometryReader { geometry in
                ForEach(Array(controller.detections.enumerated()), id: \.offset) { _, detection in
                    boxOverlay(for: detection, in: geometry.size)
                }
            }
            hud
        }
        // The frame's own aspect, so aspect-fill and aspect-fit coincide and
        // nothing is cropped. The box mapping below relies on this.
        .aspectRatio(controller.frameAspect, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)   // the status card and list carry this in words
    }

    /// Fractions of the frame map linearly onto the view, because the view has
    /// the frame's aspect ratio. Assist cannot do this -- its preview is
    /// aspect-filled into a fixed strip, hence `AssistView.viewRect`.
    private func boxOverlay(for detection: Detection, in size: CGSize) -> some View {
        let rect = CGRect(x: detection.box.minX * size.width,
                          y: detection.box.minY * size.height,
                          width: detection.box.width * size.width,
                          height: detection.box.height * size.height)
        let tint = tint(for: detection.className)
        // A box touching the top of the frame would push its label out of the
        // preview, so the label moves inside the box instead.
        let labelInside = rect.minY < 18
        return RoundedRectangle(cornerRadius: 3)
            .strokeBorder(tint, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topLeading) {
                Text(String(format: "%@ %.2f", detection.className, detection.confidence))
                    .font(Theme.data(10))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(tint, in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(Theme.night)
                    .offset(y: labelInside ? 3 : -17)
                    .padding(.leading, labelInside ? 3 : 0)
            }
            .position(x: rect.midX, y: rect.midY)
    }

    private var hud: some View {
        HStack(spacing: 10) {
            Label(controller.isRunning ? "\(controller.processedFPS, specifier: "%.0f") fps" : "stopped",
                  systemImage: controller.isRunning ? "waveform" : "pause.fill")
            if controller.isRunning {
                Text("·")
                Text("\(controller.inferenceMilliseconds, specifier: "%.1f") ms")
            }
            Text("·")
            Text(AssistView.thermalName(controller.thermalState))
                .foregroundStyle(AssistView.thermalTint(controller.thermalState))
        }
        .font(Theme.data(11))
        .foregroundStyle(Theme.creamDim)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.night.opacity(0.72), in: Capsule())
        .padding(10)
        // Collapse, then hide: `.accessibilityHidden(true)` alone leaves a
        // layout container's children reachable. See `AssistView.hud`.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }

    // MARK: Status card

    private var statusCard: some View {
        let detections = controller.detections
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: controller.isRunning ? "viewfinder" : "pause.circle")
                    .font(Theme.icon(18))
                    .foregroundStyle(controller.isRunning ? Theme.sky : Theme.creamFaint)
                    .accessibilityHidden(true)
                Text(controller.isRunning ? "Detecting" : "Stopped")
                    .font(Theme.label(15))
                    .tracking(0.8)
                    .foregroundStyle(controller.isRunning ? Theme.sky : Theme.creamFaint)
                Spacer(minLength: 8)
                Text(controller.model.displayName)
                    .font(Theme.data(12))
                    .foregroundStyle(Theme.creamFaint)
            }

            if controller.isRunning && !detections.isEmpty {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(detections.count)")
                        .font(Theme.readout(readoutSize))
                        .foregroundStyle(Theme.cream)
                    Text(detections.count == 1 ? "object" : "objects")
                        .font(Theme.label(20))
                        .foregroundStyle(Theme.creamDim)
                }
                Text(classTally(detections))
                    .font(Theme.label(15))
                    .foregroundStyle(Theme.cream)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(controller.isRunning ? "Nothing detected" : "Not running")
                    .font(Theme.label(22))
                    .foregroundStyle(Theme.creamDim)
                Text(controller.isRunning
                     ? String(format: "Nothing above %.0f%%. Sweep slowly, or lower the threshold to see weaker detections.",
                              controller.confidenceThreshold * 100)
                     : "Press Start to see what the detector finds.")
                    .font(Theme.data(12))
                    .foregroundStyle(Theme.creamFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.depth.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.sky.opacity(detections.isEmpty ? 0.25 : 0.6), lineWidth: 1.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenStatus)
    }

    private var spokenStatus: String {
        guard controller.isRunning else { return "Stopped. Press Start to see what the detector finds." }
        return DetectController.summary(of: controller.detections, threshold: controller.confidenceThreshold)
    }

    /// "chair ×2 · door ×1", ordered by count then name so the line does not
    /// reshuffle every frame when two classes tie.
    private func classTally(_ detections: [Detection]) -> String {
        let counts = Dictionary(grouping: detections, by: \.className).mapValues(\.count)
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { "\($0.key.replacingOccurrences(of: "_", with: " ")) ×\($0.value)" }
            .joined(separator: " · ")
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            PrimaryButton(title: controller.isRunning ? "Stop" : "Start",
                          symbol: controller.isRunning ? "stop.fill" : "play.fill",
                          tint: controller.isRunning ? Theme.ember : Theme.dawn) {
                if controller.isRunning { controller.stop() } else { controller.start() }
            }
            .accessibilityLabel(controller.isRunning ? "Stop detecting objects" : "Start detecting objects")

            Button {
                controller.announceDetections()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(Theme.icon(18))
                    .frame(width: 58, height: 54)
                    .background(Theme.depth, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.depthLine, lineWidth: 1))
                    .foregroundStyle(controller.isRunning ? Theme.sky : Theme.creamFaint)
            }
            .buttonStyle(.plain)
            .disabled(!controller.isRunning)
            .accessibilityLabel("Speak detected objects")
        }
    }

    private func noticeCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Theme.icon(13))
                .foregroundStyle(Theme.ember)
            Text(message)
                .font(Theme.data(12))
                .foregroundStyle(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ember.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ember.opacity(0.5), lineWidth: 1))
    }

    // MARK: This frame

    private var detectionsPanel: some View {
        Panel(title: "This frame", accent: Theme.sky,
              trailing: controller.isRunning
                ? "\(controller.detections.count) box\(controller.detections.count == 1 ? "" : "es")"
                : nil) {
            VStack(spacing: 8) {
                if controller.detections.isEmpty {
                    Text(controller.isRunning ? "No detections above the threshold." : "Not running.")
                        .font(Theme.data(12))
                        .foregroundStyle(Theme.creamFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(controller.detections.enumerated()), id: \.offset) { _, detection in
                    detectionRow(detection)
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func detectionRow(_ detection: Detection) -> some View {
        let bearing = BearingZone.from(centroidX: detection.box.midX)
        let name = detection.className.replacingOccurrences(of: "_", with: " ")
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(tint(for: detection.className), lineWidth: 2)
                .frame(width: 12, height: 12)
            Text(name)
                .font(Theme.label(14))
                .foregroundStyle(Theme.cream)
            Text(bearing.spokenName)
                .font(Theme.data(11))
                .foregroundStyle(Theme.sky)
            Spacer(minLength: 6)
            ConfidenceBar(value: detection.confidence, tint: tint(for: detection.className))
                .frame(width: 64, height: 6)
            Text(String(format: "%.2f", detection.confidence))
                .font(Theme.data(12))
                .foregroundStyle(detection.confidence < 0.45 ? Theme.ember : Theme.creamDim)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%@, %@, %.0f percent", name, bearing.spokenName,
                                   detection.confidence * 100))
    }

    // MARK: Threshold

    private var thresholdPanel: some View {
        Panel(title: "Confidence threshold", accent: Theme.dawn,
              trailing: String(format: "%.2f", controller.confidenceThreshold)) {
            Slider(value: $controller.confidenceThreshold, in: 0.05...0.95, step: 0.05)
                .tint(Theme.dawn)
                .accessibilityLabel("Confidence threshold")
                .accessibilityValue(String(format: "%.0f percent", controller.confidenceThreshold * 100))
            Text("Assist acts on 0.30. Lower shows what the detector almost found, which tells a class it sees weakly from one it cannot see at all.")
                .font(Theme.data(11))
                .foregroundStyle(Theme.creamFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: What the detector knows

    /// Training instances per class in the merged corpus's train split, from
    /// `results/dataset_report.md`. Duplicated rather than read at runtime for
    /// the same reason `HazardWeight` is: the app and the Python tooling share
    /// no build step. If the corpus is ever rebuilt, change both.
    private static let trainingInstances: [String: Int] = [
        "person": 1248, "chair": 1069, "table": 777, "door": 410,
        "door_glass": 0, "window": 3756, "stairs": 398, "pole": 0,
        "handrail": 0, "wall": 355, "low_obstacle": 1903, "other": 0,
    ]

    private var classesPanel: some View {
        let names = controller.classNames
        let untrained = names.filter { Self.trainingInstances[$0] == 0 }
        return Panel(title: "What it can find", accent: Theme.creamFaint,
                     trailing: "\(names.count - untrained.count) of \(names.count) trained") {
            DisclosureGroup(isExpanded: $showClasses) {
                VStack(spacing: 6) {
                    ForEach(names, id: \.self) { name in
                        let count = Self.trainingInstances[name]
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(tint(for: name), lineWidth: 2)
                                .frame(width: 12, height: 12)
                            Text(name.replacingOccurrences(of: "_", with: " "))
                                .font(Theme.data(12))
                                .foregroundStyle(Theme.cream)
                            Spacer(minLength: 6)
                            if count == 0 {
                                Text("never trained")
                                    .font(Theme.data(10))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Theme.ember.opacity(0.25), in: Capsule())
                                    .foregroundStyle(Theme.ember)
                            } else {
                                Text(count.map { "\($0) examples" } ?? "—")
                                    .font(Theme.data(11))
                                    .foregroundStyle(Theme.creamFaint)
                            }
                        }
                        .opacity(count == 0 ? 0.7 : 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(count == 0
                            ? "\(name.replacingOccurrences(of: "_", with: " ")), never trained"
                            : "\(name.replacingOccurrences(of: "_", with: " ")), \(count.map(String.init) ?? "unknown") training examples")
                    }
                    if !untrained.isEmpty {
                        Text("These classes have no training examples: the only source carrying them was never obtained (§3.3.3). This model cannot report one however close it is — Objective 2's pole captures never once came back as `pole`.")
                            .font(Theme.data(11))
                            .foregroundStyle(Theme.creamFaint)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 9)
            } label: {
                Text(showClasses ? "Hide the class list" : "Show the \(names.count) classes and their training data")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.cream)
            }
            .tint(Theme.sky)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var detectorPanel: some View {
        Panel(title: "Detector", accent: Theme.creamFaint,
              trailing: controller.isRunning ? "locked while running" : nil) {
            // A menu, not a segmented control: five names do not fit across a
            // phone, and the two experimental ones need a word beside them.
            Picker("Detector", selection: $controller.model) {
                ForEach(DetectorVariant.allCases) { variant in
                    Text(variant.isMeasured ? variant.displayName
                                            : "\(variant.displayName) — experimental").tag(variant)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.sky)
            .disabled(controller.isRunning)
            if !controller.model.isMeasured {
                Text("Experimental weights from the retraining experiments. Better on the photograph benchmarks, but both draw boxes on empty floor in a real corridor — \(controller.model == .yolo26nFull ? "this one calls them `door`" : "this one calls them `wall`"). No thesis figure was measured with it.")
                    .font(Theme.data(11))
                    .foregroundStyle(Theme.ember)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Switch to compare detectors on the same scene: the three Objective 1 candidates, and the two retrained ones. Latency figures belong to Benchmark, not to this screen.")
                .font(Theme.data(11))
                .foregroundStyle(Theme.creamFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Class colour

    /// Six hues that stay legible over a camera image, assigned by the class's
    /// index in the model's own list so a class keeps its colour between
    /// frames and between runs. Twelve classes share six hues; the label on
    /// every box is what disambiguates, never the colour.
    private static let classHues: [Color] = [
        Theme.sky,
        Theme.dawn,
        Color(red: 0.600, green: 0.851, blue: 0.494),   // #99D97E
        Theme.ember,
        Color(red: 0.749, green: 0.639, blue: 0.980),   // #BFA3FA
        Theme.cream,
    ]

    private func tint(for className: String) -> Color {
        let index = controller.classNames.firstIndex(of: className) ?? 0
        return Self.classHues[index % Self.classHues.count]
    }
}

/// A thin horizontal meter for one detection's confidence.
private struct ConfidenceBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.depthLine)
                Capsule().fill(tint)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .accessibilityHidden(true)
    }
}
