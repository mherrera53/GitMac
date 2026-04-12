import SwiftUI

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

func buildCommitGraph(commits: [Commit], branchHeads: [String: String]) -> [GraphNode] {
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

    // Pre-index edges for O(1) lookup by row
    var edgesByParentRow: [Int: [GraphEdge]] = [:]
    var edgesByChildRow: [Int: [GraphEdge]] = [:]
    for edge in edges {
        edgesByParentRow[edge.parentRow, default: []].append(edge)
        edgesByChildRow[edge.childRow, default: []].append(edge)
    }

    // Sweep-line: track active edges passing through the current row
    // An edge is active between its childRow (exclusive) and parentRow (exclusive)
    // We map parentColumn -> count of active edges using that column
    var activeColumns: [Int: Int] = [:]

    var result: [GraphNode] = []

    for (row, commit) in commits.enumerated() {
        // Sweep-line update: activate edges that started at the previous row (childRow == row - 1)
        // An edge passes through row when childRow < row < parentRow, so it becomes active at childRow + 1
        if row > 0 {
            for edge in edgesByChildRow[row - 1] ?? [] {
                // Only activate if there's at least one row between child and parent
                if edge.parentRow > row {
                    activeColumns[edge.parentColumn, default: 0] += 1
                }
            }
        }

        // Sweep-line update: deactivate edges that end at this row (parentRow == row)
        // These edges were active up to row - 1, now they terminate here
        for edge in edgesByParentRow[row] ?? [] {
            if edge.childRow < row {
                activeColumns[edge.parentColumn, default: 0] -= 1
                if activeColumns[edge.parentColumn] == 0 {
                    activeColumns.removeValue(forKey: edge.parentColumn)
                }
            }
        }

        guard let col = shaToColumn[commit.sha] else { continue }

        // Pass-through columns from the sweep-line set
        var passThroughColumns = Set(activeColumns.keys)

        // Edges that END at this row (I am the parent)
        let incomingEdges = edgesByParentRow[row] ?? []

        // Line from top: any edge ends here in MY column
        let lineFromTop = incomingEdges.contains { $0.parentColumn == col }

        // Edges that START at this row (I am the child)
        let outgoingEdges = edgesByChildRow[row] ?? []

        // Line to bottom: my first parent is in MY column
        let lineToBottom = outgoingEdges.contains { $0.parentColumn == col && $0.isFirstParent }

        // If there's an edge passing through my column but I don't have lineFromTop/lineToBottom,
        // we need to keep it in passThroughColumns so the vertical line is drawn
        // Only remove my column from passThroughColumns if I have lineFromTop OR lineToBottom
        if lineFromTop || lineToBottom {
            passThroughColumns.remove(col)
        }

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

// MARK: - Branch Color Extension
extension Color {
    @MainActor static func branchColor(_ index: Int) -> Color {
        let colors = AppTheme.graphLaneColors
        return colors[index % colors.count]
    }
}

// MARK: - Commit Extension
extension Commit {
    var shortSha: String { String(sha.prefix(7)) }
}
