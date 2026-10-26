import Foundation

// MARK: - Graph Node Data Model
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

/// Lightweight node for minimap rendering (no commit data, just position + parent connections)
struct MinimapCommitNode: Sendable {
    let index: Int
    let lane: Int
    let isMerge: Bool
    let parentIndices: [Int]  // indices into the minimapNodes array
    let parentLanes: [Int]    // lane of each parent
    var sha: String = ""
}

/// Pure lightweight history layout, shared by production and regression tests.
enum MinimapLayout {
    static func build(log: String) -> [MinimapCommitNode] {
        // Borrow slices only while building. Copy each retained SHA once into
        // the result, not again for every edge, row and deduplication table.
        var rows: [[Substring]] = []
        var indices: [Substring: Int] = [:]
        for line in log.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let sha = fields.first, indices[sha] == nil else { continue }
            indices[sha] = rows.count
            rows.append(fields)
        }
        var columns: [Substring: Int] = [:]
        var slots: [Substring?] = []
        func freeColumn() -> Int {
            if let index = slots.firstIndex(where: { $0 == nil }) { return index }
            slots.append(nil)
            return slots.count - 1
        }
        // Match the main graph's reservation rule, without allocating Commits.
        for row in rows {
            let sha = row[0]
            let parents = row.dropFirst()
            let lane = columns[sha] ?? freeColumn()
            columns[sha] = lane
            slots[lane] = sha
            if let parent = parents.first, columns[parent] == nil { columns[parent] = lane }
            for parent in parents.dropFirst() where columns[parent] == nil && indices[parent] != nil {
                let parentLane = freeColumn()
                columns[parent] = parentLane
                slots[parentLane] = parent
            }
            if parents.isEmpty || parents.first.flatMap({ columns[$0] }) != lane { slots[lane] = nil }
        }
        return rows.enumerated().map { index, row in
            var parentIndices: [Int] = []
            var parentLanes: [Int] = []
            for sha in row.dropFirst() {
                guard let parentIndex = indices[sha], let lane = columns[sha] else { continue }
                parentIndices.append(parentIndex)
                parentLanes.append(lane)
            }
            return MinimapCommitNode(index: index, lane: columns[row[0]] ?? 0,
                isMerge: row.count > 2, parentIndices: parentIndices,
                parentLanes: parentLanes, sha: String(row[0]))
        }
    }

    /// Keep the entire SHA index, but bound per-frame Canvas work. Dense
    /// histories use one representative (prefer a merge) per history bucket.
    static func drawingSample(_ nodes: [MinimapCommitNode], maximum: Int = 4096) -> [MinimapCommitNode] {
        let limit = max(2, maximum)
        guard nodes.count > limit else { return nodes }
        return (0..<limit).map { bucket in
            let lower = bucket * nodes.count / limit
            let upper = (bucket + 1) * nodes.count / limit
            if bucket == 0 { return nodes[0] }
            if bucket == limit - 1 { return nodes[nodes.count - 1] }
            return nodes[lower..<upper].first(where: \.isMerge) ?? nodes[lower]
        }
    }

    static func index(at y: CGFloat, height: CGFloat, count: Int) -> Int? {
        guard count > 0, height.isFinite, height > 0, y.isFinite else { return nil }
        let fraction = min(1, max(0, y / height))
        return min(count - 1, Int(fraction * CGFloat(count - 1)))
    }

    static func viewport(range: ClosedRange<Int>?, height: CGFloat, count: Int) -> CGRect? {
        guard let range, count > 0, height.isFinite, height > 0 else { return nil }
        let lower = min(count - 1, max(0, range.lowerBound))
        let upper = min(count - 1, max(lower, range.upperBound))
        let visibleHeight = min(height, max(8, height * CGFloat(upper - lower + 1) / CGFloat(count)))
        let offset = min(height - visibleHeight, height * CGFloat(lower) / CGFloat(count))
        return CGRect(x: 0, y: offset, width: 1, height: visibleHeight)
    }

    static func visibleRange(timeline: [TimelineItem], indices: [String: Int],
                             offset: CGFloat, height: CGFloat, rowHeight: CGFloat) -> ClosedRange<Int>? {
        guard !timeline.isEmpty, offset.isFinite, height.isFinite, height > 0,
              rowHeight.isFinite, rowHeight > 0 else { return nil }
        let lower = Int(min(CGFloat(timeline.count - 1), max(0, offset / rowHeight)))
        let upper = Int(min(CGFloat(timeline.count - 1), max(CGFloat(lower), (offset + height) / rowHeight)))
        let visible = timeline[lower...upper].compactMap { item -> Int? in
            guard case .commit(let node) = item else { return nil }
            return indices[node.commit.sha]
        }
        guard let first = visible.min(), let last = visible.max() else { return nil }
        return first...last
    }
}
