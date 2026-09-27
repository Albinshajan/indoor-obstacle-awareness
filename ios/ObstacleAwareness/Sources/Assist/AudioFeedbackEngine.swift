import AVFoundation
import Foundation

/// The audio channel: pre-rendered earcons panned by bearing zone, plus
/// on-demand speech for object identity.
///
/// The split is a hard requirement from CLAUDE.md section 7 and it is worth
/// restating why, because the obvious implementation is the wrong one.
/// `AVSpeechSynthesizer`'s *first* utterance costs hundreds of milliseconds
/// before any sound is produced. Putting speech in the per-frame feedback path
/// would therefore dominate the pipeline latency this project exists to
/// measure -- Objective 1's whole detection pipeline runs in about 13 ms, so a
/// single spoken word would swamp it by an order of magnitude and the reported
/// latency would be a property of the speech synthesiser rather than of the
/// detector. Earcons are synthesised into PCM buffers up front, at engine
/// start, and playing one afterwards is a buffer schedule and nothing more.
/// Speech stays reserved for identity on demand, dispatched off the processing
/// queue, and is never timed as part of the feedback stage.
final class AudioFeedbackEngine {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let synthesiser = AVSpeechSynthesizer()
    private let speechQueue = DispatchQueue(label: "assist.speech", qos: .utility)

    /// One pre-rendered buffer per urgency level.
    private var earcons: [UrgencyLevel: AVAudioPCMBuffer] = [:]
    private var isConfigured = false

    private(set) var lastError: String?

    // MARK: Lifecycle

    func start() {
        do {
            // `.mixWithOthers` is not a detail. A real BVI user runs VoiceOver
            // continuously, and a category that interrupts other audio would
            // silence their screen reader -- turning an assistive aid into an
            // accessibility regression. Mixing is a partial mitigation only;
            // the two channels still compete for attention, which is recorded
            // in the limitations rather than claimed as solved.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            lastError = "Could not configure the audio session: \(error.localizedDescription)"
        }

        guard !isConfigured else {
            restartIfNeeded()
            return
        }

        // Mono source into a stereo mixer: that is what makes `player.pan`
        // meaningful. Connecting a pre-panned stereo buffer would leave the
        // mixer nothing to place.
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            lastError = "Could not create the audio format."
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: monoFormat)
        renderEarcons(format: monoFormat)

        do {
            try engine.start()
            isConfigured = true
        } catch {
            lastError = "Could not start the audio engine: \(error.localizedDescription)"
        }
    }

    func stop() {
        player.stop()
        engine.stop()
        synthesiser.stopSpeaking(at: .immediate)
        isConfigured = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: Earcons

    /// Play the earcon for a level, placed by bearing.
    func play(level: UrgencyLevel, bearing: BearingZone) {
        guard isConfigured, level != .none, let buffer = earcons[level] else { return }
        if !engine.isRunning { restartIfNeeded() }
        player.pan = bearing.pan
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    /// Synthesise the three earcons once, into buffers.
    ///
    /// Pitch rises and duration shortens with urgency: both are conventional
    /// alarm-design cues, so the mapping does not have to be taught. `high`
    /// gets two short bursts instead of one long tone -- a repeated onset
    /// reads as more insistent than a sustained tone of the same energy, and
    /// onsets are also what survives a noisy corridor.
    private func renderEarcons(format: AVAudioFormat) {
        earcons[.low] = makeTone(format: format, frequency: 440, bursts: [0.090])
        earcons[.medium] = makeTone(format: format, frequency: 660, bursts: [0.070])
        earcons[.high] = makeTone(format: format, frequency: 880, bursts: [0.055, 0.055])
    }

    /// Build a PCM buffer of one or more sine bursts separated by short gaps.
    ///
    /// Each burst gets a raised-cosine attack and release. Without an envelope
    /// a tone that starts or stops mid-cycle produces a step discontinuity,
    /// which is audible as a click on every single earcon -- and at several
    /// earcons a second that click becomes the dominant sound.
    private func makeTone(format: AVAudioFormat, frequency: Double, bursts: [Double]) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let gap = 0.045
        let totalSeconds = bursts.reduce(0, +) + gap * Double(max(0, bursts.count - 1))
        let frameCount = AVAudioFrameCount(totalSeconds * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for i in 0..<Int(frameCount) { channel[i] = 0 }

        let rampSeconds = 0.008
        var cursor = 0
        for (index, burst) in bursts.enumerated() {
            let burstFrames = Int(burst * sampleRate)
            let rampFrames = max(1, Int(rampSeconds * sampleRate))
            for n in 0..<burstFrames {
                let global = cursor + n
                guard global < Int(frameCount) else { break }
                let phase = 2.0 * Double.pi * frequency * Double(n) / sampleRate
                // Raised-cosine (Hann) attack and release, flat in between.
                var envelope = 1.0
                if n < rampFrames {
                    envelope = 0.5 * (1 - cos(Double.pi * Double(n) / Double(rampFrames)))
                } else if n > burstFrames - rampFrames {
                    let remaining = max(0, burstFrames - n)
                    envelope = 0.5 * (1 - cos(Double.pi * Double(remaining) / Double(rampFrames)))
                }
                channel[global] = Float(sin(phase) * envelope * 0.7)
            }
            cursor += burstFrames
            if index < bursts.count - 1 { cursor += Int(gap * sampleRate) }
        }
        return buffer
    }

    // MARK: Speech, on demand only

    /// Speak an obstacle's identity. Called from a button, never per frame.
    ///
    /// Dispatched off the caller's queue because even queuing an utterance
    /// touches the synthesiser's internals, and the caller here is the video
    /// processing queue.
    func speak(_ phrase: String) {
        speechQueue.async { [weak self] in
            guard let self else { return }
            self.synthesiser.stopSpeaking(at: .word)
            let utterance = AVSpeechUtterance(string: phrase)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.volume = 1.0
            self.synthesiser.speak(utterance)
        }
    }

    /// A one-line description of the most urgent obstacle: class, bearing,
    /// distance. Kept here so the phrasing has a single definition.
    static func phrase(for obstacle: Obstacle) -> String {
        let name = obstacle.className.replacingOccurrences(of: "_", with: " ")
        guard let distance = obstacle.distance else {
            return "\(name) \(obstacle.bearing.spokenName)"
        }
        return String(format: "%@ %@, %.1f metres", name, obstacle.bearing.spokenName, distance)
    }

    private func restartIfNeeded() {
        guard isConfigured, !engine.isRunning else { return }
        try? engine.start()
    }
}
