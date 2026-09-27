import CoreGraphics
import CoreVideo
import Foundation

/// Samples ARKit `sceneDepth` inside a region of interest.
///
/// **Why LiDAR and not the monocular network.** CLAUDE.md deliberately left
/// this choice open until Objective 2 had real data, because the decision
/// layer's depth source should follow the measurement rather than an
/// assumption. Objective 2 (`results/objective2_findings.md`, 102
/// tape-measured frames) settles it: on detector-driven boxes LiDAR reached
/// MAE 0.188 m / 16.1% MAPE against a tape measure, and 0.077 m / 4.3% on
/// doors, while Depth-Anything-V2-Metric-Hypersim-Small reached 1.221 m /
/// 69.7% -- roughly six and a half times the error. LiDAR also costs
/// essentially nothing per frame (sensor-driven, already in the `ARFrame`)
/// where the monocular network costs real Neural Engine time that would
/// compete with the detector. Accuracy and latency point the same way for
/// once, so the prototype samples `sceneDepth`.
///
/// The cost of that choice is device coverage -- this path needs a Pro-tier
/// iPhone -- and that trade-off is RQ2's actual answer, not a limitation
/// discovered late.
enum DepthSampler {

    /// Discard anything below this ARKit confidence level. `.low` (raw 0) is
    /// dropped: glass and dark matte surfaces return confident-*looking*
    /// garbage at low confidence, and a median cannot rescue a region whose
    /// values are wrong rather than noisy.
    static let minimumConfidence: UInt8 = 1

    /// Upper bound on samples drawn from a region. A full-frame box would
    /// otherwise put ~49,000 values through a sort on every frame; striding to
    /// a bounded count keeps the median stable (it is a robust statistic --
    /// a few hundred samples locate it as well as fifty thousand) while making
    /// the per-frame cost independent of how much of the frame the box covers.
    static let maximumSamples = 1_500

    /// Median depth in metres over `roi`, or `nil` if the region yields no
    /// usable pixels.
    ///
    /// - Parameters:
    ///   - depthMap: ARKit's `sceneDepth.depthMap`, Float32 metres, in the
    ///     native landscape sensor frame.
    ///   - confidenceMap: matching `sceneDepth.confidenceMap`, UInt8
    ///     `ARConfidenceLevel` raw values. Sampling proceeds without filtering
    ///     if this is absent rather than refusing outright.
    ///   - roi: fractions of the **landscape** frame, top-left origin. Callers
    ///     holding an upright-frame box must convert through
    ///     `FrameGeometry.landscapeROI(forPortrait:)` first.
    ///
    /// Returning `nil` rather than a sentinel is deliberate: "no reading" and
    /// "a reading of zero" have to stay distinguishable all the way up to the
    /// UI, because the first is a glass door or an out-of-range wall and the
    /// second would be an obstacle against the lens.
    static func medianDepth(depthMap: CVPixelBuffer,
                            confidenceMap: CVPixelBuffer?,
                            roi: CGRect) -> Double? {
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return nil }

        // Clip in fraction space *before* converting to pixels, and bail out
        // if nothing is left.
        //
        // Clamping the pixel bounds instead looks equivalent and is not: an
        // ROI entirely outside the frame clamps to a one-pixel sliver at
        // whichever edge it left by, and then returns that pixel's depth as
        // though it were a reading of the object. `verify_decision_layer.sh`
        // caught exactly that. A partly-visible box must still clip and
        // sample what is visible, which the intersection below does.
        let clipped = roi.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }

        let x0 = max(0, min(width - 1, Int((clipped.minX * CGFloat(width)).rounded())))
        let x1 = max(0, min(width, Int((clipped.maxX * CGFloat(width)).rounded())))
        let y0 = max(0, min(height - 1, Int((clipped.minY * CGFloat(height)).rounded())))
        let y1 = max(0, min(height, Int((clipped.maxY * CGFloat(height)).rounded())))
        guard x1 > x0, y1 > y0 else { return nil }

        let regionWidth = x1 - x0
        let regionHeight = y1 - y0
        let stride = max(1, Int((Double(regionWidth * regionHeight) / Double(maximumSamples)).squareRoot().rounded(.up)))

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let depthRowBytes = CVPixelBufferGetBytesPerRow(depthMap)

        var confidenceBase: UnsafeMutableRawPointer?
        var confidenceRowBytes = 0
        var confidenceScaleX = 1.0
        var confidenceScaleY = 1.0
        if let confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            confidenceBase = CVPixelBufferGetBaseAddress(confidenceMap)
            confidenceRowBytes = CVPixelBufferGetBytesPerRow(confidenceMap)
            // The confidence map is documented as matching the depth map's
            // dimensions, but scaling rather than assuming costs one division
            // and removes a whole class of silent off-by-resolution bug -- the
            // same mistake that cost Objective 2 a day offline.
            confidenceScaleX = Double(CVPixelBufferGetWidth(confidenceMap)) / Double(width)
            confidenceScaleY = Double(CVPixelBufferGetHeight(confidenceMap)) / Double(height)
        }
        defer {
            if let confidenceMap { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
        }

        var values: [Float] = []
        values.reserveCapacity(maximumSamples)

        var y = y0
        while y < y1 {
            let depthRow = depthBase.advanced(by: y * depthRowBytes).assumingMemoryBound(to: Float32.self)
            let confidenceRow: UnsafePointer<UInt8>? = confidenceBase.map {
                let cy = min(Int(Double(y) * confidenceScaleY), max(0, CVPixelBufferGetHeight(confidenceMap!) - 1))
                return UnsafePointer($0.advanced(by: cy * confidenceRowBytes).assumingMemoryBound(to: UInt8.self))
            }

            var x = x0
            while x < x1 {
                if let confidenceRow {
                    let cx = min(Int(Double(x) * confidenceScaleX), max(0, CVPixelBufferGetWidth(confidenceMap!) - 1))
                    if confidenceRow[cx] < minimumConfidence {
                        x += stride
                        continue
                    }
                }
                let value = depthRow[x]
                // ARKit reports 0 for "no return". Treated as absent, not as
                // an obstacle touching the lens.
                if value.isFinite, value > 0.05 {
                    values.append(value)
                }
                x += stride
            }
            y += stride
        }

        guard !values.isEmpty else { return nil }
        values.sort()
        // Median, not mean: CLAUDE.md section 7 is explicit, and the reason is
        // that one background pixel bleeding in through a loose box edge moves
        // a mean by metres while barely moving a median.
        let mid = values.count / 2
        if values.count % 2 == 1 {
            return Double(values[mid])
        }
        return Double(values[mid - 1] + values[mid]) / 2.0
    }
}
