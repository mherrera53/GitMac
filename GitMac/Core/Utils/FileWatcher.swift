import Foundation
import Combine

/// Watches for file system changes in a directory
class FileWatcher: ObservableObject {
    @Published var lastChange: Date = Date()

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let path: String
    private var isWatching = false

    init(path: String) {
        self.path = path
    }

    deinit {
        stop()
    }

    /// Start watching for changes
    func start() {
        guard !isWatching else { return }

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("FileWatcher: Failed to open \(path)")
            return
        }

        let eventMask: DispatchSource.FileSystemEvent = [
            .write,
            .delete,
            .rename,
            .extend,
            .attrib,
            .link,
            .revoke
        ]

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: eventMask,
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            self?.handleChange()
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source?.resume()
        isWatching = true
    }

    /// Stop watching
    func stop() {
        source?.cancel()
        source = nil
        isWatching = false
    }

    /// Restart watching (useful after the watched directory changes)
    func restart() {
        stop()
        start()
    }

    private func handleChange() {
        lastChange = Date()
    }
}

// MARK: - Repository Change Signal

/// Differentiated change signals from file watcher for incremental updates
enum RepositoryChangeSignal: String, CaseIterable {
    case status          // index or working dir changed - refresh status only
    case head            // HEAD changed (checkout, commit) - refresh head + commits
    case refs            // branches/tags changed - refresh refs only
    case stash           // stash reflog changed - refresh stashes only
    case config          // .git/config changed - may need full refresh
    case full            // unknown change, full refresh needed
}

/// Watches a Git repository's .git directory and working directory for changes
/// Emits differentiated signals for incremental updates
class GitRepositoryWatcher: ObservableObject {
    // Legacy properties for backward compatibility
    @Published var hasChanges = false
    @Published var headChanged = false

    // New differentiated signal
    @Published private(set) var lastSignal: RepositoryChangeSignal?

    // Signal stream for async consumers
    private var signalContinuation: AsyncStream<RepositoryChangeSignal>.Continuation?
    private(set) var signalStream: AsyncStream<RepositoryChangeSignal>!

    private var headWatcher: FileWatcher?
    private var indexWatcher: FileWatcher?
    private var stashWatcher: FileWatcher?
    private var configWatcher: FileWatcher?
    private var refsWatcher: RecursiveDirectoryWatcher?
    private var workingDirWatcher: RecursiveDirectoryWatcher?

    private var cancellables = Set<AnyCancellable>()
    private let repositoryPath: String
    private let debounceInterval: TimeInterval

    init(repositoryPath: String, debounceInterval: TimeInterval = 0.2) {
        self.repositoryPath = repositoryPath
        self.debounceInterval = debounceInterval

        // Setup signal stream
        signalStream = AsyncStream { [weak self] continuation in
            self?.signalContinuation = continuation
        }

        setupWatchers()
    }

    deinit {
        stopAll()
        signalContinuation?.finish()
    }

    private func setupWatchers() {
        let gitDir = (repositoryPath as NSString).appendingPathComponent(".git")
        let fm = FileManager.default

        // Watch HEAD file -> .head signal
        let headPath = (gitDir as NSString).appendingPathComponent("HEAD")
        headWatcher = FileWatcher(path: headPath)
        headWatcher?.$lastChange
            .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.emitSignal(.head)
                self?.headChanged = true
            }
            .store(in: &cancellables)

        // Watch index file (staging area) -> .status signal
        let indexPath = (gitDir as NSString).appendingPathComponent("index")
        indexWatcher = FileWatcher(path: indexPath)
        indexWatcher?.$lastChange
            .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.emitSignal(.status)
            }
            .store(in: &cancellables)

        // Watch stash reflog -> .stash signal
        let stashLogPath = (gitDir as NSString).appendingPathComponent("logs/refs/stash")
        if fm.fileExists(atPath: stashLogPath) {
            stashWatcher = FileWatcher(path: stashLogPath)
            stashWatcher?.$lastChange
                .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    self?.emitSignal(.stash)
                }
                .store(in: &cancellables)
        }

        // Watch config file -> .config signal
        let configPath = (gitDir as NSString).appendingPathComponent("config")
        configWatcher = FileWatcher(path: configPath)
        configWatcher?.$lastChange
            .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.emitSignal(.config)
            }
            .store(in: &cancellables)

        // Watch refs directory for branch/tag changes -> .refs signal
        let refsPath = (gitDir as NSString).appendingPathComponent("refs")
        if fm.fileExists(atPath: refsPath) {
            refsWatcher = RecursiveDirectoryWatcher(
                paths: [refsPath],
                latency: debounceInterval,
                excludePaths: []
            ) { [weak self] in
                self?.emitSignal(.refs)
            }
        }

        // Watch working directory for file changes -> .status signal
        // Increased latency and extensive excludes for large repos (AWS CodeBuild, etc.)
        workingDirWatcher = RecursiveDirectoryWatcher(
            paths: [repositoryPath],
            latency: 0.5, // Increased from 0.2 for large repos
            excludePaths: [
                // Version control
                ".git",
                // JavaScript/Node
                "node_modules", ".npm", ".pnpm-store", ".yarn",
                // Python
                "__pycache__", ".pytest_cache", ".venv", "venv", ".tox", ".mypy_cache",
                // Swift/iOS
                "DerivedData", "Pods", ".swiftpm", ".build",
                // Ruby
                "vendor",
                // AWS/Serverless
                ".aws-sam", ".serverless", "cdk.out", ".amplify",
                // General build
                "build", "dist", "out", "target", "bin", "obj",
                // Terraform/IaC
                ".terraform",
                // Misc
                ".cache", "tmp", ".tmp", "temp", "logs"
            ]
        ) { [weak self] in
            self?.emitSignal(.status)
        }
    }

    private func emitSignal(_ signal: RepositoryChangeSignal) {
        lastSignal = signal
        hasChanges = true
        signalContinuation?.yield(signal)
    }

    /// Start all watchers
    func startAll() {
        headWatcher?.start()
        indexWatcher?.start()
        stashWatcher?.start()
        configWatcher?.start()
        refsWatcher?.start()
        workingDirWatcher?.start()
    }

    /// Stop all watchers
    func stopAll() {
        headWatcher?.stop()
        indexWatcher?.stop()
        stashWatcher?.stop()
        configWatcher?.stop()
        refsWatcher?.stop()
        workingDirWatcher?.stop()
    }

    /// Reset change flags
    func acknowledgeChanges() {
        hasChanges = false
        headChanged = false
        lastSignal = nil
    }

    /// Get pending signals and clear them
    func consumeSignal() -> RepositoryChangeSignal? {
        let signal = lastSignal
        lastSignal = nil
        return signal
    }
}

/// Recursive directory watcher for more comprehensive monitoring
class RecursiveDirectoryWatcher {
    private var eventStream: FSEventStreamRef?
    private let paths: [String]
    private let latency: TimeInterval
    private let excludePaths: [String]
    private let callback: () -> Void

    init(paths: [String], latency: TimeInterval = 0.3, excludePaths: [String] = [], callback: @escaping () -> Void) {
        self.paths = paths
        self.latency = latency
        self.excludePaths = excludePaths
        self.callback = callback
    }

    deinit {
        stop()
    }

    func start() {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Removed kFSEventStreamCreateFlagNoDefer for better coalescing on large repos
        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents
        )

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPaths, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<RecursiveDirectoryWatcher>.fromOpaque(info).takeUnretainedValue()

                // Filter out excluded paths
                let pathsPtr = unsafeBitCast(eventPaths, to: NSArray.self)
                if let cfPaths = pathsPtr as NSArray? {
                    for i in 0..<numEvents {
                        if let path = cfPaths[Int(i)] as? String {
                            let shouldExclude = watcher.excludePaths.contains { excludePath in
                                path.contains("/\(excludePath)/") || path.hasSuffix("/\(excludePath)")
                            }
                            if !shouldExclude {
                                watcher.callback()
                                return
                            }
                        }
                    }
                }
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }
}
