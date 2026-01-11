//
//  BranchPRTracker.swift
//  GitMac
//
//  Tracks pull requests associated with branches for real-time UI updates
//

import SwiftUI
import Combine

/// Tracks open pull requests for branches to enable real-time context menu updates
@MainActor
class BranchPRTracker: ObservableObject {
    static let shared = BranchPRTracker()

    /// Map of branch name to its open PR (if any)
    @Published private(set) var branchPRs: [String: GitHubPullRequest] = [:]

    /// All open PRs for the current repo
    @Published private(set) var openPRs: [GitHubPullRequest] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Current repo info
    private var owner: String = ""
    private var repo: String = ""
    private var repoPath: String = ""

    private let githubService = GitHubService()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotificationObservers()
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        // Refresh when PR is created
        NotificationCenter.default.publisher(for: .pullRequestCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)

        // Refresh when repository changes
        NotificationCenter.default.publisher(for: .repositoryDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let path = notification.object as? String {
                    Task { await self?.configure(forRepoAt: path) }
                }
            }
            .store(in: &cancellables)

        // Note: No periodic timer - PR data is refreshed after each git action
        // (push, pull, checkout, merge, delete) for immediate feedback
    }

    // MARK: - Configuration

    /// Configure tracker for a repository
    func configure(forRepoAt path: String) async {
        guard !path.isEmpty else { return }

        // Get GitHub remote info
        let engine = GitEngine()
        do {
            let remotes = try await engine.getRemotes(at: path)
            guard let githubRemote = remotes.first(where: { $0.isGitHub }),
                  let ownerRepo = githubRemote.ownerAndRepo else {
                clear()
                return
            }

            self.owner = ownerRepo.owner
            self.repo = ownerRepo.repo
            self.repoPath = path

            await refresh()
        } catch {
            print("BranchPRTracker: Failed to get remotes: \(error)")
            clear()
        }
    }

    /// Configure with explicit owner/repo
    func configure(owner: String, repo: String, repoPath: String) async {
        self.owner = owner
        self.repo = repo
        self.repoPath = repoPath
        await refresh()
    }

    // MARK: - Public API

    /// Get the PR associated with a branch (if any)
    func getPR(for branchName: String) -> GitHubPullRequest? {
        // Clean the branch name (remove "origin/" prefix if present)
        let cleanName = branchName.replacingOccurrences(of: "origin/", with: "")
        return branchPRs[cleanName.lowercased()]
    }

    /// Check if a branch has an open PR
    func hasPR(for branchName: String) -> Bool {
        return getPR(for: branchName) != nil
    }

    /// Refresh PR data from GitHub
    func refresh() async {
        guard !owner.isEmpty && !repo.isEmpty else { return }
        guard !isLoading else { return } // Prevent concurrent refresh

        isLoading = true
        defer { isLoading = false }

        do {
            let prs = try await githubService.listPullRequests(
                owner: owner,
                repo: repo,
                state: .open
            )

            openPRs = prs

            // Build branch -> PR mapping (keep the most recent PR per branch)
            var newBranchPRs: [String: GitHubPullRequest] = [:]
            for pr in prs {
                let branchKey = pr.head.ref.lowercased()
                // Keep the PR with the highest number (most recent)
                if let existing = newBranchPRs[branchKey] {
                    if pr.number > existing.number {
                        newBranchPRs[branchKey] = pr
                    }
                } else {
                    newBranchPRs[branchKey] = pr
                }
            }
            branchPRs = newBranchPRs

            // Post notification that PR data was updated
            NotificationCenter.default.post(name: .branchPRsDidUpdate, object: nil)

            print("BranchPRTracker: Loaded \(prs.count) PRs, mapped \(branchPRs.count) branches")
        } catch {
            print("BranchPRTracker: Failed to load PRs: \(error)")
        }
    }

    /// Merge a PR
    func mergePR(_ pr: GitHubPullRequest, method: MergeMethod) async throws {
        let branchKey = pr.head.ref.lowercased()

        // API call waits for response - when it returns, PR is merged
        try await githubService.mergePullRequest(
            owner: owner,
            repo: repo,
            number: pr.number,
            mergeMethod: method
        )

        // Remove PR from local cache (API confirmed merge)
        // This triggers @Published update, which notifies all @ObservedObject observers
        branchPRs.removeValue(forKey: branchKey)
        openPRs.removeAll { $0.number == pr.number }

        // Post notifications for other components
        NotificationCenter.default.post(name: .pullRequestMerged, object: pr)
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: repoPath)

        NotificationManager.shared.success(
            "PR #\(pr.number) merged",
            detail: "\(pr.title) merged with \(method.rawValue)"
        )
    }

    /// Clear all tracked data
    func clear() {
        branchPRs = [:]
        openPRs = []
        owner = ""
        repo = ""
        repoPath = ""
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let branchPRsDidUpdate = Notification.Name("branchPRsDidUpdate")
    static let repositoryDidChange = Notification.Name("repositoryDidChange")
    static let pullRequestMerged = Notification.Name("pullRequestMerged")
}
