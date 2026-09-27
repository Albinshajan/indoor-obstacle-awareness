import Foundation

/// Every detector bundled in the app. Raw values match both the bundled
/// `.mlpackage` resource names (compiled to `.mlmodelc` at build time) and
/// `tools/export_coreml.py`'s manifest model names, so results line up.
///
/// The first three are Objective 1's candidates, trained under one recipe and
/// compared in §4.1. **`yolo26n` is the measured model**: every accuracy,
/// distance, latency and thermal figure in the thesis was produced with it,
/// and it stays the default everywhere.
///
/// The last two come from the retraining experiments
/// (`results/objective1_ablation_findings.md`) and are here to be *compared
/// against* the measured model, not to replace it. Both score better on the
/// photograph benchmarks and worse in the one place that matters most:
/// pointed at the corridor the ground-truth captures were taken in, both draw
/// large boxes on the empty floor — `aib` calls them `wall`, `full` calls them
/// `door`, which in Assist would take its distance from the floor ahead and
/// warn about a door that is not there. Select them in the Detect tab and
/// sweep a real corridor: that is the comparison no benchmark here can make.
enum DetectorVariant: String, CaseIterable, Identifiable {
    case yolov8n
    case yolo11n
    case yolo26n
    /// yolo26n retrained with mosaic augmentation, the missing person/chair/
    /// table labels filled in, and the AI Builders corpus added.
    case yolo26nFull = "yolo26n_full"
    /// yolo26n retrained with the AI Builders corpus added, nothing else.
    case yolo26nAIB = "yolo26n_aib"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yolov8n, .yolo11n, .yolo26n: return rawValue
        case .yolo26nFull: return "26n+full"
        case .yolo26nAIB: return "26n+aib"
        }
    }

    /// True for the three models Chapter 4 reports. The experimental two are
    /// marked in the interface so a screenshot cannot imply the thesis
    /// measured them.
    var isMeasured: Bool {
        switch self {
        case .yolov8n, .yolo11n, .yolo26n: return true
        case .yolo26nFull, .yolo26nAIB: return false
        }
    }
}
