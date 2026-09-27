import CoreHaptics
import Foundation

/// The haptic channel: urgency -> (intensity, sharpness, pulse rate).
///
/// CLAUDE.md section 7 names this mapping as Objective 3's contribution, and
/// the reviewed literature is the reason -- Chapter 2's Domain C finding is
/// that the haptic channel's own contribution is rarely isolated, and most
/// systems that vibrate at all treat vibration as a binary alert. Encoding a
/// continuous urgency scalar into three simultaneously-varying tactile
/// dimensions is the thing being built here.
///
/// Implemented with one looping `CHHapticAdvancedPatternPlayer` rather than by
/// scheduling a fresh pattern per frame. That matters for a reason that is not
/// obvious: pattern construction and scheduling cost real time on the audio
/// thread, and doing it at frame rate produces audible/tactile glitching as
/// players are torn down mid-playback. Instead the pattern is built once as a
/// short pulse inside a loop, and all three dimensions are then steered on the
/// live player -- intensity and sharpness as dynamic parameters, pulse rate by
/// moving the loop's end point. Nothing is rebuilt while feedback is running.
final class HapticFeedbackEngine {

    /// Base event values. Dynamic parameters steer *relative* to these, so
    /// they are set to the top of the intensity range and the middle of the
    /// sharpness range, giving the controls room in both directions.
    private static let baseIntensity: Float = 1.0
    private static let baseSharpness: Float = 0.5
    /// Length of the pulse itself. The gap that follows it is what varies.
    private static let pulseDuration: TimeInterval = 0.12
    /// Loop period at zero and full urgency: roughly 1.1 Hz up to about 7 Hz.
    private static let slowestPeriod: TimeInterval = 0.90
    private static let fastestPeriod: TimeInterval = 0.14

    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var isPlaying = false
    /// Last values actually sent, so an unchanged frame sends nothing.
    private var lastIntensity: Float = -1
    private var lastSharpness: Float = -1
    private var lastPeriod: TimeInterval = -1

    private(set) var isSupported = false
    private(set) var lastError: String?

    init() {
        isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: Lifecycle

    func start() {
        guard isSupported else {
            lastError = "This device has no Core Haptics support (iPhone 8 and later only)."
            return
        }
        guard engine == nil else {
            restartIfNeeded()
            return
        }
        do {
            let engine = try CHHapticEngine()
            // Keeps the haptic engine out of the audio session entirely, so it
            // cannot interfere with the earcon path in `AudioFeedbackEngine`.
            engine.playsHapticsOnly = true
            // The system stops the engine on interruptions (a call, going to
            // background). Without these handlers feedback dies silently and
            // stays dead, which in a safety-adjacent system is the worst
            // available failure mode -- the user cannot tell the difference
            // between "no obstacle" and "no haptics".
            engine.stoppedHandler = { [weak self] _ in
                self?.isPlaying = false
            }
            engine.resetHandler = { [weak self] in
                guard let self else { return }
                self.player = nil
                self.isPlaying = false
                self.resetSentValues()
                try? self.engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            lastError = "Could not start the haptic engine: \(error.localizedDescription)"
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        isPlaying = false
        resetSentValues()
        engine?.stop()
        engine = nil
    }

    /// Silence the channel without tearing the engine down, so the next
    /// obstacle does not pay engine start-up cost.
    func silence() {
        guard isPlaying else { return }
        try? player?.stop(atTime: CHHapticTimeImmediate)
        isPlaying = false
        resetSentValues()
    }

    // MARK: The mapping

    /// Drive the channel from an urgency score in 0...1.
    ///
    /// All three dimensions rise together deliberately. They are not
    /// independent codes the user has to learn separately -- they are one
    /// perceptual dimension ("how alarming") expressed redundantly, which is
    /// the design choice most likely to survive the fact that tactile
    /// discrimination through a hand-held phone case is poor. Tokmurziyev's
    /// 81.3% across thirteen distinguishable patterns is an upper bound
    /// obtained with a dedicated wearable actuator, not a phone in a pocket.
    func update(urgency: Double) {
        guard isSupported, engine != nil else { return }
        guard urgency > 0.02 else {
            silence()
            return
        }

        let u = Float(max(0, min(1, urgency)))
        let intensity = 0.25 + 0.75 * u
        let sharpness = 0.20 + 0.80 * u
        let period = Self.slowestPeriod + (Self.fastestPeriod - Self.slowestPeriod) * Double(u)

        do {
            if player == nil {
                player = try makePlayer()
            }
            guard let player else { return }

            if !isPlaying {
                try player.start(atTime: CHHapticTimeImmediate)
                isPlaying = true
            }

            // Dynamic parameter semantics differ between the two controls and
            // this is easy to get backwards: intensity control is a
            // *multiplier* over 0...1 (default 1), sharpness control is an
            // *offset* over -1...1 (default 0). Hence the subtraction.
            var parameters: [CHHapticDynamicParameter] = []
            if abs(intensity - lastIntensity) > 0.01 {
                parameters.append(CHHapticDynamicParameter(parameterID: .hapticIntensityControl,
                                                           value: intensity,
                                                           relativeTime: 0))
                lastIntensity = intensity
            }
            if abs(sharpness - lastSharpness) > 0.01 {
                parameters.append(CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                                           value: sharpness - Self.baseSharpness,
                                                           relativeTime: 0))
                lastSharpness = sharpness
            }
            if !parameters.isEmpty {
                try player.sendParameters(parameters, atTime: CHHapticTimeImmediate)
            }

            // Pulse rate is quantised to 20 ms steps before being applied.
            // Without that, a score drifting by a thousandth rewrites the loop
            // boundary every frame, which audibly stutters the pulse train.
            if abs(period - lastPeriod) > 0.02 {
                player.loopEnd = period
                lastPeriod = period
            }
        } catch {
            lastError = "Haptic playback failed: \(error.localizedDescription)"
        }
    }

    // MARK: Pattern construction

    private func makePlayer() throws -> CHHapticAdvancedPatternPlayer {
        guard let engine else { throw CHHapticError(.engineNotRunning) }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Self.baseIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: Self.baseSharpness),
            ],
            relativeTime: 0,
            duration: Self.pulseDuration
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makeAdvancedPlayer(with: pattern)
        player.loopEnabled = true
        player.loopEnd = Self.slowestPeriod
        return player
    }

    private func restartIfNeeded() {
        guard let engine else { return }
        try? engine.start()
    }

    private func resetSentValues() {
        lastIntensity = -1
        lastSharpness = -1
        lastPeriod = -1
    }
}
