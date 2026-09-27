import CoreGraphics
import Foundation

/// Frame-to-frame association, closing-rate estimation and the announcement
/// gate. Pure Swift, no framework dependency, for the same reason as
/// `ObstacleDecision.swift`.
///
/// Why any of this exists: a per-frame detector drops objects it found in the
/// previous frame perfectly routinely. Driving haptics or speech straight off
/// raw per-frame detections produces feedback that stutters on and off several
/// times a second, which CLAUDE.md section 7 flags as simply unusable -- and
/// which no amount of detector accuracy fixes, because the fix is temporal,
/// not visual. It is also the only way to get a closing rate at all: distance
/// is a per-frame quantity, but *approach speed* only exists across frames.
final class ObstacleTracker {

    // MARK: Tuning

    struct Configuration {
        /// Minimum IoU for a detection to continue an existing track. Low
        /// enough to survive a fast walking pan, high enough not to merge two
        /// chairs side by side.
        var matchIoU: Double = 0.25
        /// N-of-M confirmation: `minHits` detections within the last
        /// `windowLength` frames before a track may drive feedback.
        var minHits: Int = 3
        var windowLength: Int = 5
        /// Consecutive misses tolerated before a confirmed track is dropped.
        /// Deliberately larger than the confirmation window: slow to trust,
        /// slower to forget, so a briefly occluded obstacle keeps warning.
        var maxMisses: Int = 8
        /// Samples older than this are ignored when fitting the closing rate.
        var closingRateWindow: TimeInterval = 0.6
        /// Minimum samples in the window before a closing rate is reported.
        var minSamplesForRate: Int = 3
        /// How far a level must fall below its own rising threshold before the
        /// gate lets it drop. Escalation is immediate; de-escalation is not.
        var levelFallMargin: Double = 0.08
        /// Minimum gap between spoken announcements for one track.
        var reannounceInterval: TimeInterval = 2.5

        static let `default` = Configuration()
    }

    // MARK: Track state

    private final class Track {
        let id: Int
        var className: String
        var box: CGRect
        var confidence: Double
        var distance: Double?
        /// (timestamp, distance) history, trimmed to the closing-rate window.
        var samples: [(t: TimeInterval, d: Double)] = []
        /// Sliding hit/miss window, newest last.
        var window: [Bool] = []
        var consecutiveMisses = 0
        var confirmed = false
        var heldLevel: UrgencyLevel = .none
        var lastAnnounced: TimeInterval = -.infinity

        init(id: Int, className: String, box: CGRect, confidence: Double) {
            self.id = id
            self.className = className
            self.box = box
            self.confidence = confidence
        }
    }

    private var tracks: [Track] = []
    private var nextID = 1
    private let config: Configuration
    private let model: UrgencyModel

    init(config: Configuration = .default, model: UrgencyModel = .default) {
        self.config = config
        self.model = model
    }

    func reset() {
        tracks.removeAll()
        nextID = 1
    }

    // MARK: The per-frame update

    /// Associate this frame's detections with existing tracks, update the
    /// closing-rate fits, run the gate, and return every track's current
    /// state. Unconfirmed tracks are returned too, flagged -- the caller
    /// decides whether to show them; only confirmed ones should drive feedback.
    ///
    /// - Parameters:
    ///   - detections: this frame's boxes, in upright frame fractions.
    ///   - distances: metres per detection, index-aligned, `nil` where depth
    ///     could not be sampled.
    ///   - timestamp: monotonic seconds. Passed in rather than read from a
    ///     clock so the closing-rate arithmetic can be exercised off-device.
    func update(detections: [Detection],
                distances: [Double?],
                timestamp: TimeInterval) -> [Obstacle] {

        var claimedTrack = Set<Int>()
        var claimedDetection = Set<Int>()

        // Greedy association, best IoU first. A global assignment would be
        // more correct, but with a handful of indoor obstacles per frame the
        // difference never shows and greedy costs nothing.
        var pairs: [(iou: Double, track: Int, detection: Int)] = []
        for (ti, track) in tracks.enumerated() {
            for (di, detection) in detections.enumerated() {
                guard detection.className == track.className else { continue }
                let iou = Self.intersectionOverUnion(track.box, detection.box)
                if iou >= config.matchIoU {
                    pairs.append((iou, ti, di))
                }
            }
        }
        pairs.sort { $0.iou > $1.iou }

        for pair in pairs {
            guard !claimedTrack.contains(pair.track), !claimedDetection.contains(pair.detection) else { continue }
            claimedTrack.insert(pair.track)
            claimedDetection.insert(pair.detection)

            let track = tracks[pair.track]
            let detection = detections[pair.detection]
            track.box = detection.box
            track.confidence = detection.confidence
            track.distance = distances[pair.detection]
            track.consecutiveMisses = 0
            push(&track.window, true, limit: config.windowLength)
            if let d = distances[pair.detection] {
                track.samples.append((timestamp, d))
            }
            track.samples.removeAll { timestamp - $0.t > config.closingRateWindow }
        }

        // Unmatched tracks: record a miss, and retire the ones past tolerance.
        for (ti, track) in tracks.enumerated() where !claimedTrack.contains(ti) {
            track.consecutiveMisses += 1
            push(&track.window, false, limit: config.windowLength)
            track.samples.removeAll { timestamp - $0.t > config.closingRateWindow }
        }
        tracks.removeAll { $0.consecutiveMisses > config.maxMisses }

        // Unmatched detections start new tracks.
        for (di, detection) in detections.enumerated() where !claimedDetection.contains(di) {
            let track = Track(id: nextID, className: detection.className, box: detection.box, confidence: detection.confidence)
            nextID += 1
            track.distance = distances[di]
            push(&track.window, true, limit: config.windowLength)
            if let d = distances[di] {
                track.samples.append((timestamp, d))
            }
            tracks.append(track)
        }

        return tracks.map { score($0) }
    }

    /// Mark a track as just announced, so `reannounceInterval` is respected.
    func noteAnnounced(id: Int, at timestamp: TimeInterval) {
        tracks.first { $0.id == id }?.lastAnnounced = timestamp
    }

    /// Whether this track is allowed a fresh spoken announcement.
    func mayAnnounce(id: Int, at timestamp: TimeInterval) -> Bool {
        guard let track = tracks.first(where: { $0.id == id }) else { return false }
        return timestamp - track.lastAnnounced >= config.reannounceInterval
    }

    // MARK: Scoring and gating

    private func score(_ track: Track) -> Obstacle {
        let hits = track.window.filter { $0 }.count
        if hits >= config.minHits { track.confirmed = true }

        let rate = closingRate(track)
        let distance = track.distance
        let hazard = HazardWeight.forClass(track.className)
        let urgency = distance.map {
            model.urgency(distance: $0, closingRate: rate ?? 0, hazard: hazard)
        } ?? 0

        let ttc: Double? = {
            guard let distance, let rate, rate > 0.05 else { return nil }
            return distance / rate
        }()

        // Hysteresis. Escalate the moment the score says so -- a safety signal
        // that lags its own input is worse than one that occasionally
        // over-warns. De-escalate only once the score has fallen clear of the
        // threshold it rose through, which is what stops a score sitting on a
        // boundary from switching the haptic pattern several times a second.
        let raw = UrgencyLevel.from(score: urgency)
        if raw > track.heldLevel {
            track.heldLevel = raw
        } else if raw < track.heldLevel {
            let fallingFloor = Self.risingThreshold(for: track.heldLevel) - config.levelFallMargin
            if urgency < fallingFloor {
                track.heldLevel = raw
            }
        }

        return Obstacle(id: track.id,
                        className: track.className,
                        confidence: track.confidence,
                        box: track.box,
                        distance: distance,
                        bearing: BearingZone.from(centroidX: Double(track.box.midX)),
                        closingRate: rate,
                        timeToContact: ttc,
                        urgency: urgency,
                        level: track.heldLevel,
                        isConfirmed: track.confirmed)
    }

    /// Least-squares slope of distance against time over the window, negated so
    /// approaching is positive. A slope beats differencing the first and last
    /// samples here: LiDAR distance samples are noisy at the centimetre level
    /// and a two-point difference turns that noise straight into a spurious
    /// closing rate, which then feeds time-to-contact.
    private func closingRate(_ track: Track) -> Double? {
        let samples = track.samples
        guard samples.count >= config.minSamplesForRate else { return nil }

        let n = Double(samples.count)
        let meanT = samples.reduce(0.0) { $0 + $1.t } / n
        let meanD = samples.reduce(0.0) { $0 + $1.d } / n
        var covariance = 0.0
        var variance = 0.0
        for sample in samples {
            let dt = sample.t - meanT
            covariance += dt * (sample.d - meanD)
            variance += dt * dt
        }
        guard variance > 1e-9 else { return nil }
        let slope = covariance / variance
        return slope.isFinite ? -slope : nil
    }

    private static func risingThreshold(for level: UrgencyLevel) -> Double {
        switch level {
        case .none: return 0
        case .low: return 0.12
        case .medium: return 0.45
        case .high: return 0.70
        }
    }

    private func push(_ window: inout [Bool], _ value: Bool, limit: Int) {
        window.append(value)
        if window.count > limit { window.removeFirst(window.count - limit) }
    }

    static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> Double {
        let intersection = a.intersection(b)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return 0 }
        let intersectionArea = Double(intersection.width * intersection.height)
        let union = Double(a.width * a.height) + Double(b.width * b.height) - intersectionArea
        guard union > 1e-9 else { return 0 }
        return intersectionArea / union
    }
}
