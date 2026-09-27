import ARKit
import CoreImage
import UIKit

/// Writes the four sidecar files for one captured frame.
///
/// Everything is kept in ARKit's native (unrotated) sensor-buffer frame --
/// the same frame `sceneDepth.depthMap` and `camera.intrinsics` already use
/// -- rather than physically rotating the JPEG to portrait. That keeps RGB
/// pixel coordinates, depth-map coordinates and the stored intrinsics
/// trivially consistent with each other with zero rotation math on either
/// side. Display orientation is tagged as EXIF metadata only, which photo
/// viewers respect but a raw numpy/PIL read does not -- exactly what's
/// wanted here. (This is unrelated to the on-device inference pipeline's
/// own orientation handling in CLAUDE.md section 5, which reads a live
/// AVCaptureSession buffer, not these saved files.)
enum FrameWriter {
    private static let ciContext = CIContext()

    static func writeJPEG(frame: ARFrame, to url: URL) throws {
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw CaptureError.imageConversionFailed
        }
        guard let data = UIImage(cgImage: cgImage, scale: 1, orientation: .right).jpegData(compressionQuality: 0.9) else {
            throw CaptureError.imageConversionFailed
        }
        try data.write(to: url, options: .atomic)
    }

    static func writeDepthNPY(pixelBuffer: CVPixelBuffer, to url: URL) throws {
        let values = try readFloat32Plane(pixelBuffer)
        try NPYWriter.writeFloat32(values.data, shape: (values.height, values.width), to: url)
    }

    static func writeConfidenceNPY(pixelBuffer: CVPixelBuffer, to url: URL) throws {
        let values = try readUInt8Plane(pixelBuffer)
        try NPYWriter.writeUInt8(values.data, shape: (values.height, values.width), to: url)
    }

    static func writeMetadataJSON(frame: ARFrame, thermalState: ProcessInfo.ThermalState, to url: URL) throws {
        let camera = frame.camera
        let intrinsics = camera.intrinsics
        let imageResolution = camera.imageResolution

        var depthWidth = 0
        var depthHeight = 0
        if let depthMap = frame.sceneDepth?.depthMap {
            depthWidth = CVPixelBufferGetWidth(depthMap)
            depthHeight = CVPixelBufferGetHeight(depthMap)
        }

        let metadata: [String: Any] = [
            "timestamp": frame.timestamp,
            "thermal_state": thermalStateString(thermalState),
            // Convention-free tilt measure: elevation of the optical axis above
            // (+) or below (-) horizontal. Verified to agree with
            // eulerAngles.x to 2dp on real captures -- both are recorded, and
            // this is the one to prefer since it depends on no axis ordering.
            // See ARCamera.elevationDegrees in ARCaptureController.swift.
            "camera_elevation_deg": camera.elevationDegrees,
            "device_euler_angles_deg": [
                "pitch": Double(camera.eulerAngles.x) * 180.0 / .pi,
                "yaw": Double(camera.eulerAngles.y) * 180.0 / .pi,
                "roll": Double(camera.eulerAngles.z) * 180.0 / .pi,
            ],
            // PROMPT.md's Stage 2 spec also asked for exposure duration/offset; the installed
            // iOS 18.5 SDK's ARFrame has no such members (unverified whether that's an SDK
            // version difference or a wrong assumption on my part) -- ambient light readings
            // are the closest available substitute for judging the bright/dim toggle.
            "ambient_intensity_lumens": frame.lightEstimate?.ambientIntensity as Any,
            "ambient_color_temperature_k": frame.lightEstimate?.ambientColorTemperature as Any,
            // Native (unrotated) sensor-buffer frame -- matches depth_width/depth_height below and the .jpg's raw pixels.
            "image_width": Int(imageResolution.width),
            "image_height": Int(imageResolution.height),
            "image_intrinsics_row_major": [
                intrinsics.columns.0.x, intrinsics.columns.1.x, intrinsics.columns.2.x,
                intrinsics.columns.0.y, intrinsics.columns.1.y, intrinsics.columns.2.y,
                intrinsics.columns.0.z, intrinsics.columns.1.z, intrinsics.columns.2.z,
            ],
            "depth_width": depthWidth,
            "depth_height": depthHeight,
            "jpeg_exif_orientation": "right (cosmetic only -- pixel data itself is unrotated, see file header comment)",
        ]

        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private static func readFloat32Plane(_ pixelBuffer: CVPixelBuffer) throws -> (data: [Float32], width: Int, height: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { throw CaptureError.imageConversionFailed }

        var values = [Float32](repeating: 0, count: width * height)
        for row in 0..<height {
            let rowPtr = (base + row * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for col in 0..<width {
                values[row * width + col] = rowPtr[col]
            }
        }
        return (values, width, height)
    }

    private static func readUInt8Plane(_ pixelBuffer: CVPixelBuffer) throws -> (data: [UInt8], width: Int, height: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { throw CaptureError.imageConversionFailed }

        var values = [UInt8](repeating: 0, count: width * height)
        for row in 0..<height {
            let rowPtr = (base + row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for col in 0..<width {
                values[row * width + col] = rowPtr[col]
            }
        }
        return (values, width, height)
    }

    private static func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
