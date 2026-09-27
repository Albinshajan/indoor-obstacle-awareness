import CoreGraphics
import Foundation

/// The derived-feature layer: everything between the models' raw output and
/// the feedback channels (CLAUDE.md section 7). This is Objective 3's real
/// design artifact, so it is kept as plain value types with no ARKit, Core ML,
/// AVFoundation or Core Haptics dependency -- the scoring can then be reasoned
/// about, and checked, without a camera or a device in the loop.
///
/// Coordinate convention, stated once because getting it wrong is the single
/// most expensive mistake available here. Every box in this file is in
/// **normalised fractions of the upright (portrait) display frame, top-left
/// origin**. The detector sees an upright frame, so its boxes are already in
/// that space once the letterbox padding is undone; the depth map is in
/// ARKit's native landscape sensor frame and is reached through
/// `FrameGeometry.landscapeROI(forPortrait:)` below. The equivalent confusion
/// in the offline pipeline -- one pixel box applied to two differently-sized
/// arrays -- silently produced a plausible-looking hardware finding out of a
/// coordinate bug, and cost Objective 2 a day.

// MARK: - Bearing

/// Which way the user is told to expect the obstacle. Three zones rather than
/// a continuous angle: the feedback channels cannot resolve better than this
/// (stereo panning and a single haptic actuator), so inventing precision here
/// would not survive into anything the user perceives.
enum BearingZone: String, CaseIterable {
    case left
    case centre
    case right

    /// Centre spans the middle third of the frame.
    static func from(centroidX: Double) -> BearingZone {
        if centroidX < 1.0 / 3.0 { return .left }
        if centroidX > 2.0 / 3.0 { return .right }
        return .centre
    }

    /// Stereo pan position for the audio channel, -1 hard left to +1 hard right.
    var pan: Float {
        switch self {
        case .left: return -0.8
        case .centre: return 0
        case .right: return 0.8
        }
    }

    var spokenName: String {
        switch self {
        case .left: return "left"
        case .centre: return "ahead"
        case .right: return "right"
        }
    }
}

// MARK: - Hazard weighting

/// Fixed per-class hazard weights, mirroring `tools/taxonomy.py`'s
/// `HAZARD_WEIGHT` exactly. Duplicated rather than generated because the Swift
/// app and the Python tooling have no shared build step -- if either side
/// changes, change both. The ordering follows Khilnani and Devesh's
/// prioritisation argument: what hurts most if you walk into it ranks highest,
/// which is why `stairs` tops the table and `person` (which moves out of the
/// way, and is the one class that must never have a frame persisted) sits near
/// the bottom.
enum HazardWeight {
    static let table: [String: Double] = [
        "stairs": 1.0,
        "door_glass": 0.9,
        "pole": 0.8,
        "door": 0.7,
        "low_obstacle": 0.6,
        "handrail": 0.4,
        "wall": 0.4,
        "table": 0.3,
        "chair": 0.3,
        "window": 0.3,
        "person": 0.2,
        "other": 0.1,
    ]

    /// Unknown classes fall back to `other`'s weight rather than to zero, so a
    /// class name drifting out of sync with the taxonomy degrades the ranking
    /// instead of silently suppressing the object entirely.
    static func forClass(_ name: String) -> Double {
        table[name] ?? table["other"] ?? 0.1
    }
}

// MARK: - Urgency

/// Tuning constants for the urgency score, gathered in one place so the
/// function's behaviour can be described in Chapter 3 without reading the
/// arithmetic.
struct UrgencyModel {
    /// Beyond this, an indoor obstacle is not yet actionable for a walking
    /// user and scores zero proximity. Set to 4.0 m rather than the LiDAR
    /// sensor's ~5 m ceiling because Objective 2 measured error growing with
    /// distance, so the last metre of range is the least trustworthy.
    var maxRange: Double = 4.0
    /// At or inside this, proximity saturates -- an obstacle 0.4 m away is not
    /// meaningfully less urgent than one 0.3 m away, both are immediate.
    var minRange: Double = 0.5
    /// Time-to-contact horizon. Inside this many seconds, closing speed starts
    /// contributing; 4 s is roughly two walking paces of reaction time.
    var timeToContactHorizon: Double = 4.0
    /// How much closing speed may add on top of proximity.
    ///
    /// A *boost* rather than a co-weighted term, and the distinction is not
    /// cosmetic. Splitting a fixed budget between proximity and
    /// time-to-contact (0.65/0.35, the first thing written here) made the top
    /// urgency band unreachable for a stationary user: a staircase 0.5 m away
    /// with no closing rate scored 0.65 and came out as "close" rather than
    /// "stop", because the 0.35 reserved for motion could never be claimed.
    /// Proximity alone must be able to saturate the score -- being about to
    /// walk into something is urgent whether or not you are currently moving
    /// towards it -- and approach speed then escalates it earlier.
    var timeToContactBoost: Double = 0.35
    /// How much of the score hazard class is allowed to modulate. At 0.6, a
    /// weight-0.3 chair keeps 72% of its proximity-driven urgency and a
    /// weight-1.0 staircase keeps all of it.
    ///
    /// Hazard is deliberately a *gain* on proximity rather than a term added
    /// to it. Multiplying by the raw weight instead would score a chair 0.3 m
    /// from the user's shin at 0.3 -- a low-hazard *class* is not a low-hazard
    /// *situation* once it is that close. Hazard's job here is to break ties
    /// when several obstacles compete for one announcement slot, not to decide
    /// whether a collision matters.
    var hazardFloor: Double = 0.6

    static let `default` = UrgencyModel()

    /// Distance term: 1 at `minRange` or nearer, 0 at `maxRange` or beyond.
    func proximity(distance: Double) -> Double {
        guard distance.isFinite else { return 0 }
        if distance <= minRange { return 1 }
        if distance >= maxRange { return 0 }
        return (maxRange - distance) / (maxRange - minRange)
    }

    /// Closing term: 1 at contact, 0 at or beyond the horizon. Receding or
    /// stationary obstacles (`closingRate <= 0`) contribute nothing, which is
    /// the whole point of tracking -- a 2 m obstacle being walked towards
    /// matters more than a 2 m obstacle standing still beside the path.
    func timeToContactTerm(distance: Double, closingRate: Double) -> Double {
        guard closingRate > 0.05, distance.isFinite else { return 0 }
        let ttc = distance / closingRate
        guard ttc.isFinite, ttc >= 0 else { return 0 }
        if ttc >= timeToContactHorizon { return 0 }
        return (timeToContactHorizon - ttc) / timeToContactHorizon
    }

    /// The scalar the feedback channels encode, in 0...1.
    ///
    /// Worth being explicit about in the write-up: these weights are a
    /// reasoned design choice, not a fitted or validated one. Validating the
    /// urgency function against what users actually find urgent is exactly
    /// what the descoped participant study (RQ3) would have begun to do, so
    /// the function must be reported as a designed artifact and not as a
    /// tuned result.
    func urgency(distance: Double, closingRate: Double, hazard: Double) -> Double {
        let base = min(1.0, proximity(distance: distance)
            + timeToContactBoost * timeToContactTerm(distance: distance, closingRate: closingRate))
        let gain = hazardFloor + (1 - hazardFloor) * max(0, min(1, hazard))
        return max(0, min(1, base * gain))
    }
}

/// Coarse urgency bands. The continuous score drives haptic intensity, but the
/// *audio* channel and the announcement gate both need discrete levels, and
/// hysteresis is only definable against discrete levels.
enum UrgencyLevel: Int, Comparable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Thresholds are the *rising* edges. Falling edges sit lower, applied by
    /// `AnnouncementGate`, so a score hovering on a boundary does not chatter.
    static func from(score: Double) -> UrgencyLevel {
        if score >= 0.70 { return .high }
        if score >= 0.45 { return .medium }
        if score >= 0.12 { return .low }
        return .none
    }

    var spokenName: String {
        switch self {
        case .none: return "clear"
        case .low: return "ahead"
        case .medium: return "close"
        case .high: return "stop"
        }
    }
}

// MARK: - Detections and obstacles

/// One raw detector output, before depth or tracking.
struct Detection {
    var className: String
    var confidence: Double
    /// Fractions of the upright display frame, top-left origin.
    var box: CGRect
}

/// A detection that has been through depth sampling, tracking and scoring.
struct Obstacle: Identifiable {
    var id: Int
    var className: String
    var confidence: Double
    var box: CGRect
    /// Metres, from the median of the box's lower third. `nil` when depth
    /// could not be sampled -- no valid high-confidence pixels in the region,
    /// which is the expected outcome for glass and for anything past the
    /// sensor's range ceiling.
    var distance: Double?
    var bearing: BearingZone
    /// Metres per second, positive when approaching. `nil` until the track has
    /// enough history to estimate it.
    var closingRate: Double?
    var timeToContact: Double?
    var urgency: Double
    var level: UrgencyLevel
    /// False while the track is still accumulating confirmations, so the UI can
    /// show what the gate is holding back rather than hiding it.
    var isConfirmed: Bool
}

// MARK: - Frame geometry

/// The one place a coordinate space changes hands.
enum FrameGeometry {

    /// Undo YOLO letterbox padding, converting a model-space normalised centre
    /// box into a fraction-of-frame rect in the upright display frame.
    ///
    /// - Parameters:
    ///   - center: `(x, y, w, h)` normalised to the square model input, as the
    ///     Ultralytics Core ML NMS export emits it.
    ///   - frameAspect: width / height of the upright frame (so 0.75 for a
    ///     portrait 3:4 frame).
    static func unletterbox(center: (x: Double, y: Double, w: Double, h: Double),
                            frameAspect: Double) -> CGRect {
        // Letterbox scales the long side to fill the square, so the short side
        // occupies `min(aspect, 1/aspect)` of the canvas and is centre-padded.
        let contentW = frameAspect >= 1 ? 1.0 : frameAspect
        let contentH = frameAspect >= 1 ? 1.0 / frameAspect : 1.0
        let padX = (1 - contentW) / 2
        let padY = (1 - contentH) / 2

        let cx = (center.x - padX) / contentW
        let cy = (center.y - padY) / contentH
        let w = center.w / contentW
        let h = center.h / contentH

        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// The lower third of a box, where a floor-standing object actually is.
    /// Sampling the whole box lets the top edge catch the wall or floor behind
    /// the object and drags the median past it -- Objective 2 measured exactly
    /// that as a positive distance bias even sampling the lower third only.
    static func lowerThird(of box: CGRect) -> CGRect {
        CGRect(x: box.minX,
               y: box.minY + box.height * 2.0 / 3.0,
               width: box.width,
               height: box.height / 3.0)
    }

    /// Rotate a fraction rect from the upright portrait display frame into
    /// ARKit's native landscape sensor frame, which is what `sceneDepth` and
    /// `camera.intrinsics` use.
    ///
    /// A portrait display frame is the landscape sensor frame rotated 90
    /// degrees clockwise (EXIF orientation 6 -- the same tag the capture app
    /// writes, and the same rotation `tools/orientation.py` applies offline).
    /// With a top-left origin in both spaces, landscape (lx, ly) appears at
    /// portrait (1 - ly, lx), so the inverse is lx = py, ly = 1 - px. Both
    /// frames are 4:3, so fractions map with no aspect correction.
    ///
    /// Do not "simplify" this to an identity or a plain axis swap. Dropping the
    /// flip mirrors every region vertically, which does not fail loudly -- it
    /// samples the wrong part of the scene and returns a plausible number.
    static func landscapeROI(forPortrait box: CGRect) -> CGRect {
        CGRect(x: box.minY,
               y: 1 - box.maxX,
               width: box.height,
               height: box.width)
    }
}
