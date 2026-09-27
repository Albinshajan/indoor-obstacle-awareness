import Foundation

/// Must match `tools/taxonomy.py`'s `CAPTURE_CLASSES` exactly -- these raw
/// values are parsed straight out of saved filenames by distance_eval.py.
enum ObstacleClass: String, CaseIterable, Identifiable {
    case door
    case chair
    case tableEdge = "table_edge"
    case pole
    case lowObstacle = "low_obstacle"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .door: return "Door"
        case .chair: return "Chair"
        case .tableEdge: return "Table edge"
        case .pole: return "Wall / pole"
        case .lowObstacle: return "Low obstacle"
        }
    }
}

enum LightingCondition: String, CaseIterable, Identifiable {
    case bright
    case dim

    var id: String { rawValue }
}

/// The distances the capture protocol asks for (CLAUDE.md section 5): 0.5-4.5 m in 0.5 m steps.
enum CaptureProtocol {
    static let distancesMM: [Int] = stride(from: 500, through: 4500, by: 500).map { $0 }
}
