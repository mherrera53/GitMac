import Foundation

/// One policy for initial history loading and subsequent status refreshes.
struct GraphWorkingCopyCounts {
    let staged: Int
    let unstaged: Int
    let conflicted: Int
    var hasChanges: Bool { staged > 0 || unstaged > 0 || conflicted > 0 }

    init(status: RepositoryStatus) {
        staged = status.staged.count
        unstaged = status.unstaged.count + status.untracked.count
        conflicted = status.conflicted.count
    }
}

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

/// Shared logical coordinates for commit, stash and work-in-progress rows.
enum GraphGeometry {
    static func laneX(_ lane: Int, laneWidth: CGFloat, zoom: CGFloat) -> CGFloat {
        (CGFloat(lane) * laneWidth + laneWidth / 2 + 12) * zoom
    }
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
        // Three short passes avoid retaining an array of fields for every row
        // and a second SHA-to-lane dictionary. Slices borrow the input only
        // during construction; returned nodes own their SHA strings.
        var indices: [Substring: Int] = [:]
        for line in log.split(separator: "\n") {
            guard let sha = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).first,
                  indices[sha] == nil else { continue }
            indices[sha] = indices.count
        }
        var lanes = Array(repeating: -1, count: indices.count)
        var missingParentLanes: [Substring: Int] = [:]
        var slots: [Bool] = []
        func freeColumn() -> Int {
            if let index = slots.firstIndex(of: false) { return index }
            slots.append(false)
            return slots.count - 1
        }
        var nextRow = 0
        for line in log.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let sha = fields.first, let index = indices[sha], index == nextRow else { continue }
            nextRow += 1
            let lane = lanes[index] >= 0 ? lanes[index] : freeColumn()
            lanes[index] = lane
            slots[lane] = true
            var firstParentLane: Int?
            if fields.count > 1 {
                let parent = fields[1]
                if let parentIndex = indices[parent] {
                    if lanes[parentIndex] < 0 { lanes[parentIndex] = lane }
                    firstParentLane = lanes[parentIndex]
                } else {
                    if missingParentLanes[parent] == nil { missingParentLanes[parent] = lane }
                    firstParentLane = missingParentLanes[parent]
                }
            }
            for parent in fields.dropFirst(2) {
                guard let parentIndex = indices[parent], lanes[parentIndex] < 0 else { continue }
                let parentLane = freeColumn()
                lanes[parentIndex] = parentLane
                slots[parentLane] = true
            }
            if firstParentLane != lane { slots[lane] = false }
        }
        var nodes: [MinimapCommitNode] = []
        nodes.reserveCapacity(indices.count)
        for line in log.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let sha = fields.first, let index = indices[sha], index == nodes.count else { continue }
            var parentIndices: [Int] = []
            var parentLanes: [Int] = []
            for parent in fields.dropFirst() {
                guard let parentIndex = indices[parent] else { continue }
                let lane = lanes[parentIndex]
                parentIndices.append(parentIndex)
                parentLanes.append(lane)
            }
            nodes.append(MinimapCommitNode(index: index, lane: lanes[index],
                isMerge: fields.count > 2, parentIndices: parentIndices,
                parentLanes: parentLanes, sha: String(sha)))
        }
        return nodes
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
