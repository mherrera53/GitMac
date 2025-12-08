import Foundation

/// Result of a shell command execution
struct ShellResult {
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

        self.defaultEnvironment = env
    }

    /// Execute a command and return the result
    func execute(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60
    ) async -> ShellResult {
        await withCheckedContinuation { continuation in
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

            // Timeout handling
            let timeoutWorkItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeout,
                execute: timeoutWorkItem
            )

            do {
                try process.run()
                process.waitUntilExit()

                timeoutWorkItem.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

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
        onOutput: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
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
