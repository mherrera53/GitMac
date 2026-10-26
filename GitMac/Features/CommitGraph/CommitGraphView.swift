import SwiftUI

// Models, Components, ViewModels, and Services are defined in their respective files:
// - Models/: GraphTransferables, GraphSettings, GraphNode, StashNode, TimelineItem, GraphNotifications
// - Components/: GhostBranchesOverlay, BranchBadge, StashBadge, UncommittedChangesRow, GraphStashRow, GraphRow, CommitContextMenu
// - ViewModels/: GraphViewModel
// - Services/: GraphLayoutEngine

// BranchPanelView, BranchSection, BranchPanelRow, and GraphMinimapView are
// defined in Components/ folder - do not redefine here

// MARK: - Commit Graph View
struct CommitGraphView: View {
    @Environment(AppState.self) var appState
    @State private var vm = GraphViewModel()
    @StateObject private var detailVM = CommitDetailViewModel()
    @StateObject private var tracker = RemoteOperationTracker.shared
    @State private var settings = GraphSettings()
    @State private var selectedIds: Set<String> = []
    @State private var lastSelectedId: String?
    @State private var hoveredId: String?
    @State private var hoveredBranch: String?
    @State private var themeRefreshTrigger = UUID()
    @State private var showBranchPanel = false
    @AppStorage("graphShowMinimap") private var showMinimap = true
    @State private var showDetailPanel = false
    @State private var selectedFileDiff: FileDiff? = nil
    @State private var dismissedOperationIds: Set<UUID> = []

    // Minimap visible range tracking
    @State private var graphScrollOffset: CGFloat = 0
    @State private var graphViewportHeight: CGFloat = 0
    @State private var scrollToID: String?
    @State private var minimapSeekTask: Task<Void, Never>?
    @State private var minimapSeekID = UUID()
    @State private var isSeekingMinimap = false
    @State private var minimapSeekError: String?

    // Commit comparison mode - state managed in appState
    @State private var showStaleBranchCleanup = false
    @State private var zoomBaseLevel: CGFloat = 1.0

    // PR creation from drag & drop
    @State private var showPRSheet = false
    @State private var prHeadBranch: String = ""
    @State private var prBaseBranch: String = ""

    // Worktree creation from commit
    @State private var showWorktreeSheet = false
    @State private var worktreeCommitSHA: String = ""

    private func isDismissedOperation(_ operation: RemoteOperation) -> Bool {
        dismissedOperationIds.contains(operation.id)
    }

    private func dismissOperation(_ operation: RemoteOperation) {
        _ = withAnimation(.easeOut(duration: 0.2)) {
            dismissedOperationIds.insert(operation.id)
        }
    }

    @State private var selectedCommit: Commit?

    @ViewBuilder
    private func detailPanelView(commit: Commit) -> some View {
        CommitDetailPanel(
            commit: commit,
            onClose: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetailPanel = false
                }
            },
            onOpenDiff: { (c: Commit) in
                appState.selectCommit(c)
            }
        )
        .environment(appState)
        .transition(.move(edge: .trailing))
    }

    private func selectBranchInGraph(_ branch: Branch) {
        if let commit = vm.commitsBySHA[branch.targetSHA] {
            selectedIds = [commit.sha]
            lastSelectedId = commit.sha
        }
    }

    private func updateSelectedCommit() {
        guard let lastId = lastSelectedId else {
            selectedCommit = nil
            return
        }
        selectedCommit = vm.commitsBySHA[lastId]
    }

    var body: some View {
        mainGraphLayout
            .background(AppTheme.background)
            .modifier(GraphDataModifiers(appState: appState, vm: vm, settings: settings, lastSelectedId: $lastSelectedId, selectedCommit: $selectedCommit))
            .modifier(GraphSheetModifiers(appState: appState, showPRSheet: $showPRSheet, prHeadBranch: prHeadBranch, prBaseBranch: prBaseBranch, showStaleBranchCleanup: $showStaleBranchCleanup, showWorktreeSheet: $showWorktreeSheet, worktreeCommitSHA: worktreeCommitSHA))
            .modifier(GraphNotificationModifiers(appState: appState, vm: vm, showStaleBranchCleanup: $showStaleBranchCleanup, worktreeCommitSHA: $worktreeCommitSHA, showWorktreeSheet: $showWorktreeSheet))
            .onAppear {
                zoomBaseLevel = settings.zoomLevel
            }
            .onChange(of: vm.historySnapshotID) { _, _ in
                minimapSeekTask?.cancel()
                minimapSeekID = UUID()
                isSeekingMinimap = false
                scrollToID = nil
            }
            .onDisappear { minimapSeekTask?.cancel() }
            .alert("Could not navigate to commit", isPresented: Binding(
                get: { minimapSeekError != nil }, set: { if !$0 { minimapSeekError = nil } })) {
                Button("OK") { minimapSeekError = nil }
            } message: { Text(minimapSeekError ?? "") }
    }

    @ViewBuilder
    private var mainGraphLayout: some View {
        VStack(spacing: 0) {
            if let operation = lastOperationForCurrentBranch, !isDismissedOperation(operation) {
                remoteStatusBar(operation: operation)
            }

            graphToolbar
                .id(themeRefreshTrigger)

            HStack(spacing: 0) {
                if showBranchPanel {
                    BranchPanelView(
                        branches: $vm.branches,
                        currentBranch: appState.currentRepository?.currentBranch,
                        onSelectBranch: { branch in selectBranchInGraph(branch) },
                        onCheckout: { branch in Task { await checkoutBranch(branch) } }
                    )
                    .transition(.move(edge: .leading))
                    Divider()
                }

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        graphHeader
                        graphContent
                    }
                    .onAppear { settings.availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, newWidth in settings.availableWidth = newWidth }
                }

                if showMinimap {
                    Divider()
                    minimapPanel
                }

                if showDetailPanel, let commit = selectedCommit {
                    Divider()
                    detailPanelView(commit: commit)
                }
            }
        }
    }

    @ViewBuilder
    private var minimapPanel: some View {
        GraphMinimapView(
            minimapNodes: vm.minimapDrawingNodes,
            totalCount: vm.totalCommitCount,
            maxLane: vm.minimapMaxLane,
            loadedCount: vm.nodes.count,
            visibleRange: minimapVisibleRange,
            selectedIndex: lastSelectedId.flatMap { vm.minimapIndexBySHA[$0] },
            isLoading: vm.isLoadingMinimap || isSeekingMinimap,
            errorMessage: vm.minimapError,
            onSeek: { index in handleMinimapSeek(index) },
            onRetry: { Task { await vm.reloadMinimap() } }
        )
        .transition(.move(edge: .trailing))
    }

    private var filteredTimelineItems: [TimelineItem] {
        if settings.searchText.isEmpty && settings.filterAuthor.isEmpty && settings.showTags && settings.showBranches && settings.showStashes {
            return vm.timelineItems
        }
        return vm.timelineItems.filter { item in
            switch item {
            case .uncommitted: return true
            case .commit(let node): return matchesSearchAndFilter(node)
            case .stash: return settings.showStashes
            }
        }
    }

    private func handleItemAppear(_ item: TimelineItem) {
        if vm.timelineItems.suffix(10).contains(where: { $0.id == item.id }), vm.hasMore, !vm.isLoading {
            Task { await vm.loadMore() }
        }
    }

    private func handleMinimapSeek(_ index: Int) {
        guard vm.minimapNodes.indices.contains(index) else { return }
        let sha = vm.minimapNodes[index].sha
        let snapshot = vm.historySnapshotID
        minimapSeekTask?.cancel()
        let request = UUID()
        minimapSeekID = request
        isSeekingMinimap = true
        minimapSeekTask = Task { @MainActor in
            defer { if minimapSeekID == request { isSeekingMinimap = false } }
            while vm.isLoading {
                do { try await Task.sleep(nanoseconds: 30_000_000) } catch { return }
            }
            guard !Task.isCancelled, vm.historySnapshotID == snapshot else { return }
            await vm.loadUpTo(index: index)
            guard !Task.isCancelled, vm.historySnapshotID == snapshot else { return }
            guard let commit = vm.commitsBySHA[sha] else {
                minimapSeekError = vm.lastError ?? "The selected revision is no longer available. Refresh the history and retry."
                return
            }
            settings.searchText = ""
            settings.filterAuthor = ""
            selectedIds = [sha]
            lastSelectedId = sha
            appState.selectCommit(commit)
            appState.selectStash(nil)
            scrollToID = sha
        }
    }

    private var minimapVisibleRange: ClosedRange<Int>? {
        MinimapLayout.visibleRange(timeline: filteredTimelineItems, indices: vm.minimapIndexBySHA,
            offset: max(0, -graphScrollOffset), height: graphViewportHeight, rowHeight: settings.rowHeight)
    }

    // MARK: - Remote Status

    private var lastOperationForCurrentBranch: RemoteOperation? {
        guard let branch = appState.currentRepository?.currentBranch?.name else { return nil }
        return tracker.getLastOperation(for: branch)
    }

    private func remoteStatusBar(operation: RemoteOperation) -> some View {
        return HStack(spacing: DesignTokens.Spacing.md) {
            // Status icon and info
            RemoteStatusBadge(operation: operation, compact: false)

            // Time ago
            Text(operation.timestamp.formatted(.relative(presentation: .named)))
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            // Error details button
            if !operation.success, let error = operation.error {
                Button {
                    NotificationManager.shared.error(
                        "\(operation.type.displayName) failed",
                        detail: error
                    )
                } label: {
                    Label("Details", systemImage: "info.circle")
                        .font(DesignTokens.Typography.caption)
                }
                .buttonStyle(.borderless)
            }

            // Dismiss button
            Button {
                dismissOperation(operation)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            ZStack(alignment: .bottom) {
                operation.color.opacity(0.08)
                Rectangle()
                    .frame(height: DesignTokens.Spacing.xxs)
                    .foregroundStyle(operation.color.opacity(0.4))
            }
        )
    }

    // MARK: - Branch Operations

    private func checkoutBranch(_ branch: Branch) async {
        guard let repoPath = appState.currentRepository?.path else { return }

        let executor = ShellExecutor.shared
        let result = await executor.execute(
            "git",
            arguments: ["checkout", branch.name],
            workingDirectory: repoPath
        )

        if result.exitCode == 0 {
            NotificationManager.shared.success("Checked out \(branch.name)")
            // Refresh the graph
            vm.load(at: repoPath)
            // Notify app state to update current branch
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: repoPath)
        } else {
            NotificationManager.shared.error(
                "Failed to checkout \(branch.name)",
                detail: result.stderr
            )
        }
    }

    // MARK: - Graph Toolbar

    private var graphToolbar: some View {
        HStack(spacing: 8) {
            DSSearchField(placeholder: "Search commits…", text: $settings.searchText)
                .frame(minWidth: 80, maxWidth: 400)
                .accessibilityLabel("Search commits by message, author or SHA")
            Spacer(minLength: 0)

            if settings.availableWidth >= 760 {
                HStack(spacing: 0) {
                    Button { settings.zoomOut() } label: {
                        Image(systemName: "minus.magnifyingglass").frame(width: 28, height: 28)
                    }
                    .disabled(settings.zoomLevel <= GraphSettings.zoomMin)
                    .help("Zoom out").accessibilityLabel("Zoom out graph")
                    Button { settings.resetZoom() } label: {
                        Text("\(settings.zoomPercentage)%").monospacedDigit().frame(width: 42, height: 28)
                    }
                    .help("Reset zoom to 100%").accessibilityLabel("Reset graph zoom")
                    Button { settings.zoomIn() } label: {
                        Image(systemName: "plus.magnifyingglass").frame(width: 28, height: 28)
                    }
                    .disabled(settings.zoomLevel >= GraphSettings.zoomMax)
                    .help("Zoom in").accessibilityLabel("Zoom in graph")
                }
                .buttonStyle(.borderless)
            }

            Button { showMinimap.toggle() } label: {
                Image(systemName: "map")
                    .foregroundStyle(showMinimap ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Show or hide full local-history minimap")
            .accessibilityLabel("History minimap")
            .accessibilityValue(showMinimap ? "Shown" : "Hidden")

            Menu {
                Section("Panels") {
                    Toggle("History Minimap", isOn: $showMinimap)
                    Toggle("Branch Panel", isOn: $showBranchPanel)
                    Toggle("Commit Details", isOn: $showDetailPanel)
                }
                Section("Display") {
                    Toggle("Branch Labels", isOn: $settings.showBranches)
                    Toggle("Tag Labels", isOn: $settings.showTags)
                    Toggle("Stashes", isOn: $settings.showStashes)
                    Toggle("Avatars", isOn: $settings.showAvatars)
                    Toggle("Compact Rows", isOn: $settings.compactMode)
                    Toggle("Dim Merge Commits", isOn: $settings.dimMergeCommits)
                }
                Menu("Columns") {
                    Toggle("Branch / Tag", isOn: $settings.showBranchColumn)
                    Toggle("Author", isOn: $settings.showAuthorColumn)
                    Toggle("Date / Time", isOn: $settings.showDateColumn)
                    Toggle("SHA", isOn: $settings.showSHAColumn)
                }
                Menu("Zoom") {
                    Button("Zoom In") { settings.zoomIn() }
                        .disabled(settings.zoomLevel >= GraphSettings.zoomMax)
                    Button("Zoom Out") { settings.zoomOut() }
                        .disabled(settings.zoomLevel <= GraphSettings.zoomMin)
                    Button("Reset Zoom (100%)") { settings.resetZoom() }
                }
                if !settings.filterAuthor.isEmpty || !settings.searchText.isEmpty {
                    Button("Clear Search and Author Filter") {
                        settings.searchText = ""
                        settings.filterAuthor = ""
                    }
                }
            } label: {
                Label("Graph Options", systemImage: "slider.horizontal.3")
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Graph display, panels, columns and zoom")
            .accessibilityLabel("Graph display options")
            .accessibilityIdentifier("graph-display-options")
            GitHelpButton(topicID: "graph")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Graph Header

    private var graphHeader: some View {
        return HStack(spacing: 0) {
            if settings.shouldShowBranchColumn {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .symbolRenderingMode(.monochrome)
                    Text("BRANCH / TAG")
                }
                .frame(width: settings.responsiveBranchColumnWidth, alignment: .leading)
                .padding(.leading, 12)

                ColumnResizer(
                    width: $settings.branchColumnWidth,
                    minWidth: 80,
                    maxWidth: 300
                )
            }

            HStack(spacing: 4) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .symbolRenderingMode(.monochrome)
                Text("GRAPH")
            }
            .frame(width: settings.graphColumnWidth, alignment: .center)

            Text("COMMIT MESSAGE")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, DesignTokens.Spacing.sm)

            ColumnResizer(
                width: $settings.changesColumnWidth,
                minWidth: 60,
                maxWidth: 200
            )

            Text("CHANGES")
                .frame(width: settings.responsiveChangesColumnWidth, alignment: .leading)

            if settings.shouldShowAuthorColumn {
                ColumnResizer(
                    width: $settings.authorColumnWidth,
                    minWidth: 80,
                    maxWidth: 200
                )

                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("AUTHOR")
                }
                .frame(width: settings.authorColumnWidth, alignment: .leading)
            }

            if settings.shouldShowDateColumn {
                ColumnResizer(
                    width: $settings.dateColumnWidth,
                    minWidth: 60,
                    maxWidth: 160
                )

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("DATE")
                }
                .frame(width: settings.dateColumnWidth, alignment: .trailing)
            }

            if settings.shouldShowSHAColumn {
                ColumnResizer(
                    width: $settings.shaColumnWidth,
                    minWidth: 60,
                    maxWidth: 120
                )

                HStack(spacing: 4) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("SHA")
                }
                .frame(width: settings.shaColumnWidth, alignment: .trailing)
                .padding(.trailing, DesignTokens.Spacing.sm)
            }
        }
        .font(DesignTokens.Typography.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(AppTheme.textPrimary)
        .frame(height: 28)
        .background(AppTheme.backgroundSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Graph Header")
    }

    // MARK: - Graph Content

    private var showsWorkingCopyConnection: Bool {
        vm.hasUncommittedChanges && !vm.nodes.isEmpty
            && settings.searchText.isEmpty && settings.filterAuthor.isEmpty
    }

    @ViewBuilder
    private var graphContent: some View {
        if vm.isLoading && vm.nodes.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else {
            graphScrollView
        }
    }

    private var graphScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredTimelineItems) { item in
                        itemView(for: item)
                            .frame(minHeight: settings.rowHeight)
                            .id(item.id)
                            .onAppear {
                                handleItemAppear(item)
                            }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: GraphScrollOffsetKey.self,
                        value: geometry.frame(in: .named("commitGraphScroll")).minY)
                })
            }
            .coordinateSpace(name: "commitGraphScroll")
            .background(GeometryReader { geometry in
                Color.clear.preference(key: GraphViewportHeightKey.self, value: geometry.size.height)
            })
            .onPreferenceChange(GraphScrollOffsetKey.self) { graphScrollOffset = $0 }
            .onPreferenceChange(GraphViewportHeightKey.self) { graphViewportHeight = $0 }
            .onChange(of: scrollToID) { _, id in
                if let id {
                    proxy.scrollTo(id, anchor: .center)
                    scrollToID = nil
                }
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let delta = value.magnification - 1.0
                    let newZoom = zoomBaseLevel + delta * 0.5
                    settings.zoomLevel = min(max(newZoom, GraphSettings.zoomMin), GraphSettings.zoomMax)
                }
                .onEnded { _ in
                    zoomBaseLevel = settings.zoomLevel
                }
        )
    }

    @ViewBuilder
    private func itemView(for item: TimelineItem) -> some View {
        switch item {
        case .uncommitted(let staged, let unstaged):
            UncommittedChangesRow(
                stagedCount: staged,
                unstagedCount: unstaged,
                isSelected: selectedIds.contains("uncommitted-changes"),
                isHovered: hoveredId == "uncommitted-changes",
                settings: settings,
                connectToHistory: showsWorkingCopyConnection,
                conflictedCount: vm.conflictedCount
            )
            .onHover { h in hoveredId = h ? "uncommitted-changes" : nil }
            .onTapGesture {
                handleSelection(item: item)
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    handleDoubleClick(item: item)
                }
            )
        case .commit(let node):
                GraphRow(
                    node: node,
                    isSelected: selectedIds.contains(node.commit.sha),
                    isHovered: hoveredId == node.commit.sha,
                    settings: settings,
                    hasWorkingCopyChild: showsWorkingCopyConnection && node.commit.sha == vm.nodes.first?.commit.sha,
                    onHoverBranch: { branch in
                        hoveredBranch = branch
                    },
                    onDropBranch: { targetBranch, droppedBranch in
                        // When a branch is dropped on another, show PR creation
                        prHeadBranch = droppedBranch.name
                        prBaseBranch = targetBranch
                        showPRSheet = true
                    }
                )
                .withGhostBranches(
                    commit: node.commit,
                    branches: vm.branches,
                    repoPath: appState.currentRepository?.path ?? "",
                    isHovered: hoveredId == node.commit.sha
                )
                .onHover { h in hoveredId = h ? node.commit.sha : nil }
                .onTapGesture {
                    handleSelection(item: item)
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        handleDoubleClick(item: item)
                    }
                )
                .draggable(CommitTransferable(commit: node.commit))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Commit \(node.commit.shortSha) by \(node.commit.author): \(node.commit.summary)")
                .accessibilityHint("Double tap to view details, drag branch to create PR, context click for more actions")
        case .stash(let stashNode):
            GraphStashRow(
                stash: stashNode,
                isSelected: selectedIds.contains(stashNode.id),
                isHovered: hoveredId == stashNode.id,
                settings: settings
            )
            .onHover { h in hoveredId = h ? stashNode.id : nil }
            .onTapGesture {
                handleSelection(item: item)
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    handleDoubleClick(item: item)
                }
            )
        }
    }

    // MARK: - Search and Filter

    private func matchesSearchAndFilter(_ node: GraphNode) -> Bool {
        // Parse advanced search syntax
        if !settings.searchText.isEmpty {
            let query = SearchSyntaxParser.parse(settings.searchText)
            if !query.matches(node.commit, currentUserEmail: vm.currentUserEmail) {
                return false
            }
        }

        // Filter by author (legacy support)
        if !settings.filterAuthor.isEmpty {
            if !node.commit.author.localizedCaseInsensitiveContains(settings.filterAuthor) {
                return false
            }
        }

        // Label visibility must not remove commits or change seek identity.
        return true
    }

    // MARK: - Selection

    private func handleSelection(item: TimelineItem) {
        let itemId = item.id
        let modifiers = NSEvent.modifierFlags

        if modifiers.contains(.command) {
            // Toggle selection
            if selectedIds.contains(itemId) {
                selectedIds.remove(itemId)
            } else {
                selectedIds.insert(itemId)
                lastSelectedId = itemId
            }
        } else if modifiers.contains(.shift), let lastId = lastSelectedId {
            // Range selection
            let allIds = vm.timelineItems.map { $0.id }
            if let lastIdx = allIds.firstIndex(of: lastId),
               let currentIdx = allIds.firstIndex(of: itemId) {
                let start = min(lastIdx, currentIdx)
                let end = max(lastIdx, currentIdx)
                let rangeIds = allIds[start...end]
                selectedIds.formUnion(rangeIds)
            }
        } else {
            // Single selection
            selectedIds = [itemId]
            lastSelectedId = itemId
        }

        // Show details for the last clicked item (not arbitrary Set.first)
        let targetId = lastSelectedId ?? selectedIds.first
        if let targetId {
            if let commitItem = vm.timelineItems.first(where: { $0.id == targetId }),
               case .commit(let node) = commitItem {
                appState.selectCommit(node.commit)
                appState.selectStash(nil)
            } else if let stashItem = vm.timelineItems.first(where: { $0.id == targetId }),
                      case .stash(let stashNode) = stashItem {
                appState.selectCommit(nil)
                appState.selectStash(stashNode.stash)
            } else if targetId == "uncommitted-changes" {
                // WIP selected - clear commit/stash to show staging area
                appState.selectCommit(nil)
                appState.selectStash(nil)
            }
        }
    }

    /// Handle double-click to load the diff for the first file
    private func handleDoubleClick(item: TimelineItem) {
        // Post notification to load diff for first file
        NotificationCenter.default.post(name: .loadFirstFileDiff, object: nil)
    }

    private var selectedCommits: [Commit] {
        vm.timelineItems.compactMap { item in
            if case .commit(let node) = item, selectedIds.contains(node.commit.sha) {
                return node.commit
            }
            return nil
        }
    }
}

private struct GraphScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct GraphViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - File Changes Indicator
/// Visual indicator showing file changes with count and add/delete bars
// FileChangesIndicator is defined in Features/CommitGraph/Components/FileChangesIndicator.swift

// MARK: - Column Resizer

/// Draggable divider between columns for resizing
struct ColumnResizer: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0

    var body: some View {
        ZStack {
            // Hit area for dragging
            Rectangle()
                .fill(Color.clear)
                .frame(width: 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                // Store initial width at drag start
                                dragStartWidth = width
                                isDragging = true
                            }
                            // Calculate new width from start position + translation
                            let newWidth = dragStartWidth + value.translation.width
                            width = min(maxWidth, max(minWidth, newWidth))
                        }
                        .onEnded { _ in
                            isDragging = false
                            updateCursor()
                        }
                )
                .onHover { hovering in
                    isHovering = hovering
                    updateCursor()
                }

            // Visual divider line
            Rectangle()
                .fill(visualColor)
                .frame(width: 1)
                .allowsHitTesting(false)
        }
        .frame(width: 8, height: 28)
    }

    private func updateCursor() {
        if isHovering || isDragging {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private var visualColor: Color {
        if isDragging {
            return AppTheme.accent
        } else if isHovering {
            return AppTheme.border.opacity(0.8)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Modifier Groups (extracted for type-checker performance)

private struct GraphDataModifiers: ViewModifier {
    var appState: AppState
    var vm: GraphViewModel
    var settings: GraphSettings
    @Binding var lastSelectedId: String?
    @Binding var selectedCommit: Commit?

    func body(content: Content) -> some View {
        content
            .task {
                if let p = appState.currentRepository?.path {
                    settings.setRepository(p)
                    vm.load(at: p)
                }
            }
            .onChange(of: appState.currentRepository?.path) { _, p in
                if let p {
                    settings.setRepository(p)
                    vm.load(at: p)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
                if let path = notification.object as? String,
                   path == appState.currentRepository?.path {
                    Task { await vm.refreshStatus() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoteOperationCompleted)) { _ in
                if let path = appState.currentRepository?.path {
                    vm.load(at: path)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .gitHubOperationCompleted)) { _ in
                if let path = appState.currentRepository?.path {
                    vm.load(at: path)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .branchDidCheckout)) { _ in
                if let path = appState.currentRepository?.path {
                    vm.load(at: path)
                }
            }
            .onChange(of: lastSelectedId) { _, _ in
                updateSelectedCommit()
            }
            .onChange(of: vm.timelineItems.count) { _, _ in
                updateSelectedCommit()
            }
            .onChange(of: vm.maxLane) { _, newMaxLane in
                settings.maxLane = newMaxLane
            }
    }

    private func updateSelectedCommit() {
        guard let lastId = lastSelectedId else {
            selectedCommit = nil
            return
        }
        selectedCommit = vm.commitsBySHA[lastId]
    }
}

private struct GraphSheetModifiers: ViewModifier {
    var appState: AppState
    @Binding var showPRSheet: Bool
    var prHeadBranch: String
    var prBaseBranch: String
    @Binding var showStaleBranchCleanup: Bool
    @Binding var showWorktreeSheet: Bool
    var worktreeCommitSHA: String

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showPRSheet) {
                prSheetContent
            }
            .sheet(isPresented: $showStaleBranchCleanup) {
                StaleBranchCleanupView()
                    .environment(appState)
            }
            .sheet(isPresented: $showWorktreeSheet) {
                CreateWorktreeFromCommitSheet(commitSHA: worktreeCommitSHA)
                    .environment(appState)
            }
    }

    @ViewBuilder
    private var prSheetContent: some View {
        if !prHeadBranch.isEmpty && !prBaseBranch.isEmpty {
            let fallback = Branch(name: prHeadBranch, fullName: "refs/heads/\(prHeadBranch)", isRemote: false, targetSHA: "")
            let headBranchObj: Branch = appState.currentRepository?.branches.first { $0.name == prHeadBranch } ?? fallback
            CreatePullRequestSheet(branch: headBranchObj, defaultBaseBranch: prBaseBranch)
                .environment(appState)
        }
    }
}

private struct GraphNotificationModifiers: ViewModifier {
    var appState: AppState
    var vm: GraphViewModel
    @Binding var showStaleBranchCleanup: Bool
    @Binding var worktreeCommitSHA: String
    @Binding var showWorktreeSheet: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .compareCommit)) { notification in
                handleCompareCommit(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showStaleBranchCleanup)) { _ in
                showStaleBranchCleanup = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .createWorktreeFromCommit)) { notification in
                if let sha = notification.object as? String {
                    worktreeCommitSHA = sha
                    showWorktreeSheet = true
                }
            }
    }

    private func handleCompareCommit(_ notification: Notification) {
        if let commits = notification.object as? [Commit], commits.count == 2 {
            appState.comparisonCommitA = commits[0]
            appState.comparisonCommitB = commits[1]
            appState.selectCommit(nil)
        } else if let commit = notification.object as? Commit {
            if appState.comparisonCommitA == nil {
                appState.comparisonCommitA = commit
                NotificationManager.shared.info(
                    "Select second commit",
                    detail: "Right-click another commit and choose 'Compare with...' to complete the comparison"
                )
            } else {
                appState.comparisonCommitB = commit
                appState.selectCommit(nil)
            }
        }
    }
}
