import Foundation
import SwiftUI

// UI-only dependency: no layout or Git behavior is replaced.
enum AppTheme {
    @MainActor static let graphLaneColors: [Color] = [.blue, .green, .orange]
}

enum FixtureError: Error { case unavailable }

@MainActor final class PagingEngine {
    var skips: [Int] = []
    var scopes: [String?] = []
    var limits: [Int] = []
    var history: [Commit]?
    var failOnce = true
    var beforeReturn: (() -> Void)?
    func getCommitsV2(at: String, branch: String? = nil, limit: Int, skip: Int) async throws -> [Commit] {
        skips.append(skip)
        scopes.append(branch)
        limits.append(limit)
        if failOnce { failOnce = false; throw FixtureError.unavailable }
        beforeReturn?()
        return history.map { Array($0.dropFirst(skip).prefix(limit)) } ?? []
    }
}

@MainActor final class PagingHarness {
    let engine = PagingEngine()
    var path: String? = "fixture"
    var isLoading = false
    var hasMore = true
    var page = 0
    var generation = UUID()
    var historyTipSHA: String? = "fixture-head"
    var lastError: String?
    var commits: [Commit] = []
    var branchHeads: [String: String] = [:]
    var nodes: [GraphNode] = []
    var maxLane = 0
    var hasUncommittedChanges = false
    var stagedCount = 0
    var unstagedCount = 0
    var stashNodes: [StashNode] = []
    var timelineItems: [TimelineItem] = []
    var commitsBySHA: [String: Commit] = [:]
    // PRODUCTION_VIEW_MODEL_METHODS
    func refreshTimeline() { buildTimeline() }
}

@main struct CoreRegressions {
    static func commit(_ sha: String, _ parents: [String] = [], time: TimeInterval = 100) -> Commit {
        Commit(sha: sha, message: "Fixture", author: "Fixture", authorEmail: "fixture@example.invalid",
               authorDate: Date(timeIntervalSince1970: time), committer: "Fixture",
               committerEmail: "fixture@example.invalid", committerDate: Date(timeIntervalSince1970: time), parentSHAs: parents)
    }

    @MainActor static func main() async throws {
        var failures: [String] = []
        func check(_ condition: Bool, _ label: String) {
            print("\(condition ? "PASS" : "FAIL") \(label)")
            if !condition { failures.append(label) }
        }

        let paging = PagingHarness()
        await paging.loadMore()
        check(paging.lastError != nil && !paging.isLoading, "failed page exposes an error and releases loading state")
        await paging.loadMore()
        check(paging.engine.skips == [100, 100], "pagination retries the failed offset")
        check(paging.engine.scopes.allSatisfy { $0 == "fixture-head" }, "pagination is pinned to the original history tip")
        let exhausted = PagingHarness()
        exhausted.hasMore = false
        await exhausted.loadMore()
        check(exhausted.engine.skips.isEmpty, "exhausted pagination does not issue another command")
        let jump = PagingHarness()
        await jump.loadUpTo(index: 150)
        await jump.loadUpTo(index: 150)
        check(jump.engine.skips == [100, 100], "minimap loading retries the failed offset")
        let busy = PagingHarness()
        busy.isLoading = true
        await busy.loadUpTo(index: 150)
        await busy.loadMore()
        check(busy.engine.skips.isEmpty, "pagination cannot overlap an active load")
        let bulk = PagingHarness()
        let history = (0..<2500).map { commit("bulk-\($0)") }
        bulk.engine.history = history
        bulk.engine.failOnce = false
        bulk.commits = Array(history.prefix(100))
        await bulk.loadUpTo(index: 1150)
        check(bulk.engine.skips == [100, 1100] && bulk.engine.limits == [1000, 100],
              "distant minimap seek uses bounded batches and the next exact offset")
        check(bulk.page == 11 && bulk.commits.map(\.sha) == Array(history.prefix(1200)).map(\.sha),
              "bulk seek preserves every commit exactly once and commits the page cursor")
        await bulk.loadMore()
        check(bulk.engine.skips == [100, 1100, 1200] && bulk.page == 12 && bulk.commits.count == 1300,
              "normal pagination resumes immediately after a bulk seek without gaps")
        for seek in [false, true] {
            let stale = PagingHarness()
            stale.engine.failOnce = false
            stale.engine.beforeReturn = {
                stale.generation = UUID()
                stale.path = "new-repository"
                stale.isLoading = true
            }
            if seek { await stale.loadUpTo(index: 150) } else { await stale.loadMore() }
            check(stale.page == 0 && stale.nodes.isEmpty && stale.hasMore && stale.isLoading,
                  "\(seek ? "minimap" : "pagination") discards stale results without clearing new loading state")
        }

        let child = commit("child", ["parent"], time: 100)
        let parent = commit("parent", time: 200)
        let timeline = PagingHarness()
        timeline.hasUncommittedChanges = true
        timeline.stashNodes = [.init(id: "stash-0", stash: .init(index: 0, message: "Fixture", sha: "stash",
                                                                 date: Date(timeIntervalSince1970: 150)))]
        timeline.nodes = buildCommitGraph(commits: [child, parent], branchHeads: [:])
        timeline.refreshTimeline()
        let order = timeline.timelineItems.compactMap { item -> String? in
            if case .commit(let node) = item { return node.id }; return nil
        }
        check(order == ["child", "parent"], "timeline preserves topology despite skewed author dates")
        check(timeline.timelineItems.map(\.id) == ["uncommitted-changes", "stash-0", "child", "parent"],
              "auxiliary rows never split connected commit rows")

        let adjacent = buildCommitGraph(commits: [child, parent, commit("other")], branchHeads: [:])
        check(adjacent.last?.passThroughLanes.isEmpty == true, "adjacent edges leave no phantom lane")
        // Compare sweep-line output with a direct interval oracle for many DAGs.
        var seed: UInt64 = 42
        var oracleMatches = true
        for iteration in 0..<80 {
            let count = 25
            var commits: [Commit] = []
            for row in 0..<count {
                var parents: [String] = []
                for candidate in (row + 1)..<count {
                    seed = seed &* 6364136223846793005 &+ 1
                    if seed % 11 == 0 && parents.count < 3 { parents.append("\(iteration)-\(candidate)") }
                }
                commits.append(commit("\(iteration)-\(row)", parents))
            }
            let nodes = buildCommitGraph(commits: commits, branchHeads: [:])
            let rows = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($1.id, $0) })
            for (row, node) in nodes.enumerated() {
                var expected = Set<Int>()
                for (childRow, childNode) in nodes.enumerated() where childRow < row {
                    for parent in childNode.commit.parentSHAs {
                        if let parentRow = rows[parent], parentRow > row { expected.insert(nodes[parentRow].lane) }
                    }
                }
                if node.lineFromTop || node.lineToBottom { expected.remove(node.lane) }
                if expected != node.passThroughLanes { oracleMatches = false }
            }
        }
        check(oracleMatches, "sweep-line agrees with independent interval oracle across 80 DAGs")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-patch-\(UUID())'s repo")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let git = await ShellExecutor.shared.execute("git", arguments: ["init", "--quiet"], workingDirectory: directory.path)
        check(git.isSuccess, "isolated Git fixture initializes")
        let file = directory.appendingPathComponent("example.txt")
        try "before\n".write(to: file, atomically: true, encoding: .utf8)
        let diff = "--- a/example.txt\n+++ b/example.txt\n@@ -1 +1 @@\n-before\n+after\n"
        let patch = CloudPatchService.CloudPatch(id: "../../untrusted", title: "Fixture", description: nil,
            files: [.init(filename: "patch.diff", content: diff, language: nil)], createdAt: Date(), expiresAt: nil,
            shareURL: "https://example.invalid", isPublic: false, author: "fixture")
        do {
            try await CloudPatchService.shared.applyPatch(patch, to: directory.path)
            check(try String(contentsOf: file, encoding: .utf8) == "after\n", "patch applies with quoted repo path and untrusted ID")
        } catch { check(false, "patch applies with quoted repo path and untrusted ID: \(error)") }
        let validIDPatch = CloudPatchService.CloudPatch(id: "fixture", title: patch.title, description: nil,
            files: patch.files, createdAt: Date(), expiresAt: nil, shareURL: patch.shareURL, isPublic: false, author: "fixture")
        do {
            try await CloudPatchService.shared.applyPatch(validIDPatch, to: directory.appendingPathComponent("missing").path)
            check(false, "patch rejects a failed process even without an error keyword")
        } catch { check(true, "patch rejects a failed process even without an error keyword") }
        do {
            try await CloudPatchService.shared.applyPatch(validIDPatch, to: directory.path)
            check(false, "reapplying a patch reports a Git failure")
        } catch { check(true, "reapplying a patch reports a Git failure") }

        let hostileDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitmac-patch-\(UUID())';touch injected-marker;#")
        try FileManager.default.createDirectory(at: hostileDirectory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: hostileDirectory) }
        _ = await ShellExecutor.shared.execute("git", arguments: ["init", "--quiet"], workingDirectory: hostileDirectory.path)
        try "before\n".write(to: hostileDirectory.appendingPathComponent("example.txt"), atomically: true, encoding: .utf8)
        do {
            try await CloudPatchService.shared.applyPatch(validIDPatch, to: hostileDirectory.path)
            check(try String(contentsOf: hostileDirectory.appendingPathComponent("example.txt"), encoding: .utf8) == "after\n",
                  "shell metacharacters in the repository path stay literal")
        } catch { check(false, "shell metacharacters in the repository path stay literal: \(error)") }
        check(!FileManager.default.fileExists(atPath: hostileDirectory.appendingPathComponent("injected-marker").path),
              "an attacker-controlled repository name cannot execute a command")

        print("\(failures.count) failures")
        if !failures.isEmpty { exit(1) }
    }
}
