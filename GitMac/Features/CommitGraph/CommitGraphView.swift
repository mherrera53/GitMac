import SwiftUI

// MARK: - Ghost Branches (integrated from GhostBranchesOverlay.swift)

/// Shows nearby branches when hovering over a commit in the graph
struct GhostBranchesOverlay: View {
    let commit: Commit
    let allBranches: [Branch]
    let repoPath: String
    @State private var nearbyBranches: [NearbyBranch] = []
    @State private var isLoading = false
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return Group {
            if !nearbyBranches.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Nearby Branches")
                        .font(DesignTokens.Typography.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)

                    ForEach(nearbyBranches.prefix(5)) { branch in
                        NearbyBranchRow(branch: branch)
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(theme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .shadow(color: .black.opacity(0.2), radius: DesignTokens.Spacing.xs)
            }
        }
        .task {
            await findNearbyBranches()
        }
    }

    private func findNearbyBranches() async {
        isLoading = true

        var nearby: [NearbyBranch] = []

        for branch in allBranches {
            // Skip if this commit IS the branch tip
            guard branch.targetSHA != commit.sha else { continue }

            // Check distance to this branch
            if let distance = await getCommitDistance(from: commit.sha, to: branch.targetSHA) {
                if distance.ahead <= 10 || distance.behind <= 10 {
                    nearby.append(NearbyBranch(
                        name: branch.name,
                        sha: branch.targetSHA,
                        ahead: distance.ahead,
                        behind: distance.behind,
                        isCurrent: branch.isCurrent
                    ))
                }
            }
        }

        // Sort by total distance
        nearbyBranches = nearby.sorted { ($0.ahead + $0.behind) < ($1.ahead + $1.behind) }
        isLoading = false
    }

    private func getCommitDistance(from: String, to: String) async -> (ahead: Int, behind: Int)? {
        let executor = ShellExecutor()
        let result = await executor.execute(
            "git",
            arguments: ["rev-list", "--left-right", "--count", "\(from)...\(to)"],
            workingDirectory: repoPath
        )

        guard result.exitCode == 0 else { return nil }

        let parts = result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard parts.count == 2,
              let ahead = Int(parts[0]),
              let behind = Int(parts[1]) else { return nil }

        return (ahead, behind)
    }
}

struct NearbyBranch: Identifiable {
    let id = UUID()
    let name: String
    let sha: String
    let ahead: Int
    let behind: Int
    let isCurrent: Bool

    var distanceDescription: String {
        var parts: [String] = []
        if ahead > 0 { parts.append("\(ahead) ahead") }
        if behind > 0 { parts.append("\(behind) behind") }
        return parts.joined(separator: ", ")
    }
}

struct NearbyBranchRow: View {
    let branch: NearbyBranch

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
            // Branch icon with color
            Image(systemName: "arrow.triangle.branch")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(branch.isCurrent ? AppTheme.success : AppTheme.accent)

            // Branch name
            Text(branch.name)
                .font(DesignTokens.Typography.caption)
                .fontWeight(branch.isCurrent ? .semibold : .regular)
                .lineLimit(1)

            Spacer()

            // Distance indicator
            HStack(spacing: DesignTokens.Spacing.xs) {
                if branch.ahead > 0 {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8)) // Graph badge font - intentionally small
                        Text("\(branch.ahead)")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(AppTheme.success)
                }

                if branch.behind > 0 {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8)) // Graph badge font - intentionally small
                        Text("\(branch.behind)")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundColor(AppTheme.warning)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
    }
}

extension View {
    /// Add ghost branches overlay on hover
    func withGhostBranches(
        commit: Commit,
        branches: [Branch],
        repoPath: String,
        isHovered: Bool
    ) -> some View {
        self.overlay(alignment: .topTrailing) {
            if isHovered {
                GhostBranchesOverlay(
                    commit: commit,
                    allBranches: branches,
                    repoPath: repoPath
                )
                .offset(x: 10, y: -10)
            }
        }
    }
}

// MARK: - Graph Display Settings
@MainActor
class GraphSettings: ObservableObject {
    // Column visibility
    @Published var showBranchColumn = true {
        didSet { saveSettings() }
    }
    @Published var showAuthorColumn = false {
        didSet { saveSettings() }
    }
    @Published var showDateColumn = false {
        didSet { saveSettings() }
    }
    @Published var showSHAColumn = false {
        didSet { saveSettings() }
    }

    // Column widths
    @Published var branchColumnWidth: CGFloat = 140 {
        didSet { saveSettings() }
    }
    @Published var graphColumnWidth: CGFloat = 110 {
        didSet { saveSettings() }
    }
    @Published var authorColumnWidth: CGFloat = 120 {
        didSet { saveSettings() }
    }
    @Published var dateColumnWidth: CGFloat = 100 {
        didSet { saveSettings() }
    }
    @Published var shaColumnWidth: CGFloat = 80 {
        didSet { saveSettings() }
    }

    // Display preferences
    @Published var showAvatars = true {
        didSet { saveSettings() }
    }
    @Published var showInitials = false {
        didSet { saveSettings() }
    }
    @Published var compactMode = false {
        didSet { saveSettings() }
    }
    @Published var dimMergeCommits = false {
        didSet { saveSettings() }
    }

    // Filtering
    @Published var showTags = true
    @Published var showBranches = true
    @Published var showStashes = true
    @Published var filterAuthor: String = ""
    @Published var searchText: String = ""

    // Repository path for persistence
    private var repositoryPath: String = ""
    private let defaults = UserDefaults.standard

    // Computed properties
    var rowHeight: CGFloat {
        compactMode ? 32 : 44
    }

    var nodeRadius: CGFloat {
        compactMode ? 10 : 14
    }

    var avatarSize: CGFloat {
        compactMode ? 18 : 26
    }

    // MARK: - Persistence
    func setRepository(_ path: String) {
        self.repositoryPath = path
        loadSettings()
    }

    private func saveSettings() {
        guard !repositoryPath.isEmpty else { return }

        let key = "graphSettings_\(repositoryPath)"
        let settings: [String: Any] = [
            "showBranchColumn": showBranchColumn,
            "showAuthorColumn": showAuthorColumn,
            "showDateColumn": showDateColumn,
            "showSHAColumn": showSHAColumn,
            "branchColumnWidth": branchColumnWidth,
            "graphColumnWidth": graphColumnWidth,
            "authorColumnWidth": authorColumnWidth,
            "dateColumnWidth": dateColumnWidth,
            "shaColumnWidth": shaColumnWidth,
            "showAvatars": showAvatars,
            "showInitials": showInitials,
            "compactMode": compactMode,
            "dimMergeCommits": dimMergeCommits
        ]
        defaults.set(settings, forKey: key)
    }

    private func loadSettings() {
        guard !repositoryPath.isEmpty else { return }

        let key = "graphSettings_\(repositoryPath)"
        guard let settings = defaults.dictionary(forKey: key) else { return }

        if let value = settings["showBranchColumn"] as? Bool {
            showBranchColumn = value
        }
        if let value = settings["showAuthorColumn"] as? Bool {
            showAuthorColumn = value
        }
        if let value = settings["showDateColumn"] as? Bool {
            showDateColumn = value
        }
        if let value = settings["showSHAColumn"] as? Bool {
            showSHAColumn = value
        }
        if let value = settings["branchColumnWidth"] as? CGFloat {
            branchColumnWidth = value
        }
        if let value = settings["graphColumnWidth"] as? CGFloat {
            graphColumnWidth = value
        }
        if let value = settings["authorColumnWidth"] as? CGFloat {
            authorColumnWidth = value
        }
        if let value = settings["dateColumnWidth"] as? CGFloat {
            dateColumnWidth = value
        }
        if let value = settings["shaColumnWidth"] as? CGFloat {
            shaColumnWidth = value
        }
        if let value = settings["showAvatars"] as? Bool {
            showAvatars = value
        }
        if let value = settings["showInitials"] as? Bool {
            showInitials = value
        }
        if let value = settings["compactMode"] as? Bool {
            compactMode = value
        }
        if let value = settings["dimMergeCommits"] as? Bool {
            dimMergeCommits = value
        }
    }
}

// MARK: - Color Extension for Branch Colors
private extension Color {
    @MainActor static func branchColor(_ index: Int) -> Color {
        let colors = AppTheme.graphLaneColors
        return colors[index % colors.count]
    }
}

// MARK: - Commit Graph View
struct CommitGraphView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = GraphViewModel()
    @StateObject private var tracker = RemoteOperationTracker.shared
    @StateObject private var settings = GraphSettings()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedIds: Set<String> = []
    @State private var lastSelectedId: String?
    @State private var hoveredId: String?
    @State private var hoveredBranch: String?
    @State private var showSettings = false
    @State private var themeRefreshTrigger = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Remote operation status bar (if exists)
            if let operation = lastOperationForCurrentBranch {
                remoteStatusBar(operation: operation)
                Divider()
            }

            // Search and filter toolbar
            graphToolbar
                .id(themeRefreshTrigger)
            Divider()

            graphHeader
            Divider()
            graphContent
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
        .onChange(of: themeManager.currentTheme) { _, _ in
            themeRefreshTrigger = UUID()
        }
        .onChange(of: themeManager.customColors) { _, _ in
            themeRefreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            if let path = notification.object as? String,
               path == appState.currentRepository?.path {
                // Use silent refresh to avoid graph flickering
                Task { await vm.refreshStatus() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteOperationCompleted)) { _ in
            // Force refresh when operation completes
        }
    }
    
    private var lastOperationForCurrentBranch: RemoteOperation? {
        guard let branch = appState.currentRepository?.currentBranch?.name else { return nil }
        return tracker.getLastOperation(for: branch)
    }
    
    private func remoteStatusBar(operation: RemoteOperation) -> some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.md) {
            // Status icon and info
            RemoteStatusBadge(operation: operation, compact: false)

            // Time ago
            Text(operation.timestamp.formatted(.relative(presentation: .named)))
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)

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
                // Clear this specific operation from being shown
                // (but keep in history)
                withAnimation {
                    tracker.lastOperation = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.text)
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(operation.color.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: DesignTokens.Spacing.xxs)
                .foregroundColor(operation.color.opacity(0.4)),
            alignment: .bottom
        )
    }

    // MARK: - Graph Toolbar
    private var graphToolbar: some View {
        let theme = Color.Theme(themeManager.colors)

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
                        .foregroundColor(theme.textSecondary)
                    Text(settings.filterAuthor)
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                    Button {
                        settings.filterAuthor = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.error)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(theme.info.opacity(0.2))
                .foregroundColor(theme.info)
                .cornerRadius(DesignTokens.CornerRadius.xl)
            }

            Spacer()

            // Toggle buttons for visibility using DS
            HStack(spacing: DesignTokens.Spacing.xs) {
                Button(action: {
                    settings.showBranches.toggle()
                }) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(settings.showBranches ? AppTheme.accent : theme.text)
                }
                .buttonStyle(.borderless)
                .help("Show Branches")

                Button(action: {
                    settings.showTags.toggle()
                }) {
                    Image(systemName: "tag.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(settings.showTags ? AppTheme.accent : theme.text)
                }
                .buttonStyle(.borderless)
                .help("Show Tags")

                Button(action: {
                    settings.showStashes.toggle()
                }) {
                    Image(systemName: "shippingbox.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(settings.showStashes ? AppTheme.accent : theme.text)
                }
                .buttonStyle(.borderless)
                .help("Show Stashes")
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
            .tint(theme.textSecondary)
            .help("Display Options")
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(theme.backgroundSecondary)
    }

    private var graphHeader: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: 0) {
            if settings.showBranchColumn {
                Text("BRANCH / TAG")
                    .frame(width: settings.branchColumnWidth, alignment: .leading)
                    .padding(.leading, 12)
            }

            Text("GRAPH")
                .frame(width: settings.graphColumnWidth, alignment: .center)

            Text("COMMIT MESSAGE")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, DesignTokens.Spacing.sm)

            Text("CHANGES")
                .frame(width: 140, alignment: .leading)

            if settings.showAuthorColumn {
                Text("AUTHOR")
                    .frame(width: settings.authorColumnWidth, alignment: .leading)
            }

            if settings.showDateColumn {
                Text("DATE")
                    .frame(width: settings.dateColumnWidth, alignment: .trailing)
            }

            if settings.showSHAColumn {
                Text("SHA")
                    .frame(width: settings.shaColumnWidth, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
            }
        }
        .font(DesignTokens.Typography.caption2)
        .fontWeight(.semibold)
        .foregroundColor(theme.text)
        .frame(height: 28)
        .background(theme.backgroundSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Graph Header")
    }

    @ViewBuilder
    private var graphContent: some View {
        if vm.isLoading && vm.nodes.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else {
            graphScrollView
        }
    }

    private var graphScrollView: some View {
        // Phase 1: Use DSVirtualizedList for 60fps with 10,000+ items
        DSVirtualizedList(items: vm.timelineItems) { item in
            itemView(for: item)
        }
        .estimatedItemHeight(settings.rowHeight)
        .bufferSize(20)
    }

    @ViewBuilder
    private func itemView(for item: TimelineItem) -> some View {
        // Calculate index for load more trigger
        let itemIndex = vm.timelineItems.firstIndex(where: { $0.id == item.id }) ?? 0
        let isNearEnd = itemIndex >= vm.timelineItems.count - 10

        switch item {
        case .uncommitted(let staged, let unstaged):
            UncommittedChangesRow(
                stagedCount: staged,
                unstagedCount: unstaged,
                isSelected: selectedIds.contains("uncommitted-changes"),
                isHovered: hoveredId == "uncommitted-changes"
            )
            .onHover { h in hoveredId = h ? "uncommitted-changes" : nil }
            .onTapGesture {
                handleSelection(item: item)
            }
        case .commit(let node):
            if matchesSearchAndFilter(node) {
                GraphRow(
                    node: node,
                    isSelected: selectedIds.contains(node.commit.sha),
                    isHovered: hoveredId == node.commit.sha,
                    settings: settings,
                    onHoverBranch: { branch in
                        hoveredBranch = branch
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
                .onAppear {
                    if isNearEnd && vm.hasMore && !vm.isLoading {
                        Task { await vm.loadMore() }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Commit \(node.commit.shortSha) by \(node.commit.author): \(node.commit.summary)")
                .accessibilityHint("Double tap to view details, context click for more actions")
            }
        case .stash(let stashNode):
            if settings.showStashes {
                GraphStashRow(
                    stash: stashNode,
                    isSelected: selectedIds.contains(stashNode.id),
                    isHovered: hoveredId == stashNode.id
                )
                .onHover { h in hoveredId = h ? stashNode.id : nil }
                .onTapGesture {
                    handleSelection(item: item)
                }
                .onAppear {
                    if isNearEnd && vm.hasMore && !vm.isLoading {
                        Task { await vm.loadMore() }
                    }
                }
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

        // Update AppState for the primarily selected item
        if let firstId = selectedIds.first {
            if let commitItem = vm.timelineItems.first(where: { $0.id == firstId }),
               case .commit(let node) = commitItem {
                appState.selectedCommit = node.commit
                appState.selectedStash = nil
            } else if let stashItem = vm.timelineItems.first(where: { $0.id == firstId }),
                      case .stash(let stashNode) = stashItem {
                appState.selectedCommit = nil
                appState.selectedStash = stashNode.stash
            }
        }
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

// MARK: - Timeline Item (Commit or Stash or Uncommitted Changes)
enum TimelineItem: Identifiable {
    case uncommitted(staged: Int, unstaged: Int)
    case commit(GraphNode)
    case stash(StashNode)

    var id: String {
        switch self {
        case .uncommitted: return "uncommitted-changes"
        case .commit(let node): return node.id
        case .stash(let stash): return stash.id
        }
    }

    var date: Date {
        switch self {
        case .uncommitted: return Date() // Always most recent
        case .commit(let node): return node.commit.authorDate
        case .stash(let stash): return stash.stash.date
        }
    }
}

// MARK: - Uncommitted Changes Row
struct UncommittedChangesRow: View {
    let stagedCount: Int
    let unstagedCount: Int
    let isSelected: Bool
    let isHovered: Bool
    @StateObject private var themeManager = ThemeManager.shared

    private let H: CGFloat = 44
    private let W: CGFloat = 26
    private let R: CGFloat = 14

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: 0) {
            // Label
            HStack {
                BranchBadge(
                    name: "// WIP",
                    color: .orange,
                    isHead: false,
                    isTag: false
                )
                Spacer()
            }
            .frame(width: 140)
            .padding(.leading, DesignTokens.Spacing.sm)

            // Graph - dotted node
            ZStack {
                Canvas { ctx, size in
                    let cy = size.height / 2
                    let myX: CGFloat = W / 2 + DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs

                    // Dotted line to bottom
                    drawDottedLine(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: myX, y: size.height), color: .orange)

                    // Dotted circle
                    let nodeRect = CGRect(x: myX - R, y: cy - R, width: R * 2, height: R * 2)
                    // Fill with background to hide line passing through
                    ctx.fill(Circle().path(in: nodeRect), with: .color(theme.background))
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(.orange), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                }
                .frame(width: 110, height: H)

                // Pencil icon inside node
                Image(systemName: "pencil")
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.warning)
                    .offset(x: -43)
            }

            // Info
            HStack(spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Uncommitted changes")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.warning)
                    Text("\(stagedCount) staged, \(unstagedCount) unstaged")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(theme.text)
                }
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
        .frame(height: H)
        .background(isSelected ? theme.selection : (isHovered ? theme.hover : Color.clear))
    }

    func drawDottedLine(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 3]))
    }
}

// MARK: - Graph Stash Row (Modern)
struct GraphStashRow: View {
    let stash: StashNode
    let isSelected: Bool
    let isHovered: Bool
    @StateObject private var themeManager = ThemeManager.shared

    private let H: CGFloat = 44
    private let W: CGFloat = 26
    private let boxSize: CGFloat = 18
    private let LW: CGFloat = 2
    private var stashColor: Color { AppTheme.info }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: 0) {
            // Label - stash badge
            HStack(spacing: DesignTokens.Spacing.xs) {
                StashBadge(name: stash.stash.reference)
                Spacer()
            }
            .frame(width: 140)
            .padding(.leading, DesignTokens.Spacing.sm)

            // Graph area
            ZStack {
                Canvas { ctx, size in
                    let cy = size.height / 2
                    let mainLaneX: CGFloat = W / 2 + 6
                    let stashX: CGFloat = mainLaneX + W + 8

                    // 1) Main branch line (continues through)
                    var mainLine = Path()
                    mainLine.move(to: CGPoint(x: mainLaneX, y: 0))
                    mainLine.addLine(to: CGPoint(x: mainLaneX, y: size.height))
                    ctx.stroke(mainLine, with: .color(Color.branchColor(0)), lineWidth: LW)

                    // 2) Stash connection line
                    var connLine = Path()
                    connLine.move(to: CGPoint(x: stashX, y: cy))
                    connLine.addLine(to: CGPoint(x: mainLaneX, y: size.height)) // Connects down-left
                    ctx.stroke(connLine, with: .color(stashColor),
                              style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))

                    // 3) Stash node (Box)
                    let boxRect = CGRect(x: stashX - boxSize/2, y: cy - boxSize/2,
                                        width: boxSize, height: boxSize)
                    let roundedBox = RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm).path(in: boxRect)
                    ctx.fill(roundedBox, with: .color(stashColor))
                    ctx.stroke(roundedBox, with: .color(stashColor.opacity(0.8)), lineWidth: 1)
                }
                .frame(width: 110, height: H)

                // Box icon
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 8, weight: .bold)) // Graph badge font - intentionally small
                    .foregroundColor(AppTheme.textPrimary)
                    .offset(x: -5) // Adjust based on stashX calculation
            }

            // Info
            HStack(spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(stash.stash.displayMessage)
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(theme.text)
                        .lineLimit(1)

                    HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                        Text(stash.stash.reference)
                            .font(DesignTokens.Typography.caption2.monospaced())
                            .foregroundColor(stashColor)

                        if let branch = stash.stash.branchName {
                            Text("on \(branch)")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }

                Spacer()

                Text(stash.stash.relativeDate)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(theme.textMuted)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
        .frame(height: H)
        .background(isSelected ? theme.selection : (isHovered ? theme.hover : Color.clear))
        .contextMenu {
            Button {
                NotificationCenter.default.post(name: .applyStash, object: stash.stash.index)
            } label: {
                Label("Apply Stash", systemImage: "arrow.down.doc")
            }
            Button {
                NotificationCenter.default.post(name: .popStashAtIndex, object: stash.stash.index)
            } label: {
                Label("Pop Stash", systemImage: "arrow.up.doc")
            }
            Divider()
            Button(role: .destructive) {
                NotificationCenter.default.post(name: .dropStash, object: stash.stash.index)
            } label: {
                Label("Drop Stash", systemImage: "trash")
            }
        }
    }
}

// MARK: - Stash Badge (Modern - solid background)
struct StashBadge: View {
    let name: String
    @StateObject private var themeManager = ThemeManager.shared
    private var stashColor: Color { AppTheme.info }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xxs + 1) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 8, weight: .bold)) // Graph badge font - intentionally small
                .foregroundColor(theme.warning)
            Text(name)
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .padding(.vertical, DesignTokens.Spacing.xxs + 1)
        .background(stashColor)
        .foregroundColor(AppTheme.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.none + 3))
    }
}

// MARK: - Stash Node Model
struct StashNode: Identifiable {
    let id: String
    let stash: Stash
}

// MARK: - Stash Notification Names
extension Notification.Name {
    static let applyStash = Notification.Name("applyStash")
    static let popStashAtIndex = Notification.Name("popStashAtIndex")
    static let dropStash = Notification.Name("dropStash")
}

// MARK: - Branch Badge (Modern)
struct BranchBadge: View {
    let name: String
    let color: Color
    let isHead: Bool
    let isTag: Bool
    @StateObject private var themeManager = ThemeManager.shared

    init(name: String, color: Color, isHead: Bool = false, isTag: Bool = false) {
        self.name = name
        self.color = color
        self.isHead = isHead
        self.isTag = isTag
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: iconName)
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
            Text(name)
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }

    private var iconName: String {
        if isTag { return "tag.fill" }
        if isHead { return "checkmark.circle.fill" }
        return "arrow.triangle.branch"
    }
}

// MARK: - Graph Row
struct GraphRow: View {
    let node: GraphNode
    let isSelected: Bool
    let isHovered: Bool
    let settings: GraphSettings
    let onHoverBranch: ((String?) -> Void)?
    @StateObject private var themeManager = ThemeManager.shared

    private var H: CGFloat { settings.rowHeight }
    private var W: CGFloat { 26 }  // Lane spacing
    private var R: CGFloat { settings.nodeRadius }
    private var LW: CGFloat { 2 }  // Line width

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: 0) {
            // Branch label with badge
            if settings.showBranchColumn {
                HStack {
                    if let label = node.branchLabel {
                        BranchBadge(
                            name: label,
                            color: color(node.lane),
                            isHead: label == "main" || label == "master",
                            isTag: label.hasPrefix("v") || label.contains(".")
                        )
                    }
                    Spacer()
                }
                .frame(width: settings.branchColumnWidth)
                .padding(.leading, DesignTokens.Spacing.sm)
            }

            // Graph - Canvas for lines, overlay for avatar
            ZStack {
                Canvas { ctx, size in
                    let cy = size.height / 2
                    let myX = x(node.lane)
                    let c = color(node.lane)

                    // 1) Pass-through vertical lines (other branches)
                    for lane in node.passThroughLanes {
                        let lx = x(lane)
                        drawLine(ctx, from: CGPoint(x: lx, y: 0), to: CGPoint(x: lx, y: size.height), color: color(lane))
                    }

                    // 2) My vertical line
                    if node.lineFromTop && node.lineToBottom {
                        drawLine(ctx, from: CGPoint(x: myX, y: 0), to: CGPoint(x: myX, y: size.height), color: c)
                    } else if node.lineFromTop {
                        drawLine(ctx, from: CGPoint(x: myX, y: 0), to: CGPoint(x: myX, y: cy), color: c)
                    } else if node.lineToBottom {
                        drawLine(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: myX, y: size.height), color: c)
                    }

                    // 3) Curves going to bottom (to other columns)
                    for toLane in node.curvesToBottom {
                        let toX = x(toLane)
                        drawBezier(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: toX, y: size.height), color: color(toLane))
                    }

                    // 4) Node circle background
                    let nodeRect = CGRect(x: myX - R, y: cy - R, width: R * 2, height: R * 2)
                    ctx.fill(Circle().path(in: nodeRect), with: .color(c))
                    // Add a white/background stroke to separate node from lines
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(theme.background), lineWidth: 2)
                }
                .frame(width: settings.graphColumnWidth, height: H)

                // Avatar overlay INSIDE the node - FIXED positioning and size
                if settings.showAvatars {
                    avatarView
                        .frame(width: settings.avatarSize, height: settings.avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(color(node.lane), lineWidth: 2)
                        )
                        .background(
                            Circle()
                                .fill(theme.background)
                        )
                        .offset(x: x(node.lane) - (settings.graphColumnWidth / 2))
                        .scaleEffect(isHovered ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                }
            }

            // Commit message
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(node.commit.summary)
                    .font(settings.compactMode ? DesignTokens.Typography.caption : DesignTokens.Typography.callout)
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                if !settings.compactMode && !settings.showAuthorColumn {
                    Text(node.commit.author)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(theme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.sm)

            // Changes indicator
            FileChangesIndicator(
                additions: node.commit.additions ?? 0,
                deletions: node.commit.deletions ?? 0,
                filesChanged: node.commit.filesChanged ?? 0,
                compact: settings.compactMode
            )
            .frame(width: 140, alignment: .leading)

            // Author column (optional)
            if settings.showAuthorColumn {
                HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                    if settings.showAvatars && !settings.compactMode {
                        AvatarImageView(
                            email: node.commit.authorEmail,
                            size: 20,
                            fallbackInitial: String(node.commit.author.prefix(1))
                        )
                    }
                    Text(node.commit.author)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                }
                .frame(width: settings.authorColumnWidth, alignment: .leading)
            }

            // Date column (optional)
            if settings.showDateColumn {
                Text(node.commit.relativeDate)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(theme.textMuted)
                    .frame(width: settings.dateColumnWidth, alignment: .trailing)
            }

            // SHA column (optional)
            if settings.showSHAColumn {
                Text(node.commit.shortSha)
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundColor(theme.textMuted)
                    .frame(width: settings.shaColumnWidth, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
            }
        }
        .frame(height: H)
        .background(isSelected ? theme.selection : (isHovered ? theme.hover : Color.clear))
        .opacity(settings.dimMergeCommits && node.isMerge ? 0.5 : 1.0)
        .onHover { hovering in
            if let label = node.branchLabel, hovering {
                onHoverBranch?(label)
            } else if !hovering {
                onHoverBranch?(nil)
            }
        }
        .contextMenu {
            CommitContextMenu(commits: [node.commit])
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        AvatarImageView(
            email: node.commit.authorEmail,
            size: settings.avatarSize,
            fallbackInitial: String(node.commit.author.prefix(1))
        )
    }

    func x(_ lane: Int) -> CGFloat { CGFloat(lane) * W + W / 2 + DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs }
    func color(_ lane: Int) -> Color { Color.branchColor(lane) }

    func drawLine(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: LW, lineCap: .round))
    }

    func drawBezier(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        // More smooth smooth curve (less S-shape, more like railroad tracks that merge)
        let controlY = from.y + (to.y - from.y) * 0.6 // Push control point further down
        p.addCurve(
            to: to,
            control1: CGPoint(x: from.x, y: controlY),
            control2: CGPoint(x: to.x, y: from.y + (to.y - from.y) * 0.4)
        )
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: LW, lineCap: .round))
    }
}

// MARK: - Data Model
struct GraphNode: Identifiable {
    let id: String
    let commit: Commit
    let lane: Int
    let branchLabel: String?

    // What to draw
    let lineFromTop: Bool           // Vertical line from top of row to node
    let lineToBottom: Bool          // Vertical line from node to bottom of row
    let passThroughLanes: Set<Int>  // Vertical lines in other columns
    let curvesToBottom: [Int]       // Curves going to these columns (to bottom)

    var isMerge: Bool { commit.parentSHAs.count > 1 }
    var shortSha: String { String(commit.sha.prefix(7)) }
}

// MARK: - View Model
@MainActor
class GraphViewModel: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var stashNodes: [StashNode] = []
    @Published var timelineItems: [TimelineItem] = []
    @Published var isLoading = false
    @Published var hasMore = true

    // Uncommitted changes state
    @Published var hasUncommittedChanges = false
    @Published var stagedCount = 0
    @Published var unstagedCount = 0

    // Ghost Branches support
    @Published var branches: [Branch] = []

    // Current user email for @me filter
    @Published var currentUserEmail: String?

    private let engine = GitEngine()
    private var path: String?
    private var page = 0
    private var commits: [Commit] = []
    private var branchHeads: [String: String] = [:]

    func load(at p: String) async {
        isLoading = true
        path = p
        page = 0
        commits = []

        do {
            // Load branches (use original method - V2 has same output)
            let loadedBranches = try await engine.getBranches(at: p)
            branches = loadedBranches  // Save for Ghost Branches
            branchHeads = [:]
            for branch in loadedBranches {
                if branchHeads[branch.targetSHA] == nil {
                    branchHeads[branch.targetSHA] = branch.name
                }
            }

            // Load current user email for @me filter
            let result = await ShellExecutor().execute(
                "git",
                arguments: ["config", "user.email"],
                workingDirectory: p
            )
            if result.exitCode == 0 {
                currentUserEmail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Load commits using V2 (NUL-separated, handles special chars in messages)
            commits = try await engine.getCommitsV2(at: p, limit: 100)
            hasMore = commits.count == 100

            // Load status for uncommitted changes
            let status = try await engine.getStatus(at: p)
            stagedCount = status.staged.count
            unstagedCount = status.unstaged.count + status.untracked.count
            hasUncommittedChanges = stagedCount > 0 || unstagedCount > 0

            // Load stashes
            let stashes = try await engine.getStashes(at: p)
            stashNodes = stashes.map { StashNode(id: "stash-\($0.index)", stash: $0) }

            // Build nodes on background thread
            let newNodes = await buildNodes()
            nodes = newNodes

            // Build merged timeline (commits + stashes sorted by date)
            buildTimeline()

            // Load avatars from GitHub repository in background
            Task.detached(priority: .utility) {
                await self.loadAvatarsFromGitHub(at: p)
            }
        } catch {
            print("Error loading graph: \(error)")
        }
        isLoading = false
    }

    /// Load avatars from GitHub repository using commit SHAs
    private func loadAvatarsFromGitHub(at repoPath: String) async {
        // Get GitHub token (optional - will use Gravatar if not available)
        let token = try? await KeychainManager.shared.getGitHubToken()

        do {
            // Get remotes to find origin URL
            let remotes = try await engine.getRemotes(at: repoPath)
            guard let originRemote = remotes.first(where: { $0.name == "origin" }),
                  let (owner, repo) = extractGitHubOwnerRepo(from: originRemote.fetchURL) else {
                NSLog("⚠️ Not a GitHub repository or no origin remote, skipping avatar loading")
                await preloadAvatarsForCommits(token: token)
                return
            }

            NSLog("📥 Loading avatars by commit SHA from: \(owner)/\(repo)")

            // Load avatars by commit SHA (not email)
            if let token = token {
                await loadAvatarsBySHA(owner: owner, repo: repo, token: token)
            } else {
                NSLog("⚠️ No GitHub token - using fallback avatars")
            }

            // Preload remaining with email fallback
            await preloadAvatarsForCommits(token: token)

            NSLog("✅ Avatar loading completed")
        } catch {
            NSLog("⚠️ Could not load GitHub avatars: \(error.localizedDescription)")
            await preloadAvatarsForCommits(token: nil)
        }
    }

    /// Load avatars by fetching commits from GitHub API using their SHA
    private func loadAvatarsBySHA(owner: String, repo: String, token: String) async {
        NSLog("🔍 Loading avatars by SHA for \(commits.count) commits")

        // Process commits in batches to avoid rate limits
        let batchSize = 20
        for (index, commit) in commits.enumerated() {
            // Rate limit: max 20 at a time
            if index > 0 && index % batchSize == 0 {
                NSLog("⏸️ Processed \(index)/\(commits.count) commits, pausing...")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second pause
            }

            guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(commit.sha)") else {
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let author = json["author"] as? [String: Any],
                   let avatarUrl = author["avatar_url"] as? String {
                    let email = commit.authorEmail.lowercased()

                    // Cache by email for future lookups
                    if let url = URL(string: avatarUrl) {
                        await AvatarService.shared.cacheAvatar(url: url, for: email)
                        NSLog("  ✅ \(commit.sha.prefix(7)) → \(commit.author): \(avatarUrl)")
                    }
                }
            } catch {
                NSLog("  ⚠️ Failed to fetch commit \(commit.sha.prefix(7)): \(error)")
            }
        }

        NSLog("✅ Loaded avatars for commits via SHA")
    }

    /// Preload avatars for all unique commit author emails
    private func preloadAvatarsForCommits(token: String?) async {
        let emails = Set(commits.map { $0.authorEmail })
        await AvatarService.shared.preloadAvatars(for: Array(emails), githubToken: token)
    }

    /// Extract owner and repo name from GitHub URL
    private func extractGitHubOwnerRepo(from url: String) -> (owner: String, repo: String)? {
        // Handle various GitHub URL formats:
        // - https://github.com/owner/repo.git
        // - git@github.com:owner/repo.git
        // - https://github.com/owner/repo

        let cleanURL = url
            .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
            .replacingOccurrences(of: ".git", with: "")

        guard cleanURL.contains("github.com") else { return nil }

        let components = cleanURL.components(separatedBy: "github.com/")
        guard components.count >= 2 else { return nil }

        let pathComponents = components[1].components(separatedBy: "/")
        guard pathComponents.count >= 2 else { return nil }

        return (owner: pathComponents[0], repo: pathComponents[1])
    }

    func loadMore() async {
        guard let p = path, !isLoading else { return }
        isLoading = true
        page += 1

        do {
            let more = try await engine.getCommitsV2(at: p, limit: 100, skip: page * 100)
            commits.append(contentsOf: more)
            hasMore = more.count == 100

            // Build on background thread
            let newNodes = await buildNodes()
            nodes = newNodes

            // Rebuild merged timeline
            buildTimeline()
        } catch {
            print("Error loading more: \(error)")
        }
        isLoading = false
    }

    /// Silently refresh repository status (staged/unstaged counts) without reloading commits
    /// This prevents the graph from flickering on every file change
    func refreshStatus() async {
        guard let p = path else { return }

        do {
            // Only update status counts - don't reload commits
            let status = try await engine.getStatus(at: p)
            let newStagedCount = status.staged.count
            let newUnstagedCount = status.unstaged.count + status.untracked.count
            let newHasChanges = newStagedCount > 0 || newUnstagedCount > 0

            // Only update if counts actually changed
            if stagedCount != newStagedCount || unstagedCount != newUnstagedCount || hasUncommittedChanges != newHasChanges {
                stagedCount = newStagedCount
                unstagedCount = newUnstagedCount
                hasUncommittedChanges = newHasChanges

                // Rebuild timeline to update WIP row (but don't reload commits)
                buildTimeline()
            }
        } catch {
            print("Error refreshing status: \(error)")
        }
    }

    private func buildNodes() async -> [GraphNode] {
        // Run expensive computation off main thread
        let localCommits = commits
        let localBranchHeads = branchHeads

        return await Task.detached(priority: .userInitiated) {
            buildCommitGraph(commits: localCommits, branchHeads: localBranchHeads)
        }.value
    }

    private func buildTimeline() {
        // Merge commits and stashes into a single timeline sorted by date (newest first)
        var items: [TimelineItem] = []

        // Add uncommitted changes at the top if present
        if hasUncommittedChanges {
            items.append(.uncommitted(staged: stagedCount, unstaged: unstagedCount))
        }

        // Add all commits
        for node in nodes {
            items.append(.commit(node))
        }

        // Add all stashes
        for stash in stashNodes {
            items.append(.stash(stash))
        }

        // Sort by date (newest first)
        // Note: uncommitted will stay at top since its date is always Date()
        items.sort { $0.date > $1.date }

        timelineItems = items
    }
}

// MARK: - Graph Building (runs on background thread)
// Algorithm based on EDGE tracking (not column tracking)
// References:
// - https://pvigier.github.io/2019/05/06/commit-graph-drawing-algorithms.html
// - https://stackoverflow.com/questions/4739683/how-does-git-log-graph-or-hg-graphlog-work
// - https://github.com/alaingilbert/git2graph

/// Represents a connection from a child commit to a parent commit
private struct GraphEdge {
    let childRow: Int
    let parentRow: Int
    let childColumn: Int   // Column of the child commit
    let parentColumn: Int  // Column of the parent commit
    let color: Int
    let isFirstParent: Bool
}

private func buildCommitGraph(commits: [Commit], branchHeads: [String: String]) -> [GraphNode] {
    guard !commits.isEmpty else { return [] }

    // PHASE 1: Build indices
    var shaToRow: [String: Int] = [:]
    for (i, c) in commits.enumerated() { shaToRow[c.sha] = i }

    // PHASE 2: Assign columns using reservation system
    // Key insight: First parent inherits column, other parents get new columns
    var shaToColumn: [String: Int] = [:]
    var shaToColor: [String: Int] = [:]
    var columnSlots: [String?] = []  // Track which SHA owns each column slot
    var nextColor = 0

    func findFreeColumn() -> Int {
        if let idx = columnSlots.firstIndex(where: { $0 == nil }) {
            return idx
        }
        columnSlots.append(nil)
        return columnSlots.count - 1
    }

    func occupyColumn(_ col: Int, with sha: String) {
        while columnSlots.count <= col { columnSlots.append(nil) }
        columnSlots[col] = sha
    }

    func freeColumn(_ col: Int) {
        if col < columnSlots.count { columnSlots[col] = nil }
    }

    // Process commits from newest to oldest (topological order)
    for commit in commits {
        let sha = commit.sha

        // Get or assign column
        let col: Int
        if let reserved = shaToColumn[sha] {
            // Already reserved by a child's first-parent link
            col = reserved
            occupyColumn(col, with: sha)
        } else {
            // New branch head, find free column
            col = findFreeColumn()
            shaToColumn[sha] = col
            shaToColor[sha] = nextColor
            nextColor += 1
            occupyColumn(col, with: sha)
        }

        // First parent inherits our column (same branch continues)
        if let firstParent = commit.parentSHAs.first {
            if shaToColumn[firstParent] == nil {
                shaToColumn[firstParent] = col
                shaToColor[firstParent] = shaToColor[sha] ?? 0
            }
        }

        // Other parents (merge sources) get new columns
        for (i, parentSHA) in commit.parentSHAs.enumerated() where i > 0 {
            if shaToColumn[parentSHA] == nil && shaToRow[parentSHA] != nil {
                let parentCol = findFreeColumn()
                shaToColumn[parentSHA] = parentCol
                shaToColor[parentSHA] = nextColor
                nextColor += 1
                occupyColumn(parentCol, with: parentSHA)
            }
        }

        // Free column if branch ends here (no parents or first parent in different column)
        if commit.parentSHAs.isEmpty {
            freeColumn(col)
        } else if let firstParent = commit.parentSHAs.first,
                  let fpCol = shaToColumn[firstParent], fpCol != col {
            freeColumn(col)
        }
    }

    // PHASE 3: Create list of EDGES
    var edges: [GraphEdge] = []

    for (childRow, commit) in commits.enumerated() {
        guard let childCol = shaToColumn[commit.sha] else { continue }

        for (i, parentSHA) in commit.parentSHAs.enumerated() {
            guard let parentRow = shaToRow[parentSHA],
                  let parentCol = shaToColumn[parentSHA] else { continue }

            let edgeColor = shaToColor[parentSHA] ?? shaToColor[commit.sha] ?? 0

            edges.append(GraphEdge(
                childRow: childRow,
                parentRow: parentRow,
                childColumn: childCol,
                parentColumn: parentCol,
                color: edgeColor,
                isFirstParent: i == 0
            ))
        }
    }

    // PHASE 4: Build nodes with simplified drawing instructions
    var result: [GraphNode] = []

    for (row, commit) in commits.enumerated() {
        guard let col = shaToColumn[commit.sha] else { continue }

        // Pass-through: edges passing through this row (not my column)
        let passThroughEdges = edges.filter { edge in
            edge.childRow < row && row < edge.parentRow && edge.parentColumn != col
        }
        let passThroughColumns = Set(passThroughEdges.map { $0.parentColumn })

        // Edges that END at this row (I am the parent)
        let incomingEdges = edges.filter { $0.parentRow == row }

        // Line from top: any edge ends here in MY column
        let lineFromTop = incomingEdges.contains { $0.parentColumn == col }

        // Edges that START at this row (I am the child)
        let outgoingEdges = edges.filter { $0.childRow == row }

        // Line to bottom: my first parent is in MY column
        let lineToBottom = outgoingEdges.contains { $0.parentColumn == col && $0.isFirstParent }

        // Curves to bottom: edges to parents in OTHER columns
        let curvesToBottom = outgoingEdges
            .filter { $0.parentColumn != col }
            .map { $0.parentColumn }

        result.append(GraphNode(
            id: commit.sha,
            commit: commit,
            lane: col,
            branchLabel: branchHeads[commit.sha],
            lineFromTop: lineFromTop,
            lineToBottom: lineToBottom,
            passThroughLanes: passThroughColumns,
            curvesToBottom: curvesToBottom
        ))
    }

    return result
}

extension Commit {
    var shortSha: String { String(sha.prefix(7)) }
}

// MARK: - Commit Context Menu
struct CommitContextMenu: View {
    let commits: [Commit]
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if commits.count == 1, let commit = commits.first {
                singleCommitActions(commit: commit)
            } else if commits.count > 1 {
                multiCommitActions()
            }
        }
    }

    @ViewBuilder
    private func singleCommitActions(commit: Commit) -> some View {
        // Copy actions
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commit.sha, forType: .string)
        } label: {
            Label("Copy SHA", systemImage: "doc.on.doc")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commit.message, forType: .string)
        } label: {
            Label("Copy Message", systemImage: "text.quote")
        }

        Divider()

        // Branch/Tag actions
        Button {
            NotificationCenter.default.post(
                name: .createBranchFromCommit,
                object: commit.sha
            )
        } label: {
            Label("Create Branch Here...", systemImage: "arrow.triangle.branch")
        }

        Button {
            NotificationCenter.default.post(
                name: .createTagFromCommit,
                object: commit.sha
            )
        } label: {
            Label("Create Tag Here...", systemImage: "tag")
        }

        Divider()

        // Checkout
        Button {
            Task {
                try? await appState.gitService.checkout(commit.sha)
            }
        } label: {
            Label("Checkout This Commit", systemImage: "arrow.uturn.backward")
        }

        Divider()

        // Advanced operations
        Button {
            NotificationCenter.default.post(
                name: .cherryPickCommit,
                object: commit.sha
            )
        } label: {
            Label("Cherry-pick...", systemImage: "arrow.right.doc.on.clipboard")
        }

        Button {
            NotificationCenter.default.post(
                name: .revertCommit,
                object: [commit]
            )
        } label: {
            Label("Revert Commit...", systemImage: "arrow.uturn.left")
        }

        Divider()

        // Rebase actions
        Button {
            NotificationCenter.default.post(
                name: .rebaseOntoCommit,
                object: commit.sha
            )
        } label: {
            Label("Rebase current branch onto this...", systemImage: "arrow.triangle.pull")
        }

        Button {
            NotificationCenter.default.post(
                name: .interactiveRebase,
                object: commit.sha
            )
        } label: {
            Label("Interactive Rebase...", systemImage: "list.bullet.rectangle.portrait")
        }

        Divider()

        Button {
            // Implementation for Diff with HEAD
            NotificationCenter.default.post(
                name: .diffWithHead,
                object: commit.sha
            )
        } label: {
            Label("Diff with HEAD", systemImage: "arrow.left.arrow.right")
        }

        Button {
             let process = Process()
             process.launchPath = "/usr/bin/open"
             process.arguments = ["-a", "Terminal", appState.currentRepository?.path ?? "."]
             try? process.run()
        } label: {
            Label("Open in Terminal", systemImage: "terminal")
        }

        Divider()

        // Reset operations
        Menu {
            Button("Soft (keep changes staged)") {
                NotificationCenter.default.post(
                    name: .resetToCommit,
                    object: ["sha": commit.sha, "mode": "soft"]
                )
            }
            Button("Mixed (keep changes unstaged)") {
                NotificationCenter.default.post(
                    name: .resetToCommit,
                    object: ["sha": commit.sha, "mode": "mixed"]
                )
            }
            Button("Hard (discard all changes)") {
                NotificationCenter.default.post(
                    name: .resetToCommit,
                    object: ["sha": commit.sha, "mode": "hard"]
                )
            }
        } label: {
            Label("Reset to This Commit", systemImage: "clock.arrow.circlepath")
        }
    }

    @ViewBuilder
    private func multiCommitActions() -> some View {
        Button {
            NotificationCenter.default.post(
                name: .revertCommit,
                object: commits
            )
        } label: {
            Label("Revert \(commits.count) Commits...", systemImage: "arrow.uturn.left")
        }

        Button {
            // Placeholder for multi cherry-pick
        } label: {
            Label("Cherry-pick \(commits.count) Commits...", systemImage: "arrow.right.doc.on.clipboard")
        }

        Divider()

        Button {
            let shas = commits.map { $0.sha }.joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(shas, forType: .string)
        } label: {
            Label("Copy \(commits.count) SHAs", systemImage: "doc.on.doc")
        }
    }
}

// MARK: - File Changes Indicator
/// Visual indicator showing file changes with count and add/delete bars
struct FileChangesIndicator: View {
    let additions: Int
    let deletions: Int
    let filesChanged: Int
    let compact: Bool

    @StateObject private var themeManager = ThemeManager.shared

    init(additions: Int, deletions: Int, filesChanged: Int, compact: Bool = false) {
        self.additions = additions
        self.deletions = deletions
        self.filesChanged = filesChanged
        self.compact = compact
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            // File count icon
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textMuted)

                if filesChanged > 0 {
                    Text("\(filesChanged)")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(theme.text)
                }
            }

            if !compact && (additions > 0 || deletions > 0) {
                // Visual bar (proportional to changes)
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        // Green bar for additions
                        if additions > 0 {
                            Rectangle()
                                .fill(AppTheme.diffAddition)
                                .frame(width: barWidth(for: additions, in: geo.size.width))
                                .frame(height: 8)
                        }

                        // Red bar for deletions
                        if deletions > 0 {
                            Rectangle()
                                .fill(AppTheme.diffDeletion)
                                .frame(width: barWidth(for: deletions, in: geo.size.width))
                                .frame(height: 8)
                        }
                    }
                }
                .frame(width: 60, height: 8)
                .cornerRadius(2)
            }

            if !compact {
                // Text indicators
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    if additions > 0 {
                        Text("+\(additions)")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
                            .foregroundColor(AppTheme.diffAddition)
                    }

                    if deletions > 0 {
                        Text("-\(deletions)")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
                            .foregroundColor(AppTheme.diffDeletion)
                    }
                }
            }
        }
    }

    private func barWidth(for count: Int, in totalWidth: CGFloat) -> CGFloat {
        let total = additions + deletions
        guard total > 0 else { return 0 }
        return totalWidth * (CGFloat(count) / CGFloat(total))
    }
}

// MARK: - Additional Notification Names
extension Notification.Name {
    static let createBranchFromCommit = Notification.Name("createBranchFromCommit")
    static let createTagFromCommit = Notification.Name("createTagFromCommit")
    static let cherryPickCommit = Notification.Name("cherryPickCommit")
    static let revertCommit = Notification.Name("revertCommit")
    static let resetToCommit = Notification.Name("resetToCommit")
    static let rebaseOntoCommit = Notification.Name("rebaseOntoCommit")
    static let interactiveRebase = Notification.Name("interactiveRebase")
    static let diffWithHead = Notification.Name("diffWithHead")
}
