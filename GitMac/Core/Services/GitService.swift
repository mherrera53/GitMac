import Foundation
import Combine
import os.signpost

private let serviceLog = OSLog(subsystem: "com.gitmac", category: "service")

/// High-level Git service for the application
/// Acts as an orchestrator for repository contexts and provides a unified API
@MainActor
class GitService: ObservableObject {
    @Published var currentRepository: Repository?
    @Published var isLoading = false
    @Published var error: Error?

    private let engine = GitEngine()
    private var repositoryWatcher: GitRepositoryWatcher?
    private var cancellables = Set<AnyCancellable>()

    // Reference to context manager for multi-repo support
    private let contextManager = RepositoryContextManager.shared

    // Cache with TTL - prevents unbounded memory growth (WWDC 2018 - iOS Memory Deep Dive)
    private var branchesCache = CacheWithTTL<[Branch]>(ttl: 30)      // 30s for branches
    private var remoteBranchesCache = CacheWithTTL<[Branch]>(ttl: 60) // 60s for remote branches
    private var tagsCache = CacheWithTTL<[Tag]>(ttl: 120)            // 2min for tags (change rarely)
    private var remotesCache = CacheWithTTL<[Remote]>(ttl: 300)      // 5min for remotes (very stable)
    private var stashesCache = CacheWithTTL<[Stash]>(ttl: 30)        // 30s for stashes

    // Use V2 optimized methods flag
    private var useOptimizedMethods = true

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
        invalidateCache()

        // Notify views to refresh
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
    }

    // MARK: - Branch Operations

    func getBranches() async throws -> [Branch] {
        if let cached = branchesCache.get() { return cached }
        guard let path = currentRepository?.path else { return [] }
        let branches = try await engine.getBranches(at: path)
        branchesCache.set(branches)
        return branches
    }

    func getRemoteBranches() async throws -> [Branch] {
        if let cached = remoteBranchesCache.get() { return cached }
        guard let path = currentRepository?.path else { return [] }
        let branches = try await engine.getRemoteBranches(at: path)
        remoteBranchesCache.set(branches)
        return branches
    }

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

    func checkoutForce(_ ref: String) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        try await engine.checkoutForce(ref, at: path)
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

    /// Discard a staged file completely (unstage + discard changes)
    func discardStagedFile(path filePath: String) async throws {
        guard let repoPath = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        // Step 1: Unstage the file
        try await engine.unstage(files: [filePath], at: repoPath)
        // Step 2: Discard the changes
        try await engine.discardChanges(files: [filePath], at: repoPath)
        try await refreshStatus()
    }

    /// Discard multiple staged files completely (unstage + discard changes)
    func discardStagedFiles(paths: [String]) async throws {
        guard let repoPath = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        try await engine.unstage(files: paths, at: repoPath)
        try await engine.discardChanges(files: paths, at: repoPath)
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

        // Auto-detect if branch needs --set-upstream
        let currentBranchName = currentRepository?.currentBranch?.name
        let trackingBranch = currentRepository?.currentBranch?.trackingBranch
        let needsUpstream = setUpstream || trackingBranch == nil || trackingBranch?.isEmpty == true

        var options = PushOptions()
        options.force = force
        options.setUpstream = needsUpstream
        if needsUpstream {
            options.branch = currentBranchName
        }

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

    // MARK: - Reset Operations

    func reset(to commitSHA: String, mode: ResetMode) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        let modeFlag = switch mode {
        case .soft: "--soft"
        case .mixed: "--mixed"
        case .hard: "--hard"
        }

        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["reset", modeFlag, commitSHA],
            workingDirectory: path
        )

        if result.exitCode != 0 {
            throw GitError.commandFailed("git reset", result.stderr)
        }

        try await refresh()
    }

    // MARK: - Revert Operations

    func revert(commitSHAs: [String], noCommit: Bool = false) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        var args = ["revert"]
        if noCommit {
            args.append("--no-commit")
        }
        
        args.append(contentsOf: commitSHAs)

        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: args,
            workingDirectory: path
        )

        if result.exitCode != 0 {
            throw GitError.commandFailed("git revert", result.stderr)
        }

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

    private func invalidateCache() {
        branchesCache.invalidate()
        remoteBranchesCache.invalidate()
        tagsCache.invalidate()
        remotesCache.invalidate()
        stashesCache.invalidate()
    }

    private func refreshStatus() async throws {
        guard var repo = currentRepository else { return }

        let status = try await engine.getStatus(at: repo.path)
        repo.status = status
        currentRepository = repo // Must reassign to trigger @Published notification

        // Invalidate cache on status change (as branches might have changed)
        // Ideally we only invalidate specific parts, but for safety:
        invalidateCache()

        // Notify views (CommitGraphView, etc.) to refresh
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: repo.path)
    }

    private func setupWatcher(for path: String) {
        repositoryWatcher?.stopAll()
        cancellables.removeAll()

        repositoryWatcher = GitRepositoryWatcher(repositoryPath: path)

        // Subscribe to differentiated change signals for incremental updates
        repositoryWatcher?.$lastSignal
            .compactMap { $0 }
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] signal in
                Task { @MainActor in
                    await self?.handleChangeSignal(signal)
                    self?.repositoryWatcher?.acknowledgeChanges()
                }
            }
            .store(in: &cancellables)

        repositoryWatcher?.startAll()
    }

    /// Handle differentiated change signals for incremental updates
    private func handleChangeSignal(_ signal: RepositoryChangeSignal) async {
        let signpostID = OSSignpostID(log: serviceLog)
        os_signpost(.begin, log: serviceLog, name: "handle.signal", signpostID: signpostID,
                    "signal=%{public}s", signal.rawValue)
        defer { os_signpost(.end, log: serviceLog, name: "handle.signal", signpostID: signpostID) }

        switch signal {
        case .status:
            // Only refresh status - fast path
            try? await refreshStatusOnly()

        case .head:
            // HEAD changed - refresh status and potentially commits
            try? await refreshStatus()

        case .refs:
            // Branches/tags changed - invalidate ref caches and refresh
            branchesCache.invalidate()
            remoteBranchesCache.invalidate()
            tagsCache.invalidate()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: currentRepository?.path)

        case .stash:
            // Only stashes changed
            stashesCache.invalidate()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: currentRepository?.path)

        case .config:
            // Config changed - may need to refresh remotes
            remotesCache.invalidate()

        case .full:
            // Unknown change - do full refresh
            try? await refresh()
        }
    }

    /// Refresh only status without invalidating all caches
    private func refreshStatusOnly() async throws {
        guard var repo = currentRepository else { return }

        let signpostID = OSSignpostID(log: serviceLog)
        os_signpost(.begin, log: serviceLog, name: "refresh.status", signpostID: signpostID)
        defer { os_signpost(.end, log: serviceLog, name: "refresh.status", signpostID: signpostID) }

        // Use V2 optimized status if enabled
        let status: RepositoryStatus
        if useOptimizedMethods {
            status = try await engine.getStatusV2(at: repo.path)
        } else {
            status = try await engine.getStatus(at: repo.path)
        }

        repo.status = status
        currentRepository = repo

        NotificationCenter.default.post(name: .repositoryDidRefresh, object: repo.path)
    }

    // MARK: - Line-Level Operations (Modern)

    private let patchManipulator = PatchManipulator()

    /// Stage a single line from an unstaged diff
    func stageLine(filePath: String, hunk: DiffHunk, lineIndex: Int) async throws {
        guard let repo = currentRepository else {
            throw GitServiceError.noRepository
        }

        try await patchManipulator.stageLine(
            filePath: filePath,
            hunk: hunk,
            lineIndex: lineIndex,
            repoPath: repo.path
        )

        // Refresh status after staging
        try await refreshStatus()
    }

    /// Discard a single line from an unstaged diff
    func discardLine(filePath: String, hunk: DiffHunk, lineIndex: Int) async throws {
        guard let repo = currentRepository else {
            throw GitServiceError.noRepository
        }

        try await patchManipulator.discardLine(
            filePath: filePath,
            hunk: hunk,
            lineIndex: lineIndex,
            repoPath: repo.path
        )

        // Refresh status after discarding
        try await refreshStatus()
    }

    /// Unstage a single line from a staged diff
    func unstageLine(filePath: String, hunk: DiffHunk, lineIndex: Int) async throws {
        guard let repo = currentRepository else {
            throw GitServiceError.noRepository
        }

        try await patchManipulator.unstageLine(
            filePath: filePath,
            hunk: hunk,
            lineIndex: lineIndex,
            repoPath: repo.path
        )

        // Refresh status after unstaging
        try await refreshStatus()
    }

    // MARK: - Hunk-Level Operations

    /// Stage an entire hunk from an unstaged diff
    func stageHunk(filePath: String, hunk: DiffHunk) async throws {
        guard let repo = currentRepository else {
            throw GitServiceError.noRepository
        }

        try await patchManipulator.stageHunk(
            filePath: filePath,
            hunk: hunk,
            repoPath: repo.path
        )

        try await refreshStatus()
    }

    /// Discard an entire hunk from an unstaged diff
    func discardHunk(filePath: String, hunk: DiffHunk) async throws {
        guard let repo = currentRepository else {
            throw GitServiceError.noRepository
        }

        try await patchManipulator.discardHunk(
            filePath: filePath,
            hunk: hunk,
            repoPath: repo.path
        )

        try await refreshStatus()
    }

    /// Unstage an entire hunk from a staged diff
    func unstageHunk(filePath: String, hunk: DiffHunk) async throws {
        guard let repo = currentRepository else {
            throw GitServiceError.noRepository
        }

        try await patchManipulator.unstageHunk(
            filePath: filePath,
            hunk: hunk,
            repoPath: repo.path
        )

        try await refreshStatus()
    }

    // MARK: - V2 Optimized Methods

    /// Get commits using V2 optimized method (NUL-separated parsing)
    func getCommitsV2(branch: String? = nil, limit: Int = 100, skip: Int = 0) async throws -> [Commit] {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        return try await engine.getCommitsV2(at: path, branch: branch, limit: limit, skip: skip)
    }

    /// Get branches using V2 optimized method (for-each-ref with NUL separators)
    func getBranchesV2() async throws -> [Branch] {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        return try await engine.getBranchesV2(at: path)
    }

    /// Get commit files using V2 optimized method (unified parsing)
    func getCommitFilesV2(sha: String) async throws -> [CommitFile] {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }

        return try await engine.getCommitFilesV2(sha: sha, at: path)
    }

    /// Stream diff for large files with backpressure support
    func getDiffStream(for file: String? = nil, staged: Bool = false) -> AsyncThrowingStream<String, Error>? {
        guard let path = currentRepository?.path else {
            return nil
        }

        return engine.getDiffStreaming(for: file, staged: staged, at: path)
    }

    /// Get current active context (for multi-repo support)
    func getActiveContext() async -> RepositoryContext? {
        guard let path = currentRepository?.path else { return nil }
        return await contextManager.context(for: path)
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
