import CoreGraphics
import CoreVideo
import Foundation

// Off-device verification of Objective 3's decision layer: the coordinate
// transforms, the depth sampler, the urgency function and the tracker/gate.
//
// It exists because the offline distance pipeline shipped a coordinate bug
// that did not crash -- it applied one pixel box to two differently-sized
// arrays, returned `None` for every frame, and logged that as a plausible
// LiDAR range finding. A day went into chasing a hardware limit that was
// arithmetic. The live pipeline has the same hazard twice over (letterbox
// padding, and a portrait/landscape rotation between the detector and the
// depth map), so the transforms are checked against planted values here,
// on the Mac, where an assertion can fail loudly.
//
// Run: tools/verify_decision_layer.sh

var failures = 0
var checks = 0

func check(_ name: String, _ condition: Bool, _ detail: String = "") {
    checks += 1
    if condition {
        print("  ok    \(name)")
    } else {
        failures += 1
        print("  FAIL  \(name) \(detail)")
    }
}

func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

func section(_ title: String) { print("\n\(title)") }

// The upright frame is 1440 x 1920 (ARKit's 1920 x 1440 sensor frame rotated).
let portraitAspect = 3.0 / 4.0

// MARK: - A. Letterbox round trip

section("A. Letterbox padding is undone exactly")

// Forward letterbox of a known portrait box, by hand, then back through
// unletterbox. Anything other than an exact round trip means every box the
// detector returns is offset.
func forwardLetterbox(box: CGRect, frameAspect: Double) -> (x: Double, y: Double, w: Double, h: Double) {
    let contentW = frameAspect >= 1 ? 1.0 : frameAspect
    let contentH = frameAspect >= 1 ? 1.0 / frameAspect : 1.0
    let padX = (1 - contentW) / 2
    let padY = (1 - contentH) / 2
    return (Double(box.midX) * contentW + padX,
            Double(box.midY) * contentH + padY,
            Double(box.width) * contentW,
            Double(box.height) * contentH)
}

for original in [CGRect(x: 0.30, y: 0.40, width: 0.40, height: 0.20),
                 CGRect(x: 0.00, y: 0.00, width: 1.00, height: 1.00),
                 CGRect(x: 0.05, y: 0.70, width: 0.15, height: 0.25)] {
    let model = forwardLetterbox(box: original, frameAspect: portraitAspect)
    let back = FrameGeometry.unletterbox(center: model, frameAspect: portraitAspect)
    check("round trip \(original)",
          near(Double(back.minX), Double(original.minX), 1e-9)
          && near(Double(back.minY), Double(original.minY), 1e-9)
          && near(Double(back.width), Double(original.width), 1e-9)
          && near(Double(back.height), Double(original.height), 1e-9),
          "got \(back)")
}

// A full-frame box in model space must expand past the frame horizontally,
// which is exactly why AssistController clamps: the 640-square canvas is
// 12.5% padding on each side for a 3:4 frame.
let fullCanvas = FrameGeometry.unletterbox(center: (0.5, 0.5, 1.0, 1.0), frameAspect: portraitAspect)
check("full canvas maps wider than the frame",
      Double(fullCanvas.width) > 1.3 && near(Double(fullCanvas.height), 1.0, 1e-9),
      "got \(fullCanvas)")

// MARK: - B. Portrait -> landscape rotation

section("B. Portrait/landscape rotation maps corners correctly")

// A portrait display frame is the landscape sensor frame rotated 90 degrees
// clockwise, so with a top-left origin in both spaces the four corners must
// move one position clockwise. Getting the flip wrong does not fail loudly --
// it samples the mirrored part of the scene and returns a plausible number.
let corner = 0.10
let cases: [(name: String, portrait: CGRect, expected: CGRect)] = [
    ("portrait top-left -> landscape bottom-left",
     CGRect(x: 0, y: 0, width: corner, height: corner),
     CGRect(x: 0, y: 1 - corner, width: corner, height: corner)),
    ("portrait top-right -> landscape top-left",
     CGRect(x: 1 - corner, y: 0, width: corner, height: corner),
     CGRect(x: 0, y: 0, width: corner, height: corner)),
    ("portrait bottom-right -> landscape top-right",
     CGRect(x: 1 - corner, y: 1 - corner, width: corner, height: corner),
     CGRect(x: 1 - corner, y: 0, width: corner, height: corner)),
    ("portrait bottom-left -> landscape bottom-right",
     CGRect(x: 0, y: 1 - corner, width: corner, height: corner),
     CGRect(x: 1 - corner, y: 1 - corner, width: corner, height: corner)),
]
for c in cases {
    let got = FrameGeometry.landscapeROI(forPortrait: c.portrait)
    check(c.name,
          near(Double(got.minX), Double(c.expected.minX)) && near(Double(got.minY), Double(c.expected.minY))
          && near(Double(got.width), Double(c.expected.width)) && near(Double(got.height), Double(c.expected.height)),
          "got \(got) expected \(c.expected)")
}

// Applying the rotation four times must return the original region.
var spun = CGRect(x: 0.2, y: 0.55, width: 0.3, height: 0.15)
let startSpun = spun
for _ in 0..<4 { spun = FrameGeometry.landscapeROI(forPortrait: spun) }
check("four rotations are the identity",
      near(Double(spun.minX), Double(startSpun.minX), 1e-9) && near(Double(spun.minY), Double(startSpun.minY), 1e-9)
      && near(Double(spun.width), Double(startSpun.width), 1e-9) && near(Double(spun.height), Double(startSpun.height), 1e-9),
      "got \(spun)")

section("C. Lower third of a box")
let box = CGRect(x: 0.2, y: 0.40, width: 0.30, height: 0.30)
let third = FrameGeometry.lowerThird(of: box)
check("takes the bottom third, not the top",
      near(Double(third.minY), 0.60) && near(Double(third.height), 0.10)
      && near(Double(third.minX), 0.20) && near(Double(third.width), 0.30),
      "got \(third)")
check("lower third sits inside the box",
      near(Double(third.maxY), Double(box.maxY), 1e-9))

// MARK: - D. Depth sampling against planted values

section("D. Depth sampler recovers a planted distance")

func makeBuffer(width: Int, height: Int, format: OSType) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, format,
                        [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary, &buffer)
    return buffer!
}

let depthW = 256, depthH = 192   // ARKit sceneDepth's real resolution
let depth = makeBuffer(width: depthW, height: depthH, format: kCVPixelFormatType_DepthFloat32)
let confidence = makeBuffer(width: depthW, height: depthH, format: kCVPixelFormatType_OneComponent8)

// A portrait box whose lower third we will plant, then read back through the
// exact chain the live pipeline uses.
let detectionBox = CGRect(x: 0.30, y: 0.45, width: 0.30, height: 0.30)
let roi = FrameGeometry.landscapeROI(forPortrait: FrameGeometry.lowerThird(of: detectionBox))

let plantedDistance: Float = 2.5
let backgroundDistance: Float = 7.0
let garbageDistance: Float = 0.35   // the sort of value glass returns at low confidence

CVPixelBufferLockBaseAddress(depth, [])
CVPixelBufferLockBaseAddress(confidence, [])
let depthBase = CVPixelBufferGetBaseAddress(depth)!
let depthRowBytes = CVPixelBufferGetBytesPerRow(depth)
let confBase = CVPixelBufferGetBaseAddress(confidence)!
let confRowBytes = CVPixelBufferGetBytesPerRow(confidence)

let px0 = Int((Double(roi.minX) * Double(depthW)).rounded())
let px1 = Int((Double(roi.maxX) * Double(depthW)).rounded())
let py0 = Int((Double(roi.minY) * Double(depthH)).rounded())
let py1 = Int((Double(roi.maxY) * Double(depthH)).rounded())

for y in 0..<depthH {
    let dRow = depthBase.advanced(by: y * depthRowBytes).assumingMemoryBound(to: Float32.self)
    let cRow = confBase.advanced(by: y * confRowBytes).assumingMemoryBound(to: UInt8.self)
    for x in 0..<depthW {
        let insideROI = x >= px0 && x < px1 && y >= py0 && y < py1
        // Low-confidence garbage over the ROI's top three quarters. It has to
        // be a clear majority for this to test anything: planted over half
        // the rows it stays a minority the median rejects unaided, which says
        // nothing about whether the confidence filter works.
        let isGarbage = insideROI && y < py0 + (py1 - py0) * 3 / 4
        if isGarbage {
            dRow[x] = garbageDistance
            cRow[x] = 0                      // ARConfidenceLevel.low
        } else if insideROI {
            dRow[x] = plantedDistance
            cRow[x] = 2                      // ARConfidenceLevel.high
        } else {
            dRow[x] = backgroundDistance
            cRow[x] = 2
        }
    }
}
CVPixelBufferUnlockBaseAddress(confidence, [])
CVPixelBufferUnlockBaseAddress(depth, [])

let sampled = DepthSampler.medianDepth(depthMap: depth, confidenceMap: confidence, roi: roi)
check("recovers the planted 2.50 m",
      sampled != nil && near(sampled!, Double(plantedDistance), 0.001),
      "got \(String(describing: sampled))")

// Without the confidence filter the same region must return the garbage
// instead -- proving the filter is what rejected it, not luck in the striding.
let unfiltered = DepthSampler.medianDepth(depthMap: depth, confidenceMap: nil, roi: roi)
check("without the confidence filter the garbage wins",
      unfiltered != nil && near(unfiltered!, Double(garbageDistance), 0.001),
      "got \(String(describing: unfiltered)) -- the filter is doing nothing if this matches the planted value")

// Reading the un-rotated box (the bug the rotation exists to prevent) must
// land somewhere else entirely -- if this matched, the rotation would be
// untested by construction.
let unrotated = DepthSampler.medianDepth(depthMap: depth, confidenceMap: confidence,
                                         roi: FrameGeometry.lowerThird(of: detectionBox))
check("skipping the rotation reads the wrong region",
      unrotated == nil || !near(unrotated!, Double(plantedDistance), 0.05),
      "got \(String(describing: unrotated)) -- it should NOT be the planted value")

// An ROI entirely off-frame must return nil, not a clamped edge reading.
check("off-frame ROI returns nil",
      DepthSampler.medianDepth(depthMap: depth, confidenceMap: confidence,
                               roi: CGRect(x: 1.4, y: 1.4, width: 0.2, height: 0.2)) == nil)

// MARK: - E. Urgency function

section("E. Urgency function")

let model = UrgencyModel.default
check("proximity saturates at the near bound", near(model.proximity(distance: 0.4), 1.0))
check("proximity is zero at the far bound", near(model.proximity(distance: 4.0), 0.0))
check("proximity is monotonic",
      model.proximity(distance: 1.0) > model.proximity(distance: 2.0)
      && model.proximity(distance: 2.0) > model.proximity(distance: 3.0))

// The regression this function was rewritten for: with proximity and
// time-to-contact sharing a fixed budget, a staircase half a metre away and a
// stationary user could not reach the top band at all.
let stairsClose = model.urgency(distance: 0.5, closingRate: 0, hazard: HazardWeight.forClass("stairs"))
check("stairs at 0.5 m, stationary, reaches the top band",
      UrgencyLevel.from(score: stairsClose) == .high,
      "urgency \(stairsClose) -> \(UrgencyLevel.from(score: stairsClose))")

let chairClose = model.urgency(distance: 0.5, closingRate: 0, hazard: HazardWeight.forClass("chair"))
check("a chair at 0.5 m is also top band (low-hazard class, high-hazard situation)",
      UrgencyLevel.from(score: chairClose) == .high,
      "urgency \(chairClose)")

check("hazard class still orders two obstacles at equal distance",
      stairsClose > chairClose)

let still = model.urgency(distance: 2.5, closingRate: 0, hazard: 0.7)
let approaching = model.urgency(distance: 2.5, closingRate: 1.2, hazard: 0.7)
let receding = model.urgency(distance: 2.5, closingRate: -1.2, hazard: 0.7)
check("approaching scores above stationary", approaching > still, "\(approaching) vs \(still)")
check("receding scores the same as stationary", near(receding, still), "\(receding) vs \(still)")

check("beyond the range bound and stationary scores nothing",
      near(model.urgency(distance: 5.0, closingRate: 0, hazard: 1.0), 0))
check("urgency stays inside 0...1 under extreme input",
      (0...1).contains(model.urgency(distance: 0.01, closingRate: 12, hazard: 1.0)))
check("an unknown class falls back rather than vanishing",
      HazardWeight.forClass("not_a_real_class") == HazardWeight.forClass("other"))

section("F. Bearing zones")
check("left third", BearingZone.from(centroidX: 0.1) == .left)
check("centre third", BearingZone.from(centroidX: 0.5) == .centre)
check("right third", BearingZone.from(centroidX: 0.9) == .right)
check("pan follows bearing", BearingZone.left.pan < 0 && BearingZone.right.pan > 0
      && BearingZone.centre.pan == 0)

// MARK: - G. Tracker, closing rate, gate and hysteresis

section("G. Tracker: gate, closing rate and hysteresis")

let tracker = ObstacleTracker()
let steady = CGRect(x: 0.35, y: 0.40, width: 0.25, height: 0.35)
let door = Detection(className: "door", confidence: 0.8, box: steady)

// N-of-M confirmation: minHits 3 of a 5-frame window, so two frames must not
// be enough to drive feedback. Without this a detector dropping an object for
// one frame -- which happens constantly -- would stutter the haptics on and
// off several times a second.
var gated = tracker.update(detections: [door], distances: [3.0], timestamp: 0.0)
check("one frame is not confirmed", gated.count == 1 && !gated[0].isConfirmed)
gated = tracker.update(detections: [door], distances: [2.9], timestamp: 0.1)
check("two frames are not confirmed", !gated[0].isConfirmed)
gated = tracker.update(detections: [door], distances: [2.8], timestamp: 0.2)
check("three frames confirm the track", gated[0].isConfirmed)
check("the track keeps one identity across frames", gated[0].id == 1)

// Closing rate from a least-squares fit: 0.1 m per 0.1 s is 1 m/s approaching.
gated = tracker.update(detections: [door], distances: [2.7], timestamp: 0.3)
check("closing rate recovers 1.0 m/s approaching",
      gated[0].closingRate != nil && near(gated[0].closingRate!, 1.0, 0.02),
      "got \(String(describing: gated[0].closingRate))")
check("time to contact follows distance / rate",
      gated[0].timeToContact != nil && near(gated[0].timeToContact!, 2.7, 0.1),
      "got \(String(describing: gated[0].timeToContact))")

// A miss must not drop a confirmed track immediately.
gated = tracker.update(detections: [], distances: [], timestamp: 0.4)
check("a single dropped frame keeps the track alive", gated.count == 1 && gated[0].isConfirmed)

// Retirement after maxMisses.
var t = 0.5
for _ in 0..<9 {
    gated = tracker.update(detections: [], distances: [], timestamp: t)
    t += 0.1
}
check("a track is retired after sustained misses", gated.isEmpty, "still \(gated.count)")

// Hysteresis: escalate immediately, de-escalate only past the fall margin.
// Distances chosen for a door (hazard 0.7): 1.136 m scores just over the 0.70
// rising edge, 1.375 m scores 0.66 -- below the edge but inside the 0.08
// margin -- and 1.85 m scores clear of it.
let hysteresis = ObstacleTracker()
var levels: [UrgencyLevel] = []
var clock = 0.0
for distance in [1.136, 1.136, 1.136, 1.375, 1.85] {
    let scored = hysteresis.update(detections: [door], distances: [distance], timestamp: clock)
    levels.append(scored[0].level)
    clock += 0.1
}
check("rises to the top band", levels[2] == .high, "levels \(levels)")
check("holds the top band inside the fall margin", levels[3] == .high, "levels \(levels)")
check("drops once the score falls clear of the margin", levels[4] < .high, "levels \(levels)")

// Two obstacles of the same class must not be merged into one track.
let separate = ObstacleTracker()
let left = Detection(className: "chair", confidence: 0.7, box: CGRect(x: 0.05, y: 0.5, width: 0.2, height: 0.3))
let right = Detection(className: "chair", confidence: 0.7, box: CGRect(x: 0.70, y: 0.5, width: 0.2, height: 0.3))
let both = separate.update(detections: [left, right], distances: [1.5, 3.0], timestamp: 0)
check("two non-overlapping chairs are two tracks", both.count == 2, "got \(both.count)")
check("they get different bearings",
      Set(both.map(\.bearing)) == Set([.left, .right]), "got \(both.map(\.bearing))")
check("IoU of disjoint boxes is zero",
      ObstacleTracker.intersectionOverUnion(left.box, right.box) == 0)
check("IoU of an identical box is one",
      near(ObstacleTracker.intersectionOverUnion(left.box, left.box), 1.0))

print("\n\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    print("\(failures) FAILED")
    exit(1)
}
print("decision layer verified")
