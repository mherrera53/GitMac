import Foundation
import Testing
@testable import GitMac

@Suite("Real local remotes and preservation of working changes")
struct RemoteOperationLifecycleTests {
    @Test func fetchPullPushAndRejectedPushPreserveWorkAndHistories() async throws {
        // This suite requires the isolated runner; never inherit personal Git configuration.
        let environment = ProcessInfo.processInfo.environment
        try #require(environment["GIT_CONFIG_GLOBAL"] == "/dev/null" && environment["GIT_CONFIG_NOSYSTEM"] == "1")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-remote-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let local = root.appendingPathComponent("local"), peer = root.appendingPathComponent("peer")
        let remote = root.appendingPathComponent("remote.git")
        func git(_ args: [String], at directory: URL) async throws -> String {
            let result = await ShellExecutor.shared.execute("git", arguments: args, workingDirectory: directory.path)
            try #require(result.isSuccess, "Fixture Git command failed: \(result.stderr)")
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func commit(_ message: String, at directory: URL) async throws {
            _ = try await git(["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", message], at: directory)
        }
        _ = try await git(["init", "--bare", "--quiet", remote.path], at: root)
        _ = try await git(["init", "--quiet", "--initial-branch=main", local.path], at: root)
        try Data("base\n".utf8).write(to: local.appendingPathComponent("README"))
        try Data("tracked base\n".utf8).write(to: local.appendingPathComponent("keep.txt"))
        _ = try await git(["add", "--", "README", "keep.txt"], at: local)
        try await commit("Fixture base", at: local)
        _ = try await git(["remote", "add", "origin", remote.path], at: local)
        _ = try await git(["symbolic-ref", "HEAD", "refs/heads/main"], at: remote)
        let engine = GitEngine()
        var push = PushOptions(); push.branch = "main"; push.setUpstream = true
        try await engine.push(options: push, at: local.path)
        _ = try await git(["clone", "--quiet", remote.path, peer.path], at: root)
        try Data("incoming\n".utf8).write(to: peer.appendingPathComponent("README"))
        _ = try await git(["add", "--", "README"], at: peer)
        try await commit("Incoming fixture", at: peer)
        try await engine.push(at: peer.path)
        let incoming = try await git(["rev-parse", "HEAD"], at: peer)
        let originalHead = try await git(["rev-parse", "HEAD"], at: local)
        let note = Data("untracked local work\n".utf8)
        let staged = Data("my staged local change\n".utf8)
        try note.write(to: local.appendingPathComponent("local-note.txt"))
        try staged.write(to: local.appendingPathComponent("keep.txt"))
        _ = try await git(["add", "--", "keep.txt"], at: local)
        let stagedDiff = try await git(["diff", "--cached", "--binary"], at: local)
        try await engine.fetch(at: local.path)
        #expect(try await git(["rev-parse", "HEAD"], at: local) == originalHead)
        #expect(try await git(["rev-parse", "origin/main"], at: local) == incoming)
        #expect(try String(contentsOf: local.appendingPathComponent("README"), encoding: .utf8) == "base\n")
        #expect(try Data(contentsOf: local.appendingPathComponent("local-note.txt")) == note)
        #expect(try await git(["diff", "--cached", "--binary"], at: local) == stagedDiff)
        _ = try await git(["config", "pull.ff", "only"], at: local)
        try await engine.pull(at: local.path)
        #expect(try await git(["rev-parse", "HEAD"], at: local) == incoming)
        #expect(try String(contentsOf: local.appendingPathComponent("README"), encoding: .utf8) == "incoming\n")
        #expect(try Data(contentsOf: local.appendingPathComponent("local-note.txt")) == note)
        #expect(try Data(contentsOf: local.appendingPathComponent("keep.txt")) == staged)
        #expect(try await git(["diff", "--cached", "--binary"], at: local) == stagedDiff,
                "Pull must preserve the user's staged selection, not just working file bytes")
        try Data("local commit\n".utf8).write(to: local.appendingPathComponent("README"))
        _ = try await git(["add", "--", "README", "keep.txt"], at: local)
        try await commit("Local divergent fixture", at: local)
        let localHead = try await git(["rev-parse", "HEAD"], at: local)
        try Data("peer commit\n".utf8).write(to: peer.appendingPathComponent("README"))
        _ = try await git(["add", "--", "README"], at: peer)
        try await commit("Remote divergent fixture", at: peer)
        try await engine.push(at: peer.path)
        let remoteHead = try await git(["rev-parse", "HEAD"], at: peer)
        do { try await engine.push(at: local.path); Issue.record("Diverged push must be rejected without force") }
        catch GitError.pushFailed { }
        #expect(try await git(["rev-parse", "refs/heads/main"], at: remote) == remoteHead)
        #expect(try await git(["rev-parse", "HEAD"], at: local) == localHead)
        do { try await engine.pull(at: local.path); Issue.record("ff-only pull must not rewrite a divergent local branch") }
        catch GitError.pullFailed { }
        #expect(try await git(["rev-parse", "HEAD"], at: local) == localHead)
        #expect(try Data(contentsOf: local.appendingPathComponent("local-note.txt")) == note)
        #expect(try String(contentsOf: local.appendingPathComponent("README"), encoding: .utf8) == "local commit\n")
        #expect(!FileManager.default.fileExists(atPath: local.appendingPathComponent(".git/MERGE_HEAD").path))
    }
}
