import SwiftUI

// MARK: - Commit Graph View
struct CommitGraphView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = GraphViewModel()
    @State private var selectedId: String?
    @State private var hoveredId: String?

    var body: some View {
        VStack(spacing: 0) {
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

            Divider()

            if vm.isLoading && vm.nodes.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.nodes) { node in
                            GraphRow(
                                node: node,
                                isSelected: selectedId == node.commit.sha,
                                isHovered: hoveredId == node.commit.sha
                            )
                            .onHover { h in hoveredId = h ? node.commit.sha : nil }
                            .onTapGesture {
                                selectedId = node.commit.sha
                                appState.selectedCommit = node.commit
                            }
                        }

                        if vm.hasMore {
                            ProgressView().frame(height: 40)
                                .onAppear { Task { await vm.loadMore() } }
                        }
                    }
                }
            }
        }
        .background(GitKrakenTheme.background)
        .task {
            if let p = appState.currentRepository?.path {
                await vm.load(at: p)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, p in
            if let p { Task { await vm.load(at: p) } }
        }
    }
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

    private let H: CGFloat = 42      // Mayor altura de fila
    private let W: CGFloat = 24      // Mayor espaciado entre carriles
    private let R: CGFloat = 8       // Nodos más grandes
    private let LW: CGFloat = 3      // Líneas más gruesas

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

            // Graph - all drawn in Canvas
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

                // 5) Node circle (drawn LAST to cover intersections)
                let nodeRect = CGRect(x: myX - R, y: cy - R, width: R * 2, height: R * 2)
                ctx.fill(Circle().path(in: nodeRect), with: .color(c))

                // 6) Author initial
                let initial = String(node.commit.author.prefix(1)).uppercased()
                ctx.draw(Text(initial).font(.system(size: 9, weight: .bold)).foregroundColor(.white), at: CGPoint(x: myX, y: cy))
            }
            .frame(width: 110, height: H)

            // Commit info (avatar is now in graph node)
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
        // Smooth S-curve
        p.addCurve(
            to: to,
            control1: CGPoint(x: from.x, y: from.y + (to.y - from.y) * 0.5),
            control2: CGPoint(x: to.x, y: from.y + (to.y - from.y) * 0.5)
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
    @Published var isLoading = false
    @Published var hasMore = true

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
            let branches = try await engine.getBranches(at: p)
            // Use first branch name for each SHA (multiple branches can point to same commit)
            branchHeads = [:]
            for branch in branches {
                if branchHeads[branch.targetSHA] == nil {
                    branchHeads[branch.targetSHA] = branch.name
                }
            }

            commits = try await engine.getCommits(at: p, limit: 100)
            hasMore = commits.count == 100

            // Build on background thread
            let newNodes = await buildNodes()
            nodes = newNodes
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
}
