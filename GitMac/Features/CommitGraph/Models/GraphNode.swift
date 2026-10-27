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
    var isMerge: Bool { parentIndexValues.isMerge }
    let parentIndexValues: MinimapParentIndices
    var parentIndices: [Int] { Array(parentIndexValues) }
    let parentLanes: [Int]    // lane of each parent
    fileprivate var objectID: MinimapObjectID
    var sha: String {
        get { objectID.string }
        set { objectID = MinimapObjectID(newValue) }
    }

    init(index: Int, lane: Int, isMerge: Bool, parentIndices: [Int], parentLanes: [Int], sha: String = "") {
        self.init(index: index, lane: lane, isMerge: isMerge,
                  parentIndexValues: MinimapParentIndices(parentIndices), parentLanes: parentLanes, objectID: MinimapObjectID(sha))
    }

    fileprivate init(index: Int, lane: Int, isMerge: Bool, parentIndexValues: MinimapParentIndices,
                     parentLanes: [Int], objectID: MinimapObjectID) {
        self.index = index
        self.lane = lane
        self.parentIndexValues = parentIndexValues.withMergeFlag(isMerge)
        self.parentLanes = parentLanes
        self.objectID = objectID
    }
}

/// Common SHA-1 identities use all 160 bits inline, with no per-SHA string
/// allocation. Other object formats and literal test identities remain exact.
fileprivate enum MinimapObjectID: Hashable, Comparable, Sendable {
    case sha1(UInt64, UInt64, UInt32)
    case literal(String)

    init<S: StringProtocol>(_ value: S) {
        guard value.utf8.count == 40 else { self = .literal(String(value)); return }
        var first: UInt64 = 0, second: UInt64 = 0
        var last: UInt32 = 0
        var index = 0
        for byte in value.utf8 {
            let digit: UInt8
            switch byte {
            case 48...57: digit = byte - 48
            case 97...102: digit = byte - 87
            default: self = .literal(String(value)); return
            }
            if index < 16 { first = (first << 4) | UInt64(digit) }
            else if index < 32 { second = (second << 4) | UInt64(digit) }
            else { last = (last << 4) | UInt32(digit) }
            index += 1
        }
        self = .sha1(first, second, last)
    }

    var string: String {
        switch self {
        case .literal(let value): return value
        case .sha1(let first, let second, let last):
            let hex = Array("0123456789abcdef".utf8)
            var bytes = [UInt8](repeating: 48, count: 40)
            for index in 0..<16 { bytes[index] = hex[Int((first >> ((15 - index) * 4)) & 15)] }
            for index in 0..<16 { bytes[index + 16] = hex[Int((second >> ((15 - index) * 4)) & 15)] }
            for index in 0..<8 { bytes[index + 32] = hex[Int((last >> ((7 - index) * 4)) & 15)] }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.sha1(a, b, c), .sha1(x, y, z)):
            if a != x { return a < x }
            if b != y { return b < y }
            return c < z
        default: return lhs.string < rhs.string
        }
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
    case mergeEmpty
    case mergeSingle(Int)
    case nonMergeMultiple([Int])

    var isMerge: Bool {
        switch self {
        case .mergeEmpty, .mergeSingle, .multiple: return true
        case .empty, .single, .nonMergeMultiple: return false
        }
    }

    func withMergeFlag(_ merge: Bool) -> Self {
        switch self {
        case .empty, .mergeEmpty: return merge ? .mergeEmpty : .empty
        case .single(let value), .mergeSingle(let value): return merge ? .mergeSingle(value) : .single(value)
        case .multiple(let values), .nonMergeMultiple(let values): return merge ? .multiple(values) : .nonMergeMultiple(values)
        }
    }

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
        case .empty, .mergeEmpty: return 0
        case .single, .mergeSingle: return 1
        case .multiple(let values), .nonMergeMultiple(let values): return values.count
        }
    }
    func index(after i: Int) -> Int { i + 1 }
    func index(before i: Int) -> Int { i - 1 }
    subscript(position: Int) -> Int {
        switch self {
        case .empty, .mergeEmpty: preconditionFailure("Empty parent collection")
        case .single(let value), .mergeSingle(let value): precondition(position == 0); return value
        case .multiple(let values), .nonMergeMultiple(let values): return values[position]
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
        sortedPositions = nodes.indices.sorted { nodes[$0].objectID < nodes[$1].objectID }
    }

    var count: Int { sortedPositions.count }

    subscript(sha: String) -> Int? {
        let target = MinimapObjectID(sha)
        var lower = 0
        var upper = sortedPositions.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let position = sortedPositions[middle]
            let candidate = nodes[position].objectID
            if candidate == target { return nodes[position].index }
            if candidate < target { lower = middle + 1 } else { upper = middle }
        }
        return nil
    }
}

/// Pure lightweight history layout, shared by production and regression tests.
enum MinimapLayout {
    static func build(log: String) -> [MinimapCommitNode] {
        // A row cannot outnumber input bytes. Use compact dictionary values
        // when that proves every row fits, with an exact wide-index fallback.
        if log.utf8.count <= Int(Int32.max) { return build(log: log, indexType: Int32.self) }
        return build(log: log, indexType: Int.self)
    }

    private static func build<RowIndex: FixedWidthInteger>(log: String, indexType: RowIndex.Type) -> [MinimapCommitNode] {
        let estimatedRows = log.utf8.count / 82 + 1
        var indices = Dictionary<MinimapObjectID, RowIndex>(minimumCapacity: estimatedRows)
        var start = log.startIndex
        while start < log.endIndex {
            let end = log[start...].firstIndex(of: "\n") ?? log.endIndex
            if let token = log[start..<end].split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" }).first {
                let identity = MinimapObjectID(token)
                if indices[identity] == nil { indices[identity] = RowIndex(indices.count) }
            }
            start = end == log.endIndex ? end : log.index(after: end)
        }

        // Scan in input order without retaining an array of Substrings or a
        // second array of SHA references. Dictionary keys own each SHA once.
        // Only the first occurrence of a duplicate SHA defines its row/parents.
        func records(_ body: (Int, MinimapObjectID, Substring) -> Void) {
            var ordinal = 0
            var start = log.startIndex
            while start < log.endIndex {
                let end = log[start...].firstIndex(of: "\n") ?? log.endIndex
                if let token = log[start..<end].split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" }).first,
                   let entry = indices.index(forKey: MinimapObjectID(token)), Int(indices[entry].value) == ordinal {
                    body(ordinal, indices[entry].key, log[token.endIndex..<end])
                    ordinal += 1
                }
                start = end == log.endIndex ? end : log.index(after: end)
            }
        }
        var lanes = Array(repeating: -1, count: indices.count)
        var missingParentLanes: [MinimapObjectID: Int] = [:]
        var slots: [Bool] = []
        func freeColumn() -> Int {
            if let index = slots.firstIndex(of: false) { return index }
            slots.append(false)
            return slots.count - 1
        }
        records { index, _, row in
            let parents = row.split(whereSeparator: { $0 == " " || $0 == "\t" })
            let lane = lanes[index] >= 0 ? lanes[index] : freeColumn()
            lanes[index] = lane
            slots[lane] = true
            var firstParentLane: Int?
            if let token = parents.first {
                let parent = MinimapObjectID(token)
                if let value = indices[parent] {
                    let parentIndex = Int(value)
                    if lanes[parentIndex] < 0 { lanes[parentIndex] = lane }
                    firstParentLane = lanes[parentIndex]
                } else {
                    if missingParentLanes[parent] == nil { missingParentLanes[parent] = lane }
                    firstParentLane = missingParentLanes[parent]
                }
            }
            for token in parents.dropFirst() {
                guard let value = indices[MinimapObjectID(token)] else { continue }
                let parentIndex = Int(value)
                guard lanes[parentIndex] < 0 else { continue }
                let parentLane = freeColumn()
                lanes[parentIndex] = parentLane
                slots[parentLane] = true
            }
            if firstParentLane != lane { slots[lane] = false }
        }
        var nodes: [MinimapCommitNode] = []
        nodes.reserveCapacity(indices.count)
        var singleParentLanes = Array<[Int]?>(repeating: nil, count: 64)
        func parentLane(_ lane: Int) -> [Int] {
            if singleParentLanes.indices.contains(lane), let cached = singleParentLanes[lane] { return cached }
            let value = [lane]
            if singleParentLanes.indices.contains(lane) { singleParentLanes[lane] = value }
            return value
        }
        records { index, identity, row in
            let parents = row.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parents.count <= 1 {
                if let token = parents.first, let value = indices[MinimapObjectID(token)] {
                    let parent = Int(value)
                    nodes.append(MinimapCommitNode(index: index, lane: lanes[index], isMerge: false,
                        parentIndexValues: .single(parent), parentLanes: parentLane(lanes[parent]), objectID: identity))
                } else {
                    nodes.append(MinimapCommitNode(index: index, lane: lanes[index], isMerge: false,
                        parentIndexValues: .empty, parentLanes: [], objectID: identity))
                }
                return
            }
            var parentIndices: [Int] = []
            var parentLanes: [Int] = []
            for token in parents {
                guard let value = indices[MinimapObjectID(token)] else { continue }
                let parentIndex = Int(value)
                parentIndices.append(parentIndex)
                parentLanes.append(lanes[parentIndex])
            }
            if parentLanes.count == 1 { parentLanes = parentLane(parentLanes[0]) }
            nodes.append(MinimapCommitNode(index: index, lane: lanes[index], isMerge: true,
                parentIndexValues: MinimapParentIndices(parentIndices), parentLanes: parentLanes, objectID: identity))
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
