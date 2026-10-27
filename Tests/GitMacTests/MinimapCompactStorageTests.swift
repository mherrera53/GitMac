import Foundation
import Testing
@testable import GitMac

@Suite("Compact minimap preserves identities and every parent")
struct MinimapCompactStorageTests {
    @Test func explicitMergeFlagsAndGlobalIndicesSurviveCompactStorage() {
        for merge in [false, true] {
            for parents: [Int] in [[], [7], [7, 11], [7, 7]] {
                let node = MinimapCommitNode(index: Int.max - 1, lane: Int.max,
                    isMerge: merge, parentIndices: parents, parentLanes: parents.map { $0 % 2 }, sha: "literal-identity")
                #expect(node.isMerge == merge)
                #expect(node.parentIndices == parents)
                #expect(Array(node.parentIndexValues) == parents)
                #expect(Array(node.parentIndexValues.reversed()) == Array(parents.reversed()))
                #expect(node.lane == Int.max)
                #expect(MinimapSHAIndex(nodes: [node])["literal-identity"] == Int.max - 1)
            }
        }
    }

    @Test func streamingLayoutKeepsFirstDuplicateAndMissingParentMergeSemantics() {
        let nodes = MinimapLayout.build(log: "child known missing\nknown\nchild discarded\n")
        #expect(nodes.map(\.sha) == ["child", "known"])
        #expect(nodes[0].isMerge && nodes[0].parentIndices == [1])
        #expect(nodes[0].parentLanes == [nodes[1].lane])
        #expect(!nodes[1].isMerge && nodes[1].parentIndices.isEmpty)
        let index = MinimapSHAIndex(nodes: nodes)
        #expect(index["child"] == 0 && index["known"] == 1 && index["missing"] == nil)
        let outside = MinimapLayout.build(log: "child missing-one missing-two\n")
        #expect(outside.count == 1 && outside[0].isMerge && outside[0].parentIndices.isEmpty)
    }
    @Test func fullSHAIdentitiesRoundTripAndSortWithoutTruncation() {
        let ids = [String(repeating: "0", count: 40), String(repeating: "f", count: 40),
            "0123456789abcdef0123456789abcdef01234567", "fedcba9876543210fedcba9876543210fedcba98",
            String(repeating: "A", count: 40), String(repeating: "b", count: 64), "é e\u{301}", "", "short"]
        let nodes = ids.enumerated().map { offset, sha in
            MinimapCommitNode(index: offset + 10, lane: 0, isMerge: false, parentIndices: [], parentLanes: [], sha: sha)
        }
        for (node, original) in zip(nodes, ids) { #expect(Array(node.sha.utf8) == Array(original.utf8)) }
        let index = MinimapSHAIndex(nodes: nodes)
        for (offset, sha) in ids.enumerated() { #expect(index[sha] == offset + 10) }
        #expect(index[String(repeating: "c", count: 40)] == nil)
        var changed = nodes
        changed[0].sha = "new-identity"
        #expect(changed[0].sha == "new-identity" && nodes[0].sha == ids[0])
        #expect(index[ids[0]] == 10 && index["new-identity"] == nil)
    }

}
