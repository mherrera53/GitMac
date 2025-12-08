import Foundation
import Combine

/// High-level Git service for the application
@MainActor
class GitService: ObservableObject {
    @Published var currentRepository: Repository?
    @Published var isLoading = false
    @Published var error: Error?

    private let engine = GitEngine()
    private var repositoryWatcher: GitRepositoryWatcher?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Repository Operations

    /// Open a repository
    func openRepository(at path: String) async throws -> Repository {
        isLoading = true
        defer { isLoading = false }

        let repo = try await engine.openRepository(at: path)
        currentRepository = repo

        // Setup file watcher
        setupWatcher(for: path)

        return repo
    }

    /// Clone a repository
    func cloneRepository(from url: String, to path: String) async throws -> Repository {
        isLoading = true
        defer { isLoading = false }

        let repo = try await engine.cloneRepository(from: url, to: path)
        currentRepository = repo

        setupWatcher(for: path)

        return repo
    }

    /// Initialize a new repository
    func initRepository(at path: String) async throws -> Repository {
        isLoading = true
        defer { isLoading = false }

        let repo = try await engine.initRepository(at: path)
        currentRepository = repo

        setupWatcher(for: path)

        return repo
    }

    /// Refresh the current repository
    func refresh() async throws {
        guard let path = currentRepository?.path else { return }

        isLoading = true
        defer { isLoading = false }

        currentRepository = try await engine.openRepository(at: path)
    }

    // MARK: - Branch Operations

    func createBranch(named name: String, from startPoint: String = "HEAD", checkout: Bool = false) async throws -> Branch {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        let branch = try await engine.createBranch(named: name, from: startPoint, checkout: checkout, at: path)

        if checkout {
            try await refresh()
        }

        return branch
    }

    func deleteBranch(named name: String, force: Bool = false) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.deleteBranch(named: name, force: force, at: path)
        try await refresh()
    }

    func checkout(_ ref: String) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        try await engine.checkout(ref, at: path)
        try await refresh()
    }

    // MARK: - Staging Operations

    func stage(files: [String]) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.stage(files: files, at: path)
        try await refreshStatus()
    }

    func stageAll() async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.stageAll(at: path)
        try await refreshStatus()
    }

    func unstage(files: [String]) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.unstage(files: files, at: path)
        try await refreshStatus()
    }

    func discardChanges(files: [String]) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.discardChanges(files: files, at: path)
        try await refreshStatus()
    }

    // MARK: - Commit Operations

    func commit(message: String, amend: Bool = false) async throws -> Commit {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        let commit = try await engine.commit(message: message, amend: amend, at: path)
        try await refresh()
        return commit
    }

    func getCommits(branch: String? = nil, limit: Int = 100, skip: Int = 0) async throws -> [Commit] {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        return try await engine.getCommits(at: path, branch: branch, limit: limit, skip: skip)
    }

    // MARK: - Remote Operations

    func fetch(remote: String? = nil, prune: Bool = true) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        var options = FetchOptions()
        options.remote = remote
        options.prune = prune

        try await engine.fetch(options: options, at: path)
        try await refresh()
    }

    func pull(rebase: Bool = false) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        var options = PullOptions()
        options.rebase = rebase

        try await engine.pull(options: options, at: path)
        try await refresh()
    }

    /// Pull with automatic stash and re-apply
    /// - Parameters:
    ///   - rebase: Whether to rebase instead of merge
    /// - Returns: Result indicating if stash was needed and if it was successfully re-applied
    func pullWithAutoStash(rebase: Bool = false) async throws -> AutoStashResult {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        // Check for local changes
        let status = try await engine.getStatus(at: path)
        let hasLocalChanges = !status.staged.isEmpty || !status.unstaged.isEmpty

        var didStash = false
        var stashMessage = ""

        // Stash if there are local changes
        if hasLocalChanges {
            stashMessage = "GitMac auto-stash before pull at \(Date().formatted())"
            var stashOptions = StashOptions()
            stashOptions.message = stashMessage
            stashOptions.includeUntracked = true

            if let _ = try await engine.stash(options: stashOptions, at: path) {
                didStash = true
            }
        }

        // Perform pull
        var pullOptions = PullOptions()
        pullOptions.rebase = rebase

        do {
            try await engine.pull(options: pullOptions, at: path)
        } catch {
            // If pull fails and we stashed, try to restore
            if didStash {
                try? await engine.stashPop(at: path)
            }
            throw error
        }

        // Try to re-apply stash if we made one
        var stashApplied = false
        var stashConflict = false

        if didStash {
            do {
                try await engine.stashPop(at: path)
                stashApplied = true
            } catch {
                // Stash couldn't be applied cleanly (conflicts)
                stashConflict = true
            }
        }

        try await refresh()

        return AutoStashResult(
            hadLocalChanges: hasLocalChanges,
            didStash: didStash,
            stashApplied: stashApplied,
            stashConflict: stashConflict
        )
    }

    func push(force: Bool = false, setUpstream: Bool = false) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        var options = PushOptions()
        options.force = force
        options.setUpstream = setUpstream

        try await engine.push(options: options, at: path)
        try await refresh()
    }

    // MARK: - Stash Operations

    func stash(message: String? = nil, includeUntracked: Bool = true) async throws -> Stash? {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        var options = StashOptions()
        options.message = message
        options.includeUntracked = includeUntracked

        let stash = try await engine.stash(options: options, at: path)
        try await refresh()
        return stash
    }

    func stashPop(index: Int = 0) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.stashPop(stashRef: "stash@{\(index)}", at: path)
        try await refresh()
    }

    func stashApply(index: Int = 0) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        var options = StashApplyOptions()
        options.stashRef = "stash@{\(index)}"

        try await engine.stashApply(options: options, at: path)
        try await refresh()
    }

    func stashDrop(index: Int) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.stashDrop(stashRef: "stash@{\(index)}", at: path)
        try await refresh()
    }

    // MARK: - Tag Operations

    func createTag(name: String, message: String? = nil, ref: String = "HEAD") async throws -> Tag {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        var options = TagOptions(name: name)
        options.message = message
        options.targetRef = ref

        let tag = try await engine.createTag(options: options, at: path)
        try await refresh()
        return tag
    }

    func deleteTag(named name: String) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.deleteTag(named: name, at: path)
        try await refresh()
    }

    // MARK: - Merge Operations

    func merge(branch: String, noFastForward: Bool = false, squash: Bool = false) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        var options = MergeOptions()
        options.noFastForward = noFastForward
        options.squash = squash

        try await engine.merge(branch: branch, options: options, at: path)
        try await refresh()
    }

    func mergeAbort() async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.mergeAbort(at: path)
        try await refresh()
    }

    // MARK: - Rebase Operations

    func rebase(onto branch: String) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        try await engine.rebase(onto: branch, at: path)
        try await refresh()
    }

    func rebaseContinue() async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.rebaseContinue(at: path)
        try await refresh()
    }

    func rebaseAbort() async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.rebaseAbort(at: path)
        try await refresh()
    }

    // MARK: - Diff Operations

    func getDiff(for file: String? = nil, staged: Bool = false) async throws -> String {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        return try await engine.getDiff(for: file, staged: staged, at: path)
    }

    func getDiff(from baseBranch: String, to headBranch: String) async throws -> String {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        return try await engine.getDiff(from: baseBranch, to: headBranch, at: path)
    }

    func getCommits(branch: String, limit: Int = 50) async throws -> [Commit] {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        return try await engine.getCommits(at: path, branch: branch, limit: limit)
    }

    // MARK: - Private Helpers

    private func refreshStatus() async throws {
        guard let path = currentRepository?.path else { return }

        let status = try await engine.getStatus(at: path)
        currentRepository?.status = status
    }

    private func setupWatcher(for path: String) {
        repositoryWatcher?.stopAll()
        repositoryWatcher = GitRepositoryWatcher(repositoryPath: path)

        repositoryWatcher?.$hasChanges
            .filter { $0 }
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    try? await self?.refreshStatus()
                    self?.repositoryWatcher?.acknowledgeChanges()
                }
            }
            .store(in: &cancellables)

        repositoryWatcher?.startAll()
    }
}

// MARK: - Errors

enum GitServiceError: LocalizedError {
    case noRepository

    var errorDescription: String? {
        switch self {
        case .noRepository:
            return "No repository is currently open"
        }
    }
}

// MARK: - Auto Stash Result

/// Result of a pull operation with auto-stash
struct AutoStashResult {
    /// Whether there were local changes before pull
    let hadLocalChanges: Bool

    /// Whether changes were stashed
    let didStash: Bool

    /// Whether the stash was successfully re-applied after pull
    let stashApplied: Bool

    /// Whether there was a conflict when trying to re-apply stash
    let stashConflict: Bool

    /// User-friendly message describing what happened
    var message: String {
        if !hadLocalChanges {
            return "Pull completed successfully"
        }

        if !didStash {
            return "Pull completed (no changes to stash)"
        }

        if stashApplied {
            return "Pull completed. Your local changes have been re-applied."
        }

        if stashConflict {
            return "Pull completed but your local changes could not be re-applied due to conflicts. Your changes are saved in the stash list."
        }

        return "Pull completed"
    }

    /// Whether the operation was fully successful (no conflicts)
    var isFullySuccessful: Bool {
        return !stashConflict
    }
}
