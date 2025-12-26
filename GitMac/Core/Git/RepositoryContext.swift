import Foundation
import Combine
import os.signpost

// MARK: - Performance Logging

private let perfLog = OSLog(subsystem: "com.gitmac", category: "performance")

// MARK: - Repository Snapshot

/// Immutable snapshot of repository state at a point in time
struct RepositorySnapshot: Sendable {
    let path: String
    let head: Reference?
    let status: RepositoryStatus
    let branches: [Branch]
    let remoteBranches: [Branch]
    let tags: [Tag]
    let remotes: [Remote]
    let stashes: [Stash]
    let timestamp: Date

    init(
        path: String,
        head: Reference? = nil,
        status: RepositoryStatus = RepositoryStatus(),
        branches: [Branch] = [],
        remoteBranches: [Branch] = [],
        tags: [Tag] = [],
        remotes: [Remote] = [],
        stashes: [Stash] = [],
        timestamp: Date = Date()
    ) {
        self.path = path
        self.head = head
        self.status = status
        self.branches = branches
        self.remoteBranches = remoteBranches
        self.tags = tags
        self.remotes = remotes
        self.stashes = stashes
        self.timestamp = timestamp
    }
}

/// Lightweight refs snapshot for incremental updates
struct RepositoryRefs: Sendable {
    let head: Reference?
    let branches: [Branch]
    let remoteBranches: [Branch]
    let tags: [Tag]
    let timestamp: Date
}

// Note: RepositoryChangeSignal is defined in FileWatcher.swift

// MARK: - Repository Context Actor

/// Per-repository context that encapsulates all Git operations, caching, and file watching.
/// Each open repository gets its own isolated context to prevent state mixing.
actor RepositoryContext {
    // MARK: - Properties

    let path: String
    private let engine: GitEngine
    nonisolated(unsafe) private var watcher: GitRepositoryWatcher?

    // Bounded caches with TTL (scoped to this repository)
    private var branchesCache = CacheWithTTL<[Branch]>(ttl: 30)
    private var remoteBranchesCache = CacheWithTTL<[Branch]>(ttl: 60)
    private var tagsCache = CacheWithTTL<[Tag]>(ttl: 120)
    private var remotesCache = CacheWithTTL<[Remote]>(ttl: 300)
    private var stashesCache = CacheWithTTL<[Stash]>(ttl: 30)
    private var statusCache = CacheWithTTL<RepositoryStatus>(ttl: 5)
    private var headCache = CacheWithTTL<Reference>(ttl: 10)

    // Commits cache (paginated)
    private var commitsCache: [Int: [Commit]] = [:]  // page -> commits
    private var commitsTimestamp: Date?
    private let commitsCacheTTL: TimeInterval = 60

    // Coalescing for concurrent refresh requests
    private var pendingRefresh: Task<RepositorySnapshot, Error>?
    private var pendingStatusRefresh: Task<RepositoryStatus, Error>?

    // Change stream for UI subscriptions
    private var changesContinuation: AsyncStream<RepositoryChangeSignal>.Continuation?
    private(set) var changesStream: AsyncStream<RepositoryChangeSignal>?

    // Task for listening to watcher signals
    private var watcherTask: Task<Void, Never>?

    // MARK: - Initialization

    init(path: String) {
        self.path = path
        self.engine = GitEngine()
    }

    /// Setup the changes stream (must be called after init due to actor isolation)
    func setupChangesStream() {
        var continuation: AsyncStream<RepositoryChangeSignal>.Continuation?
        changesStream = AsyncStream { cont in
            continuation = cont
        }
        changesContinuation = continuation
    }

    deinit {
        watcherTask?.cancel()
        watcher?.stopAll()
        changesContinuation?.finish()
    }

    // MARK: - Lifecycle

    /// Start watching for file system changes
    func startWatching() {
        guard watcher == nil else { return }

        watcher = GitRepositoryWatcher(repositoryPath: path)
        watcher?.startAll()

        // Connect watcher signals to changesContinuation and handle cache invalidation
        watcherTask = Task { [weak self, weak watcher] in
            guard let watcher = watcher, let self = self else { return }

            for await signal in watcher.signalStream {
                await self.handleSignal(signal)
            }
        }
    }

    /// Handle incoming change signal - invalidate caches and forward to stream
    private func handleSignal(_ signal: RepositoryChangeSignal) {
        // Invalidate appropriate caches based on signal type
        switch signal {
        case .status:
            // Working directory or index changed
            statusCache.invalidate()

        case .head:
            // HEAD changed (checkout, commit, merge, rebase)
            statusCache.invalidate()
            headCache.invalidate()
            commitsCache.removeAll()
            commitsTimestamp = nil

        case .refs:
            // Branches or tags changed
            branchesCache.invalidate()
            remoteBranchesCache.invalidate()
            tagsCache.invalidate()

        case .stash:
            // Stash list changed
            stashesCache.invalidate()

        case .config:
            // Git config changed - remotes may have changed
            remotesCache.invalidate()

        case .full:
            // Unknown change - invalidate everything
            invalidateAll()
        }

        // Forward signal to subscribers
        changesContinuation?.yield(signal)
    }

    /// Stop watching and cleanup
    func stopWatching() {
        watcherTask?.cancel()
        watcherTask = nil
        watcher?.stopAll()
        watcher = nil
    }

    // MARK: - Full Snapshot

    /// Get a complete repository snapshot, using caches when valid
    func snapshot() async throws -> RepositorySnapshot {
        os_signpost(.begin, log: perfLog, name: "snapshot")
        defer { os_signpost(.end, log: perfLog, name: "snapshot") }

        // Coalesce concurrent requests
        if let pending = pendingRefresh {
            return try await pending.value
        }

        let task = Task<RepositorySnapshot, Error> {
            // Parallel fetch of all components
            async let headResult = getHead()
            async let statusResult = getStatus()
            async let branchesResult = getBranches()
            async let remoteBranchesResult = getRemoteBranches()
            async let tagsResult = getTags()
            async let remotesResult = getRemotes()
            async let stashesResult = getStashes()

            return RepositorySnapshot(
                path: path,
                head: try? await headResult,
                status: (try? await statusResult) ?? RepositoryStatus(),
                branches: (try? await branchesResult) ?? [],
                remoteBranches: (try? await remoteBranchesResult) ?? [],
                tags: (try? await tagsResult) ?? [],
                remotes: (try? await remotesResult) ?? [],
                stashes: (try? await stashesResult) ?? [],
                timestamp: Date()
            )
        }

        pendingRefresh = task
        defer { pendingRefresh = nil }

        return try await task.value
    }

    // MARK: - Incremental Updates

    /// Refresh only status (fast path for file changes)
    func refreshStatus() async throws -> RepositoryStatus {
        if let pending = pendingStatusRefresh {
            return try await pending.value
        }

        let task = Task<RepositoryStatus, Error> {
            statusCache.invalidate()
            return try await getStatus()
        }

        pendingStatusRefresh = task
        defer { pendingStatusRefresh = nil }

        return try await task.value
    }

    /// Refresh only refs (branches, tags, head)
    func refreshRefs() async throws -> RepositoryRefs {
        branchesCache.invalidate()
        remoteBranchesCache.invalidate()
        tagsCache.invalidate()
        headCache.invalidate()

        async let head = getHead()
        async let branches = getBranches()
        async let remoteBranches = getRemoteBranches()
        async let tags = getTags()

        return RepositoryRefs(
            head: try? await head,
            branches: (try? await branches) ?? [],
            remoteBranches: (try? await remoteBranches) ?? [],
            tags: (try? await tags) ?? [],
            timestamp: Date()
        )
    }

    /// Refresh stashes only
    func refreshStashes() async throws -> [Stash] {
        stashesCache.invalidate()
        return try await getStashes()
    }

    /// Full cache invalidation
    func invalidateAll() {
        branchesCache.invalidate()
        remoteBranchesCache.invalidate()
        tagsCache.invalidate()
        remotesCache.invalidate()
        stashesCache.invalidate()
        statusCache.invalidate()
        headCache.invalidate()
        commitsCache.removeAll()
        commitsTimestamp = nil
    }

    // MARK: - Cached Getters

    func getHead() async throws -> Reference {
        if let cached = headCache.get() {
            return cached
        }

        let head = try await engine.getHead(at: path)
        headCache.set(head)
        return head
    }

    func getStatus() async throws -> RepositoryStatus {
        if let cached = statusCache.get() {
            return cached
        }

        os_signpost(.begin, log: perfLog, name: "git.status")
        let status = try await engine.getStatus(at: path)
        os_signpost(.end, log: perfLog, name: "git.status")

        statusCache.set(status)
        return status
    }

    func getBranches() async throws -> [Branch] {
        if let cached = branchesCache.get() {
            return cached
        }

        let branches = try await engine.getBranches(at: path)
        branchesCache.set(branches)
        return branches
    }

    func getRemoteBranches() async throws -> [Branch] {
        if let cached = remoteBranchesCache.get() {
            return cached
        }

        let branches = try await engine.getRemoteBranches(at: path)
        remoteBranchesCache.set(branches)
        return branches
    }

    func getTags() async throws -> [Tag] {
        if let cached = tagsCache.get() {
            return cached
        }

        let tags = try await engine.getTags(at: path)
        tagsCache.set(tags)
        return tags
    }

    func getRemotes() async throws -> [Remote] {
        if let cached = remotesCache.get() {
            return cached
        }

        let remotes = try await engine.getRemotes(at: path)
        remotesCache.set(remotes)
        return remotes
    }

    func getStashes() async throws -> [Stash] {
        if let cached = stashesCache.get() {
            return cached
        }

        let stashes = try await engine.getStashes(at: path)
        stashesCache.set(stashes)
        return stashes
    }

    // MARK: - Commits (Paginated)

    func getCommits(page: Int = 0, limit: Int = 100, branch: String? = nil) async throws -> [Commit] {
        // Check cache validity
        if let timestamp = commitsTimestamp,
           Date().timeIntervalSince(timestamp) < commitsCacheTTL,
           let cached = commitsCache[page] {
            return cached
        }

        os_signpost(.begin, log: perfLog, name: "git.commits", "page=%d", page)
        let commits = try await engine.getCommits(
            at: path,
            branch: branch,
            limit: limit,
            skip: page * limit
        )
        os_signpost(.end, log: perfLog, name: "git.commits")

        commitsCache[page] = commits
        if page == 0 {
            commitsTimestamp = Date()
        }

        return commits
    }

    /// Prepend new commits when HEAD changes (incremental update)
    func prependNewCommits(since oldHeadSHA: String) async throws -> [Commit] {
        // Get commits from current HEAD to old HEAD
        // This is an optimization for when we know only new commits were added
        let newCommits = try await engine.getCommits(at: path, limit: 50)

        guard let oldIndex = newCommits.firstIndex(where: { $0.sha == oldHeadSHA }) else {
            // Old HEAD not found in recent commits, need full refresh
            commitsCache.removeAll()
            commitsTimestamp = nil
            return try await getCommits()
        }

        let addedCommits = Array(newCommits.prefix(oldIndex))

        // Update cache by prepending
        if var page0 = commitsCache[0] {
            page0.insert(contentsOf: addedCommits, at: 0)
            // Trim to limit
            commitsCache[0] = Array(page0.prefix(100))
        }

        return addedCommits
    }

    // MARK: - Diff Streaming

    /// Stream diff hunks for a file (supports Large File Mode)
    func diffStream(
        for file: String,
        staged: Bool = false
    ) -> AsyncThrowingStream<DiffHunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    os_signpost(.begin, log: perfLog, name: "diff.stream", "%{public}s", file)

                    // For now, use existing getDiff and parse
                    // TODO: Replace with true streaming parser
                    let diffOutput = try await engine.getDiff(for: file, staged: staged, at: path)
                    let hunks = parseDiffOutput(diffOutput)

                    for hunk in hunks {
                        // Check for cancellation
                        try Task.checkCancellation()
                        continuation.yield(hunk)
                    }

                    os_signpost(.end, log: perfLog, name: "diff.stream")
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Mutating Operations

    func stage(files: [String]) async throws {
        try await engine.stage(files: files, at: path)
        statusCache.invalidate()
        changesContinuation?.yield(.status)
    }

    func stageAll() async throws {
        try await engine.stageAll(at: path)
        statusCache.invalidate()
        changesContinuation?.yield(.status)
    }

    func unstage(files: [String]) async throws {
        try await engine.unstage(files: files, at: path)
        statusCache.invalidate()
        changesContinuation?.yield(.status)
    }

    func discardChanges(files: [String]) async throws {
        try await engine.discardChanges(files: files, at: path)
        statusCache.invalidate()
        changesContinuation?.yield(.status)
    }

    func commit(message: String, amend: Bool = false) async throws -> Commit {
        let commit = try await engine.commit(message: message, amend: amend, at: path)

        // Invalidate relevant caches
        statusCache.invalidate()
        headCache.invalidate()
        commitsCache.removeAll()
        commitsTimestamp = nil

        changesContinuation?.yield(.head)
        return commit
    }

    func checkout(_ ref: String) async throws {
        try await engine.checkout(ref, at: path)

        // Full invalidation on checkout
        invalidateAll()
        changesContinuation?.yield(.head)
    }

    // MARK: - Private Helpers

    /// Basic diff parser - TODO: Replace with streaming state machine
    private func parseDiffOutput(_ output: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var currentLines: [DiffLine] = []
        var currentHeader = ""
        var oldStart = 0, oldLines = 0, newStart = 0, newLines = 0

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)

            if lineStr.hasPrefix("@@") {
                // Save previous hunk if any
                if !currentLines.isEmpty {
                    hunks.append(DiffHunk(
                        header: currentHeader,
                        oldStart: oldStart,
                        oldLines: oldLines,
                        newStart: newStart,
                        newLines: newLines,
                        lines: currentLines
                    ))
                    currentLines = []
                }

                // Parse hunk header: @@ -old,count +new,count @@
                currentHeader = lineStr
                let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: lineStr, range: NSRange(lineStr.startIndex..., in: lineStr)) {

                    oldStart = Int((lineStr as NSString).substring(with: match.range(at: 1))) ?? 0
                    oldLines = match.range(at: 2).location != NSNotFound
                        ? Int((lineStr as NSString).substring(with: match.range(at: 2))) ?? 1
                        : 1
                    newStart = Int((lineStr as NSString).substring(with: match.range(at: 3))) ?? 0
                    newLines = match.range(at: 4).location != NSNotFound
                        ? Int((lineStr as NSString).substring(with: match.range(at: 4))) ?? 1
                        : 1
                }

            } else if lineStr.hasPrefix("+") && !lineStr.hasPrefix("+++") {
                currentLines.append(DiffLine(
                    type: .addition,
                    content: String(lineStr.dropFirst()),
                    oldLineNumber: nil,
                    newLineNumber: newStart + currentLines.filter { $0.type != .deletion }.count
                ))

            } else if lineStr.hasPrefix("-") && !lineStr.hasPrefix("---") {
                currentLines.append(DiffLine(
                    type: .deletion,
                    content: String(lineStr.dropFirst()),
                    oldLineNumber: oldStart + currentLines.filter { $0.type != .addition }.count,
                    newLineNumber: nil
                ))

            } else if lineStr.hasPrefix(" ") || lineStr.isEmpty {
                let oldNum = oldStart + currentLines.filter { $0.type != .addition }.count
                let newNum = newStart + currentLines.filter { $0.type != .deletion }.count
                currentLines.append(DiffLine(
                    type: .context,
                    content: lineStr.isEmpty ? "" : String(lineStr.dropFirst()),
                    oldLineNumber: oldNum,
                    newLineNumber: newNum
                ))
            }
        }

        // Save last hunk
        if !currentLines.isEmpty {
            hunks.append(DiffHunk(
                header: currentHeader,
                oldStart: oldStart,
                oldLines: oldLines,
                newStart: newStart,
                newLines: newLines,
                lines: currentLines
            ))
        }

        return hunks
    }
}

// MARK: - Context Manager

/// Manages multiple repository contexts (one per open repo)
@MainActor
class RepositoryContextManager: ObservableObject {
    static let shared = RepositoryContextManager()

    @Published private(set) var contexts: [String: RepositoryContext] = [:]
    @Published var activeContextPath: String?

    var activeContext: RepositoryContext? {
        guard let path = activeContextPath else { return nil }
        return contexts[path]
    }

    private init() {}

    /// Get or create a context for a repository path
    func context(for path: String) async -> RepositoryContext {
        if let existing = contexts[path] {
            return existing
        }

        let context = RepositoryContext(path: path)
        await context.setupChangesStream()
        await context.startWatching()
        contexts[path] = context
        return context
    }

    /// Set the active repository
    func setActive(path: String) async {
        activeContextPath = path
        _ = await context(for: path)
    }

    /// Close a repository context
    func close(path: String) async {
        if let context = contexts[path] {
            await context.stopWatching()
            contexts.removeValue(forKey: path)
        }

        if activeContextPath == path {
            activeContextPath = contexts.keys.first
        }
    }

    /// Close all contexts
    func closeAll() async {
        for (_, context) in contexts {
            await context.stopWatching()
        }
        contexts.removeAll()
        activeContextPath = nil
    }
}
