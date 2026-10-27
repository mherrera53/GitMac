import Foundation
import Testing
@testable import GitMac

@Suite("Pull recovery with real Git repositories")
struct PullRecoveryLifecycleTests {
    @Test(arguments: ["restore", "tracked-conflict", "untracked-collision", "network-failure", "wrong-branch", "untracked-only", "configured-autostash", "linked-worktree", "pending-operation", "merge-conflict", "rebase-conflict"])
    func recoveryPreservesLocalWork(scenario: String) async throws {
        let env = ProcessInfo.processInfo.environment
        try #require(env["GIT_CONFIG_GLOBAL"] == "/dev/null" && env["GIT_CONFIG_NOSYSTEM"] == "1")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-pull-recovery-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let local = root.appendingPathComponent("local"), peer = root.appendingPathComponent("peer")
        let remote = root.appendingPathComponent("remote.git")
        func git(_ args: [String], at dir: URL) async throws -> String {
            let r = await ShellExecutor.shared.execute("git", arguments: args, workingDirectory: dir.path)
            try #require(r.isSuccess, "Git fixture: \(args) \(r.stderr)")
            return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func write(_ value: String, _ file: String, at dir: URL) throws {
            try Data(value.utf8).write(to: dir.appendingPathComponent(file))
        }
        func commit(_ label: String, at dir: URL) async throws {
            _ = try await git(["-c", "commit.gpgsign=false", "commit", "-am", label, "--quiet"], at: dir)
        }
        _ = try await git(["init", "--bare", "--quiet", remote.path], at: root)
        _ = try await git(["init", "--quiet", "--initial-branch=main", local.path], at: root)
        let base = (0..<30).map { "line \($0)" }.joined(separator: "\n") + "\n"
        try write(base, "Timeline.vue", at: local); try write("index base\n", "index.txt", at: local)
        _ = try await git(["add", "."], at: local); try await commit("Base", at: local)
        _ = try await git(["remote", "add", "origin", remote.path], at: local)
        _ = try await git(["symbolic-ref", "HEAD", "refs/heads/main"], at: remote)
        _ = try await git(["push", "--quiet", "-u", "origin", "main"], at: local)
        _ = try await git(["clone", "--quiet", remote.path, peer.path], at: root)
        var work = local, branch = "main"
        if scenario == "linked-worktree" {
            work = root.appendingPathComponent("linked"); branch = "linked"
            _ = try await git(["worktree", "add", "--quiet", "-b", branch, work.path], at: local)
            _ = try await git(["branch", "--set-upstream-to=origin/main"], at: work)
        }
        let engine = GitEngine()
        // Existing stash must never be popped or deleted by recovery.
        try write("older stash\n", "index.txt", at: work)
        let older = try #require(try await engine.stash(at: work.path))
        #expect(try await engine.getStatus(at: work.path).hasChanges == false)
        let incoming = base.replacingOccurrences(of: "line 0\n", with: "remote first line\n")
        try write(incoming, "Timeline.vue", at: peer)
        if scenario == "untracked-collision" {
            try write("remote file\n", "collision.txt", at: peer)
            _ = try await git(["add", "collision.txt"], at: peer)
        }
        try await commit("Incoming", at: peer)
        _ = try await git(["push", "--quiet"], at: peer)
        if scenario == "merge-conflict" || scenario == "rebase-conflict" {
            try write(base.replacingOccurrences(of: "line 0\n", with: "committed local first\n"), "Timeline.vue", at: work)
            try await commit("Divergent local history", at: work)
            _ = try await git(["config", "pull.rebase", "false"], at: work)
        }
        let oldHead = try await git(["rev-parse", "HEAD"], at: work)
        let remoteHead = try await git(["rev-parse", "HEAD"], at: peer)
        let localContent = base.replacingOccurrences(of: scenario == "tracked-conflict" ? "line 0\n" : "line 29\n", with: "local edit\n")
        if scenario != "untracked-only" && scenario != "untracked-collision" { try write(localContent, "Timeline.vue", at: work) }
        if scenario != "untracked-only" {
            try write("staged edit\n", "index.txt", at: work)
            _ = try await git(["add", "--", "index.txt"], at: work)
            try write("staged edit\nextra unstaged\n", "index.txt", at: work)
        }
        try write("local untracked\n", scenario == "untracked-collision" ? "collision.txt" : "note.txt", at: work)
        let stagedBefore = try await git(["diff", "--cached", "--binary"], at: work)
        let unstagedBefore = try await git(["diff", "--binary"], at: work)
        var options = PullOptions()
        if scenario == "configured-autostash" {
            _ = try await git(["config", "pull.autostash", "true"], at: work)
            _ = try await git(["config", "rebase.autostash", "true"], at: work)
        }
        if scenario == "restore" || scenario == "configured-autostash" {
            do { try await engine.pull(at: work.path); Issue.record("Ordinary pull must protect overlapping work") }
            catch { #expect(PullRecovery.canSaveChanges(after: error)) }
            #expect(try await git(["rev-parse", "HEAD"], at: work) == oldHead)
        }
        if scenario == "network-failure" { options.remote = "missing-remote" }
        if scenario == "merge-conflict" || scenario == "rebase-conflict" {
            options.rebase = scenario == "rebase-conflict"
            do {
                _ = try await engine.pullPreservingLocalChanges(options: options, expectedBranch: branch, at: work.path)
                Issue.record("Conflicting incoming history must not report success")
            } catch let failure as PullRecoveryFailure {
                let sha = try #require(failure.backupSHA)
                #expect(try await git(["show", sha + ":index.txt"], at: work) == "staged edit\nextra unstaged")
                #expect(try await git(["show", sha + "^2:index.txt"], at: work) == "staged edit")
                #expect(try await git(["show", sha + "^3:note.txt"], at: work) == "local untracked")
                #expect(try await git(["diff", "--cached", "--name-only", "--", "index.txt"], at: work).isEmpty,
                    "Never reapply a backup into an unresolved merge/rebase")
                #expect(try await engine.getStatus(at: work.path).hasConflicts)
                #expect(try await engine.getStashes(at: work.path).contains { $0.sha == older.sha })
            }
            return
        }
        if scenario == "pending-operation" {
            let dir = try RepositoryFileLocations(repositoryPath: work.path).gitDirectory
            try Data((oldHead + "\n").utf8).write(to: dir.appendingPathComponent("MERGE_HEAD"))
        }
        if ["network-failure", "wrong-branch", "pending-operation"].contains(scenario) {
            do {
                _ = try await engine.pullPreservingLocalChanges(options: options,
                    expectedBranch: scenario == "wrong-branch" ? "unexpected" : branch, at: work.path)
                Issue.record("Recovery must refuse this scenario")
            } catch let failure as PullRecoveryFailure {
                #expect((failure.backupSHA != nil) == (scenario == "network-failure"))
                if let sha = failure.backupSHA {
                    #expect(try await git(["show", sha + ":Timeline.vue"], at: work) == localContent.trimmingCharacters(in: .newlines))
                }
            }
            #expect(try await git(["rev-parse", "HEAD"], at: work) == oldHead)
            #expect(try await git(["diff", "--cached", "--binary"], at: work) == stagedBefore)
            #expect(try await git(["diff", "--binary"], at: work) == unstagedBefore)
        } else {
            let result = try await engine.pullPreservingLocalChanges(options: options, expectedBranch: branch, at: work.path)
            let sha = try #require(result.backupSHA)
            #expect(result.didStash && result.hadLocalChanges)
            #expect(try await git(["rev-parse", "HEAD"], at: work) == remoteHead)
            if scenario == "tracked-conflict" || scenario == "untracked-collision" {
                #expect(result.stashConflict && !result.isFullySuccessful)
                if scenario == "tracked-conflict" {
                    #expect(try await git(["show", sha + ":Timeline.vue"], at: work) == localContent.trimmingCharacters(in: .newlines))
                } else {
                    #expect(try await git(["show", sha + "^3:collision.txt"], at: work) == "local untracked")
                    #expect(try String(contentsOf: work.appendingPathComponent("collision.txt"), encoding: .utf8) == "remote file\n")
                }
            } else {
                #expect(result.isFullySuccessful && result.stashApplied)
                #expect(try await git(["diff", "--cached", "--binary"], at: work) == stagedBefore)
                #expect(try String(contentsOf: work.appendingPathComponent("note.txt"), encoding: .utf8) == "local untracked\n")
                if scenario != "untracked-only" {
                    #expect(try String(contentsOf: work.appendingPathComponent("index.txt"), encoding: .utf8) == "staged edit\nextra unstaged\n")
                    #expect(try String(contentsOf: work.appendingPathComponent("Timeline.vue"), encoding: .utf8) == incoming.replacingOccurrences(of: "line 29\n", with: "local edit\n"))
                }
            }
            #expect(try await engine.getStashes(at: work.path).contains { $0.sha == sha })
        }
        #expect(try await engine.getStashes(at: work.path).contains { $0.sha == older.sha })
    }

    @Test func classificationDoesNotOfferStashingForNetworkOrDivergence() {
        #expect(!PullRecovery.canSaveChanges(after: GitError.pullFailed("Could not resolve host")))
        #expect(!PullRecovery.canSaveChanges(after: GitError.pullFailed("Not possible to fast-forward, aborting.")))
        #expect(!PullRecovery.canSaveChanges(after: GitError.stashFailed("would be overwritten")))
        #expect(PullRecovery.canSaveChanges(after: GitError.pullFailed("Your local changes would be overwritten by merge")))
    }
}
