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
    @Published private(set) var isPerformingOperation = false
    @Published private(set) var error: String?
    @Published private(set) var currentRepoPath: String?

    /// Map of branch names to their worktree paths (for quick lookup)
    @Published private(set) var branchWorktreeMap: [String: String] = [:]

    // MARK: - Private Properties

    private let engine = GitEngine()
    private var cancellables = Set<AnyCancellable>()
    private var refreshGeneration = UUID()

    private init() {
        setupNotificationObservers()
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        // Refresh when repository changes
        NotificationCenter.default.publisher(for: .repositoryDidRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let path = notification.object as? String, path == self?.currentRepoPath {
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
        refreshGeneration = UUID()
        let request = refreshGeneration
        guard let path = path else {
            worktrees = []
            branchWorktreeMap = [:]
            currentRepoPath = nil
            isLoading = false
            error = nil
            return
        }

        if currentRepoPath != path { worktrees = []; branchWorktreeMap = [:] }
        currentRepoPath = path
        isLoading = true
        error = nil
        defer { if refreshGeneration == request { isLoading = false } }

        do {
            let list = try await engine.listWorktrees(at: path)
            guard !Task.isCancelled, refreshGeneration == request else { return }
            worktrees = list
            rebuildBranchMap()
        } catch {
            guard !Task.isCancelled, refreshGeneration == request else { return }
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
        force: Bool = false,
        repositoryPath: String? = nil
    ) async throws -> Worktree {
        guard let repoPath = repositoryPath ?? currentRepoPath else {
            throw WorktreeError.noRepository
        }

        try beginOperation()
        defer { isPerformingOperation = false }

        do {
            let worktree = try await engine.addWorktree(
                path: path,
                branch: branch,
                newBranch: newBranch,
                force: force,
                detach: detach,
                at: repoPath
            )

            if currentRepoPath == repoPath { await refresh(at: repoPath) }
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
    func addWorktreeFromCommit(path: String, commitSHA: String, repositoryPath: String? = nil) async throws -> Worktree {
        guard let repoPath = repositoryPath ?? currentRepoPath else {
            throw WorktreeError.noRepository
        }

        try beginOperation()
        defer { isPerformingOperation = false }

        do {
            let worktree = try await engine.addWorktree(
                path: path,
                branch: commitSHA,
                newBranch: nil,
                force: false,
                detach: true,
                at: repoPath
            )

            if currentRepoPath == repoPath { await refresh(at: repoPath) }
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
    func removeWorktree(_ worktree: Worktree, force: Bool = false, repositoryPath: String? = nil) async throws {
        guard let repoPath = repositoryPath ?? currentRepoPath else {
            throw WorktreeError.noRepository
        }

        guard !worktree.isMain else {
            throw WorktreeError.cannotRemoveMain
        }

        try beginOperation()
        defer { isPerformingOperation = false }

        do {
            let registered = try await engine.listWorktrees(at: repoPath)
            guard let current = registered.first(where: { $0.path == worktree.path }) else {
                throw GitError.worktreeRemoveFailed(worktree.path, "This folder is no longer registered. Refresh the list.")
            }
            guard !current.isMain else { throw WorktreeError.cannotRemoveMain }
            guard URL(fileURLWithPath: current.path).resolvingSymlinksInPath().path !=
                    URL(fileURLWithPath: repoPath).resolvingSymlinksInPath().path else {
                throw WorktreeError.cannotRemoveCurrent
            }
            guard !current.isLocked else { throw WorktreeError.locked }
            guard !current.isDetached else { throw WorktreeError.detachedNeedsBranch }
            if !force {
                let status = try await engine.getStatus(at: current.path)
                guard !status.hasChanges else { throw WorktreeError.uncommitted }
            }
            try await engine.removeWorktree(path: current.path, force: force, at: repoPath)
            if currentRepoPath == repoPath { await refresh(at: repoPath) }
            NotificationCenter.default.post(name: .worktreeDidChange, object: nil)
            NotificationManager.shared.success("Worktree removed", detail: worktree.name)
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to remove worktree", detail: error.localizedDescription)
            throw error
        }
    }

    /// Lock a worktree to prevent removal
    func lockWorktree(_ worktree: Worktree, reason: String? = nil, repositoryPath: String? = nil) async throws {
        guard let repoPath = repositoryPath ?? currentRepoPath else {
            throw WorktreeError.noRepository
        }

        try beginOperation()
        defer { isPerformingOperation = false }

        do {
            try await engine.lockWorktree(path: worktree.path, reason: reason, at: repoPath)
            if currentRepoPath == repoPath { await refresh(at: repoPath) }
            NotificationManager.shared.success("Worktree locked", detail: worktree.name)
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Failed to lock worktree", detail: error.localizedDescription)
            throw error
        }
    }

    /// Unlock a worktree
    func unlockWorktree(_ worktree: Worktree, repositoryPath: String? = nil) async throws {
        guard let repoPath = repositoryPath ?? currentRepoPath else {
            throw WorktreeError.noRepository
        }

        try beginOperation()
        defer { isPerformingOperation = false }

        do {
            try await engine.unlockWorktree(path: worktree.path, at: repoPath)
            if currentRepoPath == repoPath { await refresh(at: repoPath) }
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

        try beginOperation()
        defer { isPerformingOperation = false }

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

    private func beginOperation() throws {
        guard !isPerformingOperation else { throw WorktreeError.busy }
        isPerformingOperation = true
    }

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
    case busy
    case noRepository
    case cannotRemoveMain
    case worktreeExists(String)
    case branchInUse(String)
    case locked
    case uncommitted
    case detachedNeedsBranch
    case cannotRemoveCurrent

    var errorDescription: String? {
        switch self {
        case .busy: return "A worktree operation is still running. Wait for it to finish, then retry."
        case .cannotRemoveCurrent:
            return "Open another worktree before removing the current folder. Closing its tab does not delete files."
        case .locked:
            return "Unlock this worktree before removing it. Locking protects the folder from removal."
        case .uncommitted:
            return "This worktree has uncommitted or untracked files. Commit or stash them, then retry. No files were removed."
        case .detachedNeedsBranch:
            return "Create a branch for this detached revision before removing its worktree, so its commits remain reachable."
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
