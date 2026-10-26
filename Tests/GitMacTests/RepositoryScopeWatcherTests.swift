import Foundation
import Darwin
import Combine
import Testing
@testable import GitMac

@Suite(.serialized)
struct RepositoryScopeWatcherTests {
    @MainActor private func awaitEvent(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }

    @Test @MainActor func lateFileCreationAndAtomicReplacementRemainObservable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-rearm-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("late/refs/stash")
        let watcher = FileWatcher(path: file.path)
        var events = 0
        let observation = watcher.$lastChange.dropFirst().sink { _ in events += 1 }
        defer { watcher.stop(); observation.cancel() }
        watcher.start()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "initial\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(try await awaitEvent { events > 0 }, "File created after start must be observed")
        for index in 1...3 {
            let previous = events
            try "replacement \(index)\n".write(to: file, atomically: true, encoding: .utf8)
            #expect(try await awaitEvent { events > previous }, "Every atomic replacement must remain observable")
        }
        let beforeDelete = events
        try FileManager.default.removeItem(at: file)
        #expect(try await awaitEvent { events > beforeDelete }, "Deletion must be observed")
        let beforeRecreation = events
        try "recreated\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(try await awaitEvent { events > beforeRecreation }, "Recreation must rearm the file")
        watcher.stop()
        let stopped = events
        try "after stop\n".write(to: file, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(events == stopped, "Stopped watcher cannot emit queued changes")
    }

    @Test @MainActor func unrelatedSiblingCreationDoesNotSignalTheWatchedFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-sibling-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("HEAD")
        try "fixture\n".write(to: file, atomically: true, encoding: .utf8)
        let watcher = FileWatcher(path: file.path)
        var events = 0
        let observation = watcher.$lastChange.dropFirst().sink { _ in events += 1 }
        watcher.start()
        defer { watcher.stop(); observation.cancel() }
        try "unrelated\n".write(to: root.appendingPathComponent("neighbor"), atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(events == 0)
    }

    @Test @MainActor func burstReplacementConvergesToTheFinalInodeWithoutPolling() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-burst-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("index")
        try Data("initial\n".utf8).write(to: file)
        let watcher = FileWatcher(path: file.path)
        var events = 0
        let observation = watcher.$lastChange.dropFirst().sink { _ in events += 1 }
        watcher.start()
        defer { watcher.stop(); observation.cancel() }
        try await Task.detached {
            for index in 0..<80 { try Data("replacement \(index)\n".utf8).write(to: file, options: .atomic) }
        }.value
        let expected = try #require(try FileManager.default.attributesOfItem(atPath: file.path)[.systemFileNumber] as? NSNumber).uint64Value
        func targetsFinalFile() -> Bool {
            guard let fd = Mirror(reflecting: watcher).children.first(where: { $0.label == "fileDescriptor" })?.value as? Int32 else { return false }
            var status = stat()
            return fstat(fd, &status) == 0 && UInt64(status.st_ino) == expected
        }
        #expect(try await awaitEvent { targetsFinalFile() }, "Coalescing may merge signals but must follow the final inode")
        let previous = events
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("in-place\n".utf8))
        try handle.close()
        #expect(try await awaitEvent { events > previous }, "The final inode must still deliver writes")
    }

    @Test @MainActor func firstRealStashEmitsItsOwnSignal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-first-stash-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func git(_ args: [String]) async throws {
            let result = await ShellExecutor.shared.execute("git", arguments: args, workingDirectory: root.path)
            #expect(result.isSuccess, "\(args): \(result.stderr)")
        }
        try await git(["init", "--quiet"])
        let file = root.appendingPathComponent("file")
        try "initial\n".write(to: file, atomically: true, encoding: .utf8)
        try await git(["add", "--", "file"])
        try await git(["commit", "--quiet", "-m", "Fixture"])
        let watcher = GitRepositoryWatcher(repositoryPath: root.path, debounceInterval: 0.01)
        var sawStash = false
        let observation = watcher.$lastSignal.sink { if $0 == .stash { sawStash = true } }
        watcher.startAll()
        defer { watcher.stopAll(); observation.cancel() }
        try "changed\n".write(to: file, atomically: true, encoding: .utf8)
        try await git(["stash", "push", "--quiet", "-m", "First fixture stash"])
        #expect(try await awaitEvent { sawStash }, "The first stash must not require reopening the repository")
    }

    @Test @MainActor func actualGitWorktreesShareCommonIdentityButNotIndexOrHeadDirectory() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-scope-\(UUID())")
        let main = parent.appendingPathComponent("main ñ\nrepo")
        let linked = parent.appendingPathComponent("linked ñ\nworktree")
        try FileManager.default.createDirectory(at: main, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        func git(_ args: [String], at path: String) async throws -> String {
            let result = await ShellExecutor.shared.execute("git", arguments: args, workingDirectory: path)
            #expect(result.isSuccess, "\(args): \(result.stderr)")
            return result.stdout
        }
        _ = try await git(["init", "--quiet"], at: main.path)
        try "fixture\n".write(to: main.appendingPathComponent("file"), atomically: true, encoding: .utf8)
        _ = try await git(["add", "--", "file"], at: main.path)
        _ = try await git(["commit", "--quiet", "-m", "Fixture"], at: main.path)
        _ = try await git(["worktree", "add", "--quiet", "-b", "topic", "--", linked.path], at: main.path)
        let a = try RepositoryFileLocations(repositoryPath: main.path)
        let b = try RepositoryFileLocations(repositoryPath: linked.path)
        #expect(a.commonRepositoryID == b.commonRepositoryID)
        #expect(a.worktreeID != b.worktreeID)
        #expect(a.gitDirectory != b.gitDirectory)
        #expect(a.commonGitDirectory == b.commonGitDirectory)
        #expect(Repository(path: linked.path).gitDirectory == b.gitDirectory)
        let oracle = try await git(["rev-parse", "--absolute-git-dir"], at: linked.path)
        // Git preserves /private and Unicode spelling; Foundation may resolve
        // their filesystem aliases. Compare actual directory identity instead
        // of either stripping all whitespace or assuming byte-identical paths.
        #expect(oracle.hasSuffix("\n"))
        let oraclePath = String(oracle.dropLast())
        let oracleAttributes = try FileManager.default.attributesOfItem(atPath: oraclePath)
        let oracleDevice = try #require(oracleAttributes[.systemNumber] as? NSNumber)
        let oracleInode = try #require(oracleAttributes[.systemFileNumber] as? NSNumber)
        #expect(b.worktreeID == oracleDevice.stringValue + ":" + oracleInode.stringValue)
        let mainWatcher = GitRepositoryWatcher(repositoryPath: main.path, debounceInterval: 0.01)
        let linkedWatcher = GitRepositoryWatcher(repositoryPath: linked.path, debounceInterval: 0.01)
        var mainSignals: [RepositoryChangeSignal] = []
        var linkedSignals: [RepositoryChangeSignal] = []
        let mainObservation = mainWatcher.$lastSignal.sink { if let signal = $0 { mainSignals.append(signal) } }
        let linkedObservation = linkedWatcher.$lastSignal.sink { if let signal = $0 { linkedSignals.append(signal) } }
        mainWatcher.startAll(); linkedWatcher.startAll()
        defer {
            mainWatcher.stopAll(); linkedWatcher.stopAll()
            mainObservation.cancel(); linkedObservation.cancel()
        }
        try "ref: refs/heads/topic\n".write(to: b.gitDirectory.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        #expect(try await awaitEvent { linkedSignals.contains(.head) })
        #expect(!mainSignals.contains(.head), "Linked worktree HEAD cannot invalidate another HEAD")
        let config = a.commonGitDirectory.appendingPathComponent("config")
        let configuration = try String(contentsOf: config, encoding: .utf8)
        try (configuration + "\n# fixture update\n").write(to: config, atomically: true, encoding: .utf8)
        #expect(try await awaitEvent { mainSignals.contains(.config) && linkedSignals.contains(.config) },
                "Both worktrees must observe common config after atomic replacement")
        let alias = parent.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: linked)
        #expect(try RepositoryFileLocations(repositoryPath: alias.path).worktreeID == b.worktreeID)
        let bare = parent.appendingPathComponent("bare")
        _ = try await git(["init", "--bare", "--quiet", bare.path], at: main.path)
        let bareScope = try RepositoryFileLocations(repositoryPath: bare.path)
        #expect(bareScope.gitDirectory == bareScope.commonGitDirectory)
    }

    @Test func malformedAndOversizeGitPointersFailClosed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-pointer-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let marker = root.appendingPathComponent(".git")
        for input in ["broken", "gitdir: \0bad\n", String(repeating: "x", count: 16385)] {
            try input.write(to: marker, atomically: true, encoding: .utf8)
            #expect(throws: (any Error).self) { try RepositoryFileLocations(repositoryPath: root.path) }
        }
    }

    @Test @MainActor func cancelHandlerClosesOnlyItsOwnDescriptorAcrossRestartAndDeinit() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-fd-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("file")
        try "fixture".write(to: file, atomically: true, encoding: .utf8)
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        let inode = try #require(attributes[.systemFileNumber] as? NSNumber).uint64Value
        func descriptor(_ watcher: FileWatcher) throws -> Int32 {
            try #require(Mirror(reflecting: watcher).children.first { $0.label == "fileDescriptor" }?.value as? Int32)
        }
        func ownsFixture(_ fd: Int32) -> Bool {
            var info = stat()
            return fstat(fd, &info) == 0 && UInt64(info.st_ino) == inode
        }
        var watcher: FileWatcher? = FileWatcher(path: file.path)
        watcher!.start()
        let old = try descriptor(watcher!)
        #expect(ownsFixture(old))
        watcher!.restart()
        let replacement = try descriptor(watcher!)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(ownsFixture(replacement), "Old cancel handler must not close the replacement fd")
        if old != replacement { #expect(!ownsFixture(old)) }
        weak var weakWatcher = watcher
        watcher = nil
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(weakWatcher == nil)
        #expect(!ownsFixture(replacement), "Cancellation must close the fd even when its owner is gone")
        // Negative-control cleanup: only descriptors still pointing to our fixture.
        if ownsFixture(old) { close(old) }
        if replacement != old && ownsFixture(replacement) { close(replacement) }
    }

    @Test @MainActor func initialPublishedDatesAreNotRepositoryChanges() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-initial-watch-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let initResult = await ShellExecutor.shared.execute("git", arguments: ["init", "--quiet"], workingDirectory: root.path)
        #expect(initResult.isSuccess)
        let watcher = GitRepositoryWatcher(repositoryPath: root.path, debounceInterval: 0.01)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(watcher.lastSignal == nil)
        watcher.stopAll()
        NotificationCenter.default.post(name: .appDidBecomeActiveAgain, object: nil)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(watcher.lastSignal == nil, "Permanently stopped watchers must not resume on app activation")
    }
}
