import Foundation
import Testing
@testable import GitMac

@Suite("Production minimap identity, topology and geometry")
struct MinimapLayoutTests {
    @Test func conflictOnlyWorkingCopyCannotAppearClean() {
        let clean = GraphWorkingCopyCounts(status: RepositoryStatus())
        #expect(!clean.hasChanges)
        var status = RepositoryStatus()
        status.conflicted = [FileStatus(path: "README.md", status: .unmerged)]
        let conflict = GraphWorkingCopyCounts(status: status)
        #expect(conflict.hasChanges)
        #expect(conflict.conflicted == 1)
        #expect(conflict.staged == 0 && conflict.unstaged == 0)
        status.untracked = ["note.txt"]
        let mixed = GraphWorkingCopyCounts(status: status)
        #expect(mixed.hasChanges && mixed.conflicted == 1 && mixed.unstaged == 1)
    }

    @Test func allRowKindsShareLaneOriginsAtEveryZoomAndDensity() {
        for zoom: CGFloat in [0.5, 0.75, 1, 1.5, 2] {
            #expect(GraphGeometry.laneX(0, laneWidth: 28, zoom: zoom) == 26 * zoom)
            for width: CGFloat in [14, 20, 28] {
                for lane in 0..<10 {
                    let start = GraphGeometry.laneX(lane, laneWidth: width, zoom: zoom)
                    let next = GraphGeometry.laneX(lane + 1, laneWidth: width, zoom: zoom)
                    #expect(abs((next - start) - width * zoom) < 0.000001)
                    #expect(start >= 12 * zoom)
                }
            }
        }
    }

    private func commit(_ sha: String, parents: [String]) -> Commit {
        Commit(sha: sha, message: "Fixture", author: "Fixture", authorEmail: "fixture@example.invalid",
            authorDate: Date(), committer: "Fixture", committerEmail: "fixture@example.invalid",
            committerDate: Date(), parentSHAs: parents)
    }

    @Test func emptyAndDuplicateHistoryCannotCreateInvalidIndices() {
        #expect(MinimapLayout.build(log: "\n \n").isEmpty)
        let nodes = MinimapLayout.build(log: "a b\na b\nb\n")
        #expect(nodes.map(\.sha) == ["a", "b"])
        #expect(nodes.map(\.index) == [0, 1])
        #expect(nodes[0].parentIndices == [1])
    }

    @Test func firstParentKeepsItsLaneAcrossAChain() {
        let nodes = MinimapLayout.build(log: "c b\nb a\na\n")
        #expect(nodes.map(\.lane) == [0, 0, 0])
        #expect(nodes.map(\.parentIndices) == [[1], [2], []])
        #expect(nodes.map(\.parentLanes) == [[0], [0], []])
    }

    @Test func compactSHAIndexKeepsOriginalPositionsAndSnapshots() {
        let shas = (0..<5000).reversed().map { String(format: "%040x", $0 + 1) }
        let nodes = MinimapLayout.build(log: shas.joined(separator: "\n"))
        let lookup = MinimapSHAIndex(nodes: nodes)
        #expect(lookup.count == nodes.count)
        #expect(shas.enumerated().allSatisfy { lookup[$0.element] == $0.offset })
        #expect(lookup["missing"] == nil && lookup[""] == nil && MinimapSHAIndex()["a"] == nil)
        var edited = nodes
        edited[0].sha = "changed"
        #expect(lookup[shas[0]] == 0 && lookup["changed"] == nil)
        var parentLanes = MinimapLayout.build(log: "a b\nb c\nc\n")
        parentLanes[0] = MinimapCommitNode(index: 0, lane: 9, isMerge: false,
                                         parentIndices: [1], parentLanes: [9], sha: "a")
        #expect(parentLanes[1].parentLanes == [0])
    }

    @Test func inlineParentIndicesPreserveEmptySingleAndMergeValues() {
        for values in [[], [0], [-1], [Int.max], [3, 1, 6], [7, 7, 2]] as [[Int]] {
            let node = MinimapCommitNode(index: 0, lane: 0, isMerge: values.count > 1,
                                         parentIndices: values, parentLanes: values.map { _ in 0 })
            #expect(node.parentIndices == values)
            #expect(Array(node.parentIndexValues) == values)
            #expect(node.parentIndexValues.count == values.count)
        }
    }

    @Test func compactSHAIndexViewportUsesGlobalIndices() {
        let nodes = [MinimapCommitNode(index: 10, lane: 0, isMerge: false, parentIndices: [], parentLanes: [], sha: "a"),
                     MinimapCommitNode(index: 80, lane: 0, isMerge: false, parentIndices: [], parentLanes: [], sha: "b")]
        let graph = buildCommitGraph(commits: [commit("a", parents: ["b"]), commit("b", parents: [])], branchHeads: [:])
        let rows = graph.map(TimelineItem.commit)
        #expect(MinimapLayout.visibleRange(timeline: rows, indices: MinimapSHAIndex(nodes: nodes),
                                          offset: 0, height: 88, rowHeight: 44) == 10...80)
    }

    @Test func mergeLanesMatchTheActualMainGraphWithoutModuloAliasing() {
        let parents = (0..<10).map { "parent\($0)" }
        let commits = [commit("merge", parents: parents)]
            + parents.map { commit($0, parents: ["root"]) } + [commit("root", parents: [])]
        let log = commits.map { ([$0.sha] + $0.parentSHAs).joined(separator: " ") }.joined(separator: "\n")
        let minimap = MinimapLayout.build(log: log)
        let graph = buildCommitGraph(commits: commits, branchHeads: [:])
        #expect(minimap.map(\.lane) == graph.map(\.lane))
        #expect(Set(minimap[1...10].map(\.lane)).count == 10)
        #expect(minimap[0].parentIndices == Array(1...10))
        #expect(minimap[0].parentLanes == minimap[1...10].map(\.lane))
    }

    @Test func missingParentsDoNotMisalignTheRemainingEdges() {
        let nodes = MinimapLayout.build(log: "merge missing present\npresent\n")
        #expect(nodes[0].parentIndices == [1])
        #expect(nodes[0].parentLanes == [nodes[1].lane])
    }

    @Test func deterministicDAGsPreserveFullLengthIdentityLanesAndEdges() {
        var seed: UInt64 = 0x4749544d4143
        func next() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1; return seed }
        for _ in 0..<80 {
            let shas = (0..<32).map { String(format: "%040x", $0 + 1) }
            let commits = shas.indices.map { index in
                let parents = shas.indices.dropFirst(index + 1).filter { _ in next() % 7 == 0 }.map { shas[$0] }
                return commit(shas[index], parents: parents)
            }
            let log = commits.map { ([$0.sha] + $0.parentSHAs).joined(separator: " ") }.joined(separator: "\n")
            let nodes = MinimapLayout.build(log: log)
            #expect(nodes.map(\.sha) == shas)
            #expect(nodes.map(\.lane) == buildCommitGraph(commits: commits, branchHeads: [:]).map(\.lane))
            for (index, node) in nodes.enumerated() {
                let expected = commits[index].parentSHAs.compactMap { shas.firstIndex(of: $0) }
                #expect(node.parentIndices == expected)
                #expect(node.parentLanes == expected.map { nodes[$0].lane })
            }
        }
    }

    @Test func hundredThousandNodesKeepFullIdentityWithBoundedDrawing() {
        let start = Date()
        let log = (0..<100_000).map { index in
            index == 99_999 ? "n\(index)" : "n\(index) n\(index + 1)"
        }.joined(separator: "\n")
        let nodes = MinimapLayout.build(log: log)
        let drawing = MinimapLayout.drawingSample(nodes)
        #expect(nodes.count == 100_000)
        #expect(drawing.count == 4096)
        #expect(drawing.first?.sha == "n0" && drawing.last?.sha == "n99999")
        #expect(Set(drawing.map(\.index)).count == drawing.count)
        #expect(nodes[50_000].sha == "n50000")
        print("Minimap 100k synthetic chain: \(Date().timeIntervalSince(start)) seconds; \(drawing.count) drawing nodes")
    }

    @Test func viewportIsBoundedForEmptySingleAndFullHistory() {
        #expect(MinimapLayout.viewport(range: nil, height: 100, count: 10) == nil)
        #expect(MinimapLayout.viewport(range: 0...0, height: 0, count: 10) == nil)
        #expect(MinimapLayout.viewport(range: 0...0, height: .nan, count: 10) == nil)
        #expect(MinimapLayout.viewport(range: 0...0, height: 100, count: 0) == nil)
        #expect(MinimapLayout.viewport(range: 0...0, height: 100, count: 1)?.height == 100)
        for range in [0...99, 90...99, Int.max...Int.max, -100 ... -1] {
            let viewport = MinimapLayout.viewport(range: range, height: 100, count: 100)!
            #expect(viewport.minY >= 0 && viewport.maxY <= 100)
            #expect(viewport.height >= 8 && viewport.height <= 100)
        }
    }

    @Test func clickAndDragEndpointsAreSafeForZeroAndOneCommit() {
        #expect(MinimapLayout.index(at: 1, height: 100, count: 0) == nil)
        #expect(MinimapLayout.index(at: 1, height: 0, count: 100) == nil)
        #expect(MinimapLayout.index(at: .nan, height: 100, count: 100) == nil)
        #expect(MinimapLayout.index(at: 100, height: 100, count: 1) == 0)
        #expect(MinimapLayout.index(at: -100, height: 100, count: 100) == 0)
        #expect(MinimapLayout.index(at: 1000, height: 100, count: 100) == 99)
        #expect(MinimapLayout.index(at: 100, height: 100, count: 100) == 99)
    }

    @Test func viewportTracksSHAsRatherThanAuxiliaryOrFilteredRowOffsets() {
        let graph = buildCommitGraph(commits: [commit("a", parents: ["b"]), commit("b", parents: [])], branchHeads: [:])
        let stash = StashNode(id: "stash-0", stash: Stash(index: 0, message: "Fixture", sha: "stash", date: Date()))
        let rows: [TimelineItem] = [.uncommitted(staged: 1, unstaged: 0), .stash(stash)] + graph.map(TimelineItem.commit)
        let indices = ["a": 10, "b": 80]
        #expect(MinimapLayout.visibleRange(timeline: rows, indices: indices, offset: 88, height: 44, rowHeight: 44) == 10...80)
        #expect(MinimapLayout.visibleRange(timeline: rows, indices: indices, offset: 0, height: 40, rowHeight: 44) == nil)
        #expect(MinimapLayout.visibleRange(timeline: [.commit(graph[1])], indices: indices, offset: 0, height: 44, rowHeight: 44) == 80...80)
        #expect(MinimapLayout.visibleRange(timeline: rows, indices: indices, offset: .nan, height: 44, rowHeight: 44) == nil)
    }
}
