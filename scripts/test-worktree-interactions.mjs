import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-interaction-checks-'));
try {
  const manager = await fs.readFile(path.join(root, 'GitMac/Core/Services/WorktreeManager.swift'), 'utf8');
  const input = await fs.readFile(path.join(root, 'GitMac/Features/Terminal/Views/TerminalInputBar.swift'), 'utf8');
  const insertion = input.slice(input.indexOf('    private func insertCommand('), input.indexOf('    /// Clear caches to free memory')).replace('private func insertCommand', 'func insertCommand');
  if (!insertion.includes('clearSuggestions()')) throw Error('Terminal draft boundary changed');
  const panel = await fs.readFile(path.join(root, 'GitMac/Features/BottomPanel/Views/BottomPanelContent.swift'), 'utf8');
  const boundary = '.onChange(of: appState.currentRepository?.path) { _, newPath in';
  const repositoryChange = panel.split(boundary)[1]?.split('\n        }')[0];
  if (!repositoryChange?.includes('terminalContextPath')) throw Error('Repository-change boundary changed');
  await fs.writeFile(path.join(temporary, 'Manager.swift'), manager);
  await fs.copyFile(path.join(root, 'GitMac/Core/Git/Worktree.swift'), path.join(temporary, 'Worktree.swift'));
  await fs.writeFile(path.join(temporary, 'Checks.swift'), String.raw`import Foundation
import SwiftUI

// Deterministic suspension of the process boundary; production coordinator code is unchanged.
// Real Git semantics are covered separately by test-production-suites.mjs.
actor FixtureOperations {
    static let shared = FixtureOperations()
    var calls = 0
    var waiter: CheckedContinuation<Worktree, Error>?
    var pending: Bool { waiter != nil }
    func add(_ path: String) async throws -> Worktree {
        calls += 1
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }
    func finish(failure: Bool) {
        let current = waiter; waiter = nil
        if failure { current?.resume(throwing: CocoaError(.fileWriteUnknown)) }
        else { current?.resume(returning: Worktree(path: "/fixture/new", branch: "task", commitSHA: "abc")) }
    }
}
actor GitEngine {
    func listWorktrees(at path: String) async throws -> [Worktree] { [Worktree(path: path, branch: "main", commitSHA: "abc", isMain: true)] }
    func addWorktree(path: String, branch: String?, newBranch: String?, force: Bool, detach: Bool, at: String) async throws -> Worktree { try await FixtureOperations.shared.add(path) }
    struct Status { let hasChanges = false }
    func getStatus(at: String) async throws -> Status { Status() }
    func removeWorktree(path: String, force: Bool, at: String) async throws {}
    func lockWorktree(path: String, reason: String?, at: String) async throws {}
    func unlockWorktree(path: String, at: String) async throws {}
    func pruneWorktrees(dryRun: Bool, at: String) async throws -> [String] { [] }
}
enum GitError: Error { case worktreeRemoveFailed(String, String) }
@MainActor final class NotificationManager {
    static let shared = NotificationManager()
    func success(_ message: String, detail: String?) {}
    func error(_ message: String, detail: String?) {}
}
extension Notification.Name {
    static let repositoryDidRefresh = Notification.Name("fixture.repositoryDidRefresh")
    static let worktreeDidChange = Notification.Name("fixture.worktreeDidChange")
}
@MainActor final class DraftInput {
    var text = ""
    struct Focus { var wrappedValue = false }
    var isFocused = Focus()
    var cleared = 0
    var terminalContextPath: String? = "/fixture/original"
    var terminalError: String?
    var injectedChanges = 0
    func clearSuggestions() { cleared += 1 }
    func changeRepositoryDirectory(_ path: String?) { injectedChanges += 1; terminalContextPath = path }
INSERTION
    func repositoryChanged(_ newPath: String?) {
REPOSITORY_CHANGE
    }
}
@main struct Checks {
 @MainActor static func main() async throws {
    var checks = 0, failures = 0
    func check(_ condition: Bool, _ label: String) { checks += 1; if !condition { failures += 1; print("FAIL " + label) } }
    let manager = WorktreeManager.shared
    await manager.refresh(at: "/fixture/main")
    let first = Task { try await manager.addWorktree(path: "/fixture/new", newBranch: "task") }
    for _ in 0..<10000 { if await FixtureOperations.shared.pending { break }; await Task.yield() }
    check(await FixtureOperations.shared.pending, "first worktree operation reaches its suspended process boundary")
    check(manager.isPerformingOperation, "operation is marked busy before awaiting Git")
    await manager.refresh(at: "/fixture/main")
    check(manager.isPerformingOperation && !manager.isLoading, "refresh cannot clear an in-flight mutation's busy state")
    do { _ = try await manager.addWorktree(path: "/fixture/duplicate"); check(false, "duplicate mutation rejected") }
    catch WorktreeError.busy { check(true, "duplicate mutation rejected") }
    do { try await manager.lockWorktree(Worktree(path: "/fixture/new", commitSHA: "abc")); check(false, "lock cannot overlap creation") }
    catch WorktreeError.busy { check(true, "lock cannot overlap creation") }
    check(await FixtureOperations.shared.calls == 1, "duplicate clicks never reach the process boundary")
    await FixtureOperations.shared.finish(failure: false)
    _ = try await first.value
    check(!manager.isPerformingOperation, "successful mutation releases the guard")
    let failed = Task { try await manager.addWorktree(path: "/fixture/failure") }
    for _ in 0..<10000 { if await FixtureOperations.shared.pending { break }; await Task.yield() }
    await FixtureOperations.shared.finish(failure: true)
    do { _ = try await failed.value; check(false, "process failure surfaces") }
    catch { check(true, "process failure surfaces") }
    check(!manager.isPerformingOperation && manager.error != nil, "failed mutation releases the guard and exposes recovery information")
    let draft = DraftInput()
    draft.insertCommand("git status --short --branch")
    check(draft.text == "git status --short --branch" && draft.isFocused.wrappedValue && draft.cleared == 1, "insert puts a reviewable command into an empty focused editor")
    draft.text = "git commit -m 'my unfinished message'"
    draft.insertCommand("git diff")
    check(draft.text == "git commit -m 'my unfinished message'" && draft.cleared == 1, "insert never overwrites a command draft")
    draft.repositoryChanged("/fixture/another")
    check(draft.injectedChanges == 0 && draft.terminalContextPath == "/fixture/original" && draft.terminalError != nil, "repository switch preserves the shell instead of injecting cd into a running job")
    draft.repositoryChanged("/fixture/original")
    check(draft.terminalError == nil, "returning to the terminal's repository clears the change notice")
    print("WORKTREE_AND_TERMINAL_INTERACTION_CHECKS: \(checks) checks, \(failures) failures")
    if failures != 0 { exit(1) }
 }
}
`.replace('INSERTION', insertion).replace('REPOSITORY_CHANGE', repositoryChange));
  const binary = path.join(temporary, 'checks');
  execFileSync('xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', ...['Manager.swift', 'Worktree.swift', 'Checks.swift'].map(file => path.join(temporary, file)), '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
