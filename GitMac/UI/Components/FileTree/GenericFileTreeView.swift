import SwiftUI

// MARK: - Generic File Tree View

/// Generic tree view that can display any hierarchical file structure
struct GenericFileTreeView<T, NodeView: View>: View {
    let paths: [String]
    let dataProvider: (String) -> T?
    @Binding var selectedPath: String?
    let section: String
    var extensionFilter: String? = nil
    @ViewBuilder let nodeView: (GenericTreeNode<T>, Bool, String) -> NodeView

    @ObservedObject private var expansionState = TreeExpansionState.shared

    var body: some View {
        let tree = buildTree()
        ForEach(tree.sortedChildren.filter { nodeMatchesFilter($0) }) { node in
            GenericTreeNodeView(
                node: node,
                selectedPath: $selectedPath,
                section: section,
                extensionFilter: extensionFilter,
                nodeView: nodeView
            )
        }
    }

    /// Check if a node or any of its descendants match the extension filter
    private func nodeMatchesFilter(_ node: GenericTreeNode<T>) -> Bool {
        guard let ext = extensionFilter else { return true }

        if node.isFolder {
            // Folder matches if any child matches
            return node.children.contains { nodeMatchesFilter($0) }
        } else {
            // File matches if extension matches
            let fileExt = (node.path as NSString).pathExtension.lowercased()
            return fileExt == ext.lowercased()
        }
    }

    private func buildTree() -> GenericTreeNode<T> {
        let root = GenericTreeNode<T>(name: "", path: "", isFolder: true)

        for path in paths {
            addToTree(root: root, path: path)
        }

        return root
    }

    private func addToTree(root: GenericTreeNode<T>, path: String) {
        let components = path.split(separator: "/").map(String.init)
        var current = root

        for (index, component) in components.enumerated() {
            let isLast = index == components.count - 1
            let currentPath = components[0...index].joined(separator: "/")

            if isLast {
                // This is a file
                let data = dataProvider(currentPath)
                let fileNode = GenericTreeNode<T>(
                    name: component,
                    path: currentPath,
                    isFolder: false,
                    data: data
                )
                current.addChild(fileNode)
            } else {
                // This is a folder - find or create
                current = current.findOrCreateFolder(name: component, path: currentPath)
            }
        }
    }
}

// MARK: - Generic Tree Node View (Recursive)

struct GenericTreeNodeView<T, NodeView: View>: View {
    @ObservedObject var node: GenericTreeNode<T>
    @Binding var selectedPath: String?
    let section: String
    var extensionFilter: String? = nil
    @ViewBuilder let nodeView: (GenericTreeNode<T>, Bool, String) -> NodeView

    @ObservedObject private var expansionState = TreeExpansionState.shared
    @State private var isHovered = false

    private var isSelected: Bool {
        selectedPath == node.path
    }

    private var isExpanded: Bool {
        expansionState.isExpanded(node.path, section: section)
    }

    /// Filtered children based on extension filter
    private var filteredChildren: [GenericTreeNode<T>] {
        guard extensionFilter != nil else { return node.sortedChildren }
        return node.sortedChildren.filter { nodeMatchesFilter($0) }
    }

    /// Check if a node or any of its descendants match the extension filter
    private func nodeMatchesFilter(_ node: GenericTreeNode<T>) -> Bool {
        guard let ext = extensionFilter else { return true }

        if node.isFolder {
            return node.children.contains { nodeMatchesFilter($0) }
        } else {
            let fileExt = (node.path as NSString).pathExtension.lowercased()
            return fileExt == ext.lowercased()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Node content with chevron for folders
            HStack(spacing: 0) {
                // Disclosure chevron with clickable area for folders (positioned right before folder icon)
                if node.isFolder {
                    Button(action: {
                        // Toggle state immediately (no animation wrapper to prevent click lag)
                        expansionState.toggle(node.path, section: section)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.chevronColor)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.15), value: isExpanded)
                            .frame(width: 14, height: 14)
                            .padding(.trailing, 2)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .help(isExpanded ? "Click to collapse" : "Click to expand")
                } else {
                    // Empty spacer for files to align with folder content
                    Spacer()
                        .frame(width: 16)
                }

                // Node content
                nodeView(node, isSelected, section)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }

            // Children (if folder and expanded)
            if node.isFolder && isExpanded {
                ForEach(filteredChildren) { child in
                    GenericTreeNodeView(
                        node: child,
                        selectedPath: $selectedPath,
                        section: section,
                        extensionFilter: extensionFilter,
                        nodeView: nodeView
                    )
                    .padding(.leading, 16)
                }
            }
        }
    }
}

// MARK: - Convenience Extensions

// StagingFile support (for ContentView staging)
extension GenericFileTreeView {
    /// Creates a file tree for StagingFile objects (requires StagingFile to be imported)
    static func forStagingFiles<SF, NV: View>(
        files: [SF],
        selectedPath: Binding<String?>,
        section: String,
        extensionFilter: String? = nil,
        pathExtractor: @escaping (SF) -> String,
        @ViewBuilder nodeView: @escaping (GenericTreeNode<SF>, Bool, String) -> NV
    ) -> GenericFileTreeView<SF, NV> {
        let allPaths = files.map(pathExtractor)

        let dataProvider: (String) -> SF? = { path in
            files.first { pathExtractor($0) == path }
        }

        return GenericFileTreeView<SF, NV>(
            paths: allPaths,
            dataProvider: dataProvider,
            selectedPath: selectedPath,
            section: section,
            extensionFilter: extensionFilter,
            nodeView: nodeView
        )
    }
}

// FileStatus support (for StagingAreaView)
extension GenericFileTreeView where T == FileStatus {
    /// Creates a file tree for FileStatus objects
    static func forFileStatus(
        files: [FileStatus],
        untrackedPaths: [String],
        selectedPath: Binding<String?>,
        section: String,
        extensionFilter: String? = nil,
        @ViewBuilder nodeView: @escaping (GenericTreeNode<FileStatus>, Bool, String) -> NodeView
    ) -> GenericFileTreeView<FileStatus, NodeView> {
        // Combine all paths
        let allPaths = files.map { $0.path } + untrackedPaths

        // Data provider
        let dataProvider: (String) -> FileStatus? = { path in
            files.first { $0.path == path }
        }

        return GenericFileTreeView(
            paths: allPaths,
            dataProvider: dataProvider,
            selectedPath: selectedPath,
            section: section,
            extensionFilter: extensionFilter,
            nodeView: nodeView
        )
    }
}
