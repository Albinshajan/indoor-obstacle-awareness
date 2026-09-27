import ARKit
import SwiftUI

/// The prototype's screen.
///
/// Two audiences, which is what shapes the layout. A user of the system needs
/// one thing answered immediately — *what is near me and how close* — so that
/// answer is the largest element on the screen and is also the only part
/// VoiceOver reads as a single sentence. An examiner needs to see that the
/// derived-feature layer computes what Chapter 3 says it computes, so every
/// intermediate quantity stays available underneath, in a trace that can be
/// collapsed out of the way. A screenshot showing only "WARNING" would
/// evidence almost nothing (§4.3.2).
///
/// Accessibility is not a pass over this file, it is the reason for several of
/// its decisions: the status card is one combined VoiceOver element with a
/// written-out summary rather than nine separately-focusable labels; urgency
/// carries a symbol and a pip count as well as a colour; controls are 54pt
/// tall rather than the 44pt minimum; and the palette is committed dark to hold
/// contrast rather than inheriting an unknown ground. See `Theme`.
struct AssistView: View {
    @StateObject private var controller = AssistController()
    @State private var showTrace = false
    @State private var showTracks = false

    /// The distance readout sits above the largest text style, so its size is
    /// scaled here rather than resolved onto one. `relativeTo: .largeTitle`
    /// keeps it growing with Larger Text without tracking body copy, which
    /// would make it absurd at accessibility sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var readoutSize: CGFloat = 62

    private let model = UrgencyModel.default

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                preview
                ScrollView {
                    VStack(spacing: 12) {
                        statusCard
                        controls
                        if let message = controller.statusMessage {
                            noticeCard(message)
                        }
                        conditionPanel
                        tracePanel
                        tracksPanel
                        detectorPanel
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .onDisappear { controller.stop() }
    }

    /// A restrained dawn: the ground warms very slightly toward the bottom of
    /// the screen. One gesture, no gradient behind any text that has to be read.
    private var backdrop: some View {
        LinearGradient(colors: [Theme.night, Theme.night, Theme.depth.opacity(0.75)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: Camera preview

    private var preview: some View {
        ZStack(alignment: .topLeading) {
            Theme.night
            ARPreviewView(session: controller.session)
            // `ARSCNView` is opaque and renders white until a camera feed
            // arrives, so painting a ground *behind* it does nothing -- the
            // white covers it. Overlaying instead, and only while the session
            // is not running, cannot interfere with the live feed: on a real
            // device this placeholder disappears the moment Start is pressed.
            // Left as a white void it read as a rendering failure rather than
            // an idle state.
            if !controller.isRunning {
                ZStack {
                    Theme.night
                    VStack(spacing: 8) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(Theme.icon(22, .regular))
                            .foregroundStyle(Theme.depthLine)
                        Text("Camera preview")
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.creamFaint)
                        Text(controller.depthSupported
                             ? "Detected obstacles are outlined here once running."
                             : "Needs a LiDAR-equipped iPhone.")
                            .font(Theme.data(11))
                            .foregroundStyle(Theme.creamFaint)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                // Same flattening problem, same fix: collapse then hide.
                // This placeholder only describes the preview, and the status
                // card already says "Not running".
                .accessibilityElement(children: .ignore)
                .accessibilityHidden(true)
            }
            GeometryReader { geometry in
                ForEach(controller.obstacles) { obstacle in
                    boxOverlay(for: obstacle, in: geometry.size)
                }
            }
            hud
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.depthLine).frame(height: 1)
        }
        .accessibilityHidden(true)   // the status card carries this in words
    }

    private func boxOverlay(for obstacle: Obstacle, in size: CGSize) -> some View {
        let rect = Self.viewRect(for: obstacle.box, in: size)
        return RoundedRectangle(cornerRadius: 3)
            .strokeBorder(obstacle.level.tint,
                          style: StrokeStyle(lineWidth: obstacle.isConfirmed ? 2.5 : 1,
                                             dash: obstacle.isConfirmed ? [] : [4, 3]))
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topLeading) {
                Text(Self.label(for: obstacle))
                    .font(Theme.data(10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(obstacle.level.tint, in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(Theme.night)
                    .offset(y: -15)
            }
            .position(x: rect.midX, y: rect.midY)
            // A gated track is drawn dashed and faded rather than hidden, so
            // the announcement gate is visible instead of looking like a missed
            // detection. It is not driving feedback.
            .opacity(obstacle.isConfirmed ? 1 : 0.5)
    }

    private var hud: some View {
        HStack(spacing: 10) {
            Label(controller.isRunning ? "\(controller.processedFPS, specifier: "%.0f") fps" : "stopped",
                  systemImage: controller.isRunning ? "waveform" : "pause.fill")
            Text("·")
            Text(Self.thermalName(controller.thermalState))
                .foregroundStyle(Self.thermalTint(controller.thermalState))
            if controller.isRunning && !controller.depthSupported {
                Text("· no depth").foregroundStyle(Theme.halt)
            }
            // Which detector is running, always visible. Without this a picker
            // left on an experimental model looks like a broken prototype:
            // on 26 September a session that ended on yolov8n read as "it has
            // stopped warning me", when the default model had issued "stop" in
            // 441 of the 446 frames where something came within 0.8 m.
            Text("·")
            Text(controller.model.displayName)
                .foregroundStyle(controller.model.isMeasured ? Theme.creamDim : Theme.ember)
            if !controller.model.isMeasured {
                Text("exp").foregroundStyle(Theme.ember)
            }
        }
        .font(Theme.data(11))
        .foregroundStyle(Theme.creamDim)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.night.opacity(0.72), in: Capsule())
        .padding(12)
        // `.accessibilityHidden(true)` ALONE DOES NOT WORK HERE, and the
        // combination below is not belt-and-braces -- it is the fix.
        //
        // Measured with `UITests/AccessibilityTreeTests`: with only
        // `.accessibilityHidden(true)` on this HStack (and again on the preview
        // container above it) every child stayed directly queryable, so a
        // reader still walked through "Pause", "stopped", "." and "nominal"
        // before reaching the status card. SwiftUI flattens a
        // layout-only container's children out to the enclosing level and the
        // hidden flag does not follow them. Collapsing the subtree into a
        // single element first, with `children: .ignore`, gives the modifier
        // one thing to hide. All of this is glanceable telemetry for a sighted
        // operator and all of it is already in the status card in words.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }

    // MARK: The answer — largest thing on the screen

    private var top: Obstacle? {
        controller.obstacles.first { $0.isConfirmed && $0.distance != nil }
    }

    private var statusCard: some View {
        let obstacle = top
        let level = obstacle?.level ?? .none
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: level.symbol)
                    .font(Theme.icon(20))
                    .foregroundStyle(level.tint)
                    .accessibilityHidden(true)
                Text(level.displayName)
                    .font(Theme.label(15))
                    .tracking(0.8)
                    .foregroundStyle(level.tint)
                Spacer(minLength: 8)
                UrgencyPips(level: level)
            }

            if let obstacle, let distance = obstacle.distance {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", distance))
                        .font(Theme.readout(readoutSize))
                        .foregroundStyle(Theme.cream)
                    Text("m")
                        .font(Theme.label(22))
                        .foregroundStyle(Theme.creamDim)
                }
                HStack(spacing: 8) {
                    Text(obstacle.className.replacingOccurrences(of: "_", with: " "))
                        .font(Theme.label(19))
                        .foregroundStyle(Theme.cream)
                    bearingChip(obstacle.bearing)
                    if let rate = obstacle.closingRate, rate > 0.05 {
                        Text(String(format: "closing %.1f m/s", rate))
                            .font(Theme.data(12))
                            .foregroundStyle(Theme.dawn)
                    }
                }
            } else {
                Text(controller.isRunning ? "Nothing confirmed in view" : "Not running")
                    .font(Theme.label(22))
                    .foregroundStyle(Theme.creamDim)
                Text(controller.isRunning
                     ? "Sweep slowly. A detection must appear in 3 of 5 frames before it is announced."
                     : "Press Start to begin detecting obstacles.")
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
                .strokeBorder(level.tint.opacity(obstacle == nil ? 0.25 : 0.7), lineWidth: 1.5)
        )
        // One element, one sentence. Nine separate labels here would make
        // VoiceOver read the card for longer than the obstacle takes to reach.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenStatus)
    }

    private var spokenStatus: String {
        let detector = controller.model.isMeasured ? "" : " Experimental detector \(controller.model.displayName)."
        guard controller.isRunning else {
            return "Stopped. Press Start to begin detecting obstacles." + detector
        }
        guard let obstacle = top, let distance = obstacle.distance else {
            return "Nothing confirmed in view." + detector
        }
        let name = obstacle.className.replacingOccurrences(of: "_", with: " ")
        var phrase = String(format: "%@. %@ %@, %.1f metres",
                            obstacle.level.displayName, name,
                            obstacle.bearing.spokenName, distance)
        if let rate = obstacle.closingRate, rate > 0.05 {
            phrase += String(format: ", closing at %.1f metres per second", rate)
        }
        return phrase + detector
    }

    private func bearingChip(_ bearing: BearingZone) -> some View {
        HStack(spacing: 4) {
            Image(systemName: bearing == .left ? "arrow.left"
                            : bearing == .right ? "arrow.right" : "arrow.up")
                .font(Theme.icon(11))
                .accessibilityHidden(true)
            Text(bearing.spokenName)
                .font(Theme.label(12))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.depthLine, in: Capsule())
        .foregroundStyle(Theme.sky)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            PrimaryButton(title: controller.isRunning ? "Stop" : "Start",
                          symbol: controller.isRunning ? "stop.fill" : "play.fill",
                          tint: controller.isRunning ? Theme.ember : Theme.dawn) {
                if controller.isRunning { controller.stop() }
                else { controller.start(logDirectory: Self.logDirectory()) }
            }
            .accessibilityLabel(controller.isRunning ? "Stop detecting" : "Start detecting")

            Button {
                controller.announceTopObstacle()
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
            .accessibilityLabel("Speak nearest obstacle")
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

    // MARK: Feedback condition

    private var conditionPanel: some View {
        Panel(title: "Feedback condition", accent: Theme.dawn) {
            HStack(spacing: 8) {
                ForEach(AssistController.FeedbackMode.allCases) { mode in
                    Button { controller.mode = mode } label: {
                        VStack(spacing: 5) {
                            Image(systemName: symbol(for: mode))
                                .font(Theme.icon(15, .semibold))
                                .accessibilityHidden(true)
                            Text(mode.displayName)
                                .font(Theme.label(11))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(controller.mode == mode ? Theme.dawn : Theme.depthLine.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 11))
                        .foregroundStyle(controller.mode == mode ? Theme.night : Theme.creamDim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.displayName)
                    .accessibilityAddTraits(controller.mode == mode ? [.isSelected] : [])
                }
            }
            Text("Switchable at runtime so RQ3's audio-only versus audio-plus-haptic comparison is built in. Counterbalance the order if the study is run.")
                .font(Theme.data(11))
                .foregroundStyle(Theme.creamFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func symbol(for mode: AssistController.FeedbackMode) -> String {
        switch mode {
        case .audio: return "speaker.wave.2.fill"
        case .haptic: return "waveform.path"
        case .both: return "square.stack.3d.up.fill"
        }
    }

    // MARK: Decision trace — the Chapter 4 evidence

    private var tracePanel: some View {
        Panel(title: "Decision trace", accent: Theme.sky,
              trailing: String(format: "%.2f ms dispatch", controller.lastFeedbackMilliseconds)) {
            DisclosureGroup(isExpanded: $showTrace) {
                if let obstacle = top, let distance = obstacle.distance {
                    let rate = obstacle.closingRate ?? 0
                    let hazard = HazardWeight.forClass(obstacle.className)
                    let proximity = model.proximity(distance: distance)
                    let ttc = model.timeToContactTerm(distance: distance, closingRate: rate)
                    let gain = model.hazardFloor + (1 - model.hazardFloor) * hazard
                    VStack(spacing: 7) {
                        TraceRow(name: "distance", value: String(format: "%.2f m", distance))
                        TraceRow(name: "closing rate",
                                 value: obstacle.closingRate.map { String(format: "%+.2f m/s", $0) } ?? "—")
                        TraceRow(name: "time to contact",
                                 value: obstacle.timeToContact.map { String(format: "%.1f s", $0) } ?? "—")
                        Divider().overlay(Theme.depthLine)
                        TraceRow(name: "proximity", value: String(format: "%.3f", proximity))
                        TraceRow(name: String(format: "+ closing × %.2f", model.timeToContactBoost),
                                 value: String(format: "%.3f", ttc * model.timeToContactBoost))
                        TraceRow(name: String(format: "hazard gain (w %.1f)", hazard),
                                 value: String(format: "× %.2f", gain))
                        Divider().overlay(Theme.depthLine)
                        TraceRow(name: "urgency", value: String(format: "%.3f", obstacle.urgency), emphasised: true)
                        TraceRow(name: "gated level", value: obstacle.level.displayName)
                    }
                    .padding(.top, 9)
                } else {
                    Text("No confirmed obstacle to trace.")
                        .font(Theme.data(12))
                        .foregroundStyle(Theme.creamFaint)
                        .padding(.top, 9)
                }
            } label: {
                Text(showTrace ? "Hide the derived features" : "Show how urgency was computed")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.cream)
            }
            .tint(Theme.sky)
            // Capped, unlike the status card. These are label/value rows in a
            // fixed two-column grid; past roughly AX2 they stop being rows and
            // start being overlapping text. The card that actually answers
            // "how close is it" scales without limit, which is the right place
            // to spend the budget.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }

    // MARK: Tracks

    private var tracksPanel: some View {
        let confirmed = controller.obstacles.filter(\.isConfirmed).count
        let gated = controller.obstacles.count - confirmed
        return Panel(title: "Tracks", accent: Theme.sky,
                     trailing: "\(confirmed) driving · \(gated) gated") {
            DisclosureGroup(isExpanded: $showTracks) {
                VStack(spacing: 6) {
                    if controller.obstacles.isEmpty {
                        Text(controller.isRunning ? "No detections in view." : "Not running.")
                            .font(Theme.data(12))
                            .foregroundStyle(Theme.creamFaint)
                    }
                    ForEach(controller.obstacles) { obstacle in
                        HStack(spacing: 8) {
                            Circle().fill(obstacle.level.tint).frame(width: 7, height: 7)
                            Text(obstacle.className)
                                .font(Theme.data(12))
                                .foregroundStyle(Theme.cream)
                            Spacer(minLength: 6)
                            Text(obstacle.distance.map { String(format: "%.2fm", $0) } ?? "—")
                                .font(Theme.data(12))
                                .foregroundStyle(Theme.creamDim)
                            Text(String(format: "c%.2f", obstacle.confidence))
                                .font(Theme.data(11))
                                .foregroundStyle(obstacle.confidence < 0.45 ? Theme.ember : Theme.creamFaint)
                            if !obstacle.isConfirmed {
                                Text("gated")
                                    .font(Theme.data(10))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Theme.depthLine, in: Capsule())
                                    .foregroundStyle(Theme.creamFaint)
                            }
                        }
                        .opacity(obstacle.isConfirmed ? 1 : 0.55)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 9)
            } label: {
                Text("Gated rows are shown, not acted on")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.cream)
            }
            .tint(Theme.sky)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
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
            Text("yolo26n by default — Objective 1's winner on accuracy, size and sustained latency, and the detector every distance, latency and thermal figure in the thesis was measured with.")
                .font(Theme.data(11))
                .foregroundStyle(Theme.creamFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Helpers

    /// Map a fraction-of-frame box into the preview's coordinates.
    ///
    /// `ARSCNView` renders the camera feed aspect-**filled**, so on a tall
    /// phone screen a 3:4 frame is scaled to the view's height and cropped
    /// horizontally. Mapping fractions straight onto the view's bounds would
    /// place every box too far left and too narrow — correct-looking enough to
    /// pass a glance, wrong enough to make a Chapter 4 figure misleading.
    static func viewRect(for box: CGRect, in size: CGSize) -> CGRect {
        let sourceAspect: CGFloat = 3.0 / 4.0   // upright frame: 1440 x 1920
        let viewAspect = size.width / max(size.height, 1)
        var drawnWidth = size.width
        var drawnHeight = size.height
        if viewAspect < sourceAspect {
            drawnWidth = size.height * sourceAspect
        } else {
            drawnHeight = size.width / sourceAspect
        }
        let offsetX = (size.width - drawnWidth) / 2
        let offsetY = (size.height - drawnHeight) / 2
        return CGRect(x: offsetX + box.minX * drawnWidth,
                      y: offsetY + box.minY * drawnHeight,
                      width: box.width * drawnWidth,
                      height: box.height * drawnHeight)
    }

    static func label(for obstacle: Obstacle) -> String {
        let distance = obstacle.distance.map { String(format: " %.2fm", $0) } ?? ""
        return "\(obstacle.className)\(distance)"
    }

    static func thermalName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    /// Thermal state earns semantic colour, which is separate from the
    /// palette's accent: §4.3.4 measured `serious` arriving in two minutes, so
    /// this is a reading worth noticing rather than decoration.
    static func thermalTint(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return Theme.creamDim
        case .fair: return Theme.dawn
        case .serious: return Theme.ember
        case .critical: return Theme.halt
        @unknown default: return Theme.creamDim
        }
    }

    static func logDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
