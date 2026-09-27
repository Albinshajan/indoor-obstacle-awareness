import SwiftUI

/// The prototype's visual language.
///
/// **Why a committed dark palette rather than following the system theme.**
/// Every colour here is painted explicitly and the view does not adapt to light
/// mode. Three reasons, in order of weight. A deep ground cuts screen glare,
/// which matters for the large share of the intended users who have low vision
/// and light sensitivity rather than no sight at all. It keeps the urgency
/// colours at consistent contrast ratios instead of letting them land on an
/// unknown background. And on the OLED panel of the target device it costs
/// materially less battery on a screen that stays awake for the whole session.
///
/// **Hope and courage, concretely.** The palette is a dawn: `night` and `depth`
/// are the steadfast dark before it, `dawn` is first light, `ember` the warmth
/// behind it. The intent is a tool that reads as encouraging rather than
/// clinical — this is a mobility aid, and the alarm-panel aesthetic that
/// assistive technology often defaults to is a design choice, not a
/// requirement.
///
/// **The accessibility rule that overrides aesthetics.** No state in this
/// interface is communicated by hue alone. Every urgency level carries a
/// distinct symbol and a distinct number of filled pips alongside its colour,
/// because roughly one in twelve men has a colour-vision deficiency and
/// because this app's users are specifically people whose sight cannot be
/// assumed. Colour is the fastest of the three channels, never the only one.
enum Theme {

    // MARK: Palette

    static let night = Color(red: 0.055, green: 0.106, blue: 0.165)   // #0E1B2A
    static let depth = Color(red: 0.090, green: 0.188, blue: 0.290)   // #17304A
    static let depthLine = Color(red: 0.149, green: 0.271, blue: 0.396)

    static let dawn = Color(red: 0.961, green: 0.647, blue: 0.141)    // #F5A524
    static let ember = Color(red: 0.886, green: 0.349, blue: 0.231)   // #E2593B
    static let sky = Color(red: 0.498, green: 0.769, blue: 0.839)     // #7FC4D6

    static let cream = Color(red: 0.969, green: 0.945, blue: 0.894)   // #F7F1E4
    static let creamDim = Color(red: 0.706, green: 0.729, blue: 0.769)
    static let creamFaint = Color(red: 0.494, green: 0.541, blue: 0.608)

    static let halt = Color(red: 0.957, green: 0.204, blue: 0.259)    // #F43442

    // MARK: Type

    /// **Every font here scales with the reader's Larger Text setting**, by
    /// resolving a nominal point size onto the nearest `Font.TextStyle` rather
    /// than pinning it. That is not a nicety in this app. `.system(size:)`
    /// produces a fixed size that ignores Dynamic Type entirely, so the first
    /// version of this file rendered a 12pt caption at 12pt for a user who had
    /// already turned their text size up — making the interface least legible
    /// for precisely the people it exists for. The sizes at the call sites are
    /// kept as design intent and read as "about this big at the default
    /// setting".
    private static func style(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2      // 11
        case ..<12.5: return .caption       // 12
        case ..<14.5: return .footnote      // 13
        case ..<16.5: return .subheadline   // 15
        case ..<18.5: return .body          // 17
        case ..<21:   return .title3        // 20
        case ..<28:   return .title2        // 22
        default:      return .title         // 28
        }
    }

    /// Numbers. Tabular so the digits do not shuffle as the value changes
    /// thirty times a second, which is otherwise the most distracting thing on
    /// the screen.
    ///
    /// Above the largest text style there is nothing to resolve onto, so a
    /// display size stays nominal — the one call site that needs it (the
    /// distance readout) wraps its size in `@ScaledMetric` so it still grows.
    static func readout(_ size: CGFloat) -> Font {
        size >= 34
            ? .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
            : .system(style(for: size), design: .rounded).weight(.semibold).monospacedDigit()
    }
    static func label(_ size: CGFloat) -> Font {
        size >= 34
            ? .system(size: size, weight: .semibold, design: .rounded)
            : .system(style(for: size), design: .rounded).weight(.semibold)
    }
    static func data(_ size: CGFloat) -> Font {
        .system(style(for: size), design: .monospaced)
    }
    /// A weighted variant for symbols and emphasis, replacing the bare
    /// `.system(size:weight:)` calls that did not scale.
    static func icon(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(style(for: size)).weight(weight)
    }
}

// MARK: - Urgency presentation

/// How an urgency band is shown. Colour, symbol and pip count are three
/// independent encodings of the same value; see `Theme`'s note on why.
extension UrgencyLevel {
    var tint: Color {
        switch self {
        case .none: return Theme.sky
        case .low: return Theme.dawn
        case .medium: return Theme.ember
        case .high: return Theme.halt
        }
    }

    /// Distinct shapes, not just distinct colours — and they escalate in
    /// visual weight the way the levels do.
    var symbol: String {
        switch self {
        case .none: return "checkmark.circle.fill"
        case .low: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "hand.raised.fill"
        }
    }

    var filledPips: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    /// Shown on screen. `spokenName` in `ObstacleDecision.swift` stays the
    /// terser form used for speech and for the CSV.
    var displayName: String {
        switch self {
        case .none: return "Clear"
        case .low: return "Ahead"
        case .medium: return "Close"
        case .high: return "Stop"
        }
    }
}

// MARK: - Components

/// Three pips, filled to the urgency level. The redundant encoding that works
/// without colour vision and at a glance.
struct UrgencyPips: View {
    let level: UrgencyLevel
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: size * 0.55) {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < level.filledPips ? level.tint : Theme.depthLine)
                    .frame(width: size, height: size * 1.9)
            }
        }
        .accessibilityHidden(true)   // the parent card speaks the level in words
    }
}

/// A titled panel. Border and fill are spent only where a real boundary
/// exists, so the hierarchy stays readable rather than every block looking
/// like a separate object.
struct Panel<Content: View>: View {
    let title: String
    var accent: Color = Theme.sky
    var trailing: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(Theme.label(11))
                    .tracking(1.2)
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(Theme.data(11))
                        .foregroundStyle(Theme.creamFaint)
                }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.depth.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.depthLine, lineWidth: 1)
        )
    }
}

/// One label/value line of the decision trace.
struct TraceRow: View {
    let name: String
    let value: String
    var emphasised = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(Theme.data(12))
                .foregroundStyle(Theme.creamFaint)
            Spacer(minLength: 10)
            Text(value)
                .font(emphasised ? Theme.readout(14) : Theme.data(12))
                .foregroundStyle(emphasised ? Theme.dawn : Theme.cream)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(value)")
    }
}

/// The primary action. Large, unambiguous, and labelled with what will happen
/// rather than with the state it is in.
struct PrimaryButton: View {
    let title: String
    let symbol: String
    var tint: Color = Theme.dawn
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(Theme.icon(17))
                    .accessibilityHidden(true)
                Text(title)
                    .font(Theme.label(18))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)          // comfortably past the 44pt minimum target
            .background(tint, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Theme.night)
        }
        .buttonStyle(.plain)
    }
}
