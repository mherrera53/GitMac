import Foundation
import Combine
import CoreServices

/// Watches for file system changes in a directory
class FileWatcher: ObservableObject {
    @Published var lastChange: Date = Date()

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var parentSource: DispatchSourceFileSystemObject?
    private var parentDescriptor: Int32 = -1
    private var parentPath: String?
    private var generation = UUID()
    private var parentGeneration = UUID()
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
        isWatching = true
        updateParentWatch()
        rearmFileIfNeeded(emit: false)
    }

    private func rearmFileIfNeeded(emit: Bool) {
        guard isWatching, !stillTargetsPath(fileDescriptor, path: path) else { return }
        let wasPresent = fileDescriptor >= 0
        source?.cancel()
        source = nil
        fileDescriptor = -1
        generation = UUID()
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            if emit && wasPresent { lastChange = Date() }
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

        let request = generation
        source?.setEventHandler { [weak self] in
            guard let self, self.isWatching, self.generation == request else { return }
            self.lastChange = Date()
            self.updateParentWatch()
            self.rearmFileIfNeeded(emit: false)
        }

        let ownedDescriptor = fileDescriptor
        source?.setCancelHandler {
            // The old source owns only its original fd, even after restart or
            // owner deinitialization. Never close a replacement descriptor.
            close(ownedDescriptor)
        }

        source?.resume()
        if emit { lastChange = Date() }
    }

    private func stillTargetsPath(_ descriptor: Int32, path: String) -> Bool {
        var opened = stat()
        var current = stat()
        return descriptor >= 0 && fstat(descriptor, &opened) == 0
            && fstatat(AT_FDCWD, path, &current, 0) == 0
            && opened.st_dev == current.st_dev && opened.st_ino == current.st_ino
    }

    /// Git writes HEAD/index through lock+rename. Watching only their old inode
    /// loses future changes. Follow the nearest existing parent without polling,
    /// then descend as missing logs/refs directories are created.
    private func updateParentWatch() {
        var directory = URL(fileURLWithPath: path).deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue { break }
            directory.deleteLastPathComponent()
        }
        if parentPath == directory.path, stillTargetsPath(parentDescriptor, path: directory.path) { return }
        parentSource?.cancel()
        parentSource = nil
        parentDescriptor = -1
        parentPath = nil
        parentGeneration = UUID()
        // A missing volume must not turn into a watcher for the whole filesystem.
        guard directory.path != "/" else { return }
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        parentDescriptor = descriptor
        parentPath = directory.path
        let request = parentGeneration
        let parent = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .revoke, .attrib], queue: .main)
        parent.setCancelHandler { close(descriptor) }
        parent.setEventHandler { [weak self] in
            guard let self, self.isWatching, self.parentGeneration == request else { return }
            self.updateParentWatch()
            self.rearmFileIfNeeded(emit: true)
        }
        parentSource = parent
        parent.resume()
    }

    /// Stop watching
    func stop() {
        isWatching = false
        generation = UUID()
        parentGeneration = UUID()
        source?.cancel()
        source = nil
        fileDescriptor = -1
        parentSource?.cancel()
        parentSource = nil
        parentDescriptor = -1
        parentPath = nil
    }

    /// Restart watching (useful after the watched directory changes)
    func restart() {
        stop()
        start()
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
    private var isRunning = false
    private var observesActivity = false

    init(repositoryPath: String, debounceInterval: TimeInterval = 0.2) {
        self.repositoryPath = repositoryPath
        self.debounceInterval = debounceInterval

        // Setup signal stream
        signalStream = AsyncStream { [weak self] continuation in
            self?.signalContinuation = continuation
        }

        setupWatchers()
        setupActivityObserver()
    }

    deinit {
        stopAll()
        signalContinuation?.finish()
    }

    /// Automatically pause/resume file watchers based on app activity
    private func setupActivityObserver() {
        NotificationCenter.default.publisher(for: .appDidBecomeInactive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.suspendAll()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appDidBecomeActiveAgain)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.observesActivity, !self.isRunning else { return }
                self.resumeAll()
                // Emit a full signal so UI catches up on any changes that happened while suspended
                self.emitSignal(.full)
            }
            .store(in: &cancellables)
    }

    /// Temporarily suspend watchers without destroying them (for app inactivity)
    private func suspendAll() {
        headWatcher?.stop()
        indexWatcher?.stop()
        stashWatcher?.stop()
        configWatcher?.stop()
        refsWatcher?.stop()
        workingDirWatcher?.stop()
        isRunning = false
    }

    /// Resume previously suspended watchers
    private func resumeAll() {
        headWatcher?.start()
        indexWatcher?.start()
        stashWatcher?.start()
        configWatcher?.start()
        refsWatcher?.start()
        workingDirWatcher?.start()
        isRunning = true
    }

    private func setupWatchers() {
        guard let scope = try? RepositoryFileLocations(repositoryPath: repositoryPath) else { return }
        let gitDir = scope.gitDirectory.path
        let commonDir = scope.commonGitDirectory.path
        let fm = FileManager.default

        // Watch HEAD file -> .head signal
        let headPath = (gitDir as NSString).appendingPathComponent("HEAD")
        headWatcher = FileWatcher(path: headPath)
        headWatcher?.$lastChange
            .dropFirst()
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
            .dropFirst()
            .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.emitSignal(.status)
            }
            .store(in: &cancellables)

        // Watch stash reflog -> .stash signal
        let stashLogPath = (commonDir as NSString).appendingPathComponent("logs/refs/stash")
        stashWatcher = FileWatcher(path: stashLogPath)
        stashWatcher?.$lastChange
            .dropFirst()
            .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.emitSignal(.stash)
            }
            .store(in: &cancellables)

        // Watch config file -> .config signal
        let configPath = (commonDir as NSString).appendingPathComponent("config")
        configWatcher = FileWatcher(path: configPath)
        configWatcher?.$lastChange
            .dropFirst()
            .debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.emitSignal(.config)
            }
            .store(in: &cancellables)

        // Watch refs directory for branch/tag changes -> .refs signal
        let refsPath = (commonDir as NSString).appendingPathComponent("refs")
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
        // High latency + directory-level events for minimal CPU overhead on large repos
        workingDirWatcher = RecursiveDirectoryWatcher(
            paths: [repositoryPath],
            latency: 1.0, // Increased for better event coalescing on large repos
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
        observesActivity = true
        headWatcher?.start()
        indexWatcher?.start()
        stashWatcher?.start()
        configWatcher?.start()
        refsWatcher?.start()
        workingDirWatcher?.start()
        isRunning = true
    }

    /// Stop all watchers
    func stopAll() {
        observesActivity = false
        headWatcher?.stop()
        indexWatcher?.stop()
        stashWatcher?.stop()
        configWatcher?.stop()
        refsWatcher?.stop()
        workingDirWatcher?.stop()
        isRunning = false
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
        guard eventStream == nil else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Use directory-level events (not file-level) for much lower CPU overhead.
        // kFSEventStreamCreateFlagFileEvents removed: file-level events fire per-file
        // and are extremely expensive on large repos. Directory-level is sufficient
        // since we just need to know "something changed" to trigger a git status.
        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
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
