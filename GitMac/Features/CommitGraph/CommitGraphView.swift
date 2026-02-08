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
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = GraphViewModel()
    @StateObject private var detailVM = CommitDetailViewModel()
    @StateObject private var tracker = RemoteOperationTracker.shared
    @StateObject private var settings = GraphSettings()
    @State private var selectedIds: Set<String> = []
    @State private var lastSelectedId: String?
    @State private var hoveredId: String?
    @State private var hoveredBranch: String?
    @State private var showSettings = false
    @State private var themeRefreshTrigger = UUID()
    @State private var showBranchPanel = false
    @State private var showMinimap = false
    @State private var showDetailPanel = false
    @State private var selectedFileDiff: FileDiff? = nil
    @State private var dismissedOperationIds: Set<UUID> = []

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

    private var selectedCommit: Commit? {
        guard let lastId = lastSelectedId else { return nil }
        return vm.timelineItems.compactMap { item -> Commit? in
            if case .commit(let node) = item {
                return node.commit
            }
            return nil
        }.first(where: { $0.sha == lastId })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Remote operation status bar (if exists and not dismissed)
            if let operation = lastOperationForCurrentBranch, !isDismissedOperation(operation) {
                remoteStatusBar(operation: operation)
            }

            // Search and filter toolbar
            graphToolbar
                .id(themeRefreshTrigger)

            // Main content with optional panels
            HStack(spacing: 0) {
                // Branch Panel (left sidebar)
                if showBranchPanel {
                    BranchPanelView(
                        branches: $vm.branches,
                        currentBranch: appState.currentRepository?.currentBranch,
                        onSelectBranch: { branch in
                            // Select branch in graph
                            if let commit = vm.timelineItems.compactMap({ item -> Commit? in
                                if case .commit(let node) = item {
                                    return node.commit
                                }
                                return nil
                            }).first(where: { $0.sha == branch.targetSHA }) {
                                selectedIds = [commit.sha]
                                lastSelectedId = commit.sha
                            }
                        },
                        onCheckout: { branch in
                            Task {
                                await checkoutBranch(branch)
                            }
                        }
                    )
                    .transition(.move(edge: .leading))

                    Divider()
                }

                // Main graph area with responsive width detection
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        graphHeader
                        graphContent
                    }
                    .onAppear {
                        settings.availableWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        settings.availableWidth = newWidth
                    }
                }

                // Minimap (right sidebar)
                if showMinimap {
                    Divider()

                    GraphMinimapView(
                        nodes: vm.timelineItems.compactMap { item in
                            if case .commit(let node) = item {
                                return node
                            }
                            return nil
                        },
                        visibleRange: 0...max(vm.timelineItems.count - 1, 0),
                        totalHeight: CGFloat(vm.timelineItems.count * 30),
                        onSeek: { index in
                            // Scroll to index
                            if index < vm.timelineItems.count,
                               case .commit(let node) = vm.timelineItems[index] {
                                selectedIds = [node.commit.sha]
                                lastSelectedId = node.commit.sha
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                }

                // Detail Panel (right sidebar)
                if showDetailPanel, let commit = selectedCommit {
                    Divider()

                    CommitDetailPanel(
                        commit: commit,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDetailPanel = false
                            }
                        },
                        onOpenDiff: { selectedCommit in
                            // Set appState.selectedCommit to open diff in the right panel
                            appState.selectedCommit = selectedCommit
                        }
                    )
                    .environmentObject(appState)
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .background(AppTheme.background)
        .task {
            if let p = appState.currentRepository?.path {
                settings.setRepository(p)
                await vm.load(at: p)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, p in
            if let p {
                settings.setRepository(p)
                Task { await vm.load(at: p) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            if let path = notification.object as? String,
               path == appState.currentRepository?.path {
                // Use silent refresh to avoid graph flickering
                Task { await vm.refreshStatus() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteOperationCompleted)) { _ in
            // Full reload when remote operation completes (push/pull/fetch)
            if let path = appState.currentRepository?.path {
                Task { await vm.load(at: path) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gitHubOperationCompleted)) { _ in
            // Full reload when any GitHub operation completes
            if let path = appState.currentRepository?.path {
                Task { await vm.load(at: path) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidCheckout)) { _ in
            // Full reload when branch changes
            if let path = appState.currentRepository?.path {
                Task { await vm.load(at: path) }
            }
        }
        .onChange(of: vm.maxLane) { _, newMaxLane in
            settings.maxLane = newMaxLane
        }
        .sheet(isPresented: $showPRSheet) {
            if !prHeadBranch.isEmpty && !prBaseBranch.isEmpty {
                // Find or create the head branch object
                let headBranchObj = appState.currentRepository?.branches.first { $0.name == prHeadBranch }
                    ?? Branch(name: prHeadBranch, fullName: "refs/heads/\(prHeadBranch)", isRemote: false, targetSHA: "")

                CreatePullRequestSheet(
                    branch: headBranchObj,
                    defaultBaseBranch: prBaseBranch
                )
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showStaleBranchCleanup) {
            StaleBranchCleanupView()
                .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .compareCommit)) { notification in
            if let commits = notification.object as? [Commit], commits.count == 2 {
                // Multi-select: compare two commits directly
                appState.comparisonCommitA = commits[0]
                appState.comparisonCommitB = commits[1]
                appState.selectedCommit = nil
            } else if let commit = notification.object as? Commit {
                // Single-select: set as first commit to compare
                if appState.comparisonCommitA == nil {
                    appState.comparisonCommitA = commit
                    NotificationManager.shared.info(
                        "Select second commit",
                        detail: "Right-click another commit and choose 'Compare with...' to complete the comparison"
                    )
                } else {
                    appState.comparisonCommitB = commit
                    appState.selectedCommit = nil
                }
            }
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
        .sheet(isPresented: $showWorktreeSheet) {
            CreateWorktreeFromCommitSheet(commitSHA: worktreeCommitSHA)
                .environmentObject(appState)
        }
        .onAppear {
            zoomBaseLevel = settings.zoomLevel
        }
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
                .foregroundColor(AppTheme.textPrimary)

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
                    .foregroundColor(AppTheme.textSecondary)
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
                    .foregroundColor(operation.color.opacity(0.4))
            }
        )
    }

    // MARK: - Branch Operations

    private func checkoutBranch(_ branch: Branch) async {
        guard let repoPath = appState.currentRepository?.path else { return }

        let executor = ShellExecutor()
        let result = await executor.execute(
            "git",
            arguments: ["checkout", branch.name],
            workingDirectory: repoPath
        )

        if result.exitCode == 0 {
            NotificationManager.shared.success("Checked out \(branch.name)")
            // Refresh the graph
            await vm.load(at: repoPath)
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
        return HStack(spacing: DesignTokens.Spacing.md) {
            // Search field using DS component
            DSSearchField(
                placeholder: "Search commits (message, author, SHA)...",
                text: $settings.searchText
            )
            .frame(maxWidth: 400)

            // Filter by author
            if !settings.filterAuthor.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "person.fill")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(settings.filterAuthor)
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                    Button {
                        settings.filterAuthor = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.error)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(AppTheme.info.opacity(0.2))
                .foregroundColor(AppTheme.info)
                .cornerRadius(DesignTokens.CornerRadius.xl)
            }

            Spacer()

            // CI/CD Status Badge
            CICDToolbarBadge(repoPath: appState.currentRepository?.path)

            Spacer()

            // Toggle buttons for visibility using DS
            HStack(spacing: DesignTokens.Spacing.xs) {
                Button(action: {
                    settings.showBranches.toggle()
                }) {
                    Image(systemName: settings.showBranches ? "point.3.connected.trianglepath.dotted" : "arrow.triangle.branch")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(settings.showBranches ? AppTheme.accent : AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Toggle branch labels visibility")

                Button(action: {
                    settings.showTags.toggle()
                }) {
                    Image(systemName: settings.showTags ? "tag.circle.fill" : "tag.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(settings.showTags ? AppTheme.warning : AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Toggle tag labels visibility")

                Button(action: {
                    settings.showStashes.toggle()
                }) {
                    Image(systemName: settings.showStashes ? "archivebox.circle.fill" : "archivebox.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(settings.showStashes ? AppTheme.warning : AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Toggle stash labels visibility")
            }

            Divider()
                .frame(height: DesignTokens.Spacing.lg)

            // Panel toggles
            HStack(spacing: DesignTokens.Spacing.xs) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBranchPanel.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(showBranchPanel ? AppTheme.accent : AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Toggle branch panel")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showMinimap.toggle()
                    }
                }) {
                    Image(systemName: "map")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(showMinimap ? AppTheme.accent : AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Toggle minimap")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetailPanel.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(showDetailPanel ? AppTheme.accent : AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Toggle detail panel")
            }

            Divider()
                .frame(height: DesignTokens.Spacing.lg)

            // Zoom controls
            HStack(spacing: 2) {
                Button(action: { settings.zoomOut() }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(settings.zoomLevel <= GraphSettings.zoomMin ? AppTheme.textMuted : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(settings.zoomLevel <= GraphSettings.zoomMin)
                .help("Zoom out")

                Button(action: { settings.resetZoom() }) {
                    Text("\(settings.zoomPercentage)%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(settings.zoomLevel == 1.0 ? AppTheme.textMuted : AppTheme.accent)
                        .frame(width: 36)
                }
                .buttonStyle(.plain)
                .help("Reset zoom to 100%")

                Button(action: { settings.zoomIn() }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(settings.zoomLevel >= GraphSettings.zoomMax ? AppTheme.textMuted : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(settings.zoomLevel >= GraphSettings.zoomMax)
                .help("Zoom in")
            }

            Divider()
                .frame(height: DesignTokens.Spacing.lg)

            // Display options
            Menu {
                Button(action: { settings.showAvatars.toggle() }) {
                    HStack {
                        Text("Show Avatars")
                        Spacer()
                        if settings.showAvatars {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { settings.compactMode.toggle() }) {
                    HStack {
                        Text("Compact Mode")
                        Spacer()
                        if settings.compactMode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { settings.dimMergeCommits.toggle() }) {
                    HStack {
                        Text("Dim Merge Commits")
                        Spacer()
                        if settings.dimMergeCommits {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                Menu("Zoom") {
                    Button("Zoom In") { settings.zoomIn() }
                        .disabled(settings.zoomLevel >= GraphSettings.zoomMax)
                    Button("Zoom Out") { settings.zoomOut() }
                        .disabled(settings.zoomLevel <= GraphSettings.zoomMin)
                    Button("Reset Zoom (100%)") { settings.resetZoom() }
                        .disabled(settings.zoomLevel == 1.0)
                }

                Divider()

                Menu("Columns") {
                    Button(action: { settings.showAuthorColumn.toggle() }) {
                        HStack {
                            Text("Author")
                            Spacer()
                            if settings.showAuthorColumn {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { settings.showDateColumn.toggle() }) {
                        HStack {
                            Text("Date/Time")
                            Spacer()
                            if settings.showDateColumn {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { settings.showSHAColumn.toggle() }) {
                        HStack {
                            Text("SHA")
                            Spacer()
                            if settings.showSHAColumn {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .tint(AppTheme.textSecondary)
            .help("Display Options")
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Graph Header

    private var graphHeader: some View {
        return HStack(spacing: 0) {
            if settings.shouldShowBranchColumn {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .symbolRenderingMode(.monochrome)
                    Text("BRANCH / TAG")
                }
                .frame(width: settings.responsiveBranchColumnWidth, alignment: .leading)
                .padding(.leading, 12)
            }

            HStack(spacing: 4) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .symbolRenderingMode(.monochrome)
                Text("GRAPH")
            }
            .frame(width: settings.graphColumnWidth, alignment: .center)

            Text("COMMIT MESSAGE")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, DesignTokens.Spacing.sm)

            Text("CHANGES")
                .frame(width: settings.changesColumnWidth, alignment: .leading)

            if settings.shouldShowAuthorColumn {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("AUTHOR")
                }
                .frame(width: settings.authorColumnWidth, alignment: .leading)
            }

            if settings.shouldShowDateColumn {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("DATE")
                }
                .frame(width: settings.dateColumnWidth, alignment: .trailing)
            }

            if settings.shouldShowSHAColumn {
                HStack(spacing: 4) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("SHA")
                }
                .frame(width: settings.shaColumnWidth, alignment: .trailing)
                .padding(.trailing, DesignTokens.Spacing.sm)
            }
        }
        .font(DesignTokens.Typography.caption2)
        .fontWeight(.semibold)
        .foregroundColor(AppTheme.textPrimary)
        .frame(height: 28)
        .background(AppTheme.backgroundSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Graph Header")
    }

    // MARK: - Graph Content

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
        DSVirtualizedList(items: vm.timelineItems) { item in
            itemView(for: item)
        }
        .estimatedItemHeight(settings.rowHeight)
        .spacing(0)  // Zero spacing so graph lines connect perfectly between rows
        .bufferSize(20)
        .onReachEnd {
            if vm.hasMore && !vm.isLoading {
                Task { await vm.loadMore() }
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
                settings: settings
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
            if matchesSearchAndFilter(node) {
                GraphRow(
                    node: node,
                    isSelected: selectedIds.contains(node.commit.sha),
                    isHovered: hoveredId == node.commit.sha,
                    settings: settings,
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
            }
        case .stash(let stashNode):
            if settings.showStashes {
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

        // Filter by branch/tag visibility
        if let label = node.branchLabel {
            let isTag = label.hasPrefix("v") || label.contains(".")
            let isBranch = !isTag

            if isTag && !settings.showTags {
                return false
            }
            if isBranch && !settings.showBranches {
                return false
            }
        }

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
                appState.selectedCommit = node.commit
                appState.selectedStash = nil
            } else if let stashItem = vm.timelineItems.first(where: { $0.id == targetId }),
                      case .stash(let stashNode) = stashItem {
                appState.selectedCommit = nil
                appState.selectedStash = stashNode.stash
            } else if targetId == "uncommitted-changes" {
                // WIP selected - clear commit/stash to show staging area
                appState.selectedCommit = nil
                appState.selectedStash = nil
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

// MARK: - File Changes Indicator
/// Visual indicator showing file changes with count and add/delete bars
// FileChangesIndicator is defined in Features/CommitGraph/Components/FileChangesIndicator.swift
