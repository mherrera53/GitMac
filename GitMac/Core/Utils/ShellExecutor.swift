import Foundation
import Darwin
import os.signpost

private let shellLog = OSLog(subsystem: "com.gitmac", category: "shell")

enum ShellError: LocalizedError {
    case nonZeroExit(Int32)
    case timeout(command: String)
    case terminated
    case processFailedToStart(String)
    case outputLimitExceeded
    case commandFailed(Int32, String)
    case ioFailed(String)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code): return "Command exited with code \(code)"
        case .timeout(let command): return "Command '\(command)' timed out"
        case .terminated: return "Process was terminated"
        case .processFailedToStart(let message): return "Failed to start process: \(message)"
        case .outputLimitExceeded: return "Command output exceeded the configured limit"
        case .commandFailed(let code, let message): return "Command exited with code \(code): \(message)"
        case .ioFailed(let message): return "Failed to read process output: \(message)"
        }
    }
}

enum GitCommandTimeout {
    case status, log, diff, fetch, pull, push, clone, `default`
    var seconds: TimeInterval {
        switch self {
        case .status: return 10
        case .log: return 30
        case .diff, .default: return 60
        case .fetch: return 300
        case .pull, .push: return 600
        case .clone: return 1800
        }
    }
    static func infer(from arguments: [String]) -> GitCommandTimeout {
        switch arguments.first {
        case "status": return .status
        case "log", "rev-list": return .log
        case "diff", "diff-tree": return .diff
        case "fetch": return .fetch
        case "pull": return .pull
        case "push": return .push
        case "clone": return .clone
        default: return .default
        }
    }
}

enum ShellTermination: Sendable, Equatable {
    case exited, cancelled, timedOut, outputLimitExceeded, launchFailed, ioFailed
}

struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    var termination: ShellTermination = .exited
    /// Populated only by executeData; text callers retain no second output copy.
    var stdoutData: Data? = nil
    var isSuccess: Bool { exitCode == 0 && termination == .exited }
    var output: String { stdout + stderr }
}

// Every spawned command owns a new POSIX process group. No PID search, global
// pkill or inherited process group is used. All state is protected by this lock.
private final class CommandControl: @unchecked Sendable {
    private let lock = NSLock()
    private var pid: pid_t?
    private var completed = false
    private var reason: ShellTermination?
    var stopped: Bool { lock.withLock { reason != nil } }
    var termination: ShellTermination { lock.withLock { reason ?? .exited } }

    func started(_ pid: pid_t) {
        let stopNow = lock.withLock { self.pid = pid; return reason != nil }
        if stopNow { signal(SIGTERM, to: pid); escalate(pid) }
    }
    func stop(_ reason: ShellTermination) {
        let group: pid_t? = lock.withLock {
            guard !completed, self.reason == nil else { return nil }
            self.reason = reason
            return pid
        }
        if let group { signal(SIGTERM, to: group); escalate(group) }
    }
    private func signal(_ signal: Int32, to group: pid_t) {
        // Group ID is guaranteed by POSIX_SPAWN_SETPGROUP, never inferred.
        guard group > 1, group != getpgrp() else { return }
        _ = Darwin.kill(-group, signal)
    }
    private func escalate(_ group: pid_t) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [self] in
            lock.withLock { if !completed { signal(SIGKILL, to: group) } }
        }
    }
    func finish() {
        lock.withLock {
            // If the leader has exited and closed its pipes, remaining children
            // in its owned group still must not outlive this operation.
            if let pid { signal(SIGKILL, to: pid) }
            completed = true
        }
    }
}

// A single pipe reader owns each capture. Its fields are read only after the
// DispatchGroup barrier. Callback decoding retains incomplete UTF-8 sequences.
private final class CommandCapture: @unchecked Sendable {
    var bytes = Data()
    var pendingUTF8 = Data()
    func emit(_ chunk: Data, to callback: @Sendable (String) -> Void, final: Bool = false) {
        pendingUTF8.append(chunk)
        if final {
            if !pendingUTF8.isEmpty { callback(String(decoding: pendingUTF8, as: UTF8.self)) }
            pendingUTF8.removeAll()
            return
        }
        for tail in 0...min(3, pendingUTF8.count) {
            let prefix = pendingUTF8.prefix(pendingUTF8.count - tail)
            if let text = String(data: prefix, encoding: .utf8) {
                if !text.isEmpty { callback(text) }
                pendingUTF8.removeFirst(prefix.count)
                return
            }
        }
        if pendingUTF8.count > 3 {
            let prefix = pendingUTF8.prefix(pendingUTF8.count - 3)
            callback(String(decoding: prefix, as: UTF8.self))
            pendingUTF8.removeFirst(prefix.count)
        }
    }
}

actor ShellExecutor {
    static let shared = ShellExecutor()
    private let defaultEnvironment: [String: String]

    init() {
        var environment = ProcessInfo.processInfo.environment
        var paths = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for path in ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"] where !paths.contains(path) {
            paths.append(path)
        }
        environment["PATH"] = paths.joined(separator: ":")
        environment["GIT_PAGER"] = ""
        environment["PAGER"] = ""
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_LITERAL_PATHSPECS"] = "1"
        // A GUI operation must use its supplied working tree, not a Git scope
        // inherited from the terminal which launched the application.
        for key in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"] {
            environment.removeValue(forKey: key)
        }
        defaultEnvironment = environment
    }

    nonisolated func execute(_ command: String, arguments: [String] = [], workingDirectory: String? = nil,
                             environment: [String: String]? = nil, timeout: TimeInterval? = nil,
                             maxOutputBytes: Int = 32 * 1024 * 1024) async -> ShellResult {
        await run(command, arguments: arguments, workingDirectory: workingDirectory, environment: environment,
                  timeout: timeout, maxOutputBytes: max(1, maxOutputBytes))
    }

    /// Lossless bounded output for Git blobs, including non-UTF8 and NUL bytes.
    /// Uses the same process ownership, cancellation and pipe draining as text.
    nonisolated func executeData(_ command: String, arguments: [String] = [], workingDirectory: String? = nil,
                                 environment: [String: String]? = nil, timeout: TimeInterval? = nil,
                                 maxOutputBytes: Int = 8 * 1024 * 1024) async -> ShellResult {
        await run(command, arguments: arguments, workingDirectory: workingDirectory, environment: environment,
                  timeout: timeout, maxOutputBytes: max(1, maxOutputBytes), captureBytes: true)
    }

    nonisolated private func run(_ command: String, arguments: [String], workingDirectory: String?,
                                 environment: [String: String]? = nil, timeout: TimeInterval? = nil,
                                 maxOutputBytes: Int? = nil,
                                 captureBytes: Bool = false,
                                 onData: (@Sendable (Data) -> Bool)? = nil,
                                 onOutput: (@Sendable (String) -> Void)? = nil,
                                 onError: (@Sendable (String) -> Void)? = nil,
                                 control: CommandControl = CommandControl()) async -> ShellResult {
        let duration = timeout ?? (command == "git" ? GitCommandTimeout.infer(from: arguments).seconds : 60)
        var variables = defaultEnvironment
        // Stash constructs its own :(literal) pathspecs for cleanup. Forcing
        // literal mode on those child commands can leave saved untracked files
        // behind even when `git stash push -u` exits successfully.
        if command == "git", arguments.first == "stash" { variables["GIT_LITERAL_PATHSPECS"] = "0" }
        variables.merge(environment ?? [:]) { _, new in new }
        let processEnvironment = variables
        let signpost = OSSignpostID(log: shellLog)
        // Never log argv, URLs, tokens or repository paths.
        os_signpost(.begin, log: shellLog, name: "shell.execute", signpostID: signpost)
        defer { os_signpost(.end, log: shellLog, name: "shell.execute", signpostID: signpost) }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let stdout = Pipe(), stderr = Pipe()
                    let output = CommandCapture(), errorOutput = CommandCapture()
                    let group = DispatchGroup()
                    let timer = DispatchWorkItem { control.stop(.timedOut) }
                    defer { timer.cancel() }
                    do {
                        if control.stopped { throw ShellError.terminated }
                        let pid = try Self.spawn(command, arguments: arguments, directory: workingDirectory,
                                                 environment: processEnvironment, stdout: stdout, stderr: stderr)
                        control.started(pid)
                        try? stdout.fileHandleForWriting.close()
                        try? stderr.fileHandleForWriting.close()
                        DispatchQueue.global().asyncAfter(deadline: .now() + (duration.isFinite ? max(0.01, duration) : 60), execute: timer)
                        for (pipe, capture, isError) in [(stdout, output, false), (stderr, errorOutput, true)] {
                            group.enter()
                            DispatchQueue.global(qos: .userInitiated).async {
                                defer { try? pipe.fileHandleForReading.close(); group.leave() }
                                do {
                                    while let data = try pipe.fileHandleForReading.read(upToCount: 8192), !data.isEmpty {
                                        if let limit = maxOutputBytes {
                                            let remaining = max(0, limit - capture.bytes.count)
                                            capture.bytes.append(data.prefix(remaining))
                                            if data.count > remaining { control.stop(.outputLimitExceeded) }
                                        } else if isError {
                                            capture.bytes.append(data.prefix(max(0, 64 * 1024 - capture.bytes.count)))
                                        }
                                        if isError, let callback = onError { capture.emit(data, to: callback) }
                                        if !isError {
                                            if let callback = onOutput { capture.emit(data, to: callback) }
                                            if let onData, !onData(data) { control.stop(.cancelled) }
                                        }
                                    }
                                    if isError, let callback = onError { capture.emit(Data(), to: callback, final: true) }
                                    if !isError, let callback = onOutput { capture.emit(Data(), to: callback, final: true) }
                                } catch { control.stop(.ioFailed) }
                            }
                        }
                        var info = siginfo_t()
                        var observed: Int32
                        // Keep the leader unreaped until group cleanup. Its PID
                        // cannot be reused while we may still signal the group.
                        repeat { observed = waitid(P_PID, id_t(pid), &info, WEXITED | WNOWAIT) } while observed == -1 && errno == EINTR
                        if observed == -1 { control.stop(.ioFailed) }
                        // Timeout remains active until BOTH pipes reach EOF, even
                        // if the leader exits leaving a descendant with open FDs.
                        group.wait()
                        control.finish()
                        var status: Int32 = 0
                        var waited: pid_t
                        repeat { waited = waitpid(pid, &status, 0) } while waited == -1 && errno == EINTR
                        let termination = control.termination
                        let actualCode = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
                        let code: Int32 = termination == .exited ? actualCode : -1
                        var message = String(decoding: errorOutput.bytes, as: UTF8.self)
                        if termination != .exited { message += "\nCommand stopped: \(termination)" }
                        continuation.resume(returning: ShellResult(stdout: captureBytes ? "" : String(decoding: output.bytes, as: UTF8.self),
                            stderr: message, exitCode: code, termination: termination,
                            stdoutData: captureBytes ? output.bytes : nil))
                    } catch {
                        try? stdout.fileHandleForWriting.close(); try? stdout.fileHandleForReading.close()
                        try? stderr.fileHandleForWriting.close(); try? stderr.fileHandleForReading.close()
                        control.finish()
                        continuation.resume(returning: ShellResult(stdout: "", stderr: error.localizedDescription, exitCode: -1,
                            termination: control.stopped ? control.termination : .launchFailed))
                    }
                }
            }
        } onCancel: { control.stop(.cancelled) }
    }

    // posix_spawn creates an isolated group atomically, so descendants can be
    // cancelled safely without races involving setpgid or other applications.
    nonisolated private static func spawn(_ command: String, arguments: [String], directory: String?,
                                          environment: [String: String], stdout: Pipe, stderr: Pipe) throws -> pid_t {
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        func check(_ code: Int32) throws {
            if code != 0 { throw ShellError.processFailedToStart(String(cString: strerror(code))) }
        }
        try check(posix_spawn_file_actions_init(&actions))
        defer { posix_spawn_file_actions_destroy(&actions) }
        try check(posix_spawnattr_init(&attributes))
        defer { posix_spawnattr_destroy(&attributes) }
        try check(posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF)))
        try check(posix_spawnattr_setpgroup(&attributes, 0))
        var mask = sigset_t()
        sigemptyset(&mask)
        try check(posix_spawnattr_setsigmask(&attributes, &mask))
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for signal in [SIGPIPE, SIGTERM, SIGINT, SIGHUP] { sigaddset(&defaults, signal) }
        try check(posix_spawnattr_setsigdefault(&attributes, &defaults))
        try check(posix_spawn_file_actions_adddup2(&actions, stdout.fileHandleForWriting.fileDescriptor, STDOUT_FILENO))
        try check(posix_spawn_file_actions_adddup2(&actions, stderr.fileHandleForWriting.fileDescriptor, STDERR_FILENO))
        try check(posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0))
        if let directory {
            if #available(macOS 26.0, *) { try check(posix_spawn_file_actions_addchdir(&actions, directory)) }
            else { try check(posix_spawn_file_actions_addchdir_np(&actions, directory)) }
        }
        var argv = (["/usr/bin/env", command] + arguments).map { strdup($0) } + [nil]
        var envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var pid: pid_t = 0
        let code = argv.withUnsafeMutableBufferPointer { argv in
            envp.withUnsafeMutableBufferPointer { envp in
                posix_spawn(&pid, "/usr/bin/env", &actions, &attributes, argv.baseAddress!, envp.baseAddress!)
            }
        }
        try check(code)
        return pid
    }

    func executeWithStreaming(_ command: String, arguments: [String] = [], workingDirectory: String? = nil,
                              environment: [String: String]? = nil,
                              onOutput: @escaping @Sendable (String) -> Void,
                              onError: @escaping @Sendable (String) -> Void) async -> Int32 {
        let result = await run(command, arguments: arguments, workingDirectory: workingDirectory,
                               environment: environment, onOutput: onOutput, onError: onError)
        return result.exitCode
    }

    /// Bounded, lossless line stream. A dedicated pipe-reader thread retries a
    /// full FIFO, letting the OS pipe apply backpressure to Git, not the UI.
    nonisolated func executeStreaming(_ command: String, arguments: [String] = [], workingDirectory: String? = nil,
                                      bufferSize: Int = 50) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingOldest(max(1, bufferSize))) { continuation in
            let control = CommandControl()
            let lines = CommandCapture()
            @Sendable func yieldLine(_ data: Data) -> Bool {
                let bytes = data.last == 13 ? data.dropLast() : data[...]
                let line = String(decoding: bytes, as: UTF8.self)
                while !control.stopped {
                    switch continuation.yield(line) {
                    case .enqueued: return true
                    case .terminated: return false
                    case .dropped: Thread.sleep(forTimeInterval: 0.001)
                    @unknown default: return false
                    }
                }
                return false
            }
            let task = Task {
                let result = await run(command, arguments: arguments, workingDirectory: workingDirectory, onData: { chunk in
                    guard !control.stopped else { return false }
                    lines.bytes.append(chunk)
                    while let newline = lines.bytes.firstIndex(of: 10) {
                        let line = Data(lines.bytes[..<newline])
                        lines.bytes.removeSubrange(...newline)
                        if !yieldLine(line) { return false }
                    }
                    if lines.bytes.count > 1024 * 1024 { control.stop(.outputLimitExceeded); return false }
                    return !control.stopped
                }, control: control)
                if result.isSuccess {
                    if !lines.bytes.isEmpty { _ = yieldLine(lines.bytes) }
                    continuation.finish()
                } else {
                    switch result.termination {
                    case .cancelled: continuation.finish(throwing: ShellError.terminated)
                    case .timedOut: continuation.finish(throwing: ShellError.timeout(command: command))
                    case .outputLimitExceeded: continuation.finish(throwing: ShellError.outputLimitExceeded)
                    case .launchFailed: continuation.finish(throwing: ShellError.processFailedToStart(result.stderr))
                    case .ioFailed: continuation.finish(throwing: ShellError.ioFailed(result.stderr))
                    case .exited: continuation.finish(throwing: ShellError.commandFailed(result.exitCode, result.stderr))
                    }
                }
            }
            continuation.onTermination = { @Sendable _ in control.stop(.cancelled); task.cancel() }
        }
    }

    func which(_ command: String) async -> String? {
        let result = await execute("which", arguments: [command])
        guard result.isSuccess else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
    func commandExists(_ command: String) async -> Bool { await which(command) != nil }
    func gitVersion() async -> String? {
        let result = await execute("git", arguments: ["--version"])
        guard result.isSuccess else { return nil }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "git version ", with: "")
    }
    func executeSequence(_ commands: [(command: String, arguments: [String])], workingDirectory: String? = nil,
                         stopOnError: Bool = true) async -> [ShellResult] {
        var results: [ShellResult] = []
        for command in commands {
            let result = await execute(command.command, arguments: command.arguments, workingDirectory: workingDirectory)
            results.append(result)
            if stopOnError && !result.isSuccess { break }
        }
        return results
    }
}
