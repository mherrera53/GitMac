import Foundation
import SwiftUI

/// Centralized handler for all git operations
/// Eliminates duplicate code patterns and provides consistent error handling and tracking
@MainActor
class GitOperationHandler: ObservableObject {
    @Published var isOperationInProgress = false
    @Published var operationMessage = ""
    @Published var pendingPushConfirmation: PushConfirmation?

    weak var appState: AppState?
    private static var activeRepositoryPaths: Set<String> = []

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
        shouldRefresh: Bool = true,
        allowsRetry: Bool = false,
        showsSuccess: Bool = true,
        onFailure: ((Error) -> Bool)? = nil
    ) async {
        let repositoryPath = appState?.currentRepository?.path
        let operationKey = repositoryPath ?? "<no-selected-repository>"
        guard !isOperationInProgress, !Self.activeRepositoryPaths.contains(operationKey) else {
            NotificationManager.shared.info("An operation is already running", detail: "Wait for it to finish before starting another action in this repository.")
            return
        }
        Self.activeRepositoryPaths.insert(operationKey)
        isOperationInProgress = true
        operationMessage = message
        defer {
            Self.activeRepositoryPaths.remove(operationKey)
            isOperationInProgress = false
        }
        let actionName = message.replacingOccurrences(of: "...", with: "").trimmingCharacters(in: .whitespaces)
        let retry: (() async -> Void)? = allowsRetry ? { [weak self] in
            guard let self else { return }
            guard self.appState?.currentRepository?.path == repositoryPath else {
                NotificationManager.shared.info("Repository changed", detail: "Open the original repository and run the action there.")
                return
            }
            await self.execute(operation: operation, message: message, onSuccess: onSuccess,
                tracking: tracking, shouldRefresh: shouldRefresh, allowsRetry: allowsRetry,
                showsSuccess: showsSuccess, onFailure: onFailure)
        } : nil
        NotificationManager.shared.recordAction(actionName, retry: retry)
        do {
            try await operation()
            if appState?.currentRepository?.path == repositoryPath {
                if shouldRefresh { await appState?.refresh() }
                await onSuccess?()
            }
            tracking?.recordSuccess()
            if showsSuccess { NotificationManager.shared.success(actionName, detail: "Completed successfully") }
        } catch is CancellationError {
            NotificationManager.shared.info("Operation cancelled")
        } catch {
            tracking?.recordFailure(error)
            if onFailure?(error) == true { return }
            if appState?.currentRepository?.path == repositoryPath {
                appState?.errorMessage = "\(actionName) failed: \(error.localizedDescription)"
            }
            if let retry {
                NotificationManager.shared.errorWithFix("\(actionName) failed", detail: error.localizedDescription,
                    fixTitle: "Retry \(actionName)", fixHint: "Retry only in the original repository",
                    fixAction: { Task { await retry() } })
            } else {
                NotificationManager.shared.error("\(actionName) failed", detail: error.localizedDescription)
            }
        }
    }

    // MARK: - Remote Operations

    func handleFetch() async {
        guard appState?.currentRepository != nil else { return }

        await execute(
            operation: {
                try await self.appState?.gitService.fetch()
            },
            message: "Fetching from remote...",
            tracking: .fetch(remote: "origin"),
            allowsRetry: true
        )
    }

    func handlePull(rebase: Bool = false, preservingLocalChanges: Bool = false,
                    expectedRepository: String? = nil, expectedBranch: String? = nil) async {
        guard let repo = appState?.currentRepository else { return }
        let branchName = repo.currentBranch?.name ?? "unknown"
        guard (expectedRepository == nil || expectedRepository == repo.path),
              (expectedBranch == nil || expectedBranch == branchName) else {
            NotificationManager.shared.info("Repository or branch changed", detail: "Return to the original branch and start Pull again.")
            return
        }
        var result: AutoStashResult?
        await execute(
            operation: {
                guard let service = self.appState?.gitService else { throw GitServiceError.noRepository }
                if preservingLocalChanges { result = try await service.pullWithAutoStash(rebase: rebase) }
                else { try await service.pull(rebase: rebase) }
            },
            message: "Pulling changes...",
            onSuccess: {
                if let result {
                    if result.isFullySuccessful { NotificationManager.shared.success("Pull completed", detail: result.message) }
                    else { NotificationManager.shared.errorWithFix("Local changes need attention", detail: result.message,
                        fixTitle: "Open saved backup", fixHint: "Review the stash before applying anything again") {
                            guard self.appState?.currentRepository?.path == repo.path else {
                                NotificationManager.shared.info("Repository changed", detail: "Open the original repository to review its backup.")
                                return
                            }
                            NotificationCenter.default.post(name: .showStashes, object: nil)
                        }
                    }
                }
            },
            tracking: .pull(branch: branchName, remote: "origin"),
            showsSuccess: !preservingLocalChanges,
            onFailure: { error in
                guard !preservingLocalChanges, PullRecovery.canSaveChanges(after: error) else { return false }
                NotificationManager.shared.errorWithFix("Pull paused to protect your changes",
                    detail: "Save your local changes, update this branch, then restore them with their staged selection. A backup will remain in Stashes. You can also commit first.",
                    fixTitle: "Save changes and Pull", fixHint: "Includes untracked files; keeps a backup if restoration needs attention") {
                        Task { await self.handlePull(rebase: rebase, preservingLocalChanges: true,
                            expectedRepository: repo.path, expectedBranch: branchName) }
                    }
                return true
            }
        )
    }

    func handlePush(force: Bool = false, forceWithLease: Bool = false) async {
        Logger.debug("Push: handlePush called, appState=\(appState != nil), repo=\(appState?.currentRepository?.path ?? "nil")")
        guard let repo = appState?.currentRepository else {
            Logger.debug("Push: No current repository in appState")
            NotificationManager.shared.error("Push failed", detail: "No repository selected")
            return
        }
        let branchName = repo.currentBranch?.name ?? "unknown"
        Logger.debug("Push: branch=\(branchName), tracking=\(repo.currentBranch?.trackingBranch ?? "none")")

        // Check branch protection
        let protection = BranchProtectionService.shared
        let result = protection.evaluatePush(
            branchName: branchName,
            isForce: force,
            isForceWithLease: forceWithLease
        )

        Logger.debug("Push: protection result=\(result)")
        switch result {
        case .blocked(let reason, _):
            Logger.debug("Push: BLOCKED by protection: \(reason)")
            NotificationManager.shared.error("Push Blocked", detail: reason)
            return

        case .requiresConfirmation:
            // Show confirmation dialog — actual push happens in confirmPush()
            pendingPushConfirmation = PushConfirmation(
                branchName: branchName,
                result: result,
                onConfirm: { [weak self] in
                    guard let self else { return }
                    guard self.appState?.currentRepository?.path == repo.path,
                          self.appState?.currentRepository?.currentBranch?.name == branchName else {
                        self.pendingPushConfirmation = nil
                        NotificationManager.shared.error("Repository or branch changed", detail: "Review the current branch and start Push again.")
                        return
                    }
                    await self.executePush(branchName: branchName, force: force)
                },
                onCancel: { [weak self] in
                    self?.pendingPushConfirmation = nil
                }
            )
            return

        case .allowed:
            await executePush(branchName: branchName, force: force)
        }
    }

    /// Execute the actual push operation (called directly or after confirmation)
    func executePush(branchName: String, force: Bool = false) async {
        guard let repositoryPath = appState?.currentRepository?.path,
              appState?.currentRepository?.currentBranch?.name == branchName else {
            NotificationManager.shared.error("Push cancelled", detail: "Select the intended repository and branch, then try again.")
            return
        }
        guard !isOperationInProgress, !Self.activeRepositoryPaths.contains(repositoryPath) else {
            NotificationManager.shared.info("An operation is already running")
            return
        }
        Self.activeRepositoryPaths.insert(repositoryPath)
        defer {
            Self.activeRepositoryPaths.remove(repositoryPath)
            isOperationInProgress = false
        }
        isOperationInProgress = true
        operationMessage = "Pushing to remote..."
        pendingPushConfirmation = nil

        do {
            let sha = try await appState?.gitService.push(force: force) ?? ""
            let shortSHA = String(sha.prefix(7))

            if appState?.currentRepository?.path == repositoryPath { await appState?.refresh() }

            // Trigger GitHub and CodeBuild refresh after push
            NotificationCenter.default.post(name: .gitPushCompleted, object: branchName)

            // Track success
            TrackingInfo.push(branch: branchName, remote: "origin").recordSuccess()

            // Show success notification with SHA
            NotificationManager.shared.success(
                "Push completed",
                detail: "Branch '\(branchName)' pushed \u{2022} SHA: \(shortSHA)"
            )
        } catch {
            let errorMessage = "Push failed: \(error.localizedDescription)"
            if appState?.currentRepository?.path == repositoryPath { appState?.errorMessage = errorMessage }
            TrackingInfo.push(branch: branchName, remote: "origin").recordFailure(error)
            NotificationManager.shared.error("Push failed", detail: error.localizedDescription)
        }

        isOperationInProgress = false
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
                try await self.appState?.gitService.stashPop(index: 0)
            },
            message: "Popping stash..."
        )
    }

    func handlePopStash(index: Int) async {
        guard appState?.currentRepository != nil else { return }

        await execute(
            operation: {
                try await self.appState?.gitService.stashPop(index: index)
            },
            message: "Popping stash #\(index)..."
        )
    }

    func handleApplyStash(index: Int) async {
        guard appState?.currentRepository != nil else { return }

        await execute(
            operation: {
                try await self.appState?.gitService.stashApply(index: index)
            },
            message: "Applying stash #\(index)..."
        )
    }

    func handleDropStash(index: Int) async {
        guard appState?.currentRepository != nil else { return }

        await execute(
            operation: {
                try await self.appState?.gitService.stashDrop(index: index)
                try await self.appState?.gitService.refresh()
            },
            message: "Dropping stash #\(index)..."
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
        let shell = ShellExecutor.shared
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
        let shell = ShellExecutor.shared
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
