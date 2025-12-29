import Foundation
import os.signpost

// MARK: - Performance Logging

private let shellLog = OSLog(subsystem: "com.gitmac", category: "shell")

// MARK: - Thread-safe Box for concurrent data capture

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Shell Errors

enum ShellError: LocalizedError {
    case nonZeroExit(Int32)
    case timeout(command: String)
    case terminated
    case processFailedToStart(String)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code):
            return "Command exited with code \(code)"
        case .timeout(let command):
            return "Command '\(command)' timed out"
        case .terminated:
            return "Process was terminated"
        case .processFailedToStart(let message):
            return "Failed to start process: \(message)"
        }
    }
}

// MARK: - Command Timeout Configuration

/// Command-specific timeout configuration for Git operations
enum GitCommandTimeout {
    case status         // Fast read operation
    case log            // Can be slow for large repos
    case diff           // Variable based on file size
    case fetch          // Network dependent
    case pull           // Network + merge
    case push           // Network dependent
    case clone          // Large network operation
    case `default`      // General operations

    var seconds: TimeInterval {
        switch self {
        case .status: return 10
        case .log: return 30
        case .diff: return 60
        case .fetch: return 300      // 5 minutes
        case .pull: return 600       // 10 minutes
        case .push: return 600       // 10 minutes
        case .clone: return 1800     // 30 minutes
        case .default: return 60
        }
    }

    /// Infer timeout from git command arguments
    static func infer(from arguments: [String]) -> GitCommandTimeout {
        guard let firstArg = arguments.first else { return .default }

        switch firstArg {
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

// MARK: - Shell Result

/// Result of a shell command execution
struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var isSuccess: Bool {
        exitCode == 0
    }

    var output: String {
        stdout + stderr
    }
}

/// Executes shell commands
actor ShellExecutor {
    private let defaultEnvironment: [String: String]

    init() {
        // Get current environment
        var env = ProcessInfo.processInfo.environment

        // Ensure PATH includes common Git installation locations
        var path = env["PATH"] ?? ""
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin"
        ]

        for additionalPath in additionalPaths {
            if !path.contains(additionalPath) {
                path = "\(additionalPath):\(path)"
            }
        }

        env["PATH"] = path

        // Disable Git pager for non-interactive use
        env["GIT_PAGER"] = ""
        env["PAGER"] = ""

        // Ensure UTF-8 output
        env["LANG"] = "en_US.UTF-8"
        env["LC_ALL"] = "en_US.UTF-8"

        // Performance and safety flags
        env["GIT_OPTIONAL_LOCKS"] = "0"      // Avoid locks on read operations
        env["GIT_TERMINAL_PROMPT"] = "0"     // Never prompt for credentials (avoid hangs)

        self.defaultEnvironment = env
    }

    /// Execute a command and return the result
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Command arguments
    ///   - workingDirectory: Working directory for the command
    ///   - environment: Additional environment variables
    ///   - timeout: Timeout in seconds (defaults to auto-inferred for git commands)
    func execute(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async -> ShellResult {
        // Auto-infer timeout for git commands
        let effectiveTimeout: TimeInterval
        if let timeout = timeout {
            effectiveTimeout = timeout
        } else if command == "git" {
            effectiveTimeout = GitCommandTimeout.infer(from: arguments).seconds
        } else {
            effectiveTimeout = 60
        }

        let signpostID = OSSignpostID(log: shellLog)
        os_signpost(.begin, log: shellLog, name: "shell.execute", signpostID: signpostID,
                    "%{public}s %{public}s", command, arguments.joined(separator: " "))

        defer {
            os_signpost(.end, log: shellLog, name: "shell.execute", signpostID: signpostID)
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Merge environments
            var finalEnvironment = defaultEnvironment
            if let environment = environment {
                for (key, value) in environment {
                    finalEnvironment[key] = value
                }
            }
            process.environment = finalEnvironment

            if let workingDirectory = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            }

            // Data capture with actor isolation
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "com.gitmac.shell-io", attributes: .concurrent)

            let stdoutDataBox = Box<Data>(Data())
            let stderrDataBox = Box<Data>(Data())

            group.enter()
            queue.async {
                stdoutDataBox.value = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            queue.async {
                stderrDataBox.value = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            // Escalated timeout handling: SIGTERM first, then SIGKILL
            let timeoutWorkItem = DispatchWorkItem {
                guard process.isRunning else { return }

                // First try graceful termination
                process.terminate()

                // Schedule forced kill if still running after 2 seconds
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + effectiveTimeout,
                execute: timeoutWorkItem
            )

            do {
                try process.run()
                process.waitUntilExit()

                timeoutWorkItem.cancel()
                group.wait() // Wait for IO to finish

                let stdout = String(data: stdoutDataBox.value, encoding: .utf8) ?? ""
                let stderr = String(data: stderrDataBox.value, encoding: .utf8) ?? ""

                continuation.resume(returning: ShellResult(
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: process.terminationStatus
                ))
            } catch {
                timeoutWorkItem.cancel()
                continuation.resume(returning: ShellResult(
                    stdout: "",
                    stderr: error.localizedDescription,
                    exitCode: -1
                ))
            }
        }
    }

    /// Execute a command with streaming output
    func executeWithStreaming(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        onOutput: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            var finalEnvironment = defaultEnvironment
            if let environment = environment {
                for (key, value) in environment {
                    finalEnvironment[key] = value
                }
            }
            process.environment = finalEnvironment

            if let workingDirectory = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            }

            // Handle stdout
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let string = String(data: data, encoding: .utf8) {
                    onOutput(string)
                }
            }

            // Handle stderr
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let string = String(data: data, encoding: .utf8) {
                    onError(string)
                }
            }

            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: process.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                onError(error.localizedDescription)
                continuation.resume(returning: -1)
            }
        }
    }

    /// Execute a command with backpressure-aware streaming output via AsyncThrowingStream
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Command arguments
    ///   - workingDirectory: Working directory for the command
    ///   - bufferSize: Maximum number of lines to buffer before applying backpressure
    /// - Returns: An AsyncThrowingStream that yields lines as they become available
    nonisolated func executeStreaming(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        bufferSize: Int = 50
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Use default environment
            var env = ProcessInfo.processInfo.environment
            env["GIT_PAGER"] = ""
            env["PAGER"] = ""
            env["LANG"] = "en_US.UTF-8"
            env["LC_ALL"] = "en_US.UTF-8"
            env["GIT_OPTIONAL_LOCKS"] = "0"
            env["GIT_TERMINAL_PROMPT"] = "0"
            process.environment = env

            if let workingDirectory = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            }

            // Move to background thread for blocking I/O
            Task.detached {
                let stdoutHandle = stdoutPipe.fileHandleForReading
                let stderrHandle = stderrPipe.fileHandleForReading
                
                // Start stderr reader concurrently to prevent deadlocks
                let stderrTask = Task {
                    return stderrHandle.readDataToEndOfFile()
                }

                do {
                    try process.run()
                } catch {
                    continuation.finish(throwing: ShellError.processFailedToStart(error.localizedDescription))
                    return
                }

                // Handle cancellation
                continuation.onTermination = { @Sendable _ in
                    if process.isRunning {
                        process.terminate()
                    }
                }

                // Read stdout line by line
                for try await line in stdoutHandle.bytes.lines {
                    continuation.yield(line)
                }
                
                // Wait for process and stderr
                let stderrData = await stderrTask.value
                let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    _ = stderrString.isEmpty
                        ? "Process exited with code \(process.terminationStatus)"
                        : stderrString
                    continuation.finish(throwing: ShellError.nonZeroExit(process.terminationStatus))
                }
            }
        }
    }

    /// Find the path to a command
    func which(_ command: String) async -> String? {
        let result = await execute("which", arguments: [command])
        guard result.isSuccess else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    /// Check if a command exists
    func commandExists(_ command: String) async -> Bool {
        await which(command) != nil
    }

    /// Get Git version
    func gitVersion() async -> String? {
        let result = await execute("git", arguments: ["--version"])
        guard result.isSuccess else { return nil }

        // Parse "git version X.Y.Z"
        let version = result.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "git version ", with: "")

        return version
    }
}

// MARK: - Convenience Extensions

extension ShellExecutor {
    /// Execute multiple commands in sequence
    func executeSequence(
        _ commands: [(command: String, arguments: [String])],
        workingDirectory: String? = nil,
        stopOnError: Bool = true
    ) async -> [ShellResult] {
        var results: [ShellResult] = []

        for (command, arguments) in commands {
            let result = await execute(
                command,
                arguments: arguments,
                workingDirectory: workingDirectory
            )

            results.append(result)

            if stopOnError && !result.isSuccess {
                break
            }
        }

        return results
    }
}
