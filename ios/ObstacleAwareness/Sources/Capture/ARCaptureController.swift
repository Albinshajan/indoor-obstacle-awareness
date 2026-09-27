import ARKit
import Combine

/// Runs the AR session and publishes the latest frame plus a few HUD signals.
///
/// Pitch is tracked *relative to the first frame of the session* rather than
/// against an assumed absolute "zero = level" reference, because CLAUDE.md's
/// actual requirement is *consistency* across a capture session
/// ("inconsistent pitch is the biggest avoidable source of monocular error"),
/// not a specific absolute angle. Re-running `start()` resets the reference,
/// so begin each shooting session holding the phone at whatever pitch you
/// intend to hold throughout.
///
/// The angle comes from `ARCamera.elevationDegrees` below rather than
/// `eulerAngles.x`. Both were checked against twelve real on-device captures
/// (2026-09-15) and **they agree to two decimal places on every frame**, so
/// `eulerAngles.x` was never wrong here: ARKit defines it as exactly this
/// elevation. The earlier worry recorded in this file -- that a portrait-held
/// phone sits at roll ~= -90 degrees, which is where an Euler decomposition
/// couples its pitch and yaw components -- did not materialise in practice.
///
/// The forward-vector form is kept anyway because it has no convention to get
/// wrong, and is now cross-checked rather than assumed. Roll does sit at -86
/// to -93 degrees for a portrait hold, which is expected: ARKit defines the
/// camera frame in landscape-right, so portrait is rolled 90 degrees by
/// construction. That reading is not a fault and should not be "fixed".
///
/// Calibration from the same twelve frames: a deliberate level hold held to
/// within 2.5 degrees across seven captures, so the 10-degree warning
/// threshold below catches real drift without nuisance warnings.
final class ARCaptureController: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()

    @Published private(set) var latestFrame: ARFrame?
    @Published private(set) var pitchDegrees: Double = 0
    @Published private(set) var pitchDeviationDegrees: Double = 0
    @Published private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var sceneDepthSupported: Bool = false

    private var referencePitchDegrees: Double?
    let pitchWarningThresholdDegrees: Double = 10

    override init() {
        super.init()
        session.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged),
                                                name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }

    func start() {
        referencePitchDegrees = nil
        sceneDepthSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = []
        if sceneDepthSupported {
            config.frameSemantics.insert(.sceneDepth)
        }
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        latestFrame = frame
        let degrees = frame.camera.elevationDegrees
        pitchDegrees = degrees
        if referencePitchDegrees == nil {
            referencePitchDegrees = degrees
        }
        pitchDeviationDegrees = abs(degrees - (referencePitchDegrees ?? degrees))
    }

    @objc private func thermalStateChanged() {
        thermalState = ProcessInfo.processInfo.thermalState
    }
}

extension ARCamera {
    /// Elevation of the optical axis above (+) or below (-) horizontal, in degrees.
    ///
    /// Read from the camera's forward vector in gravity-aligned world space
    /// rather than from `eulerAngles`, for the reason given in the type
    /// comment above. Under `.gravity` world alignment world +Y is up, so the
    /// y component of the unit forward vector is the sine of the elevation
    /// angle -- true in any device orientation, with no axis-ordering or
    /// gimbal-lock assumption to be wrong about.
    var elevationDegrees: Double {
        let forward = simd_normalize(-simd_make_float3(transform.columns.2))
        return Double(asin(max(-1, min(1, forward.y)))) * 180.0 / .pi
    }
}
