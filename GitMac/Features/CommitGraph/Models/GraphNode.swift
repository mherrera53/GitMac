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
    let parentIndexValues: MinimapParentIndices
    var parentIndices: [Int] { Array(parentIndexValues) }
    let parentLanes: [Int]    // lane of each parent
    var sha: String = ""

    init(index: Int, lane: Int, isMerge: Bool, parentIndices: [Int], parentLanes: [Int], sha: String = "") {
        self.index = index
        self.lane = lane
        self.isMerge = isMerge
        self.parentIndexValues = MinimapParentIndices(parentIndices)
        self.parentLanes = parentLanes
        self.sha = sha
    }
}

/// Most commits have one parent. Store that index inline; merges retain every
/// parent in their original array. Rendering iterates without creating arrays.
enum MinimapParentIndices: RandomAccessCollection, Sendable {
    typealias Index = Int
    typealias Element = Int
    case empty
    case single(Int)
    case multiple([Int])

    init(_ values: [Int]) {
        switch values.count {
        case 0: self = .empty
        case 1: self = .single(values[0])
        default: self = .multiple(values)
        }
    }

    var startIndex: Int { 0 }
    var endIndex: Int {
        switch self {
        case .empty: return 0
        case .single: return 1
        case .multiple(let values): return values.count
        }
    }
    func index(after i: Int) -> Int { i + 1 }
    func index(before i: Int) -> Int { i - 1 }
    subscript(position: Int) -> Int {
        switch self {
        case .empty: preconditionFailure("Empty parent collection")
        case .single(let value): precondition(position == 0); return value
        case .multiple(let values): return values[position]
        }
    }
}

/// A sorted permutation borrows the existing node snapshot instead of keeping
/// another full dictionary of SHA keys. Lookups preserve global history indices.
struct MinimapSHAIndex: Sendable {
    private let nodes: [MinimapCommitNode]
    private let sortedPositions: [Int]

    init(nodes: [MinimapCommitNode] = []) {
        self.nodes = nodes
        sortedPositions = nodes.indices.sorted { nodes[$0].sha < nodes[$1].sha }
    }

    var count: Int { sortedPositions.count }

    subscript(sha: String) -> Int? {
        var lower = 0
        var upper = sortedPositions.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let position = sortedPositions[middle]
            let candidate = nodes[position].sha
            if candidate == sha { return nodes[position].index }
            if candidate < sha { lower = middle + 1 } else { upper = middle }
        }
        return nil
    }
}

/// Pure lightweight history layout, shared by production and regression tests.
enum MinimapLayout {
    static func build(log: String) -> [MinimapCommitNode] {
        // Retain one parent slice per row, rather than a separate array of
        // fields. Own each SHA once and use integer-indexed lanes instead of
        // retaining a second full SHA dictionary. No identities are sampled.
        let estimatedRows = log.utf8.count / 82 + 1
        var rows: [Substring] = []
        var shas: [String] = []
        var indices = Dictionary<String, Int>(minimumCapacity: estimatedRows)
        rows.reserveCapacity(estimatedRows)
        shas.reserveCapacity(estimatedRows)
        var start = log.startIndex
        while start < log.endIndex {
            let end = log[start...].firstIndex(of: "\n") ?? log.endIndex
            let line = log[start..<end]
            if let token = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" }).first {
                let sha = String(token)
                if indices[sha] == nil {
                    indices[sha] = rows.count
                    shas.append(sha)
                    rows.append(log[token.endIndex..<end])
                }
            }
            start = end == log.endIndex ? end : log.index(after: end)
        }
        var lanes = Array(repeating: -1, count: rows.count)
        var missingParentLanes: [String: Int] = [:]
        var slots: [Bool] = []
        func freeColumn() -> Int {
            if let index = slots.firstIndex(of: false) { return index }
            slots.append(false)
            return slots.count - 1
        }
        // Match the main graph's reservation rule, without allocating Commits.
        for (index, row) in rows.enumerated() {
            let parents = row.split(whereSeparator: { $0 == " " || $0 == "\t" })
            let lane = lanes[index] >= 0 ? lanes[index] : freeColumn()
            lanes[index] = lane
            slots[lane] = true
            var firstParentLane: Int?
            if let token = parents.first {
                let parent = String(token)
                if let parentIndex = indices[parent] {
                    if lanes[parentIndex] < 0 { lanes[parentIndex] = lane }
                    firstParentLane = lanes[parentIndex]
                } else {
                    if missingParentLanes[parent] == nil { missingParentLanes[parent] = lane }
                    firstParentLane = missingParentLanes[parent]
                }
            }
            for token in parents.dropFirst() {
                guard let parentIndex = indices[String(token)], lanes[parentIndex] < 0 else { continue }
                let parentLane = freeColumn()
                lanes[parentIndex] = parentLane
                slots[parentLane] = true
            }
            if firstParentLane != lane { slots[lane] = false }
        }
        var nodes: [MinimapCommitNode] = []
        nodes.reserveCapacity(rows.count)
        // Common single-parent lanes share immutable Array storage. This is a
        // bounded interning cache, not a limit on lanes or parent connections.
        var singleParentLanes = Array<[Int]?>(repeating: nil, count: 64)
        for (index, row) in rows.enumerated() {
            let parents = row.split(whereSeparator: { $0 == " " || $0 == "\t" })
            var parentIndices: [Int] = []
            var parentLanes: [Int] = []
            for token in parents {
                guard let parentIndex = indices[String(token)] else { continue }
                let lane = lanes[parentIndex]
                parentIndices.append(parentIndex)
                parentLanes.append(lane)
            }
            if parentLanes.count == 1, let lane = parentLanes.first,
               singleParentLanes.indices.contains(lane) {
                if let shared = singleParentLanes[lane] { parentLanes = shared }
                else { singleParentLanes[lane] = parentLanes }
            }
            nodes.append(MinimapCommitNode(index: index, lane: lanes[index],
                isMerge: parents.count > 1, parentIndices: parentIndices,
                parentLanes: parentLanes, sha: shas[index]))
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
        visibleRange(timeline: timeline, indexForSHA: { indices[$0] },
                     offset: offset, height: height, rowHeight: rowHeight)
    }

    static func visibleRange(timeline: [TimelineItem], indices: MinimapSHAIndex,
                             offset: CGFloat, height: CGFloat, rowHeight: CGFloat) -> ClosedRange<Int>? {
        visibleRange(timeline: timeline, indexForSHA: { indices[$0] },
                     offset: offset, height: height, rowHeight: rowHeight)
    }

    private static func visibleRange(timeline: [TimelineItem], indexForSHA: (String) -> Int?,
                                     offset: CGFloat, height: CGFloat, rowHeight: CGFloat) -> ClosedRange<Int>? {
        guard !timeline.isEmpty, offset.isFinite, height.isFinite, height > 0,
              rowHeight.isFinite, rowHeight > 0 else { return nil }
        let lower = Int(min(CGFloat(timeline.count - 1), max(0, offset / rowHeight)))
        let upper = Int(min(CGFloat(timeline.count - 1), max(CGFloat(lower), (offset + height) / rowHeight)))
        let visible = timeline[lower...upper].compactMap { item -> Int? in
            guard case .commit(let node) = item else { return nil }
            return indexForSHA(node.commit.sha)
        }
        guard let first = visible.min(), let last = visible.max() else { return nil }
        return first...last
    }
}
