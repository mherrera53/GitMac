# Proposed Performance Changes

Este documento contiene los cambios propuestos para mejorar el rendimiento de GitMac según el análisis en `PLATFORM_PERFORMANCE.md`.

---

## 1. ShellExecutor Improvements

### Cambios en Environment

```swift
// En ShellExecutor.init()
init() {
    var env = ProcessInfo.processInfo.environment

    // ... existing PATH setup ...

    // Disable Git pager for non-interactive use
    env["GIT_PAGER"] = ""
    env["PAGER"] = ""

    // Ensure UTF-8 output
    env["LANG"] = "en_US.UTF-8"
    env["LC_ALL"] = "en_US.UTF-8"

    // NEW: Performance and safety flags
    env["GIT_OPTIONAL_LOCKS"] = "0"      // Avoid locks on read operations
    env["GIT_TERMINAL_PROMPT"] = "0"     // Never prompt for credentials (avoid hangs)

    self.defaultEnvironment = env
}
```

### Timeout por Tipo de Comando

```swift
/// Command-specific timeout configuration
enum GitCommandTimeout {
    case status         // 5 seconds
    case log            // 30 seconds
    case diff           // 60 seconds (or streaming)
    case fetch          // 5 minutes
    case pull           // 10 minutes
    case push           // 10 minutes
    case clone          // 30 minutes

    var seconds: TimeInterval {
        switch self {
        case .status: return 5
        case .log: return 30
        case .diff: return 60
        case .fetch: return 300
        case .pull: return 600
        case .push: return 600
        case .clone: return 1800
        }
    }
}
```

### AsyncThrowingStream para Streaming

```swift
/// Execute a command with backpressure-aware streaming output
func executeStreaming(
    _ command: String,
    arguments: [String] = [],
    workingDirectory: String? = nil,
    bufferSize: Int = 10
) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(bufferSize)) { continuation in
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice  // or separate stream
        process.environment = defaultEnvironment

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let string = String(data: data, encoding: .utf8) {
                // Split by lines and yield each
                for line in string.split(separator: "\n", omittingEmptySubsequences: false) {
                    continuation.yield(String(line))
                }
            }
        }

        process.terminationHandler = { process in
            pipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus == 0 {
                continuation.finish()
            } else {
                continuation.finish(throwing: ShellError.nonZeroExit(process.terminationStatus))
            }
        }

        do {
            try process.run()

            continuation.onTermination = { @Sendable _ in
                if process.isRunning {
                    process.terminate()
                }
            }
        } catch {
            continuation.finish(throwing: error)
        }
    }
}
```

---

## 2. GitEngine Changes

### getStatus with Porcelain v2

```swift
/// Get repository status using porcelain v2 format
/// More robust with NUL separators and includes branch tracking info
func getStatusV2(at path: String) async throws -> RepositoryStatus {
    let result = await shellExecutor.execute(
        "git",
        arguments: [
            "status",
            "--porcelain=v2",
            "-b",           // Include branch info
            "-z",           // NUL-separated
            "-uall"         // Show all untracked files
        ],
        workingDirectory: path
    )

    guard result.exitCode == 0 else {
        throw GitError.commandFailed("git status", result.stderr)
    }

    return parseStatusV2(result.stdout)
}

private func parseStatusV2(_ output: String) -> RepositoryStatus {
    var status = RepositoryStatus()

    // Split by NUL character
    let entries = output.split(separator: "\0", omittingEmptySubsequences: false)

    for entry in entries {
        let line = String(entry)
        guard !line.isEmpty else { continue }

        // Branch header: # branch.oid <sha>
        if line.hasPrefix("# branch.") {
            // Parse branch tracking info
            continue
        }

        // Changed entries: 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
        if line.hasPrefix("1 ") || line.hasPrefix("2 ") {
            let parts = line.split(separator: " ", maxSplits: 8)
            guard parts.count >= 9 else { continue }

            let xy = String(parts[1])
            let indexStatus = xy.first!
            let worktreeStatus = xy.last!
            let filePath = String(parts[8])

            // Index (staged) changes
            if indexStatus != "." {
                if let statusType = statusTypeFromChar(indexStatus) {
                    status.staged.append(FileStatus(path: filePath, status: statusType))
                }
            }

            // Worktree (unstaged) changes
            if worktreeStatus != "." {
                if let statusType = statusTypeFromChar(worktreeStatus) {
                    status.unstaged.append(FileStatus(path: filePath, status: statusType))
                }
            }
            continue
        }

        // Untracked: ? <path>
        if line.hasPrefix("? ") {
            let filePath = String(line.dropFirst(2))
            status.untracked.append(filePath)
            continue
        }

        // Unmerged (conflict): u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>
        if line.hasPrefix("u ") {
            let parts = line.split(separator: " ", maxSplits: 10)
            if parts.count >= 11 {
                let filePath = String(parts[10])
                status.conflicted.append(FileStatus(path: filePath, status: .unmerged))
            }
        }
    }

    return status
}

private func statusTypeFromChar(_ char: Character) -> FileStatusType? {
    switch char {
    case "M": return .modified
    case "A": return .added
    case "D": return .deleted
    case "R": return .renamed
    case "C": return .copied
    case "U": return .unmerged
    default: return nil
    }
}
```

### getCommits with NUL Separator

```swift
/// Get commits with NUL-separated format to handle messages with pipes
func getCommitsV2(
    at path: String,
    branch: String? = nil,
    limit: Int = 100,
    skip: Int = 0
) async throws -> [Commit] {
    // Use %x00 as field separator (NUL byte)
    var args = [
        "log",
        "--format=%H%x00%P%x00%an%x00%ae%x00%ai%x00%cn%x00%ce%x00%ci%x00%s%x00%b%x00",
        "--topo-order",     // Topological ordering for graph
        "-n", String(limit),
        "--skip", String(skip)
    ]

    if let branch = branch {
        args.append(branch)
    }

    let result = await shellExecutor.execute("git", arguments: args, workingDirectory: path)

    guard result.exitCode == 0 else {
        throw GitError.commandFailed("git log", result.stderr)
    }

    return parseCommitsNUL(result.stdout)
}

private func parseCommitsNUL(_ output: String) -> [Commit] {
    var commits: [Commit] = []

    // Each commit record ends with an extra NUL (from %x00 after %b)
    // Split by double-NUL or parse field by field
    let fields = output.split(separator: "\0", omittingEmptySubsequences: false)

    var i = 0
    while i + 9 < fields.count {
        let sha = String(fields[i])
        let parentSHAs = String(fields[i + 1]).split(separator: " ").map(String.init)
        let authorName = String(fields[i + 2])
        let authorEmail = String(fields[i + 3])
        let authorDateStr = String(fields[i + 4])
        let committerName = String(fields[i + 5])
        let committerEmail = String(fields[i + 6])
        let committerDateStr = String(fields[i + 7])
        let subject = String(fields[i + 8])
        let body = String(fields[i + 9])

        guard !sha.isEmpty else {
            i += 10
            continue
        }

        let authorDate = parseGitDate(authorDateStr) ?? Date()
        let committerDate = parseGitDate(committerDateStr) ?? Date()

        let message = body.isEmpty ? subject : "\(subject)\n\n\(body)"

        commits.append(Commit(
            sha: sha,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            author: authorName,
            authorEmail: authorEmail,
            authorDate: authorDate,
            committer: committerName,
            committerEmail: committerEmail,
            committerDate: committerDate,
            parentSHAs: parentSHAs
        ))

        i += 10
    }

    return commits
}
```

### getDiff Streaming

```swift
/// Stream diff output for large files
func getDiffStreaming(
    for file: String? = nil,
    staged: Bool = false,
    at path: String
) -> AsyncThrowingStream<String, Error> {
    var args = ["diff", "--no-color", "--no-ext-diff"]

    if staged {
        args.append("--cached")
    }

    if let file = file {
        args.append("--")
        args.append(file)
    }

    return shellExecutor.executeStreaming(
        "git",
        arguments: args,
        workingDirectory: path,
        bufferSize: 50  // Buffer 50 lines before applying backpressure
    )
}
```

### getCommitFiles Unified

```swift
/// Get files changed in a commit with a single command
func getCommitFilesUnified(sha: String, at path: String) async throws -> [CommitFile] {
    // Combine name-status and numstat in one call using -z for robustness
    let result = await shellExecutor.execute(
        "git",
        arguments: [
            "diff-tree",
            "--no-commit-id",
            "-r",
            "-z",                    // NUL separator
            "--numstat",
            "--name-status",
            "--format=",
            sha
        ],
        workingDirectory: path
    )

    guard result.exitCode == 0 else {
        throw GitError.commandFailed("git diff-tree", result.stderr)
    }

    // Alternative: Use two separate calls but parse efficiently
    async let statusTask = shellExecutor.execute(
        "git",
        arguments: ["diff-tree", "--no-commit-id", "-r", "-z", "--name-status", sha],
        workingDirectory: path
    )
    async let numstatTask = shellExecutor.execute(
        "git",
        arguments: ["diff-tree", "--no-commit-id", "-r", "-z", "--numstat", sha],
        workingDirectory: path
    )

    let statusResult = await statusTask
    let numstatResult = await numstatTask

    // Parse numstat into dictionary
    var fileStats: [String: (Int, Int)] = [:]
    let numstatFields = numstatResult.stdout.split(separator: "\0")
    var j = 0
    while j + 2 < numstatFields.count {
        let additions = Int(numstatFields[j]) ?? 0
        let deletions = Int(numstatFields[j + 1]) ?? 0
        let filePath = String(numstatFields[j + 2])
        fileStats[filePath] = (additions, deletions)
        j += 3
    }

    // Parse name-status
    var files: [CommitFile] = []
    let statusFields = statusResult.stdout.split(separator: "\0")
    var i = 0
    while i + 1 < statusFields.count {
        let statusChar = String(statusFields[i])
        let filePath = String(statusFields[i + 1])

        let status: CommitFile.CommitFileStatus
        switch statusChar.first {
        case "A": status = .added
        case "M": status = .modified
        case "D": status = .deleted
        case "R": status = .renamed
        default: status = .modified
        }

        let stats = fileStats[filePath] ?? (0, 0)
        files.append(CommitFile(
            path: filePath,
            status: status,
            additions: stats.0,
            deletions: stats.1
        ))

        i += 2
    }

    return files
}
```

---

## 3. GitService as Orchestrator

### Updated GitService

```swift
/// High-level Git service that orchestrates repository contexts
@MainActor
class GitService: ObservableObject {
    @Published var activeContext: RepositoryContext?
    @Published var isLoading = false
    @Published var error: Error?

    private let contextManager = RepositoryContextManager.shared

    // MARK: - Repository Operations

    /// Open a repository (creates or reuses context)
    func openRepository(at path: String) async throws -> RepositorySnapshot {
        isLoading = true
        defer { isLoading = false }

        let context = await contextManager.context(for: path)
        await contextManager.setActive(path: path)
        activeContext = context

        return try await context.snapshot()
    }

    /// Get current repository snapshot
    func snapshot() async throws -> RepositorySnapshot {
        guard let context = activeContext else {
            throw GitServiceError.noRepository
        }
        return try await context.snapshot()
    }

    /// Refresh status only (fast path)
    func refreshStatus() async throws -> RepositoryStatus {
        guard let context = activeContext else {
            throw GitServiceError.noRepository
        }
        return try await context.refreshStatus()
    }

    // MARK: - Delegated Operations

    func stage(files: [String]) async throws {
        guard let context = activeContext else {
            throw GitServiceError.noRepository
        }
        try await context.stage(files: files)
    }

    func commit(message: String) async throws -> Commit {
        guard let context = activeContext else {
            throw GitServiceError.noRepository
        }
        return try await context.commit(message: message)
    }

    // ... delegate other operations to activeContext ...
}
```

---

## 4. GitRepositoryWatcher Improvements

### Differentiated Change Signals

```swift
/// Enhanced watcher that emits differentiated change signals
class GitRepositoryWatcher: ObservableObject {
    @Published var lastSignal: RepositoryChangeSignal?

    // Specific file watchers
    private var headWatcher: FileWatcher?      // .git/HEAD
    private var indexWatcher: FileWatcher?     // .git/index
    private var refsWatcher: FileWatcher?      // .git/refs/
    private var stashWatcher: FileWatcher?     // .git/logs/refs/stash
    private var configWatcher: FileWatcher?    // .git/config
    private var workingDirWatcher: RecursiveDirectoryWatcher?

    private var cancellables = Set<AnyCancellable>()
    private let repositoryPath: String

    init(repositoryPath: String) {
        self.repositoryPath = repositoryPath
        setupWatchers()
    }

    private func setupWatchers() {
        let gitDir = (repositoryPath as NSString).appendingPathComponent(".git")

        // HEAD changes → .head signal
        headWatcher = FileWatcher(path: (gitDir as NSString).appendingPathComponent("HEAD"))
        headWatcher?.$lastChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastSignal = .head
            }
            .store(in: &cancellables)

        // Index changes → .status signal
        indexWatcher = FileWatcher(path: (gitDir as NSString).appendingPathComponent("index"))
        indexWatcher?.$lastChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastSignal = .status
            }
            .store(in: &cancellables)

        // Refs changes → .refs signal
        // Note: Needs directory watching for refs/heads/, refs/tags/, refs/remotes/
        // FSEvents handles this via RecursiveDirectoryWatcher

        // Stash changes → .stash signal
        let stashLogPath = (gitDir as NSString).appendingPathComponent("logs/refs/stash")
        if FileManager.default.fileExists(atPath: stashLogPath) {
            stashWatcher = FileWatcher(path: stashLogPath)
            stashWatcher?.$lastChange
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    self?.lastSignal = .stash
                }
                .store(in: &cancellables)
        }

        // Working directory changes → .status signal
        workingDirWatcher = RecursiveDirectoryWatcher(
            paths: [repositoryPath],
            latency: 0.3,
            excludePaths: [".git", "node_modules", ".build", "DerivedData", "Pods", ".swiftpm"]
        ) { [weak self] in
            self?.lastSignal = .status
        }
    }

    func startAll() {
        headWatcher?.start()
        indexWatcher?.start()
        stashWatcher?.start()
        configWatcher?.start()
        workingDirWatcher?.start()
    }

    func stopAll() {
        headWatcher?.stop()
        indexWatcher?.stop()
        stashWatcher?.stop()
        configWatcher?.stop()
        workingDirWatcher?.stop()
    }
}
```

---

## 5. URLCache for GitHubService

```swift
actor GitHubService {
    private let baseURL = "https://api.github.com"
    private let keychainManager = KeychainManager.shared

    // Configured URLSession with caching
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default

        // Configure cache: 20MB RAM, 200MB disk
        let cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "com.gitmac.github-cache"
        )
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy

        // Reasonable timeouts
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300

        return URLSession(configuration: config)
    }()

    // Reusable decoder
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func request(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let token = await token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add ETag support for caching
        if method == "GET" {
            request.cachePolicy = .useProtocolCachePolicy
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 304:
            // Not Modified - return cached data
            if let cachedResponse = session.configuration.urlCache?.cachedResponse(for: request) {
                return cachedResponse.data
            }
            throw GitHubError.invalidResponse
        case 401:
            throw GitHubError.unauthorized
        case 403:
            // Check for rate limit
            if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
               remaining == "0" {
                let resetTime = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                throw GitHubError.rateLimited(resetTime: resetTime)
            }
            throw GitHubError.forbidden
        case 404:
            throw GitHubError.notFound
        case 422:
            throw GitHubError.validationFailed(parseError(data))
        case 429:
            // Too Many Requests - extract retry-after
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            throw GitHubError.rateLimited(resetTime: retryAfter)
        default:
            throw GitHubError.requestFailed(httpResponse.statusCode, parseError(data))
        }
    }
}

// Extended error enum
enum GitHubError: LocalizedError {
    // ... existing cases ...
    case rateLimited(resetTime: String?)

    var errorDescription: String? {
        switch self {
        // ... existing cases ...
        case .rateLimited(let resetTime):
            if let reset = resetTime {
                return "Rate limit exceeded. Resets at \(reset)"
            }
            return "Rate limit exceeded. Please wait before retrying."
        }
    }
}
```

---

## 6. AvatarService Throttled Persistence

```swift
actor AvatarService {
    // ... existing properties ...

    // Throttled persistence
    private var persistenceTask: Task<Void, Never>?
    private var needsPersistence = false
    private let persistenceDebounce: TimeInterval = 2.0  // 2 seconds

    private func schedulePersistence() {
        needsPersistence = true

        // Cancel any pending persistence
        persistenceTask?.cancel()

        persistenceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(persistenceDebounce * 1_000_000_000))

            guard !Task.isCancelled, needsPersistence else { return }

            saveCachedMappingsNow()
            needsPersistence = false
        }
    }

    private func saveCachedMappingsNow() {
        var urlStrings: [String: String] = [:]
        for (key, url) in avatarCache {
            urlStrings[key] = url.absoluteString
        }

        let mappings = AvatarCacheMappings(
            avatarURLs: urlStrings,
            githubUsernames: githubUsernameCache
        )

        if let data = try? JSONEncoder().encode(mappings) {
            try? data.write(to: mappingsFileURL, options: .atomic)
        }
    }

    // Update setAvatarURL to use throttled persistence
    private func setAvatarURL(_ url: URL, for key: String) {
        // ... existing LRU logic ...

        // Schedule throttled persistence instead of immediate write
        schedulePersistence()
    }
}
```

---

## Migration Path

### Phase 1: Infrastructure
1. Update `ShellExecutor` with new environment variables and streaming support
2. Add `RepositoryContext` (new file, no breaking changes)
3. Add `os_signpost` instrumentation

### Phase 2: GitEngine Improvements
1. Add `getStatusV2` alongside existing `getStatus`
2. Add `getCommitsV2` alongside existing `getCommits`
3. Add `getDiffStreaming` for large diffs
4. Gradually migrate callers

### Phase 3: GitService Transition
1. Update `GitService` to use `RepositoryContextManager`
2. Update views to use new context-aware APIs
3. Enable multi-tab support

### Phase 4: Polish
1. Update `GitRepositoryWatcher` with differentiated signals
2. Add `URLCache` to `GitHubService`
3. Add throttled persistence to `AvatarService`
