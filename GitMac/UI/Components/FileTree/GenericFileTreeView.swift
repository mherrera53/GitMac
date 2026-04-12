import SwiftUI

// MARK: - Lightweight Flat Tree Item (Memory Optimized)

struct GenericFlatTreeItem: Identifiable, Equatable {
    let id: String      // path serves as id
    let name: String
    let isFolder: Bool
    let depth: Int

    var path: String { id }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.isFolder == rhs.isFolder && lhs.depth == rhs.depth
    }
}

// MARK: - Generic File Tree View (Memory Optimized)

struct GenericFileTreeView<T, NodeView: View>: View {
    let paths: [String]
    let dataProvider: (String) -> T?
    @Binding var selectedPath: String?
    let section: String
    var extensionFilter: String? = nil
    let nodeView: (String, T?, Bool, Bool, String) -> NodeView  // path, data, isFolder, isSelected, section

    // Only store flat items - no tree structure retained
    @State private var flatItems: [GenericFlatTreeItem] = []
    @State private var expandedPaths: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Hidden trigger - forces view to render so .task fires
            Text("\(paths.count)")
                .font(.system(size: 0.1))
                .foregroundStyle(.clear)
                .frame(height: 0.1)

            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(flatItems) { item in
                    rowView(for: item)
                }
            }
        }
        .task(id: paths.count) { rebuildIfNeeded() }
        .onChange(of: extensionFilter) { _, _ in rebuildIfNeeded() }
    }

    @ViewBuilder
    private func rowView(for item: GenericFlatTreeItem) -> some View {
        if item.isFolder {
            // Entire folder row is clickable to toggle expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    toggleExpansion(item.path)
                }
            } label: {
                HStack(spacing: 0) {
                    if item.depth > 0 {
                        Spacer().frame(width: CGFloat(item.depth) * 12)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.chevronColor)
                        .rotationEffect(.degrees(expandedPaths.contains(item.path) ? 90 : 0))
                        .frame(width: 12, height: 12)
                        .padding(.trailing, 2)

                    nodeView(
                        item.path,
                        nil,
                        true,
                        selectedPath == item.path,
                        section
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            // File rows — click handled by nodeView's own Button
            HStack(spacing: 0) {
                if item.depth > 0 {
                    Spacer().frame(width: CGFloat(item.depth) * 12)
                }

                Spacer().frame(width: 14)

                nodeView(
                    item.path,
                    dataProvider(item.path),
                    false,
                    selectedPath == item.path,
                    section
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
    }

    private func rebuildIfNeeded() {
        // Build tree structure temporarily, extract flat items, discard tree
        let root = buildTreeStructure()
        var expanded = Set<String>()
        collectExpandedFolders(from: root, into: &expanded)
        expandedPaths = expanded
        flatItems = flattenToItems(root, depth: 0)
        // root is deallocated here - no retained tree
    }

    private func toggleExpansion(_ path: String) {
        // Check actual expanded state (accounts for default-expanded folders)
        let wasExpanded = expandedPaths.contains(path)
        TreeExpansionState.shared.toggle(path, section: section)
        if wasExpanded {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
        rebuildIfNeeded()
    }

    // MARK: - Tree Building (Temporary, not retained)

    private struct TempNode {
        let name: String
        let path: String
        let isFolder: Bool
        var children: [TempNode] = []
    }

    private func buildTreeStructure() -> [TempNode] {
        var rootChildren: [String: TempNode] = [:]

        for path in paths {
            let components = path.split(separator: "/").map(String.init)
            guard !components.isEmpty else { continue }

            insertPath(components: components, at: 0, into: &rootChildren)
        }

        return Array(rootChildren.values).sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func insertPath(components: [String], at index: Int, into nodes: inout [String: TempNode]) {
        guard index < components.count else { return }

        let name = components[index]
        let currentPath = components[0...index].joined(separator: "/")
        let isLast = index == components.count - 1

        if isLast {
            // File node
            nodes[name] = TempNode(name: name, path: currentPath, isFolder: false)
        } else {
            // Folder node
            if nodes[name] == nil {
                nodes[name] = TempNode(name: name, path: currentPath, isFolder: true)
            }
            var folder = nodes[name]!
            var folderChildren = Dictionary(uniqueKeysWithValues: folder.children.map { ($0.name, $0) })
            insertPath(components: components, at: index + 1, into: &folderChildren)
            folder.children = Array(folderChildren.values).sorted { a, b in
                if a.isFolder != b.isFolder { return a.isFolder }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            nodes[name] = folder
        }
    }

    private func collectExpandedFolders(from nodes: [TempNode], into paths: inout Set<String>) {
        for node in nodes where node.isFolder {
            if TreeExpansionState.shared.isExpanded(node.path, section: section) {
                paths.insert(node.path)
            }
            collectExpandedFolders(from: node.children, into: &paths)
        }
    }

    private func flattenToItems(_ nodes: [TempNode], depth: Int) -> [GenericFlatTreeItem] {
        var result: [GenericFlatTreeItem] = []
        result.reserveCapacity(nodes.count * 2)

        for node in nodes {
            guard nodeMatchesFilter(node) else { continue }

            result.append(GenericFlatTreeItem(
                id: node.path,
                name: node.name,
                isFolder: node.isFolder,
                depth: depth
            ))

            if node.isFolder && expandedPaths.contains(node.path) {
                result.append(contentsOf: flattenToItems(node.children, depth: depth + 1))
            }
        }
        return result
    }

    private func nodeMatchesFilter(_ node: TempNode) -> Bool {
        guard let ext = extensionFilter else { return true }
        if node.isFolder {
            return node.children.contains { nodeMatchesFilter($0) }
        }
        return (node.path as NSString).pathExtension.lowercased() == ext.lowercased()
    }
}

// MARK: - Convenience Extensions

extension GenericFileTreeView {
    /// Creates a file tree for StagingFile objects
    static func forStagingFiles<SF>(
        files: [SF],
        selectedPath: Binding<String?>,
        section: String,
        extensionFilter: String? = nil,
        pathExtractor: @escaping (SF) -> String,
        @ViewBuilder nodeView: @escaping (String, SF?, Bool, Bool, String) -> NodeView
    ) -> GenericFileTreeView<SF, NodeView> {
        let allPaths = files.map(pathExtractor)
        let fileDict = Dictionary(uniqueKeysWithValues: files.map { (pathExtractor($0), $0) })

        return GenericFileTreeView<SF, NodeView>(
            paths: allPaths,
            dataProvider: { fileDict[$0] },
            selectedPath: selectedPath,
            section: section,
            extensionFilter: extensionFilter,
            nodeView: nodeView
        )
    }
}
