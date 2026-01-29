import Foundation
import Combine

@MainActor
class BranchStateManager: ObservableObject {
    @Published var localBranches: [Branch] = []
    @Published var remoteBranches: [Branch] = []
    @Published var currentBranch: Branch?
    @Published var isCheckingOut: Bool = false
    @Published var checkoutProgress: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?

    // PR Integration - synchronized with BranchPRTracker
    @Published var branchPRs: [String: GitHubPullRequest] = [:]

    private let engine = GitEngine()
    private var currentRepoPath: String?
    
    func configure(repoPath: String) async {
        self.currentRepoPath = repoPath
        self.objectWillChange.send()

        await refresh()

        // Configure PR tracker and sync PRs
        await BranchPRTracker.shared.configure(forRepoAt: repoPath)
        await refreshPRs()

        self.objectWillChange.send()
    }
    
    func refresh() async {
        guard let path = currentRepoPath else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let branches = try await engine.getBranches(at: path)
            let remoteBranches = try await engine.getRemoteBranches(at: path)

            self.localBranches = branches.sorted { lhs, rhs in
                if lhs.isHead { return true }
                if rhs.isHead { return false }
                return lhs.name < rhs.name
            }

            self.remoteBranches = remoteBranches.sorted { $0.name < $1.name }
            self.currentBranch = branches.first { $0.isHead }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func checkoutBranch(_ branch: Branch) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }
        
        isCheckingOut = true
        isLoading = true
        checkoutProgress = "Checking out \(branch.name)..."
        defer {
            isCheckingOut = false
            isLoading = false
            checkoutProgress = ""
        }
        
        try await engine.checkout(branch.name, at: path)
        
        checkoutProgress = "Updating branch list..."
        // refresh() ya obtiene el estado correcto desde Git
        await refresh()
        
        NotificationCenter.default.post(name: .branchDidCheckout, object: branch.name)
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)

        await refreshPRs()
    }
    
    func checkoutBranchWithAutoStash(_ branch: Branch) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let shell = ShellExecutor()
        
        let stashResult = await shell.execute(
            "git",
            arguments: ["stash", "push", "-u", "-m", "Auto-stash for checkout to \(branch.name)"],
            workingDirectory: path
        )
        
        let didStash = stashResult.isSuccess && !stashResult.stdout.contains("No local changes")
        
        do {
            try await engine.checkout(branch.name, at: path)
            
            if didStash {
                let popResult = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )
                
                if !popResult.isSuccess {
                    error = "Checkout successful but stash pop failed. Your changes are in stash."
                }
            }
            
            // refresh() gets the correct state from Git
            await refresh()
            
            NotificationCenter.default.post(name: .branchDidCheckout, object: branch.name)
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            
        } catch {
            if didStash {
                _ = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )
            }
            throw error
        }
    }
    
    func createBranch(name: String, from: String, checkout: Bool) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }
        
        isLoading = true
        defer { isLoading = false }
        
        _ = try await engine.createBranch(named: name, from: from, checkout: checkout, at: path)
        
        await refresh()
        
        if checkout {
            NotificationCenter.default.post(name: .branchDidCheckout, object: name)
        }
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
    }
    
    func deleteBranch(_ branch: Branch, force: Bool = false) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await engine.deleteBranch(named: branch.name, force: force, at: path)
        
        await refresh()
        
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)

        await refreshPRs()
    }

    func checkUncommittedChanges() async -> [String] {
        guard let path = currentRepoPath else { return [] }
        let result = await ShellExecutor().execute("git", arguments: ["status", "--porcelain"], workingDirectory: path)
        guard result.isSuccess else { return [] }

        return result.stdout
            .components(separatedBy: CharacterSet.newlines)
            .filter { !$0.isEmpty }
            .map { line in
                let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: CharacterSet.whitespaces)
            }
    }

    // MARK: - Remote Branch Operations

    /// Checkout a remote branch by creating a local tracking branch
    func checkoutRemote(_ branch: Branch) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }

        isCheckingOut = true
        isLoading = true
        let localName = branch.displayName
        checkoutProgress = "Creating local branch '\(localName)' from '\(branch.name)'..."
        defer {
            isCheckingOut = false
            isLoading = false
            checkoutProgress = ""
        }

        _ = try await engine.createBranch(named: localName, from: branch.name, checkout: true, at: path)
        await refresh()

        NotificationCenter.default.post(name: .branchDidCheckout, object: localName)
        NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)

        await refreshPRs()
    }

    // MARK: - Merge & Rebase

    /// Merge a branch into the current branch
    func merge(_ branch: Branch, noFastForward: Bool = false) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }

        let currentBranchName = currentBranch?.name ?? "HEAD"
        isLoading = true
        defer { isLoading = false }

        do {
            try await engine.merge(branch: branch.name, options: MergeOptions(noFastForward: noFastForward), at: path)
            await refresh()

            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            await refreshPRs()

            RemoteOperationTracker.shared.recordMerge(
                success: true,
                sourceBranch: branch.name,
                targetBranch: currentBranchName
            )
        } catch {
            RemoteOperationTracker.shared.recordMerge(
                success: false,
                sourceBranch: branch.name,
                targetBranch: currentBranchName,
                error: error.localizedDescription
            )
            throw error
        }
    }

    /// Rebase current branch onto the specified branch
    func rebase(onto branch: Branch) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        try await engine.rebase(onto: branch.name, at: path)
        await refresh()

        NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
    }

    // MARK: - Push & Pull

    /// Push a branch to remote
    func push(_ branch: Branch) async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let options = PushOptions(branch: branch.name)
            try await engine.push(options: options, at: path)
            await refresh()

            NotificationCenter.default.post(name: .remoteOperationCompleted, object: "push")
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            GitHubSyncManager.shared.notifyOperationCompleted(type: .push, details: branch.name)

            await refreshPRs()

            NotificationManager.shared.success(
                "Pushed '\(branch.name)'",
                detail: "Changes pushed to remote"
            )

            RemoteOperationTracker.shared.recordPush(
                success: true,
                branch: branch.name,
                remote: "origin"
            )
        } catch let gitError as GitError {
            RemoteOperationTracker.shared.recordPush(
                success: false,
                branch: branch.name,
                remote: "origin",
                error: gitError.localizedDescription
            )
            if let fix = gitError.suggestedFix {
                NotificationManager.shared.errorWithFix(
                    "Push failed",
                    detail: gitError.localizedDescription,
                    fixTitle: fix.title,
                    fixHint: fix.hint
                ) {
                    Task {
                        if fix.command == "git pull --rebase" {
                            try? await self.engine.pull(options: PullOptions(rebase: true), at: path)
                            NotificationManager.shared.info("Pulled with rebase", detail: "Try pushing again")
                        }
                    }
                }
            } else {
                NotificationManager.shared.error("Push failed", detail: gitError.localizedDescription)
            }
            throw gitError
        } catch {
            RemoteOperationTracker.shared.recordPush(
                success: false,
                branch: branch.name,
                remote: "origin",
                error: error.localizedDescription
            )
            NotificationManager.shared.error("Push failed", detail: error.localizedDescription)
            throw error
        }
    }

    /// Pull from remote for the current branch
    func pull() async throws {
        guard let path = currentRepoPath else {
            throw GitServiceError.noRepository
        }

        let branchName = currentBranch?.name ?? "HEAD"
        isLoading = true
        defer { isLoading = false }

        do {
            try await engine.pull(at: path)
            await refresh()

            NotificationCenter.default.post(name: .remoteOperationCompleted, object: "pull")
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            GitHubSyncManager.shared.notifyOperationCompleted(type: .pull, details: branchName)

            await refreshPRs()

            NotificationManager.shared.success(
                "Pulled '\(branchName)'",
                detail: "Updated from remote"
            )

            RemoteOperationTracker.shared.recordPull(
                success: true,
                branch: branchName,
                remote: "origin"
            )
        } catch let gitError as GitError {
            RemoteOperationTracker.shared.recordPull(
                success: false,
                branch: branchName,
                remote: "origin",
                error: gitError.localizedDescription
            )
            if let fix = gitError.suggestedFix {
                NotificationManager.shared.errorWithFix(
                    "Pull failed",
                    detail: gitError.localizedDescription,
                    fixTitle: fix.title,
                    fixHint: fix.hint
                ) {
                    Task {
                        if fix.command == "git stash" {
                            _ = try? await self.engine.stash(at: path)
                            NotificationManager.shared.success("Changes stashed", detail: "Try pulling again")
                        }
                    }
                }
            } else {
                NotificationManager.shared.error("Pull failed", detail: gitError.localizedDescription)
            }
            throw gitError
        } catch {
            RemoteOperationTracker.shared.recordPull(
                success: false,
                branch: branchName,
                remote: "origin",
                error: error.localizedDescription
            )
            NotificationManager.shared.error("Pull failed", detail: error.localizedDescription)
            throw error
        }
    }

    // MARK: - PR Integration

    /// Refresh PRs from BranchPRTracker and sync to local state
    func refreshPRs() async {
        await BranchPRTracker.shared.refresh()
        self.branchPRs = BranchPRTracker.shared.branchPRs
    }

    /// Get the PR associated with a branch (if any)
    func getPR(for branchName: String) -> GitHubPullRequest? {
        let cleanName = branchName.replacingOccurrences(of: "origin/", with: "").lowercased()
        return branchPRs[cleanName]
    }

    /// Check if a branch has an open PR
    func hasPR(for branchName: String) -> Bool {
        return getPR(for: branchName) != nil
    }
}
