import Foundation
import SwiftUI

/// Centralized handler for all git operations
/// Eliminates duplicate code patterns and provides consistent error handling and tracking
@MainActor
class GitOperationHandler: ObservableObject {
    @Published var isOperationInProgress = false
    @Published var operationMessage = ""

    weak var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState
    }

    // MARK: - Generic Operation Executor

    /// Generic executor for git operations with consistent error handling and tracking
    func execute(
        operation: @escaping () async throws -> Void,
        message: String,
        onSuccess: (() async -> Void)? = nil,
        tracking: TrackingInfo? = nil,
        shouldRefresh: Bool = true
    ) async {
        isOperationInProgress = true
        operationMessage = message

        do {
            try await operation()

            if shouldRefresh {
                await appState?.refresh()
            }

            await onSuccess?()
            tracking?.recordSuccess()

        } catch {
            let errorMessage = "\(message.replacingOccurrences(of: "...", with: "")) failed: \(error.localizedDescription)"
            appState?.errorMessage = errorMessage
            tracking?.recordFailure(error)
        }

        isOperationInProgress = false
    }

    // MARK: - Remote Operations

    func handleFetch() async {
        guard appState?.currentRepository != nil else { return }

        await execute(
            operation: {
                try await self.appState?.gitService.fetch()
            },
            message: "Fetching from remote...",
            tracking: .fetch(remote: "origin")
        )
    }

    func handlePull() async {
        guard let repo = appState?.currentRepository else { return }
        let branchName = repo.currentBranch?.name ?? "unknown"

        await execute(
            operation: {
                try await self.appState?.gitService.pull()
            },
            message: "Pulling changes...",
            onSuccess: nil,
            tracking: .pull(branch: branchName, remote: "origin")
        )
    }

    func handlePush() async {
        guard let repo = appState?.currentRepository else { return }
        let branchName = repo.currentBranch?.name ?? "unknown"

        await execute(
            operation: {
                try await self.appState?.gitService.push()
            },
            message: "Pushing to remote...",
            tracking: .push(branch: branchName, remote: "origin")
        )
    }

    // MARK: - Stash Operations

    func handleStash() async {
        guard appState?.currentRepository != nil else { return }

        await execute(
            operation: {
                _ = try await self.appState?.gitService.stash()
            },
            message: "Creating stash..."
        )
    }

    func handlePopStash() async {
        guard appState?.currentRepository != nil else { return }

        await execute(
            operation: {
                try await self.appState?.gitService.stashPop()
            },
            message: "Popping stash..."
        )
    }

    // MARK: - File Operations

    func handleIgnoreFile(filePath: String, type: IgnoreType, repoPath: String) async {
        await execute(
            operation: {
                try await self.performIgnoreFile(filePath: filePath, type: type, repoPath: repoPath)
            },
            message: "Adding to .gitignore..."
        )
    }

    func handleAssumeUnchanged(filePath: String, repoPath: String) async {
        await execute(
            operation: {
                try await self.performAssumeUnchanged(filePath: filePath, repoPath: repoPath)
            },
            message: "Marking file as assume-unchanged..."
        )
    }

    func handleStopTrackingFile(filePath: String, repoPath: String) async {
        await execute(
            operation: {
                try await self.performStopTrackingFile(filePath: filePath, repoPath: repoPath)
            },
            message: "Removing file from tracking..."
        )
    }

    // MARK: - Private Helpers

    private func performIgnoreFile(filePath: String, type: IgnoreType, repoPath: String) async throws {
        let gitignorePath = "\(repoPath)/.gitignore"
        var currentContent = ""

        if FileManager.default.fileExists(atPath: gitignorePath) {
            currentContent = try String(contentsOfFile: gitignorePath, encoding: .utf8)
            if !currentContent.hasSuffix("\n") {
                currentContent += "\n"
            }
        }

        let entryToAdd = type.gitignoreEntry(for: filePath, repoPath: repoPath)

        let lines = currentContent.components(separatedBy: "\n")
        if !lines.contains(entryToAdd) {
            currentContent += entryToAdd + "\n"
            try currentContent.write(toFile: gitignorePath, atomically: true, encoding: .utf8)
        }

        NotificationCenter.default.post(name: .repositoryDidRefresh, object: repoPath)
    }

    private func performAssumeUnchanged(filePath: String, repoPath: String) async throws {
        let shell = ShellExecutor()
        let relativePath = filePath.replacingOccurrences(of: repoPath + "/", with: "")
        let result = await shell.execute(
            "git",
            arguments: ["update-index", "--assume-unchanged", relativePath],
            workingDirectory: repoPath
        )

        if result.exitCode != 0 {
            throw GitOperationError.commandFailed(result.stderr)
        }
    }

    private func performStopTrackingFile(filePath: String, repoPath: String) async throws {
        let shell = ShellExecutor()
        let relativePath = filePath.replacingOccurrences(of: repoPath + "/", with: "")
        let result = await shell.execute(
            "git",
            arguments: ["rm", "--cached", relativePath],
            workingDirectory: repoPath
        )

        if result.exitCode != 0 {
            throw GitOperationError.commandFailed(result.stderr)
        }
    }
}

// MARK: - Supporting Types

enum IgnoreType {
    case file
    case directory
    case fileExtension(String)

    func gitignoreEntry(for filePath: String, repoPath: String) -> String {
        let relativePath = filePath.replacingOccurrences(of: repoPath + "/", with: "")

        switch self {
        case .file:
            return relativePath
        case .directory:
            let dir = URL(fileURLWithPath: filePath).lastPathComponent
            return "\(dir)/"
        case .fileExtension(let ext):
            return "*.\(ext)"
        }
    }
}

/// Tracking information for git operations
struct TrackingInfo {
    let operation: String
    let metadata: [String: String]

    func recordSuccess() {
        Task { @MainActor in
            switch operation {
            case "fetch":
                RemoteOperationTracker.shared.recordFetch(
                    success: true,
                    remote: metadata["remote"] ?? "origin"
                )
            case "pull":
                RemoteOperationTracker.shared.recordPull(
                    success: true,
                    branch: metadata["branch"] ?? "unknown",
                    remote: metadata["remote"] ?? "origin"
                )
            case "push":
                RemoteOperationTracker.shared.recordPush(
                    success: true,
                    branch: metadata["branch"] ?? "unknown",
                    remote: metadata["remote"] ?? "origin"
                )
            default:
                break
            }
        }
    }

    func recordFailure(_ error: Error) {
        let errorDesc = error.localizedDescription

        Task { @MainActor in
            switch operation {
            case "fetch":
                RemoteOperationTracker.shared.recordFetch(
                    success: false,
                    remote: metadata["remote"] ?? "origin",
                    error: errorDesc
                )
            case "pull":
                RemoteOperationTracker.shared.recordPull(
                    success: false,
                    branch: metadata["branch"] ?? "unknown",
                    remote: metadata["remote"] ?? "origin",
                    error: errorDesc
                )
            case "push":
                RemoteOperationTracker.shared.recordPush(
                    success: false,
                    branch: metadata["branch"] ?? "unknown",
                    remote: metadata["remote"] ?? "origin",
                    error: errorDesc
                )
            default:
                break
            }
        }
    }

    static func fetch(remote: String) -> TrackingInfo {
        TrackingInfo(operation: "fetch", metadata: ["remote": remote])
    }

    static func pull(branch: String, remote: String) -> TrackingInfo {
        TrackingInfo(operation: "pull", metadata: ["branch": branch, "remote": remote])
    }

    static func push(branch: String, remote: String) -> TrackingInfo {
        TrackingInfo(operation: "push", metadata: ["branch": branch, "remote": remote])
    }
}

enum GitOperationError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        }
    }
}
