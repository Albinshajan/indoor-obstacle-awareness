import SwiftUI

/// Four independent tools sharing one app build, one per objective that
/// needed on-device work plus a window onto the detector itself:
///
/// - **Assist** (Objective 3) — the prototype itself: live detection, LiDAR
///   depth sampling, the derived-feature layer and dual audio/haptic feedback.
///   First and default, because it is the deliverable.
/// - **Detect** (Objective 1's detector, seen rather than timed) — every box
///   the fine-tuned model returns, labelled, with no depth, gating or feedback
///   in between. Second because it is what Assist is built on: when Assist
///   says nothing, this shows whether the detector saw anything at all.
/// - **Capture** (Objective 2) — the ground-truth capture tool that produced
///   the 102 tape-measured frames behind `results/objective2_findings.md`.
/// - **Benchmark** (Objective 1) — the per-stage latency harness behind
///   `results/objective1_full_table.md`.
///
/// They do not share state and are never run concurrently: Assist, Detect and
/// Capture each want the camera through an `ARSession`, and Benchmark wants it
/// through `AVCaptureSession` instead.
///
/// **Why the whole app is forced dark.** `Theme` commits to a dark palette for
/// the reasons given there — glare, predictable contrast for the urgency
/// colours, battery on an always-awake OLED screen. Assist paints that ground
/// itself, but Capture and Benchmark were written against the *system*
/// background and use adaptive colours (`.secondary`, `.ultraThinMaterial`,
/// default label colours). Painting a dark ground without also declaring the
/// colour scheme would leave those views drawing near-black text on near-black
/// — so the scheme is declared once, here, and the adaptive colours resolve
/// light-on-dark on their own. Simulator rendering caught the earlier version
/// of this: the mode picker sat on a white strip above the dark Assist
/// interface, which read as an unfinished seam rather than a choice.
struct RootView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case assist = "Assist"
        case detect = "Detect"
        case capture = "Capture"
        case benchmark = "Benchmark"

        var id: String { rawValue }

        /// The objective each tool serves, shown under the name so the build
        /// is self-describing to anyone picking up the phone at a demo.
        var objective: String {
            switch self {
            case .assist: return "prototype"
            case .detect: return "objects"
            case .capture: return "ground truth"
            case .benchmark: return "latency"
            }
        }

        var symbol: String {
            switch self {
            case .assist: return "dot.radiowaves.left.and.right"
            case .detect: return "viewfinder"
            case .capture: return "camera.metering.spot"
            case .benchmark: return "speedometer"
            }
        }
    }

    @State private var mode: Mode = .assist

    var body: some View {
        VStack(spacing: 0) {
            modeStrip
            switch mode {
            case .assist:
                AssistView()
            case .detect:
                DetectView()
            case .capture:
                CaptureView()
            case .benchmark:
                BenchmarkView()
            }
        }
        .background(Theme.night)
        .preferredColorScheme(.dark)
    }

    /// A custom strip rather than a `.segmented` Picker: the system control
    /// cannot be tinted to this palette without fighting it, and the same
    /// button language is already used for the feedback-condition selector, so
    /// reusing it keeps one idiom instead of two.
    private var modeStrip: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { candidate in
                Button { mode = candidate } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 5) {
                            Image(systemName: candidate.symbol)
                                .font(Theme.icon(12, .semibold))
                                .accessibilityHidden(true)
                            Text(candidate.rawValue)
                                .font(Theme.label(14))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        Text(candidate.objective)
                            .font(Theme.data(10))
                            .opacity(0.75)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    // A margin inside the border, so shrink-to-fit engages
                    // before a label touches it rather than after.
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(mode == candidate ? Theme.depth : Color.clear,
                                in: RoundedRectangle(cornerRadius: 11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(mode == candidate ? Theme.dawn : Theme.depthLine,
                                          lineWidth: mode == candidate ? 1.5 : 1)
                    )
                    .foregroundStyle(mode == candidate ? Theme.dawn : Theme.creamFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(candidate.rawValue), \(candidate.objective)")
                .accessibilityAddTraits(mode == candidate ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Theme.night)
        // Four fixed-width items each holding an icon and two lines of label:
        // there is no size past this where "Benchmark" still fits, and at
        // accessibility-extra-large the earlier AX1 cap still truncated it to
        // "Bench...". Capped at xLarge and allowed to shrink-to-fit rather than
        // truncate, because chrome that abbreviates its own labels reads as
        // broken. The fourth tab (Detect) narrowed every item, which is why the
        // floor is 0.65 rather than the 0.75 that sufficed for three. The content views scale far past this -- the status card is
        // uncapped, which is where the budget belongs.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}
