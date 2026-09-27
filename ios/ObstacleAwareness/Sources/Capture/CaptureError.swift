import Foundation

enum CaptureError: LocalizedError {
    case noDepth
    case imageConversionFailed
    case missingMeasurement

    var errorDescription: String? {
        switch self {
        case .noDepth:
            return "No sceneDepth on this frame -- device may not support LiDAR depth."
        case .imageConversionFailed:
            return "Failed to convert the captured frame to an image."
        case .missingMeasurement:
            return "Enter the tape-measured distance before capturing -- the filename is the ground truth, a mislabelled frame is worse than a missing one."
        }
    }
}
