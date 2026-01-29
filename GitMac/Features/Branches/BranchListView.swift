import SwiftUI

/// Branch list view with tree structure and context menus
struct BranchListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = BranchListViewModel()
    @ObservedObject private var prTracker = BranchPRTracker.shared
    @State private var searchText = ""
    @State private var showNewBranchSheet = false
    @State private var selectedBranch: Branch?
    @State private var showMergeSheet = false
    @State private var showRebaseSheet = false
    @State private var showDeleteAlert = false
    @State private var showPRSheet = false
    @State private var localBranchesExpanded = true
    @State private var remoteBranchesExpanded = true

    // Drag and drop state
    @State private var showDragDropActionSheet = false
    @State private var draggedBranch: Branch?
    @State private var targetBranch: Branch?

    // Cached filtered data (Performance optimization - Phase 0.2)
    @State private var cachedFilteredLocalBranches: [Branch] = []
    @State private var cachedFilteredRemoteBranches: [Branch] = []
    @State private var cachedGroupedRemoteBranches: [String: [Branch]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            branchListContent
        }
        .sheet(isPresented: $showNewBranchSheet) {
            NewBranchSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showMergeSheet) {
            if let branch = selectedBranch {
                MergeSheet(sourceBranch: branch, viewModel: viewModel)
                    .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showRebaseSheet) {
            if let branch = selectedBranch {
                RebaseSheet(ontoBranch: branch, viewModel: viewModel)
                    .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showPRSheet) {
            if let branch = selectedBranch {
                CreatePullRequestSheet(branch: branch, repoPath: viewModel.currentRepoPath)
                    .environmentObject(appState)
            }
        }
        .alert("Delete Branch", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let branch = selectedBranch {
                    Task { await viewModel.deleteBranch(branch) }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(selectedBranch?.name ?? "")'? This cannot be undone.")
        }
        .alert("Uncommitted Changes", isPresented: $viewModel.showUncommittedWarning) {
            Button("Cancel", role: .cancel) {
                viewModel.showUncommittedWarning = false
                viewModel.pendingCheckoutBranch = nil
            }
            Button("Stash & Checkout") {
                Task {
                    _ = try? await viewModel.stash()
                    await viewModel.forceCheckout()
                }
            }
            Button("Force Checkout", role: .destructive) {
                Task { await viewModel.forceCheckout() }
            }
        } message: {
            VStack {
                Text("You have uncommitted changes that may be lost:")
                Text(viewModel.uncommittedFiles.prefix(5).joined(separator: "\n"))
                    .font(.caption)
                if viewModel.uncommittedFiles.count > 5 {
                    Text("... and \(viewModel.uncommittedFiles.count - 5) more files")
                        .font(.caption)
                }
            }
        }
        .alert("Branch Action", isPresented: $showDragDropActionSheet) {
            Button("Cancel", role: .cancel) {
                draggedBranch = nil
                targetBranch = nil
            }
            Button("Create Pull Request") {
                performDragDropCreatePR()
            }
            Button("Merge") {
                performDragDropMerge()
            }
            Button("Rebase") {
                performDragDropRebase()
            }
        } message: {
            if let dragged = draggedBranch, let target = targetBranch {
                Text("What would you like to do with '\(dragged.name)' and '\(target.name)'?")
            }
        }
        .sheet(isPresented: $showPRSheet) {
            if let headBranch = draggedBranch, let baseBranch = targetBranch {
                CreatePullRequestSheet(
                    branch: headBranch,
                    defaultBaseBranch: baseBranch.name,
                    repoPath: viewModel.currentRepoPath
                )
                .environmentObject(appState)
            }
        }
        .task {
            // Inject branchManager reference
            viewModel.branchManager = appState.branchManager
            
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
                // Configure PR tracker for this repository
                await prTracker.configure(forRepoAt: repo.path)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
                // Reconfigure PR tracker when repo changes
                Task { await prTracker.configure(forRepoAt: repo.path) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .branchDidCheckout)) { _ in
            // Sync with branchManager after checkout
            if let manager = appState.branchManager {
                viewModel.syncFromManager(manager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pullRequestCreated)) { _ in
            // Refresh tracker when PR is created
            Task { await prTracker.refresh() }
        }
        // Note: BranchRow now observes PRTracker directly via @ObservedObject
        // so it will automatically update when branchPRs changes
        // Phase 0.2: Cache updates for performance
        .onChange(of: searchText) { _, newValue in
            updateFilterCache()
        }
        .onChange(of: viewModel.localBranches) { _, _ in
            updateFilterCache()
        }
        .onChange(of: viewModel.remoteBranches) { _, _ in
            updateFilterCache()
        }
        .onAppear {
            // Initialize cache on first appear
            updateFilterCache()
        }
        .onDisappear {
            // Clear caches to free memory
            cachedFilteredLocalBranches.removeAll()
            cachedFilteredRemoteBranches.removeAll()
            cachedGroupedRemoteBranches.removeAll()
        }
    }

    // MARK: - Cache Management

    private func updateFilterCache() {
        // Cache filtered local branches
        if searchText.isEmpty {
            cachedFilteredLocalBranches = viewModel.localBranches
        } else {
            cachedFilteredLocalBranches = viewModel.localBranches.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Cache filtered remote branches
        if searchText.isEmpty {
            cachedFilteredRemoteBranches = viewModel.remoteBranches
        } else {
            cachedFilteredRemoteBranches = viewModel.remoteBranches.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Cache grouped remote branches
        cachedGroupedRemoteBranches = Dictionary(grouping: cachedFilteredRemoteBranches) { branch in
            branch.remoteName ?? "origin"
        }
    }

    // MARK: - Subviews

    private var searchHeader: some View {
        HStack {
            // Use DS Search Field component
            DSSearchField(
                placeholder: "Search branches...",
                text: $searchText
            )

            DSIconButton(iconName: "plus", variant: .ghost, size: .sm) {
                showNewBranchSheet = true
            }
            .help("New branch")
        }
        .padding(DesignTokens.Spacing.sm)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var branchListContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // All branches in unified list - local first, then remotes
                ForEach(allBranches) { branch in
                    branchRowView(for: branch)
                }
            }
        }
    }

    /// Combined list: local branches first (HEAD at top), then remote branches
    private var allBranches: [Branch] {
        var result: [Branch] = []

        // Add local branches (HEAD first)
        let locals = filteredLocalBranches.sorted { lhs, rhs in
            if lhs.isHead { return true }
            if rhs.isHead { return false }
            return lhs.name < rhs.name
        }
        result.append(contentsOf: locals)

        // Add remote branches (grouped by remote, sorted)
        let remotes = filteredRemoteBranches.sorted { $0.name < $1.name }
        result.append(contentsOf: remotes)

        return result
    }


    private func branchRowView(for branch: Branch) -> some View {
        // BranchRow now observes PRTracker directly - no need to pass PR as parameter
        BranchRow(
            branch: branch,
            isSelected: selectedBranch?.id == branch.id,
            onSelect: { selectedBranch = branch },
            onCheckout: {
                // Use appropriate checkout for local vs remote
                if branch.isRemote {
                    await viewModel.checkoutRemote(branch)
                } else {
                    await viewModel.checkout(branch)
                }
                // PR refresh is handled by branchManager
            },
            onMerge: branch.isRemote ? nil : {
                selectedBranch = branch
                showMergeSheet = true
            },
            onDelete: branch.isRemote ? nil : {
                selectedBranch = branch
                showDeleteAlert = true
            },
            onPush: branch.isRemote ? nil : {
                await viewModel.push(branch)
                // PR refresh is handled by branchManager
            },
            onPull: branch.isRemote ? nil : {
                await viewModel.pull(branch)
                // PR refresh is handled by branchManager
            },
            onRebase: branch.isRemote ? nil : {
                selectedBranch = branch
                showRebaseSheet = true
            },
            // PR actions (BranchRow gets PR from tracker automatically)
            onCreatePR: branch.isRemote ? nil : {
                selectedBranch = branch
                showPRSheet = true
            },
            onViewPR: { prItem in
                // Open PR in browser
                if let url = URL(string: prItem.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            },
            onMergePR: { prItem, method in
                do {
                    try await prTracker.mergePR(prItem, method: method)
                } catch {
                    NotificationManager.shared.error(
                        "Merge failed",
                        detail: error.localizedDescription
                    )
                }
            },
            onBranchDropped: { droppedBranch in
                handleBranchDrop(dragged: droppedBranch, onto: branch)
            }
        )
    }

    private func remoteGroupView(for remote: String) -> some View {
        DisclosureGroup {
            ForEach(groupedRemoteBranches[remote] ?? []) { branch in
                RemoteBranchRow(
                    branch: branch,
                    isSelected: selectedBranch?.id == branch.id,
                    onSelect: { selectedBranch = branch },
                    onCheckout: { Task { await viewModel.checkoutRemote(branch) } }
                )
            }
        } label: {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(AppTheme.warning)
                Text(remote)
                    .fontWeight(.medium)
                Text("(\(groupedRemoteBranches[remote]?.count ?? 0))")
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    // MARK: - Filtered Data (Cached for performance)

    var filteredLocalBranches: [Branch] {
        cachedFilteredLocalBranches
    }

    var filteredRemoteBranches: [Branch] {
        cachedFilteredRemoteBranches
    }

    var groupedRemoteBranches: [String: [Branch]] {
        cachedGroupedRemoteBranches
    }

    // MARK: - Drag and Drop Handlers

    private func handleBranchDrop(dragged: Branch, onto target: Branch) {
        // Find the actual branch objects from the viewModel's list
        guard let actualDragged = viewModel.localBranches.first(where: { $0.name == dragged.name }),
              let actualTarget = viewModel.localBranches.first(where: { $0.name == target.name }) else {
            return
        }

        draggedBranch = actualDragged
        targetBranch = actualTarget
        showDragDropActionSheet = true
    }

    private func performDragDropMerge() {
        guard let dragged = draggedBranch, let target = targetBranch else { return }

        Task {
            // First checkout the target branch
            await viewModel.checkout(target)

            // Then merge the dragged branch into it
            await viewModel.merge(dragged)

            // Clear the state
            draggedBranch = nil
            targetBranch = nil
        }
    }

    private func performDragDropRebase() {
        guard let dragged = draggedBranch, let target = targetBranch else { return }

        Task {
            // First checkout the target branch
            await viewModel.checkout(target)

            // Then rebase onto the dragged branch
            await viewModel.rebase(onto: dragged)

            // Clear the state
            draggedBranch = nil
            targetBranch = nil
        }
    }

    private func performDragDropCreatePR() {
        // Open PR sheet with branches pre-filled
        showPRSheet = true
    }
}


// MARK: - View Model

@MainActor
class BranchListViewModel: ObservableObject {
    @Published var localBranches: [Branch] = []
    @Published var remoteBranches: [Branch] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var uncommittedFiles: [String] = []
    @Published var showUncommittedWarning = false
    @Published var pendingCheckoutBranch: Branch?

    let gitService = GitService()
    private let engine = GitEngine()

    // Reference to the app's branch state manager (single source of truth)
    weak var branchManager: BranchStateManager?

    /// Current repository path - set when loading branches
    private(set) var currentRepoPath: String?

    // MARK: - Data Loading

    func loadBranches(from repo: Repository) {
        currentRepoPath = repo.path
        // Sync with branchManager if available
        if let manager = branchManager {
            syncFromManager(manager)
        } else {
            // Fallback to repository data
            localBranches = repo.branches.sorted { lhs, rhs in
                if lhs.isHead { return true }
                if rhs.isHead { return false }
                return lhs.name < rhs.name
            }
            remoteBranches = repo.remoteBranches.sorted { $0.name < $1.name }
        }
    }

    /// Sync branches from BranchStateManager
    func syncFromManager(_ manager: BranchStateManager) {
        localBranches = manager.localBranches
        remoteBranches = manager.remoteBranches
    }

    // MARK: - Checkout Operations

    func checkout(_ branch: Branch) async {
        // Check for uncommitted changes first
        let changes = await checkUncommittedChanges()

        if !changes.isEmpty {
            pendingCheckoutBranch = branch
            uncommittedFiles = changes
            showUncommittedWarning = true

            let fileList = changes.prefix(5).joined(separator: "\n")
            let moreFiles = changes.count > 5 ? "\n... and \(changes.count - 5) more" : ""

            NotificationManager.shared.warning(
                "Uncommitted changes in \(changes.count) file(s)",
                detail: "Files:\n\(fileList)\(moreFiles)\n\nStash changes to proceed with checkout?"
            )
        } else {
            await performCheckout(branch)
        }
    }

    func forceCheckout() async {
        guard let branch = pendingCheckoutBranch else { return }

        // Use branchManager if available
        if let manager = branchManager {
            do {
                try await manager.checkoutBranchWithAutoStash(branch)
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            await performCheckoutWithAutoStash(branch.name)
        }

        showUncommittedWarning = false
        pendingCheckoutBranch = nil
    }

    private func performCheckout(_ branch: Branch) async {
        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager if available
        if let manager = branchManager {
            do {
                try await manager.checkoutBranch(branch)
                syncFromManager(manager)
                NotificationManager.shared.success("Switched to '\(branch.name)'", detail: nil)
            } catch let gitError as GitError {
                self.error = gitError.localizedDescription
                handleCheckoutError(gitError)
            } catch {
                self.error = error.localizedDescription
                NotificationManager.shared.error("Checkout failed", detail: error.localizedDescription)
            }
        } else {
            // Fallback to direct engine call
            guard let path = currentRepoPath else {
                self.error = "No repository path available"
                return
            }
            do {
                try await engine.checkout(branch.name, at: path)
                NotificationCenter.default.post(name: .branchDidCheckout, object: branch.name)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                NotificationManager.shared.success("Switched to '\(branch.name)'", detail: nil)
                await BranchPRTracker.shared.refresh()
            } catch let gitError as GitError {
                self.error = gitError.localizedDescription
                handleCheckoutError(gitError)
            } catch {
                self.error = error.localizedDescription
                NotificationManager.shared.error("Checkout failed", detail: error.localizedDescription)
            }
        }
    }

    private func handleCheckoutError(_ gitError: GitError) {
        if let fix = gitError.suggestedFix {
            NotificationManager.shared.errorWithFix(
                "Checkout failed",
                detail: gitError.localizedDescription,
                fixTitle: fix.title,
                fixHint: fix.hint
            ) {
                if fix.command == "git stash" {
                    Task {
                        _ = try? await self.stash()
                        NotificationManager.shared.success("Changes stashed", detail: "Try checkout again")
                    }
                }
            }
        } else {
            NotificationManager.shared.error("Checkout failed", detail: gitError.localizedDescription)
        }
    }

    private func performCheckoutWithAutoStash(_ branchName: String) async {
        guard let path = currentRepoPath else { return }
        isLoading = true
        defer { isLoading = false }

        let shell = ShellExecutor()
        let stashResult = await shell.execute(
            "git",
            arguments: ["stash", "push", "-u", "-m", "Auto-stash for checkout to \(branchName)"],
            workingDirectory: path
        )
        let didStash = stashResult.isSuccess && !stashResult.stdout.contains("No local changes")

        do {
            try await engine.checkout(branchName, at: path)

            if didStash {
                let popResult = await shell.execute("git", arguments: ["stash", "pop"], workingDirectory: path)
                if !popResult.isSuccess {
                    self.error = "Checkout successful but stash pop failed. Your changes are in stash."
                }
            }

            NotificationCenter.default.post(name: .branchDidCheckout, object: branchName)
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            if didStash {
                _ = await shell.execute("git", arguments: ["stash", "pop"], workingDirectory: path)
            }
            self.error = error.localizedDescription
        }
    }

    private func checkUncommittedChanges() async -> [String] {
        // Delegate to branchManager if available
        if let manager = branchManager {
            return await manager.checkUncommittedChanges()
        }

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

    /// Stash current changes
    func stash() async throws {
        guard let path = currentRepoPath else { return }
        _ = try await engine.stash(at: path)
    }

    // MARK: - Remote Branch Operations

    func checkoutRemote(_ branch: Branch) async {
        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager
        if let manager = branchManager {
            do {
                try await manager.checkoutRemote(branch)
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            // Fallback to direct engine call
            guard let path = currentRepoPath else { return }
            let localName = branch.displayName
            do {
                _ = try await engine.createBranch(named: localName, from: branch.name, checkout: true, at: path)
                NotificationCenter.default.post(name: .branchDidCheckout, object: localName)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                await BranchPRTracker.shared.refresh()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Branch Creation (kept for NewBranchSheet compatibility)

    func createBranch(name: String, from: String, checkout: Bool) async {
        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager
        if let manager = branchManager {
            do {
                try await manager.createBranch(name: name, from: from, checkout: checkout)
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            // Fallback
            guard let path = currentRepoPath else { return }
            do {
                _ = try await engine.createBranch(named: name, from: from, checkout: checkout, at: path)
                if checkout {
                    NotificationCenter.default.post(name: .branchDidCheckout, object: name)
                }
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Branch Deletion

    func deleteBranch(_ branch: Branch, force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager
        if let manager = branchManager {
            do {
                try await manager.deleteBranch(branch, force: force)
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            // Fallback
            guard let path = currentRepoPath else { return }
            do {
                try await engine.deleteBranch(named: branch.name, force: force, at: path)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                await BranchPRTracker.shared.refresh()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Merge & Rebase

    func merge(_ branch: Branch, noFastForward: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager
        if let manager = branchManager {
            do {
                try await manager.merge(branch, noFastForward: noFastForward)
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            // Fallback
            guard let path = currentRepoPath else { return }
            let currentBranchName = localBranches.first(where: { $0.isHead })?.name ?? "HEAD"
            do {
                try await engine.merge(branch: branch.name, options: MergeOptions(noFastForward: noFastForward), at: path)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                await BranchPRTracker.shared.refresh()
                RemoteOperationTracker.shared.recordMerge(success: true, sourceBranch: branch.name, targetBranch: currentBranchName)
            } catch {
                self.error = error.localizedDescription
                RemoteOperationTracker.shared.recordMerge(success: false, sourceBranch: branch.name, targetBranch: currentBranchName, error: error.localizedDescription)
            }
        }
    }

    func rebase(onto branch: Branch) async {
        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager
        if let manager = branchManager {
            do {
                try await manager.rebase(onto: branch)
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            // Fallback
            guard let path = currentRepoPath else { return }
            do {
                try await engine.rebase(onto: branch.name, at: path)
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Push & Pull

    func push(_ branch: Branch) async {
        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager
        if let manager = branchManager {
            do {
                try await manager.push(branch)
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            // Fallback - keep existing logic for when manager is not available
            guard let path = currentRepoPath else { return }
            do {
                let options = PushOptions(branch: branch.name)
                try await engine.push(options: options, at: path)

                NotificationCenter.default.post(name: .remoteOperationCompleted, object: "push")
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                GitHubSyncManager.shared.notifyOperationCompleted(type: .push, details: branch.name)
                await BranchPRTracker.shared.refresh()

                NotificationManager.shared.success("Pushed '\(branch.name)'", detail: "Changes pushed to remote")
                RemoteOperationTracker.shared.recordPush(success: true, branch: branch.name, remote: "origin")
            } catch let gitError as GitError {
                self.error = gitError.localizedDescription
                RemoteOperationTracker.shared.recordPush(success: false, branch: branch.name, remote: "origin", error: gitError.localizedDescription)
                if let fix = gitError.suggestedFix {
                    NotificationManager.shared.errorWithFix("Push failed", detail: gitError.localizedDescription, fixTitle: fix.title, fixHint: fix.hint) {
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
            } catch {
                self.error = error.localizedDescription
                RemoteOperationTracker.shared.recordPush(success: false, branch: branch.name, remote: "origin", error: error.localizedDescription)
                NotificationManager.shared.error("Push failed", detail: error.localizedDescription)
            }
        }
    }

    func pull(_ branch: Branch) async {
        guard branch.isHead else { return }

        isLoading = true
        defer { isLoading = false }

        // Delegate to branchManager
        if let manager = branchManager {
            do {
                try await manager.pull()
                syncFromManager(manager)
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            // Fallback
            guard let path = currentRepoPath else { return }
            do {
                try await engine.pull(at: path)

                NotificationCenter.default.post(name: .remoteOperationCompleted, object: "pull")
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                GitHubSyncManager.shared.notifyOperationCompleted(type: .pull, details: branch.name)
                await BranchPRTracker.shared.refresh()

                NotificationManager.shared.success("Pulled '\(branch.name)'", detail: "Updated from remote")
                RemoteOperationTracker.shared.recordPull(success: true, branch: branch.name, remote: "origin")
            } catch let gitError as GitError {
                self.error = gitError.localizedDescription
                RemoteOperationTracker.shared.recordPull(success: false, branch: branch.name, remote: "origin", error: gitError.localizedDescription)
                if let fix = gitError.suggestedFix {
                    NotificationManager.shared.errorWithFix("Pull failed", detail: gitError.localizedDescription, fixTitle: fix.title, fixHint: fix.hint) {
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
            } catch {
                self.error = error.localizedDescription
                RemoteOperationTracker.shared.recordPull(success: false, branch: branch.name, remote: "origin", error: error.localizedDescription)
                NotificationManager.shared.error("Pull failed", detail: error.localizedDescription)
            }
        }
    }
}

// MARK: - SectionHeader moved to UI/Components/Layout/SectionHeader.swift

// MARK: - BranchRow moved to UI/Components/Rows/BranchRow.swift

// MARK: - Subviews

struct RemoteBranchRow: View {
    let branch: Branch
    let isSelected: Bool
    var onSelect: () -> Void = {}
    var onCheckout: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "cloud")
                .foregroundColor(AppTheme.warning)
                .frame(width: DesignTokens.Size.iconMD)

            Text(branch.displayName)

            Spacer()

            if isHovered {
                DSIconButton(iconName: "arrow.down.circle", variant: .ghost, size: .sm) {
                    onCheckout()
                }
                .help("Checkout as local branch")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.leading, DesignTokens.Spacing.lg + DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : (isHovered ? AppTheme.textSecondary.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onCheckout() }  // Double-click to checkout
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Checkout as local branch") { onCheckout() }
            Divider()
            Button("Delete remote branch", role: .destructive) { }
        }
    }
}

// MARK: - Sheets

struct NewBranchSheet: View {
    @ObservedObject var viewModel: BranchListViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var branchName = ""
    @State private var baseBranch = "HEAD"
    @State private var checkoutAfterCreate = true

    // Branch name suggestions
    @State private var suggestions: [BranchSuggestion] = []
    @State private var isLoadingSuggestions = false
    private let suggestionService = BranchNamingSuggestionService()

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Create New Branch")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DSTextField(placeholder: "Branch name", text: $branchName)

                // Suggestions
                if isLoadingSuggestions {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Loading suggestions...")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                } else if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggestions")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)

                        FlowLayout(spacing: 6) {
                            ForEach(suggestions) { suggestion in
                                Button {
                                    branchName = suggestion.name
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: suggestion.icon)
                                            .font(.system(size: 9))
                                        Text(suggestion.name)
                                            .font(.system(size: 10))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.accent.opacity(0.1))
                                    .foregroundColor(AppTheme.accent)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                DSPicker(
                    items: ["HEAD"] + viewModel.localBranches.map { $0.name },
                    selection: .constant(baseBranch)
                )

                DSToggle("Checkout after creating", isOn: $checkoutAfterCreate, style: .checkbox)
            }
            .padding()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    Task {
                        // Always use branchManager for consistent state
                        if let manager = appState.branchManager {
                            try? await manager.createBranch(
                                name: branchName,
                                from: baseBranch,
                                checkout: checkoutAfterCreate
                            )
                            viewModel.syncFromManager(manager)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(branchName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
        .task {
            await loadSuggestions()
        }
    }

    private func loadSuggestions() async {
        guard let repoPath = viewModel.currentRepoPath else { return }

        isLoadingSuggestions = true

        let engine = GitEngine()

        var recentCommits: [Commit] = []
        var modifiedFiles: [String] = []

        do {
            recentCommits = try await engine.getCommits(at: repoPath, limit: 5)
        } catch {
            // Continue without commits
        }

        let shell = ShellExecutor()
        let statusResult = await shell.execute("git", arguments: ["status", "--porcelain"], workingDirectory: repoPath)
        if statusResult.isSuccess {
            modifiedFiles = statusResult.stdout
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .compactMap { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
        }

        let currentBranchName = viewModel.localBranches.first { $0.isHead }?.name

        let context = BranchContext(
            repoPath: repoPath,
            baseBranch: baseBranch,
            recentCommits: recentCommits,
            modifiedFiles: modifiedFiles,
            currentBranchName: currentBranchName
        )

        let loadedSuggestions = await suggestionService.suggestBranchNames(context: context)

        await MainActor.run {
            suggestions = loadedSuggestions
            isLoadingSuggestions = false
        }
    }
}

struct MergeSheet: View {
    let sourceBranch: Branch
    @ObservedObject var viewModel: BranchListViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var noFastForward = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Merge Branch")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Merge '\(sourceBranch.name)' into current branch")
                    .fontWeight(.medium)

                DSToggle("Create merge commit (no fast-forward)", isOn: $noFastForward, style: .checkbox)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Merge") {
                    Task {
                        // Use branchManager for consistent state
                        if let manager = appState.branchManager {
                            try? await manager.merge(sourceBranch, noFastForward: noFastForward)
                            viewModel.syncFromManager(manager)
                        } else {
                            await viewModel.merge(sourceBranch, noFastForward: noFastForward)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct RebaseSheet: View {
    let ontoBranch: Branch
    @ObservedObject var viewModel: BranchListViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Rebase Branch")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Rebase current branch onto '\(ontoBranch.name)'")
                    .fontWeight(.medium)

                Text("This will replay your commits on top of the target branch.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)

                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(AppTheme.warning)
                    Text("Warning: This rewrites commit history")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Rebase") {
                    Task {
                        // Use branchManager for consistent state
                        if let manager = appState.branchManager {
                            try? await manager.rebase(onto: ontoBranch)
                            viewModel.syncFromManager(manager)
                        } else {
                            await viewModel.rebase(onto: ontoBranch)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Create Pull Request Sheet

struct CreatePullRequestSheet: View {
    let branch: Branch
    var defaultBaseBranch: String? = nil  // Optional pre-set base branch (for drag-drop)
    var repoPath: String? = nil  // Optional: pass repo path directly from active tab
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var prBody = ""
    @State private var baseBranch: String? = nil  // Will be set from WorkspaceSettings
    @State private var isDraft = false
    @State private var isCreating = false
    @State private var isGeneratingAI = false
    @State private var error: String?

    private let aiService = AIService.shared
    private let gitEngine = GitEngine()

    /// Get effective repo path - prefer passed repoPath, fallback to appState
    private var effectiveRepoPath: String? {
        repoPath ?? appState.currentRepository?.path
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Create Pull Request")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Branches
                HStack {
                    VStack(alignment: .leading) {
                        Text("From")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                        Text(branch.name)
                            .fontWeight(.medium)
                    }
                    .frame(minWidth: 100)

                    Image(systemName: "arrow.right")
                        .foregroundColor(AppTheme.textPrimary)

                    VStack(alignment: .leading) {
                        Text("To")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                        if defaultBaseBranch != nil {
                            // Fixed base branch from drag-drop
                            Text(baseBranch ?? "")
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.success.opacity(0.15))
                                .foregroundColor(AppTheme.success)
                                .cornerRadius(4)
                        } else {
                            // Selectable base branch from context menu
                            DSPicker(
                                items: ["main", "master", "develop"],
                                selection: $baseBranch
                            )
                        }
                    }
                }

                DSTextField(placeholder: "Title", text: $title)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text("Description")
                        Spacer()
                        Button {
                            Task { await generateWithAI() }
                        } label: {
                            HStack(spacing: 4) {
                                if isGeneratingAI {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                }
                                Text(isGeneratingAI ? "Generating..." : "Generate with AI")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingAI)
                    }
                    DSTextEditor(
                        placeholder: "Enter PR description...",
                        text: $prBody,
                        minHeight: 120
                    )
                }

                DSToggle("Create as draft", isOn: $isDraft, style: .checkbox)

                if let error = error {
                    Text(error)
                        .foregroundColor(AppTheme.error)
                        .font(DesignTokens.Typography.caption)
                }
            }
            .padding()

            HStack {
                DSButton(variant: .secondary, size: .md) {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                DSButton(variant: .primary, size: .md, isDisabled: title.isEmpty || isCreating) {
                    await createPR()
                } label: {
                    Text(isCreating ? "Creating..." : "Create Pull Request")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
        .onAppear {
            // Set base branch: 1) from drag-drop, 2) from WorkspaceSettings, 3) fallback to "main"
            if let defaultBase = defaultBaseBranch {
                baseBranch = defaultBase
            } else if let path = effectiveRepoPath {
                baseBranch = WorkspaceSettingsManager.shared.getMainBranch(for: path)
            } else {
                baseBranch = "main"
            }

            // Default title from branch name
            let branchName = branch.name
                .replacingOccurrences(of: "feature/", with: "")
                .replacingOccurrences(of: "fix/", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            title = branchName.capitalized
        }
    }

    private func createPR() async {
        isCreating = true
        error = nil

        do {
            guard let path = effectiveRepoPath else {
                error = "No repository path"
                isCreating = false
                return
            }

            // Get remote URL from GitEngine
            let engine = GitEngine()
            let remotes = try await engine.getRemotes(at: path)
            guard let remoteURL = remotes.first?.fetchURL else {
                error = "No remote repository configured"
                isCreating = false
                return
            }

            // Extract owner/repo from URL
            let (owner, repoName) = parseGitHubURL(remoteURL)
            guard !owner.isEmpty, !repoName.isEmpty else {
                error = "Could not parse repository URL"
                isCreating = false
                return
            }

            // Strip remote prefix from branch names (e.g., "origin/master" -> "master")
            let cleanHead = branch.name.replacingOccurrences(of: #"^origin/"#, with: "", options: .regularExpression)
            let cleanBase = (baseBranch ?? "main").replacingOccurrences(of: #"^origin/"#, with: "", options: .regularExpression)

            let githubService = GitHubService()
            let newPR = try await githubService.createPullRequest(
                owner: owner,
                repo: repoName,
                title: title,
                body: prBody.isEmpty ? nil : prBody,
                head: cleanHead,
                base: cleanBase,
                draft: isDraft
            )

            NotificationManager.shared.success(
                "PR #\(newPR.number) created",
                detail: title
            )

            // Refresh PR tracker immediately so branch context menu updates
            await BranchPRTracker.shared.refresh()

            // Also refresh branchManager's PR cache
            await appState.branchManager?.refreshPRs()

            // Post notification to refresh PR data across the app
            NotificationCenter.default.post(name: .pullRequestCreated, object: newPR)
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)

            dismiss()
        } catch {
            NotificationManager.shared.error(
                "Failed to create PR",
                detail: error.localizedDescription
            )
            self.error = error.localizedDescription
        }

        isCreating = false
    }

    private func parseGitHubURL(_ url: String) -> (owner: String, repo: String) {
        // Handle both HTTPS and SSH URLs
        // https://github.com/owner/repo.git
        // git@github.com:owner/repo.git
        let cleanURL = url
            .replacingOccurrences(of: "git@github.com:", with: "")
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")

        let parts = cleanURL.components(separatedBy: "/")
        guard parts.count >= 2 else { return ("", "") }

        return (parts[0], parts[1])
    }

    private func generateWithAI() async {
        guard let path = effectiveRepoPath else { return }

        isGeneratingAI = true
        error = nil

        do {
            // Determine the base branch - use selection or from WorkspaceSettings
            let base: String
            if let selected = baseBranch, !selected.isEmpty {
                base = selected
            } else {
                base = WorkspaceSettingsManager.shared.getMainBranch(for: path)
            }

            // Use origin/base for proper comparison
            let remoteBase = "origin/\(base)"

            // Get diff using merge-base for accurate comparison
            let diff: String
            let commits: [Commit]

            do {
                // Get diff between base and current branch
                diff = try await gitEngine.getDiff(
                    from: remoteBase,
                    to: branch.name,
                    at: path
                )
            } catch {
                // Fallback: get unstaged diff
                diff = try await gitEngine.getDiff(for: nil, staged: false, at: path)
            }

            do {
                // Get commits unique to this branch (not in base)
                commits = try await gitEngine.getCommits(
                    at: path,
                    branch: "\(remoteBase)..\(branch.name)",
                    limit: 50
                )
            } catch {
                // Fallback: get recent commits on current branch
                commits = try await gitEngine.getCommits(
                    at: path,
                    branch: branch.name,
                    limit: 10
                )
            }

            // Generate title if empty
            if title.isEmpty && !commits.isEmpty {
                let generatedTitle = try await aiService.generatePRTitle(
                    commits: commits,
                    diff: diff
                )
                title = generatedTitle
            }

            // Generate description
            let generatedBody = try await aiService.generatePRDescription(
                diff: diff,
                commits: commits
            )
            prBody = generatedBody

        } catch {
            self.error = "AI generation failed: \(error.localizedDescription)"
        }

        isGeneratingAI = false
    }

    private func detectDefaultBranch(at path: String) async -> String? {
        // Check common default branch names
        for candidate in ["main", "master", "develop"] {
            let result = await ShellExecutor().execute(
                "git",
                arguments: ["rev-parse", "--verify", candidate],
                workingDirectory: path
            )
            if result.exitCode == 0 {
                return candidate
            }
        }
        return nil
    }
}

extension Notification.Name {
    static let renameBranch = Notification.Name("renameBranch")
    static let pullRequestCreated = Notification.Name("pullRequestCreated")
}
