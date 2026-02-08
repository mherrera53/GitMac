import Foundation
import SwiftUI

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
    case clean = "clean"
    case mergeConflict = "conflict"

    var icon: String {
        switch self {
        case .initialized, .clean, .upToDate: return "checkmark.circle.fill"
        case .uninitialized: return "minus.circle.fill"
        case .modified: return "exclamationmark.circle.fill"
        case .mergeConflict: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .initialized, .clean, .upToDate: return .green
        case .uninitialized, .unknown: return .gray
        case .modified: return .orange
        case .mergeConflict: return .red
        }
    }
}
