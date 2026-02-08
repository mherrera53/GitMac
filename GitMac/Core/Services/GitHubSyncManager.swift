//
//  GitHubSyncManager.swift
//  GitMac
//
//  Centralized manager for synchronizing GitHub operations across all views
//

import SwiftUI
import Combine

/// Centralized manager that broadcasts GitHub operation completions to sync all UI elements
@MainActor
class GitHubSyncManager: ObservableObject {
    static let shared = GitHubSyncManager()

    /// Current sync state
    @Published private(set) var isSyncing = false

    /// Last sync timestamp
    @Published private(set) var lastSync: Date?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupAutoSync()
    }

    // MARK: - Setup

    private func setupAutoSync() {
        // Auto-refresh every 2 minutes for background sync
        Timer.publish(every: 120, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.performBackgroundSync() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Call this after any successful GitHub operation to trigger full sync
    func notifyOperationCompleted(type: GitHubOperationType, details: String? = nil) {
        lastSync = Date()

        // Post notification for all views to refresh
        NotificationCenter.default.post(
            name: .gitHubOperationCompleted,
            object: GitHubOperationInfo(type: type, details: details)
        )

        // Also post specific notifications based on operation type
        switch type {
        case .pullRequestCreated, .pullRequestMerged, .pullRequestClosed:
            NotificationCenter.default.post(name: .pullRequestCreated, object: nil)
        case .push, .pull, .fetch:
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: nil)
        case .workflowTriggered, .workflowCompleted:
            NotificationCenter.default.post(name: .workflowsDidUpdate, object: nil)
        case .branchCreated, .branchDeleted:
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: nil)
        case .releaseCreated:
            NotificationCenter.default.post(name: .releasesDidUpdate, object: nil)
        default:
            break
        }
    }

    /// Perform a full sync of all GitHub data
    func performFullSync() async {
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Trigger refresh of all components
        NotificationCenter.default.post(name: .gitHubOperationCompleted, object: nil)

        // Also refresh PR tracker
        await BranchPRTracker.shared.refresh()

        // Check branch protection for key branches
        await checkBranchProtection()

        lastSync = Date()
    }

    /// Check branch protection status for main/master branches via `gh` CLI
    /// Only checks key branches to avoid rate limiting
    private func checkBranchProtection() async {
        guard let repoPath = await AppState.shared.currentRepository?.path else { return }

        let shell = ShellExecutor()

        // Get the remote owner/repo slug from git remote
        let remoteResult = await shell.execute(
            "git", arguments: ["remote", "get-url", "origin"],
            workingDirectory: repoPath
        )
        guard remoteResult.exitCode == 0 else { return }

        let remoteURL = remoteResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slug = extractGitHubSlug(from: remoteURL) else { return }

        // Check protection for main branches only
        let branchesToCheck = ["main", "master", "develop"]

        for branchName in branchesToCheck {
            let result = await shell.execute(
                "gh", arguments: ["api", "repos/\(slug)/branches/\(branchName)/protection", "--silent"],
                workingDirectory: repoPath
            )

            let isProtected = result.exitCode == 0

            // Update branch protection status in AppState
            await MainActor.run {
                if let tab = AppState.shared.activeTab {
                    if let idx = tab.repository.branches.firstIndex(where: { $0.name == branchName }) {
                        tab.repository.branches[idx].isProtected = isProtected
                    }
                }
            }
        }
    }

    /// Extract owner/repo from a GitHub remote URL
    private func extractGitHubSlug(from url: String) -> String? {
        // SSH: git@github.com:owner/repo.git
        if url.contains("github.com:") {
            let parts = url.components(separatedBy: "github.com:")
            if let slug = parts.last?.replacingOccurrences(of: ".git", with: "") {
                return slug.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // HTTPS: https://github.com/owner/repo.git
        if url.contains("github.com/") {
            let parts = url.components(separatedBy: "github.com/")
            if let slug = parts.last?.replacingOccurrences(of: ".git", with: "") {
                return slug.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    /// Background sync (less aggressive) — skips entirely when app is inactive
    private func performBackgroundSync() async {
        guard !isSyncing else { return }
        // Don't waste CPU/network when the app isn't being used
        guard AppActivityManager.shared.isAppActive else { return }

        // Only refresh PR data in background
        await BranchPRTracker.shared.refresh()
    }
}

// MARK: - Types

enum GitHubOperationType: String {
    case pullRequestCreated = "pr_created"
    case pullRequestMerged = "pr_merged"
    case pullRequestClosed = "pr_closed"
    case pullRequestUpdated = "pr_updated"
    case push = "push"
    case pull = "pull"
    case fetch = "fetch"
    case branchCreated = "branch_created"
    case branchDeleted = "branch_deleted"
    case workflowTriggered = "workflow_triggered"
    case workflowCompleted = "workflow_completed"
    case releaseCreated = "release_created"
    case commentAdded = "comment_added"
    case reviewSubmitted = "review_submitted"
    case other = "other"
}

struct GitHubOperationInfo {
    let type: GitHubOperationType
    let details: String?
    let timestamp: Date

    init(type: GitHubOperationType, details: String? = nil) {
        self.type = type
        self.details = details
        self.timestamp = Date()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let gitHubOperationCompleted = Notification.Name("gitHubOperationCompleted")
    static let workflowsDidUpdate = Notification.Name("workflowsDidUpdate")
    static let releasesDidUpdate = Notification.Name("releasesDidUpdate")
}
