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

/// Watches a Git repository's .git directory for changes
class GitRepositoryWatcher: ObservableObject {
    @Published var hasChanges = false
    @Published var headChanged = false

    private var gitDirWatcher: FileWatcher?
    private var workingDirWatcher: FileWatcher?
    private var headWatcher: FileWatcher?
    private var indexWatcher: FileWatcher?

    private var cancellables = Set<AnyCancellable>()
    private let repositoryPath: String

    init(repositoryPath: String) {
        self.repositoryPath = repositoryPath
        setupWatchers()
    }

    deinit {
        stopAll()
    }

    private func setupWatchers() {
        let gitDir = (repositoryPath as NSString).appendingPathComponent(".git")

        // Watch .git directory
        gitDirWatcher = FileWatcher(path: gitDir)
        gitDirWatcher?.$lastChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.hasChanges = true
            }
            .store(in: &cancellables)

        // Watch HEAD file
        let headPath = (gitDir as NSString).appendingPathComponent("HEAD")
        headWatcher = FileWatcher(path: headPath)
        headWatcher?.$lastChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.headChanged = true
            }
            .store(in: &cancellables)

        // Watch index file (staging area)
        let indexPath = (gitDir as NSString).appendingPathComponent("index")
        indexWatcher = FileWatcher(path: indexPath)
        indexWatcher?.$lastChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.hasChanges = true
            }
            .store(in: &cancellables)
    }

    /// Start all watchers
    func startAll() {
        gitDirWatcher?.start()
        headWatcher?.start()
        indexWatcher?.start()
    }

    /// Stop all watchers
    func stopAll() {
        gitDirWatcher?.stop()
        headWatcher?.stop()
        indexWatcher?.stop()
    }

    /// Reset change flags
    func acknowledgeChanges() {
        hasChanges = false
        headChanged = false
    }
}

/// Recursive directory watcher for more comprehensive monitoring
class RecursiveDirectoryWatcher {
    private var eventStream: FSEventStreamRef?
    private let paths: [String]
    private let callback: () -> Void

    init(paths: [String], callback: @escaping () -> Void) {
        self.paths = paths
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

        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPaths, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<RecursiveDirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.callback()
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // Latency in seconds
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
