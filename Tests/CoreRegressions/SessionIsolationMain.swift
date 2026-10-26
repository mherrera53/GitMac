import Foundation
import Observation
import Combine
import SwiftUI

// Only engine I/O and unrelated app services are fixtures. The entire AppState
// class is extracted unchanged below, including Observation and session storage.
@MainActor final class GitService {
    struct Pending {
        let path: String
        let continuation: CheckedContinuation<Repository, Error>
    }
    var pending: [Pending] = []
    var currentRepository: Repository?
    var activations: [String?] = []
    func readRepository(at path: String) async throws -> Repository {
        try await withCheckedThrowingContinuation { pending.append(.init(path: path, continuation: $0)) }
    }
    func openRepository(at path: String) async throws -> Repository {
        let repo = try await readRepository(at: path)
        currentRepository = repo
        return repo
    }
    func cloneRepository(from url: String, to path: String) async throws -> Repository { try await readRepository(at: path) }
    func activateRepository(_ repo: Repository?) { currentRepository = repo; activations.append(repo?.path) }
    func finish(_ index: Int, name: String = "snapshot") {
        let item = pending[index]
        item.continuation.resume(returning: Repository(path: item.path, name: name))
    }
    func fail(_ index: Int) { pending[index].continuation.resume(throwing: FixtureError.failed) }
    enum FixtureError: Error { case failed }
}
@MainActor final class BranchStateManager: ObservableObject {
    var refreshes = 0
    var currentBranch: Branch?
    var localBranches: [Branch] = []
    var remoteBranches: [Branch] = []
    var configuredPaths: [String] = []
    func configure(repoPath: String) async { configuredPaths.append(repoPath) }
    func refresh() async { refreshes += 1 }
}
@MainActor final class RepositoryTab {
    let id = UUID()
    var repository: Repository
    var selectedCommit: Commit?
    var selectedBranch: Branch?
    var selectedStash: Stash?
    let branchManager = BranchStateManager()
    init(repository: Repository) { self.repository = repository }
    func configureBranchManager() async { await branchManager.configure(repoPath: repository.path) }
}
final class GitHubService {}
final class AIService {}
enum Logger { static func debug(_ message: String) {} }
@MainActor final class RecentRepositoriesManager {
    static let shared = RecentRepositoriesManager()
    func addRecent(path: String, name: String) {}
}
actor GlobalDiffCache {
    static let shared = GlobalDiffCache()
    func clear() {}
}
actor AvatarService {
    static let shared = AvatarService()
    func clearInMemoryCaches() {}
}
extension Notification.Name { static let repositoryDidRefresh = Notification.Name("fixture-repository-refresh") }

// PRODUCTION_APP_STATE

@main struct SessionIsolationMain {
    @MainActor static func main() async throws {
        var failures = 0
        func check(_ value: Bool, _ label: String) {
            print("\(value ? "PASS" : "FAIL") \(label)")
            if !value { failures += 1 }
        }
        func ready(_ state: AppState, _ count: Int) async throws {
            for _ in 0..<1000 {
                if state.gitService.pending.count == count { return }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            throw GitService.FixtureError.failed
        }
        let suite = "com.gitmac.session-fixture.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        func state() -> (AppState, RepositoryTab, RepositoryTab) {
            let value = AppState(sessionPreferences: preferences)
            let a = RepositoryTab(repository: Repository(path: "/fixture/a", name: "A"))
            let b = RepositoryTab(repository: Repository(path: "/fixture/b", name: "B"))
            value.openTabs = [a, b]; value.activeTabId = a.id
            return (value, a, b)
        }
        let (cross, a, b) = state()
        let refreshA = Task { await cross.refresh() }
        try await ready(cross, 1)
        cross.selectTab(b.id)
        cross.gitService.finish(0, name: "A-new")
        await refreshA.value
        check(b.repository.path == "/fixture/b" && b.repository.name == "B", "late A snapshot cannot overwrite B")
        check(a.repository.name == "A-new" && a.branchManager.refreshes == 1 && b.branchManager.refreshes == 0,
              "inactive refresh updates only its original tab and branch manager")
        check(cross.gitService.currentRepository?.path == "/fixture/b", "inactive read cannot retarget active service/watcher")

        let (ordered, target, _) = state()
        let old = Task { await ordered.refresh() }; try await ready(ordered, 1)
        let latest = Task { await ordered.refresh() }; try await ready(ordered, 2)
        ordered.gitService.finish(1, name: "newest"); await latest.value
        ordered.gitService.finish(0, name: "stale"); await old.value
        check(target.repository.name == "newest", "older refresh of the same tab cannot win")

        let (closed, closing, remaining) = state()
        let abandoned = Task { await closed.refresh() }; try await ready(closed, 1)
        closed.closeTab(closing.id)
        closed.gitService.finish(0, name: "must-not-publish"); await abandoned.value
        check(closed.activeTabId == remaining.id && remaining.repository.name == "B" && closing.branchManager.refreshes == 0,
              "closed tab invalidates its late response")

        let (opening, _, _) = state()
        let openA = Task { await opening.openRepository(at: "/fixture/new-a") }; try await ready(opening, 1)
        let openB = Task { await opening.openRepository(at: "/fixture/new-b") }; try await ready(opening, 2)
        opening.gitService.finish(1); await openB.value
        opening.gitService.finish(0); await openA.value
        check(opening.currentRepository?.path == "/fixture/new-b" && !opening.openTabs.contains { $0.repository.path == "/fixture/new-a" },
              "latest requested open wins without resurrecting a stale tab")
        check(!opening.isLoading, "only current open owns loading completion")

        let (errors, _, active) = state()
        let failedA = Task { await errors.refresh() }; try await ready(errors, 1)
        errors.selectTab(active.id); errors.gitService.fail(0); await failedA.value
        check(errors.errorMessage == nil, "inactive failure cannot overwrite active-tab error state")

        let (history, hA, hB) = state()
        history.selectTab(hB.id); history.closeTab(hA.id)
        check(history.backStack.isEmpty && history.forwardStack.isEmpty, "closing a tab removes dead navigation destinations")
        history.selectTab(UUID())
        check(history.activeTabId == hB.id, "unknown tab identifier cannot blank the current window")
        history.closeTab(hB.id)
        check(preferences.string(forKey: "activeRepositoryPath") == nil && preferences.stringArray(forKey: "openRepositoryPaths") == [],
              "last-tab closure clears stale session identity in isolated preferences")
        let isolated = AppState(sessionPreferences: preferences)
        preferences.set([NSTemporaryDirectory()], forKey: "openRepositoryPaths")
        await isolated.restoreSession(arguments: ["GitMac", "-demo-mode", "true"])
        check(isolated.gitService.pending.isEmpty && isolated.openTabs.isEmpty && isolated.errorMessage != nil,
              "invalid fixture mode fails closed without restoring the user session")
        let validFixture = AppState(sessionPreferences: preferences)
        let fixturePath = NSTemporaryDirectory()
        let restoring = Task {
            await validFixture.restoreSession(arguments: ["GitMac", "--performance-fixture", fixturePath])
        }
        try await ready(validFixture, 1)
        validFixture.gitService.finish(0)
        await restoring.value
        check(validFixture.openTabs.count == 1
              && validFixture.openTabs.first?.repository.path == fixturePath
              && validFixture.openTabs.first?.branchManager.configuredPaths == [fixturePath],
              "private fixture configures its own branch manager without restoring other repositories")
        print("SESSION_CHECKS: \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
