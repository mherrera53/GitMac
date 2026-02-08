//
//  WorktreeManager.swift
//  GitMac
//
//  Centralized worktree state management with reactive updates
//

import SwiftUI
import Combine

/// Centralized manager for Git worktrees with reactive UI updates
@MainActor
class WorktreeManager: ObservableObject {
    static let shared = WorktreeManager()

    // MARK: - Published State

    @Published private(set) var worktrees: [Worktree] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var currentRepoPath: String?

    /// Map of branch names to their worktree paths (for quick lookup)
    @Published private(set) var branchWorktreeMap: [String: String] = [:]

    // MARK: - Private Properties

    private let engine = GitEngine()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotificationObservers()
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        // Refresh when repository changes
        NotificationCenter.default.publisher(for: .repositoryDidRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let path = notification.object as? String {
                    Task { await self?.refresh(at: path) }
                }
            }
            .store(in: &cancellables)

        // Refresh when worktree operations complete
        NotificationCenter.default.publisher(for: .worktreeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    if let path = self?.currentRepoPath {
                        await self?.refresh(at: path)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Refresh worktree list for a repository
    func refresh(at path: String?) async {
        guard let path = path else {
            worktrees = []
            branchWorktreeMap = [:]
            currentRepoPath = nil
            return
        }

        currentRepoPath = path
        isLoading = true
        error = nil

        do {
            let list = try await engine.listWorktrees(at: path)
            worktrees = list
            rebuildBranchMap()
        } catch {
            self.error = error.localizedDescription
            worktrees = []
            branchWorktreeMap = [:]
        }

        isLoading = false
    }

    /// Check if a branch has an active worktree
    func hasWorktree(for branchName: String) -> Bool {
        branchWorktreeMap[branchName] != nil
    }

    /// Get the worktree for a branch (if any)
    func getWorktree(for branchName: String) -> Worktree? {
        guard let path = branchWorktreeMap[branchName] else { return nil }
        return worktrees.first { $0.path == path }
    }

    /// Get the main worktree
    var mainWorktree: Worktree? {
        worktrees.first { $0.isMain }
    }

    /// Get linked (non-main) worktrees
    var linkedWorktrees: [Worktree] {
        worktrees.filter { !$0.isMain }
    }

    /// Get prunable (stale) worktrees
    var prunableWorktrees: [Worktree] {
        worktrees.filter { $0.isPrunable }
    }

    // MARK: - Worktree Operations

    /// Add a new worktree
    func addWorktree(
        path: String,
        branch: String? = nil,
        newBranch: String? = nil,
        detach: Bool = false,
        force: Bool = false
    ) async throws -> Worktree {
        guard let repoPath = currentRepoPath else {
            throw WorktreeError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let worktree = try await engine.addWorktree(
                path: path,
                branch: branch,
                newBranch: newBranch,
                force: force,
                detach: detach,
                at: repoPath
            )

            await refresh(at: repoPath)
            NotificationCenter.default.post(name: .worktreeDidChange, object: worktree)
            NotificationManager.shared.success("Worktree created", detail: worktree.name)

            return worktree
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to create worktree", detail: error.localizedDescription)
            throw error
        }
    }

    /// Add worktree for a specific commit (detached HEAD)
    func addWorktreeFromCommit(path: String, commitSHA: String) async throws -> Worktree {
        guard let repoPath = currentRepoPath else {
            throw WorktreeError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let worktree = try await engine.addWorktree(
                path: path,
                branch: commitSHA,
                newBranch: nil,
                force: false,
                detach: true,
                at: repoPath
            )

            await refresh(at: repoPath)
            NotificationCenter.default.post(name: .worktreeDidChange, object: worktree)
            NotificationManager.shared.success("Worktree created", detail: "At commit \(String(commitSHA.prefix(7)))")

            return worktree
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to create worktree", detail: error.localizedDescription)
            throw error
        }
    }

    /// Remove a worktree
    func removeWorktree(_ worktree: Worktree, force: Bool = false) async throws {
        guard let repoPath = currentRepoPath else {
            throw WorktreeError.noRepository
        }

        guard !worktree.isMain else {
            throw WorktreeError.cannotRemoveMain
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await engine.removeWorktree(path: worktree.path, force: force, at: repoPath)
            await refresh(at: repoPath)
            NotificationCenter.default.post(name: .worktreeDidChange, object: nil)
            NotificationManager.shared.success("Worktree removed", detail: worktree.name)
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to remove worktree", detail: error.localizedDescription)
            throw error
        }
    }

    /// Lock a worktree to prevent removal
    func lockWorktree(_ worktree: Worktree, reason: String? = nil) async throws {
        guard let repoPath = currentRepoPath else {
            throw WorktreeError.noRepository
        }

        do {
            try await engine.lockWorktree(path: worktree.path, reason: reason, at: repoPath)
            await refresh(at: repoPath)
            NotificationManager.shared.success("Worktree locked", detail: worktree.name)
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to lock worktree", detail: error.localizedDescription)
            throw error
        }
    }

    /// Unlock a worktree
    func unlockWorktree(_ worktree: Worktree) async throws {
        guard let repoPath = currentRepoPath else {
            throw WorktreeError.noRepository
        }

        do {
            try await engine.unlockWorktree(path: worktree.path, at: repoPath)
            await refresh(at: repoPath)
            NotificationManager.shared.success("Worktree unlocked", detail: worktree.name)
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to unlock worktree", detail: error.localizedDescription)
            throw error
        }
    }

    /// Prune stale worktrees
    func pruneWorktrees(dryRun: Bool = false) async throws -> [String] {
        guard let repoPath = currentRepoPath else {
            throw WorktreeError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let pruned = try await engine.pruneWorktrees(dryRun: dryRun, at: repoPath)

            if !dryRun {
                await refresh(at: repoPath)
                NotificationCenter.default.post(name: .worktreeDidChange, object: nil)
                if !pruned.isEmpty {
                    NotificationManager.shared.success("Pruned worktrees", detail: "\(pruned.count) stale worktree(s) removed")
                }
            }

            return pruned
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to prune worktrees", detail: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Private Helpers

    private func rebuildBranchMap() {
        var map: [String: String] = [:]
        for worktree in worktrees {
            if let branch = worktree.branch {
                map[branch] = worktree.path
            }
        }
        branchWorktreeMap = map
    }
}

// MARK: - Worktree Errors

enum WorktreeError: LocalizedError {
    case noRepository
    case cannotRemoveMain
    case worktreeExists(String)
    case branchInUse(String)

    var errorDescription: String? {
        switch self {
        case .noRepository:
            return "No repository is currently open"
        case .cannotRemoveMain:
            return "Cannot remove the main worktree"
        case .worktreeExists(let path):
            return "Worktree already exists at \(path)"
        case .branchInUse(let branch):
            return "Branch '\(branch)' is already checked out in another worktree"
        }
    }
}

// Note: Notification.Name extensions for worktrees are defined in IntegrationHelpers.swift
