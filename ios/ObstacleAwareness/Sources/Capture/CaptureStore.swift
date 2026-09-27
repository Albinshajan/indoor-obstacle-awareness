import ARKit
import Foundation

/// Owns the on-disk Captures directory. Coverage counts and rep numbers are
/// derived by scanning existing filenames rather than kept in separate
/// state, so a relaunch (or a crash) can never desync the two -- the
/// filename convention is the single source of truth (CLAUDE.md section 5).
final class CaptureStore: ObservableObject {
    let outputDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        outputDirectory = dir
    }

    func coverageCounts(for objectClass: ObstacleClass) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        let prefix = "obj-\(objectClass.rawValue)_d-"
        for stem in existingStems() where stem.hasPrefix(prefix) {
            if let mm = distanceMM(fromStem: stem) {
                counts[mm, default: 0] += 1
            }
        }
        return counts
    }

    @discardableResult
    func save(frame: ARFrame, objectClass: ObstacleClass, distanceMM: Int, lighting: LightingCondition, thermalState: ProcessInfo.ThermalState) throws -> String {
        guard let sceneDepth = frame.sceneDepth else {
            throw CaptureError.noDepth
        }

        let rep = nextRep(objectClass: objectClass, distanceMM: distanceMM, lighting: lighting)
        let stem = "obj-\(objectClass.rawValue)_d-\(distanceMM)_light-\(lighting.rawValue)_rep-\(rep)"

        let jpegURL = outputDirectory.appendingPathComponent("\(stem).jpg")
        let depthURL = outputDirectory.appendingPathComponent("\(stem).depth.npy")
        let confURL = outputDirectory.appendingPathComponent("\(stem).conf.npy")
        let jsonURL = outputDirectory.appendingPathComponent("\(stem).json")

        // Write depth/confidence first -- they're the whole point of this app; a JPEG
        // encoding failure shouldn't be allowed to silently drop the ground-truth arrays.
        try FrameWriter.writeDepthNPY(pixelBuffer: sceneDepth.depthMap, to: depthURL)
        if let confidenceMap = sceneDepth.confidenceMap {
            try FrameWriter.writeConfidenceNPY(pixelBuffer: confidenceMap, to: confURL)
        }
        try FrameWriter.writeMetadataJSON(frame: frame, thermalState: thermalState, to: jsonURL)
        try FrameWriter.writeJPEG(frame: frame, to: jpegURL)

        return stem
    }

    private func existingStems() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: outputDirectory.path)) ?? []
        return names.filter { $0.hasSuffix(".jpg") }.map { String($0.dropLast(4)) }
    }

    private func distanceMM(fromStem stem: String) -> Int? {
        guard let dRange = stem.range(of: "_d-") else { return nil }
        let rest = stem[dRange.upperBound...]
        guard let underscore = rest.firstIndex(of: "_") else { return nil }
        return Int(rest[rest.startIndex..<underscore])
    }

    private func nextRep(objectClass: ObstacleClass, distanceMM: Int, lighting: LightingCondition) -> Int {
        let prefix = "obj-\(objectClass.rawValue)_d-\(distanceMM)_light-\(lighting.rawValue)_rep-"
        let existingReps = existingStems()
            .filter { $0.hasPrefix(prefix) }
            .compactMap { Int($0.dropFirst(prefix.count)) }
        return (existingReps.max() ?? 0) + 1
    }
}
