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

        lastSync = Date()
    }

    /// Background sync (less aggressive)
    private func performBackgroundSync() async {
        guard !isSyncing else { return }

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
