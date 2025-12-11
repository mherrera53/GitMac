import SwiftUI

// MARK: - Color Extension for Branch Colors
private extension Color {
    static func branchColor(_ index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .pink, .yellow]
        return colors[index % colors.count]
    }
}

// MARK: - Commit Graph View
struct CommitGraphView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = GraphViewModel()
    @StateObject private var tracker = RemoteOperationTracker.shared
    @State private var selectedId: String?
    @State private var hoveredId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Remote operation status bar (if exists)
            if let operation = lastOperationForCurrentBranch {
                remoteStatusBar(operation: operation)
                Divider()
            }
            
            graphHeader
            Divider()
            graphContent
        }
        .background(GitKrakenTheme.background)
        .task {
            if let p = appState.currentRepository?.path {
                await vm.load(at: p)
                // Load GitHub avatars for repo contributors
                await loadRepoAvatars()
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, p in
            if let p { Task { await vm.load(at: p) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            if let path = notification.object as? String,
               path == appState.currentRepository?.path {
                Task { await vm.load(at: path) }
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
        HStack(spacing: 12) {
            // Status icon and info
            RemoteStatusBadge(operation: operation, compact: false)
            
            // Time ago
            Text(operation.timestamp.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
            
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
                        .font(.caption)
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
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(operation.color.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(operation.color.opacity(0.4)),
            alignment: .bottom
        )
    }

    /// Load avatars from GitHub repo commits API
    private func loadRepoAvatars() async {
        guard let repo = appState.currentRepository,
              let remote = repo.remotes.first(where: { $0.name == "origin" }),
              let token = try? await KeychainManager.shared.getGitHubToken(),
              !token.isEmpty else { return }

        // Parse owner/repo from GitHub URL
        let url = remote.fetchURL
        let pattern = #"github\.com[:/]([^/]+)/([^/.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
              let ownerRange = Range(match.range(at: 1), in: url),
              let repoRange = Range(match.range(at: 2), in: url) else { return }

        let owner = String(url[ownerRange])
        let repoName = String(url[repoRange])

        await AvatarService.shared.loadRepoAuthors(owner: owner, repo: repoName, token: token)
    }

    private var graphHeader: some View {
        HStack(spacing: 0) {
            Text("BRANCH / TAG")
                .frame(width: 140, alignment: .leading)
                .padding(.leading, 12)
            Text("GRAPH")
                .frame(width: 110, alignment: .center)
            Text("COMMIT MESSAGE")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(GitKrakenTheme.textMuted)
        .frame(height: 28)
        .background(GitKrakenTheme.backgroundSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Graph Header: Branch, Graph, Commit Message")
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
        ScrollView {
            LazyVStack(spacing: 0) {
                uncommittedChangesSection
                timelineSection
                loadMoreSection
            }
        }
    }

    @ViewBuilder
    private var uncommittedChangesSection: some View {
        if vm.hasUncommittedChanges {
            UncommittedChangesRow(
                stagedCount: vm.stagedCount,
                unstagedCount: vm.unstagedCount,
                isSelected: selectedId == "uncommitted",
                isHovered: hoveredId == "uncommitted"
            )
            .onHover { h in hoveredId = h ? "uncommitted" : nil }
            .onTapGesture {
                selectedId = "uncommitted"
                appState.selectedCommit = nil
                appState.selectedStash = nil
            }
        }
    }

    // Merged timeline of commits and stashes, sorted chronologically
    private var timelineSection: some View {
        ForEach(vm.timelineItems) { item in
            switch item {
            case .commit(let node):
                GraphRow(
                    node: node,
                    isSelected: selectedId == node.commit.sha,
                    isHovered: hoveredId == node.commit.sha
                )
                .onHover { h in hoveredId = h ? node.commit.sha : nil }
                .onTapGesture {
                    selectedId = node.commit.sha
                    appState.selectedCommit = node.commit
                    appState.selectedStash = nil  // Clear stash selection
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Commit \(node.commit.shortSha) by \(node.commit.author): \(node.commit.summary)")
                .accessibilityHint("Double tap to view details, context click for more actions")
            case .stash(let stashNode):
                GraphStashRow(
                    stash: stashNode,
                    isSelected: selectedId == stashNode.id,
                    isHovered: hoveredId == stashNode.id
                )
                .onHover { h in hoveredId = h ? stashNode.id : nil }
                .onTapGesture {
                    selectedId = stashNode.id
                    appState.selectedCommit = nil  // Clear commit selection
                    appState.selectedStash = stashNode.stash  // Set stash selection
                }
            }
        }
    }

    @ViewBuilder
    private var loadMoreSection: some View {
        if vm.hasMore {
            ProgressView().frame(height: 40)
                .onAppear { Task { await vm.loadMore() } }
        }
    }
}

// MARK: - Timeline Item (Commit or Stash)
enum TimelineItem: Identifiable {
    case commit(GraphNode)
    case stash(StashNode)

    var id: String {
        switch self {
        case .commit(let node): return node.id
        case .stash(let stash): return stash.id
        }
    }

    var date: Date {
        switch self {
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

    private let H: CGFloat = 44
    private let W: CGFloat = 26
    private let R: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
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
            .padding(.leading, 8)

            // Graph - dotted node
            ZStack {
                Canvas { ctx, size in
                    let cy = size.height / 2
                    let myX: CGFloat = W / 2 + 6

                    // Dotted line to bottom
                    drawDottedLine(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: myX, y: size.height), color: .orange)

                    // Dotted circle
                    let nodeRect = CGRect(x: myX - R, y: cy - R, width: R * 2, height: R * 2)
                    // Fill with background to hide line passing through
                    ctx.fill(Circle().path(in: nodeRect), with: .color(GitKrakenTheme.background))
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(.orange), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                }
                .frame(width: 110, height: H)

                // Pencil icon inside node
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .offset(x: -43)
            }

            // Info
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Uncommitted changes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                    Text("\(stagedCount) staged, \(unstagedCount) unstaged")
                        .font(.system(size: 10))
                        .foregroundColor(GitKrakenTheme.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: H)
        .background(isSelected ? GitKrakenTheme.selection : (isHovered ? GitKrakenTheme.hover : Color.clear))
    }

    func drawDottedLine(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 3]))
    }
}

// MARK: - Graph Stash Row (GitKraken style)
struct GraphStashRow: View {
    let stash: StashNode
    let isSelected: Bool
    let isHovered: Bool

    private let H: CGFloat = 44
    private let W: CGFloat = 26
    private let boxSize: CGFloat = 18
    private let LW: CGFloat = 2
    private let stashColor = Color(hex: "009999") // Teal/Cyan like GitKraken

    var body: some View {
        HStack(spacing: 0) {
            // Label - stash badge
            HStack(spacing: 4) {
                StashBadge(name: stash.stash.reference)
                Spacer()
            }
            .frame(width: 140)
            .padding(.leading, 8)

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
                    let roundedBox = RoundedRectangle(cornerRadius: 3).path(in: boxRect)
                    ctx.fill(roundedBox, with: .color(stashColor))
                    ctx.stroke(roundedBox, with: .color(stashColor.opacity(0.8)), lineWidth: 1)
                }
                .frame(width: 110, height: H)

                // Box icon
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: -5) // Adjust based on stashX calculation
            }

            // Info
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stash.stash.displayMessage)
                        .font(.system(size: 12))
                        .foregroundColor(GitKrakenTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(stash.stash.reference)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(stashColor)

                        if let branch = stash.stash.branchName {
                            Text("on \(branch)")
                                .font(.system(size: 10))
                                .foregroundColor(GitKrakenTheme.textMuted)
                        }
                    }
                }

                Spacer()

                Text(stash.stash.relativeDate)
                    .font(.system(size: 10))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: H)
        .background(isSelected ? GitKrakenTheme.selection : (isHovered ? GitKrakenTheme.hover : Color.clear))
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

// MARK: - Stash Badge (GitKraken style - solid background)
struct StashBadge: View {
    let name: String
    private let stashColor = Color(red: 0.3, green: 0.7, blue: 0.7)

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 8, weight: .bold))
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(stashColor)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 3))
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

// MARK: - Branch Badge (GitKraken style)
struct BranchBadge: View {
    let name: String
    let color: Color
    let isHead: Bool
    let isTag: Bool

    init(name: String, color: Color, isHead: Bool = false, isTag: Bool = false) {
        self.name = name
        self.color = color
        self.isHead = isHead
        self.isTag = isTag
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .semibold))
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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

    private let H: CGFloat = 44      // Mayor altura de fila
    private let W: CGFloat = 26      // Mayor espaciado entre carriles
    private let R: CGFloat = 14      // Node radius (bigger for avatar visibility)
    private let LW: CGFloat = 2      // Line width

    var body: some View {
        HStack(spacing: 0) {
            // Branch label with badge
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
            .frame(width: 140)
            .padding(.leading, 8)

            // Graph - Canvas for lines, overlay for avatar
            ZStack(alignment: .leading) {
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
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(GitKrakenTheme.background), lineWidth: 2)
                }
                .frame(width: 110, height: H)

                // Avatar overlay INSIDE the node - positioned at lane center
                avatarView
                    .frame(width: R * 2, height: R * 2)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .position(x: x(node.lane), y: H / 2)
                    .scaleEffect(isHovered ? 1.15 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            }
            .frame(width: 110, height: H)

            // Commit info
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.commit.summary)
                        .font(.system(size: 12))
                        .foregroundColor(GitKrakenTheme.textPrimary)
                        .lineLimit(1)
                    Text(node.commit.author)
                        .font(.system(size: 10))
                        .foregroundColor(GitKrakenTheme.textMuted)
                }

                Spacer()

                Text(node.commit.shortSha)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.textMuted)

                Text(node.commit.relativeDate)
                    .font(.system(size: 10))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: H)
        .background(isSelected ? GitKrakenTheme.selection : (isHovered ? GitKrakenTheme.hover : Color.clear))
        .contextMenu {
            CommitContextMenu(commit: node.commit)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        AvatarImageView(
            email: node.commit.authorEmail,
            size: R * 2 - 2,
            fallbackInitial: String(node.commit.author.prefix(1))
        )
    }

    func x(_ lane: Int) -> CGFloat { CGFloat(lane) * W + W / 2 + 6 }
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
        // More GitKraken-like smooth curve (less S-shape, more like railroad tracks that merge)
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
            // Load branches
            let branches = try await engine.getBranches(at: p)
            branchHeads = [:]
            for branch in branches {
                if branchHeads[branch.targetSHA] == nil {
                    branchHeads[branch.targetSHA] = branch.name
                }
            }

            // Load commits
            commits = try await engine.getCommits(at: p, limit: 100)
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
        } catch {
            print("Error loading graph: \(error)")
        }
        isLoading = false
    }

    func loadMore() async {
        guard let p = path, !isLoading else { return }
        isLoading = true
        page += 1

        do {
            let more = try await engine.getCommits(at: p, limit: 100, skip: page * 100)
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

        // Add all commits
        for node in nodes {
            items.append(.commit(node))
        }

        // Add all stashes
        for stash in stashNodes {
            items.append(.stash(stash))
        }

        // Sort by date (newest first)
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
    let commit: Commit
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
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
                    object: commit.sha
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
