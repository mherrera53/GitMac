import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-action-coordination-'));
try {
 const source = await fs.readFile(path.join(root, 'GitMac/Core/Git/GitOperationHandler.swift'), 'utf8');
 let executor = source.slice(0, source.indexOf('    func handlePush(')) + '\n}\n';
 const remote = await fs.readFile(path.join(root, 'GitMac/Core/Git/Remote.swift'), 'utf8');
 const engine = await fs.readFile(path.join(root, 'GitMac/Core/Git/GitEngine.swift'), 'utf8');
 const recoveryTypes = engine.slice(engine.indexOf('enum PullRecovery {')) + remote.slice(remote.indexOf('struct AutoStashResult:'));
 executor += recoveryTypes;
 if (process.argv.includes('--overlap-control')) executor = executor.replace('!Self.activeRepositoryPaths.contains(operationKey)', 'true');
 if (!executor.includes('allowsRetry')) throw Error('Action executor boundary changed');
 await fs.writeFile(path.join(temporary, 'Executor.swift'), executor);
 await fs.writeFile(path.join(temporary, 'Checks.swift'), String.raw`import Foundation
import SwiftUI
struct FixtureBranch { var name = "main" }
struct FixtureRepository { var path: String; var currentBranch: FixtureBranch? = .init() }
enum GitServiceError: Error { case noRepository }
enum GitError: Error { case pullFailed(String) }
extension Notification.Name { static let showStashes = Notification.Name("fixture.showStashes") }
@MainActor final class FixtureGitService {
    var pulls = 0, recoveries = 0
    var failure: Error? = GitError.pullFailed("Your local changes would be overwritten by merge")
    var conflict = false
    func fetch() async throws {}
    func pull(rebase: Bool) async throws { pulls += 1; if let failure { throw failure } }
    func pullWithAutoStash(rebase: Bool) async throws -> AutoStashResult {
        recoveries += 1
        return .init(hadLocalChanges: true, didStash: true, stashApplied: !conflict, stashConflict: conflict, backupSHA: String(repeating: "a", count: 40))
    }
}
@MainActor final class AppState {
    var currentRepository: FixtureRepository? = .init(path: "/fixture/original")
    let gitService = FixtureGitService()
    var errorMessage: String?
    var refreshes = 0
    func refresh() async { refreshes += 1 }
}
struct PushConfirmation {}
struct TrackingInfo {
    static func fetch(remote: String) -> TrackingInfo { .init() }
    static func pull(branch: String, remote: String) -> TrackingInfo { .init() }
    func recordSuccess() {}
    func recordFailure(_ error: Error) {}
}
@MainActor final class NotificationManager {
    static let shared = NotificationManager()
    var recovery: (() -> Void)?
    var errors = 0
    var recoveryTitle: String?
    var successes: [String] = []
    var infoMessages: [String] = []
    func recordAction(_ name: String, retry: (() async -> Void)?) {}
    func info(_ message: String, detail: String? = nil) { infoMessages.append(message) }
    func success(_ message: String, detail: String?) { successes.append(message) }
    func error(_ message: String, detail: String?) { errors += 1; recovery = nil }
    func errorWithFix(_ message: String, detail: String?, fixTitle: String, fixHint: String, fixAction: @escaping () -> Void) { errors += 1; recovery = fixAction; recoveryTitle = fixTitle }
}
actor Gate {
    var waiter: CheckedContinuation<Void, Never>?
    var pending: Bool { waiter != nil }
    func wait() async { await withCheckedContinuation { waiter = $0 } }
    func release() { let current = waiter; waiter = nil; current?.resume() }
}
@main struct Checks {
 @MainActor static func main() async throws {
    var checks = 0, failures = 0
    func check(_ condition: Bool, _ label: String) { checks += 1; if !condition { failures += 1; print("FAIL " + label) } }
    func settle() async { try? await Task.sleep(nanoseconds: 10_000_000) }
    let appState = AppState()
    let first = GitOperationHandler(appState: appState), second = GitOperationHandler(appState: appState)
    let gate = Gate()
    let running = Task { await first.execute(operation: { await gate.wait() }, message: "Working...") }
    for _ in 0..<10000 { if await gate.pending { break }; await Task.yield() }
    check(await gate.pending && first.isOperationInProgress, "operation marks progress before suspension")
    var duplicateRan = false
    await second.execute(operation: { duplicateRan = true }, message: "Duplicate...")
    check(!duplicateRan, "separate shortcut handlers cannot overlap operations on the same repository")
    await gate.release(); await running.value
    check(!first.isOperationInProgress, "completion releases progress")
    await second.execute(operation: { duplicateRan = true }, message: "Next...")
    check(duplicateRan, "next action can run after completion")
    await first.execute(operation: { throw CocoaError(.fileWriteUnknown) }, message: "Mutating action...")
    check(NotificationManager.shared.recovery == nil, "mutating errors do not offer blind automatic replay")
    check(!first.isOperationInProgress && appState.errorMessage != nil, "failure releases progress and exposes the error")
    var attempts = 0
    await first.execute(operation: { attempts += 1; if attempts == 1 { throw CocoaError(.fileReadUnknown) } }, message: "Fetching...", allowsRetry: true)
    let retry = NotificationManager.shared.recovery
    check(retry != nil, "explicitly retryable read-only failure provides recovery")
    appState.currentRepository = .init(path: "/fixture/other")
    retry?(); await settle()
    check(attempts == 1 && NotificationManager.shared.infoMessages.last == "Repository changed", "retry cannot execute in a different repository")
    appState.currentRepository = .init(path: "/fixture/original")
    retry?(); await settle()
    check(attempts == 2 && !first.isOperationInProgress, "retry can succeed in the original repository")
    let late = Gate()
    var successCallback = false
    let before = appState.refreshes
    let completing = Task { await first.execute(operation: { await late.wait() }, message: "Original repository...", onSuccess: { successCallback = true }) }
    for _ in 0..<10000 { if await late.pending { break }; await Task.yield() }
    appState.currentRepository = .init(path: "/fixture/another")
    await late.release(); await completing.value
    check(!successCallback && appState.refreshes == before, "late completion does not update the newly selected repository")
    let errorsBefore = NotificationManager.shared.errors
    await first.execute(operation: { throw CancellationError() }, message: "Cancelled action...")
    check(!first.isOperationInProgress && NotificationManager.shared.errors == errorsBefore, "cancellation releases state without offering a misleading retry")
    appState.currentRepository = .init(path: "/fixture/original")
    appState.errorMessage = nil
    await first.handlePull()
    let saveAndPull = NotificationManager.shared.recovery
    check(saveAndPull != nil && NotificationManager.shared.recoveryTitle == "Save changes and Pull", "overlapping work offers explicit recovery")
    check(appState.gitService.recoveries == 0 && appState.errorMessage == nil, "rejected pull does not stash silently or show a duplicate raw error")
    appState.currentRepository?.currentBranch = .init(name: "another")
    saveAndPull?(); await settle()
    check(appState.gitService.recoveries == 0, "stale recovery cannot run on another branch")
    appState.currentRepository = .init(path: "/fixture/other")
    saveAndPull?(); await settle()
    check(appState.gitService.recoveries == 0, "stale recovery cannot run in another repository")
    appState.currentRepository = .init(path: "/fixture/original")
    saveAndPull?(); await settle()
    check(appState.gitService.recoveries == 1 && NotificationManager.shared.successes.last == "Pull completed", "explicit recovery uses preserving service and reports its result")
    appState.gitService.failure = GitError.pullFailed("Could not resolve host")
    await first.handlePull()
    check(NotificationManager.shared.recovery == nil, "network failure does not offer stashing")
    appState.gitService.conflict = true
    let successCount = NotificationManager.shared.successes.count
    await first.handlePull(preservingLocalChanges: true)
    check(NotificationManager.shared.successes.count == successCount && NotificationManager.shared.recoveryTitle == "Open saved backup", "restore conflict offers saved backup without a success toast")
    print("GIT_ACTION_COORDINATION_CHECKS: \(checks) checks, \(failures) failures")
    if failures != 0 { exit(1) }
 }
}
`);
 const binary = path.join(temporary, 'checks');
 execFileSync('xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', path.join(temporary, 'Executor.swift'), path.join(temporary, 'Checks.swift'), '-o', binary], { stdio: 'inherit', timeout: 120000 });
 execFileSync(binary, { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
