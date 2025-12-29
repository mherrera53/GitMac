import Foundation

/// Represents a Git submodule
struct GitSubmodule: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let url: String
    let branch: String?
    let status: SubmoduleStatus
    let commitSHA: String?
    
    var displayName: String {
        name.components(separatedBy: "/").last ?? name
    }
}

enum SubmoduleStatus: String, Hashable {
    case initialized = "Initialized"
    case uninitialized = "Uninitialized"
    case modified = "Modified"
    case upToDate = "Up to date"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .initialized: return "checkmark.circle.fill"
        case .uninitialized: return "circle"
        case .modified: return "exclamationmark.circle.fill"
        case .upToDate: return "checkmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .initialized: return "green"
        case .uninitialized: return "gray"
        case .modified: return "orange"
        case .upToDate: return "green"
        case .unknown: return "gray"
        }
    }
}
