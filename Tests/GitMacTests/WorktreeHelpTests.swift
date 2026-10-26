import Foundation
import Testing
@testable import GitMac

@Suite("Production worktrees and offline contextual help")
struct WorktreeHelpTests {
    @Test func nulRecordsPreservePathsAndProtectionReasons() {
        let path = "/tmp/work tree\twith\nlines-ñ"
        let output = "worktree /tmp/main\0HEAD aaaa\0branch refs/heads/main\0\0"
            + "worktree \(path)\0HEAD bbbb\0branch refs/heads/feature/refs/heads/test\0locked external drive\nkeep it\0prunable folder missing\0\0"
        let list = Worktree.parseFromPorcelain(output)
        #expect(list.count == 2)
        #expect(list[0].isMain && !list[1].isMain)
        #expect(list[1].path == path)
        #expect(list[1].branch == "feature/refs/heads/test")
        #expect(list[1].isLocked && list[1].isPrunable)
        #expect(list[1].lockedReason == "external drive\nkeep it")
        #expect(list[1].prunableReason == "folder missing")
    }

    @Test func bareMainAndLegacyLastRecordAreNotLost() {
        let bare = Worktree.parseFromPorcelain("worktree /tmp/bare\0bare\0\0worktree /tmp/linked\0HEAD abcd\0detached\0\0")
        #expect(bare.count == 2 && bare[0].isMain && bare[0].isBare)
        #expect(bare[1].isDetached && !bare[1].isMain)
        let legacy = Worktree.parseFromPorcelain("worktree /tmp/main\nHEAD abcd\nbranch refs/heads/main\nlocked reason")
        #expect(legacy.count == 1 && legacy[0].isLocked && legacy[0].lockedReason == "reason")
    }

    @Test func contextualHelpIsSearchableOfflineAndEveryLinkIsOfficial() {
        let topics = GitHelpTopic.all
        #expect(topics.count >= 30)
        #expect(Set(topics.map(\.id)).count == topics.count)
        #expect(topics.allSatisfy { !$0.summary.isEmpty && !$0.guidance.isEmpty && !$0.risk.isEmpty })
        #expect(topics.allSatisfy { $0.documentationURL.scheme == "https" && $0.documentationURL.host == "git-scm.com" })
        #expect(GitHelpTopic.matching("PREPARACION").contains { $0.id == "stage" })
        #expect(GitHelpTopic.matching("worktree carpeta").contains { $0.id == "worktrees" })
        #expect(GitHelpTopic.matching("zz-no-such-topic-zz").isEmpty)
        #expect(GitHelpTopic.matching("   ").count == topics.count)
        #expect(Set(["basics", "graph", "worktrees", "stash", "fetch", "pull", "push", "commit", "stage"])
            .isSubset(of: Set(topics.map(\.id))))
    }

    @Test func actualGitLifecycleProtectsLockedAndDirtyFolders() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let main = root.appendingPathComponent("main")
        try FileManager.default.createDirectory(at: main, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func git(_ args: [String]) async throws -> String {
            let result = await ShellExecutor.shared.execute("git", arguments: args, workingDirectory: main.path)
            #expect(result.isSuccess)
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        _ = try await git(["init", "--quiet"])
        try Data("fixture\n".utf8).write(to: main.appendingPathComponent("README"))
        _ = try await git(["add", "--", "README"])
        _ = try await git(["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Fixture"])
        let engine = GitEngine()
        let linked = root.appendingPathComponent("linked\nñ")
        let created = try await engine.addWorktree(path: linked.path, newBranch: "fixture-worktree", at: main.path)
        #expect(!created.isMain && created.branch == "fixture-worktree")
        #expect(URL(fileURLWithPath: created.path).resolvingSymlinksInPath() == linked.resolvingSymlinksInPath())
        try await engine.lockWorktree(path: created.path, reason: "Fixture protection\nsecond line", at: main.path)
        let locked = try await engine.listWorktrees(at: main.path)
        #expect(locked.first { $0.path == created.path }?.isLocked == true)
        #expect(locked.first { $0.path == created.path }?.lockedReason == "Fixture protection\nsecond line")
        do {
            try await engine.removeWorktree(path: created.path, at: main.path)
            Issue.record("Git must reject removal of a protected folder")
        } catch { #expect(FileManager.default.fileExists(atPath: created.path)) }
        try await engine.unlockWorktree(path: created.path, at: main.path)
        let untracked = linked.appendingPathComponent("unsaved.txt")
        try Data("keep me".utf8).write(to: untracked)
        do {
            try await engine.removeWorktree(path: created.path, at: main.path)
            Issue.record("Git must reject removal of an unclean folder without force")
        } catch { #expect(try String(contentsOf: untracked, encoding: .utf8) == "keep me") }
        try FileManager.default.removeItem(at: untracked)
        try await engine.removeWorktree(path: created.path, at: main.path)
        #expect(!FileManager.default.fileExists(atPath: created.path))
        #expect(!(try await git(["rev-parse", "--verify", "refs/heads/fixture-worktree"])).isEmpty)
        #expect(try String(contentsOf: main.appendingPathComponent("README"), encoding: .utf8) == "fixture\n")
        // Relative destinations are resolved against the command's repository,
        // not the test process cwd; returned paths account for /var aliases.
        let relative = try await engine.addWorktree(path: "../relative", newBranch: "relative-fixture", at: main.path)
        #expect(URL(fileURLWithPath: relative.path).resolvingSymlinksInPath() == root.appendingPathComponent("relative").resolvingSymlinksInPath())
        try await engine.removeWorktree(path: relative.path, at: main.path)
    }
}
