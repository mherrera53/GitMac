import Foundation
@testable import GitMac

@main struct GitIntegration {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-integration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let shell = ShellExecutor.shared
        let engine = GitEngine()
        var failures = 0
        func check(_ condition: Bool, _ description: String) {
            print("\(condition ? "PASS" : "FAIL") \(description)")
            if !condition { failures += 1 }
        }
        func git(_ arguments: [String]) async throws -> String {
            let result = await shell.execute("git", arguments: arguments, workingDirectory: directory.path)
            guard result.isSuccess else { throw GitError.commandFailed(arguments.joined(separator: " "), result.output) }
            return result.stdout
        }
        func write(_ name: String, _ content: String) throws {
            try content.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        func normalized(_ status: RepositoryStatus) -> [String] {
            func entries(_ prefix: String, _ files: [FileStatus]) -> [String] {
                files.map { "\(prefix):\($0.path):\($0.oldPath ?? ""):\($0.status.rawValue):\($0.additions):\($0.deletions)" }
            }
            return (entries("S", status.staged) + entries("W", status.unstaged) + entries("C", status.conflicted)
                    + status.untracked.map { "U:\($0)" }).sorted()
        }

        _ = try await git(["init", "--quiet", "--initial-branch=main"])
        let special = ["español.txt", "line\nbreak.txt", "literal -> name.txt", "tab\tname.txt", "-option.txt", "quote'\".txt", "bracket[1].txt", "star*.txt", ":(literal)file.txt"]
        for name in special { try write(name, "one\n") }
        try write("star-untouched.txt", "not selected\n")
        try await engine.stage(files: special, at: directory.path)
        let initial = try await engine.getStatus(at: directory.path)
        for name in special {
            check(initial.staged.contains { $0.path == name && $0.additions == 1 }, "F02 exact path and numstat: \(name.debugDescription)")
        }
        check(initial.untracked.contains("star-untouched.txt") && !initial.staged.contains { $0.path == "star-untouched.txt" }, "F02 selected wildcard filename cannot stage another file")
        try FileManager.default.removeItem(at: directory.appendingPathComponent("star-untouched.txt"))
        do {
            try await engine.unstage(files: [special[0]], at: directory.path)
            check(try await engine.getStatus(at: directory.path).untracked.contains(special[0]), "F01 unstage before first commit keeps working file")
        } catch { check(false, "F01 unstage before first commit: \(error)") }
        try await engine.stage(files: special, at: directory.path)
        _ = try await git(["commit", "--quiet", "-m", "Fixture baseline"])
        check(try await engine.getStatus(at: directory.path).totalChanges == 0, "F01 clean status after initial commit")

        try write(special[0], "one\ntwo\n")
        try await engine.stage(files: [special[0]], at: directory.path)
        try write(special[0], "one\ntwo\nthree\n")
        try write("added.txt", "staged\n")
        try await engine.stage(files: ["added.txt"], at: directory.path)
        try write("added.txt", "staged\nunstaged\n")
        _ = try await git(["mv", "--", "literal -> name.txt", "renamed\n -> new.txt"])
        try write("renamed\n -> new.txt", "one\nuncommitted\n")
        let status = try await engine.getStatus(at: directory.path)
        let statusV2 = try await engine.getStatusV2(at: directory.path)
        check(status.staged.contains { $0.path == special[0] && $0.status == .modified && $0.additions == 1 }, "F03 MM staged side and stats")
        check(status.unstaged.contains { $0.path == special[0] && $0.status == .modified && $0.additions == 1 }, "F03 MM working side and stats")
        check(status.staged.contains { $0.path == "added.txt" && $0.status == .added }, "F03 AM staged addition")
        check(status.unstaged.contains { $0.path == "added.txt" && $0.status == .modified }, "F03 AM unstaged modification")
        check(status.staged.contains { $0.path == "renamed\n -> new.txt" && $0.oldPath == "literal -> name.txt" && $0.status == .renamed }, "F03 RM preserves destination and oldPath")
        check(status.unstaged.contains { $0.path == "renamed\n -> new.txt" && $0.status == .modified && $0.additions == 1 }, "F03 RM retains worktree state")
        check(normalized(status) == normalized(statusV2), "F03 both status entry points agree including stats")

        // A tracked file changing from regular file to symlink is T, not M.
        try FileManager.default.removeItem(at: directory.appendingPathComponent("-option.txt"))
        try FileManager.default.createSymbolicLink(atPath: directory.appendingPathComponent("-option.txt").path, withDestinationPath: "added.txt")
        check(try await engine.getStatusV2(at: directory.path).unstaged.contains { $0.path == "-option.txt" && $0.status == .typeChanged }, "F03 preserves type-change status")

        // Construct a genuine merge conflict using only this isolated repo.
        try await engine.stageAll(at: directory.path)
        _ = try await git(["commit", "--quiet", "-m", "Fixture worktree states"])
        _ = try await git(["checkout", "--quiet", "-b", "side"])
        try write("added.txt", "side\n")
        try await engine.stage(files: ["added.txt"], at: directory.path)
        _ = try await git(["commit", "--quiet", "-m", "Fixture side"])
        _ = try await git(["checkout", "--quiet", "main"])
        try write("added.txt", "main\n")
        try await engine.stage(files: ["added.txt"], at: directory.path)
        _ = try await git(["commit", "--quiet", "-m", "Fixture main"])
        let merge = await shell.execute("git", arguments: ["merge", "side"], workingDirectory: directory.path)
        check(!merge.isSuccess, "F08 fixture creates a real merge conflict")
        let conflict = try await engine.getStatus(at: directory.path)
        check(conflict.hasConflicts && conflict.isDirty && conflict.hasChanges, "F08 conflict is dirty and requires resolution")
        check(conflict.conflicted.contains { $0.path == "added.txt" }, "F08 preserves conflicted filename")
        _ = try await git(["merge", "--abort"])
        do {
            _ = try await engine.getStatus(at: directory.appendingPathComponent("missing").path)
            check(false, "status process failure throws rather than reporting a clean repo")
        } catch { check(true, "status process failure throws rather than reporting a clean repo") }
        print("\(failures) Git integration failures")
        if failures != 0 { exit(1) }
        print("GIT INTEGRATION PASSED")
    }
}
