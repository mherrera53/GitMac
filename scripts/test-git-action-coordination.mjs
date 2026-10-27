import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-action-coordination-'));
try {
 const source = await fs.readFile(path.join(root, 'GitMac/Core/Git/GitOperationHandler.swift'), 'utf8');
 let executor = source.split('    // MARK: - Remote Operations')[0] + '\n}\n';
 if (process.argv.includes('--overlap-control')) executor = executor.replace('!Self.activeRepositoryPaths.contains(operationKey)', 'true');
 if (!executor.includes('allowsRetry')) throw Error('Action executor boundary changed');
 await fs.writeFile(path.join(temporary, 'Executor.swift'), executor);
 await fs.writeFile(path.join(temporary, 'Checks.swift'), String.raw`import Foundation
import SwiftUI
struct FixtureRepository { var path: String }
@MainActor final class AppState {
    var currentRepository: FixtureRepository? = .init(path: "/fixture/original")
    var errorMessage: String?
    var refreshes = 0
    func refresh() async { refreshes += 1 }
}
struct PushConfirmation {}
struct TrackingInfo {
    func recordSuccess() {}
    func recordFailure(_ error: Error) {}
}
@MainActor final class NotificationManager {
    static let shared = NotificationManager()
    var recovery: (() -> Void)?
    var errors = 0
    var infoMessages: [String] = []
    func recordAction(_ name: String, retry: (() async -> Void)?) {}
    func info(_ message: String, detail: String? = nil) { infoMessages.append(message) }
    func success(_ message: String, detail: String?) {}
    func error(_ message: String, detail: String?) { errors += 1; recovery = nil }
    func errorWithFix(_ message: String, detail: String?, fixTitle: String, fixHint: String, fixAction: @escaping () -> Void) { errors += 1; recovery = fixAction }
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
    print("GIT_ACTION_COORDINATION_CHECKS: \(checks) checks, \(failures) failures")
    if failures != 0 { exit(1) }
 }
}
`);
 const binary = path.join(temporary, 'checks');
 execFileSync('xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', path.join(temporary, 'Executor.swift'), path.join(temporary, 'Checks.swift'), '-o', binary], { stdio: 'inherit', timeout: 120000 });
 execFileSync(binary, { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
