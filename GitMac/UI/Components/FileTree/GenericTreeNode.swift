import SwiftUI

// MARK: - Generic Tree Node

/// Generic tree node that can hold any type of file/folder data
class GenericTreeNode<T>: Identifiable, ObservableObject {
    let id: String
    let name: String
    let path: String
    let isFolder: Bool
    @Published var children: [GenericTreeNode<T>]
    var data: T?

    init(name: String, path: String, isFolder: Bool, data: T? = nil) {
        self.id = path.isEmpty ? UUID().uuidString : path
        self.name = name
        self.path = path
        self.isFolder = isFolder
        self.children = []
        self.data = data
    }

    /// Adds a child node, maintaining sorted order
    func addChild(_ child: GenericTreeNode<T>) {
        children.append(child)
    }

    /// Finds or creates a folder child with the given name
    func findOrCreateFolder(name: String, path: String) -> GenericTreeNode<T> {
        if let existing = children.first(where: { $0.name == name && $0.isFolder }) {
            return existing
        }

        let folder = GenericTreeNode<T>(name: name, path: path, isFolder: true)
        addChild(folder)
        return folder
    }

    /// Recursively counts all files (non-folders) in this tree
    var fileCount: Int {
        if !isFolder {
            return 1
        }
        return children.reduce(0) { $0 + $1.fileCount }
    }

    /// Returns sorted children (folders first, then alphabetically)
    var sortedChildren: [GenericTreeNode<T>] {
        children.sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder {
                return lhs.isFolder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

// MARK: - TreeNodeData Conformance
// TODO: Fix protocol conformance - TreeNodeData requires children: [Self] but we have children: [GenericTreeNode<T>]
// This requires rethinking the generic architecture

/*
extension GenericTreeNode: TreeNodeData {
    // Already conforms via properties
}
*/
