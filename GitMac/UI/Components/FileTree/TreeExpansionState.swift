import SwiftUI

// MARK: - Tree Expansion State

/// Manages expansion/collapse state for tree views
/// Shared singleton ensures state persists across view recreations
@MainActor
class TreeExpansionState: ObservableObject {
    static let shared = TreeExpansionState()

    @Published var expandedPaths: Set<String> = []

    // Track explicitly collapsed paths to distinguish from "never seen"
    private var collapsedPaths: Set<String> = []

    private init() {}

    /// Check if a path is expanded
    /// By default, folders are expanded unless explicitly collapsed
    func isExpanded(_ path: String, section: String = "") -> Bool {
        let key = section.isEmpty ? path : "\(section):\(path)"

        // If path was explicitly collapsed, return false
        if collapsedPaths.contains(key) {
            return false
        }

        // If path was explicitly expanded, return true
        if expandedPaths.contains(key) {
            return true
        }

        // Default: expand all folders on first view
        return true
    }

    /// Toggle expansion state for a path
    func toggle(_ path: String, section: String = "") {
        let key = section.isEmpty ? path : "\(section):\(path)"

        if expandedPaths.contains(key) {
            expandedPaths.remove(key)
            collapsedPaths.insert(key)
        } else {
            expandedPaths.insert(key)
            collapsedPaths.remove(key)
        }
    }

    /// Set expansion state explicitly
    func setExpanded(_ path: String, section: String = "", expanded: Bool) {
        let key = section.isEmpty ? path : "\(section):\(path)"

        if expanded {
            expandedPaths.insert(key)
            collapsedPaths.remove(key)
        } else {
            expandedPaths.remove(key)
            collapsedPaths.insert(key)
        }
    }

    /// Expand all paths in a collection
    func expandAll(_ paths: [String], section: String = "") {
        for path in paths {
            let key = section.isEmpty ? path : "\(section):\(path)"
            expandedPaths.insert(key)
            collapsedPaths.remove(key)
        }
    }

    /// Collapse all paths in a collection
    func collapseAll(_ paths: [String], section: String = "") {
        for path in paths {
            let key = section.isEmpty ? path : "\(section):\(path)"
            expandedPaths.remove(key)
            collapsedPaths.insert(key)
        }
    }

    /// Check if a path has been explicitly collapsed (vs never expanded)
    func wasCollapsed(_ path: String, section: String = "") -> Bool {
        let key = section.isEmpty ? path : "\(section):\(path)"
        return collapsedPaths.contains(key)
    }

    /// Clear all expansion state
    func reset() {
        expandedPaths.removeAll()
        collapsedPaths.removeAll()
    }
}
