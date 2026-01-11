import SwiftUI

/// Branch list view with tree structure and context menus
struct BranchListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = BranchListViewModel()
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
            }
        }
        .sheet(isPresented: $showRebaseSheet) {
            if let branch = selectedBranch {
                RebaseSheet(ontoBranch: branch, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showPRSheet) {
            if let branch = selectedBranch {
                CreatePullRequestSheet(branch: branch)
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
                    defaultBaseBranch: baseBranch.name
                )
                .environmentObject(appState)
            }
        }
        .task {
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, _ in
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
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
        Group {
            BranchRow(
                branch: branch,
                isSelected: selectedBranch?.id == branch.id,
                onSelect: { selectedBranch = branch },
                onCheckout: {
                    // Use appropriate checkout for local vs remote
                    if branch.isRemote {
                        Task { await viewModel.checkoutRemote(branch) }
                    } else {
                        Task { await viewModel.checkout(branch) }
                    }
                },
                onMerge: branch.isRemote ? nil : {
                    selectedBranch = branch
                    showMergeSheet = true
                },
                onDelete: branch.isRemote ? nil : {
                    selectedBranch = branch
                    showDeleteAlert = true
                },
                onPush: branch.isRemote ? nil : { Task { await viewModel.push(branch) } },
                onPull: branch.isRemote ? nil : { Task { await viewModel.pull(branch) } },
                onRebase: branch.isRemote ? nil : {
                    selectedBranch = branch
                    showRebaseSheet = true
                },
                onBranchDropped: { droppedBranch in
                    handleBranchDrop(dragged: droppedBranch, onto: branch)
                }
            )
        }
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

    let gitService = GitService()
    private let engine = GitEngine()

    /// Current repository path - set when loading branches
    private(set) var currentRepoPath: String?

    func loadBranches(from repo: Repository) {
        currentRepoPath = repo.path
        localBranches = repo.branches.sorted { lhs, rhs in
            if lhs.isHead { return true }
            if rhs.isHead { return false }
            return lhs.name < rhs.name
        }
        remoteBranches = repo.remoteBranches.sorted { $0.name < $1.name }
    }

    @Published var uncommittedFiles: [String] = []
    @Published var showUncommittedWarning = false
    @Published var pendingCheckoutBranch: Branch?

    func checkout(_ branch: Branch) async {
        // Check for uncommitted changes first
        let changes = await checkUncommittedChanges()

        if !changes.isEmpty {
            // Show warning with file list
            await MainActor.run {
                pendingCheckoutBranch = branch
                uncommittedFiles = changes
                showUncommittedWarning = true
            }

            // Show notification with files list
            let fileList = changes.prefix(5).joined(separator: "\n")
            let moreFiles = changes.count > 5 ? "\n... and \(changes.count - 5) more" : ""

            NotificationManager.shared.warning(
                "Uncommitted changes in \(changes.count) file(s)",
                detail: "Files:\n\(fileList)\(moreFiles)\n\nStash changes to proceed with checkout?"
            )
        } else {
            await performCheckout(branch.name)
        }
    }

    func forceCheckout() async {
        guard let branch = pendingCheckoutBranch else { return }
        await performCheckoutWithAutoStash(branch.name)
        showUncommittedWarning = false
        pendingCheckoutBranch = nil
    }

    /// Stash current changes
    func stash() async throws {
        guard let path = currentRepoPath else { return }
        _ = try await engine.stash(at: path)
    }

    private func performCheckout(_ branchName: String) async {
        guard let path = currentRepoPath else {
            self.error = "No repository path available"
            return
        }
        isLoading = true
        do {
            try await engine.checkout(branchName, at: path)
            NotificationManager.shared.success(
                "Switched to '\(branchName)'",
                detail: nil
            )
            // Post both notifications for full sync
            NotificationCenter.default.post(name: .branchDidCheckout, object: branchName)
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch let gitError as GitError {
            self.error = gitError.localizedDescription
            if let fix = gitError.suggestedFix {
                NotificationManager.shared.errorWithFix(
                    "Checkout failed",
                    detail: gitError.localizedDescription,
                    fixTitle: fix.title,
                    fixHint: fix.hint
                ) {
                    // Action depends on fix
                    if fix.command == "git stash" {
                        Task {
                            _ = try? await self.engine.stash(at: path)
                            NotificationManager.shared.success("Changes stashed", detail: "Try checkout again")
                        }
                    }
                }
            } else {
                NotificationManager.shared.error("Checkout failed", detail: gitError.localizedDescription)
            }
        } catch {
            self.error = error.localizedDescription
            NotificationManager.shared.error("Checkout failed", detail: error.localizedDescription)
        }
        isLoading = false
    }

    /// Checkout with automatic stash and pop to avoid accumulating stashes
    private func performCheckoutWithAutoStash(_ branchName: String) async {
        guard let path = currentRepoPath else { return }
        isLoading = true

        let shell = ShellExecutor()

        // 1. Stash changes (including untracked files with -u)
        let stashResult = await shell.execute(
            "git",
            arguments: ["stash", "push", "-u", "-m", "Auto-stash for checkout to \(branchName)"],
            workingDirectory: path
        )

        let didStash = stashResult.isSuccess && !stashResult.stdout.contains("No local changes")

        // 2. Perform checkout
        do {
            try await engine.checkout(branchName, at: path)

            // 3. Pop stash if we stashed something
            if didStash {
                let popResult = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )

                if !popResult.isSuccess {
                    // Pop failed (likely conflicts) - keep stash and notify user
                    self.error = "Checkout successful but stash pop failed. Your changes are in stash. Run 'git stash pop' manually after resolving conflicts."
                }
            }

            // 4. Notify UI to refresh
            NotificationCenter.default.post(name: .branchDidCheckout, object: branchName)
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            // Checkout failed - restore stash if we made one
            if didStash {
                _ = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )
            }
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func checkUncommittedChanges() async -> [String] {
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

    func checkoutRemote(_ branch: Branch) async {
        guard let path = currentRepoPath else { return }
        // Create local branch from remote and checkout
        let localName = branch.displayName
        isLoading = true
        do {
            _ = try await engine.createBranch(named: localName, from: branch.name, checkout: true, at: path)
            // Post notifications for full sync
            NotificationCenter.default.post(name: .branchDidCheckout, object: localName)
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createBranch(name: String, from: String, checkout: Bool) async {
        guard let path = currentRepoPath else { return }
        isLoading = true
        do {
            _ = try await engine.createBranch(named: name, from: from, checkout: checkout, at: path)

            // Notify UI
            if checkout {
                NotificationCenter.default.post(name: .branchDidCheckout, object: name)
            }
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteBranch(_ branch: Branch, force: Bool = false) async {
        guard let path = currentRepoPath else { return }
        isLoading = true
        do {
            try await engine.deleteBranch(named: branch.name, force: force, at: path)

            // Notify UI
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func merge(_ branch: Branch, noFastForward: Bool = false) async {
        guard let path = currentRepoPath else { return }
        let currentBranchName = localBranches.first(where: { $0.isHead })?.name ?? "HEAD"
        isLoading = true
        do {
            try await engine.merge(branch: branch.name, options: MergeOptions(noFastForward: noFastForward), at: path)

            // Notify UI
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)

            // Track successful merge
            RemoteOperationTracker.shared.recordMerge(
                success: true,
                sourceBranch: branch.name,
                targetBranch: currentBranchName
            )
        } catch {
            self.error = error.localizedDescription

            // Track failed merge
            RemoteOperationTracker.shared.recordMerge(
                success: false,
                sourceBranch: branch.name,
                targetBranch: currentBranchName,
                error: error.localizedDescription
            )
        }
        isLoading = false
    }

    func rebase(onto branch: Branch) async {
        guard let path = currentRepoPath else { return }
        isLoading = true
        do {
            try await engine.rebase(onto: branch.name, at: path)

            // Notify UI
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func push(_ branch: Branch) async {
        guard let path = currentRepoPath else { return }
        isLoading = true
        do {
            if branch.isHead {
                try await engine.push(at: path)

                // Notify UI
                NotificationCenter.default.post(name: .remoteOperationCompleted, object: "push")
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                GitHubSyncManager.shared.notifyOperationCompleted(type: .push, details: branch.name)

                NotificationManager.shared.success(
                    "Pushed '\(branch.name)'",
                    detail: "Changes pushed to remote"
                )
                RemoteOperationTracker.shared.recordPush(
                    success: true,
                    branch: branch.name,
                    remote: "origin"
                )
            }
        } catch let gitError as GitError {
            self.error = gitError.localizedDescription
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
        } catch {
            self.error = error.localizedDescription
            RemoteOperationTracker.shared.recordPush(
                success: false,
                branch: branch.name,
                remote: "origin",
                error: error.localizedDescription
            )
            NotificationManager.shared.error("Push failed", detail: error.localizedDescription)
        }
        isLoading = false
    }

    func pull(_ branch: Branch) async {
        guard let path = currentRepoPath else { return }
        isLoading = true
        do {
            if branch.isHead {
                try await engine.pull(at: path)

                // Notify UI
                NotificationCenter.default.post(name: .remoteOperationCompleted, object: "pull")
                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                GitHubSyncManager.shared.notifyOperationCompleted(type: .pull, details: branch.name)

                NotificationManager.shared.success(
                    "Pulled '\(branch.name)'",
                    detail: "Updated from remote"
                )
                RemoteOperationTracker.shared.recordPull(
                    success: true,
                    branch: branch.name,
                    remote: "origin"
                )
            }
        } catch let gitError as GitError {
            self.error = gitError.localizedDescription
            RemoteOperationTracker.shared.recordPull(
                success: false,
                branch: branch.name,
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
        } catch {
            self.error = error.localizedDescription
            RemoteOperationTracker.shared.recordPull(
                success: false,
                branch: branch.name,
                remote: "origin",
                error: error.localizedDescription
            )
            NotificationManager.shared.error("Pull failed", detail: error.localizedDescription)
        }
        isLoading = false
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
    @Environment(\.dismiss) private var dismiss

    @State private var branchName = ""
    @State private var baseBranch = "HEAD"
    @State private var checkoutAfterCreate = true

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Create New Branch")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DSTextField(placeholder: "Branch name", text: $branchName)

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
                        await viewModel.createBranch(
                            name: branchName,
                            from: baseBranch,
                            checkout: checkoutAfterCreate
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(branchName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct MergeSheet: View {
    let sourceBranch: Branch
    @ObservedObject var viewModel: BranchListViewModel
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
                        await viewModel.merge(sourceBranch, noFastForward: noFastForward)
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
                        await viewModel.rebase(onto: ontoBranch)
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
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var prBody = ""
    @State private var baseBranch: String? = "main"
    @State private var isDraft = false
    @State private var isCreating = false
    @State private var isGeneratingAI = false
    @State private var error: String?

    private let aiService = AIService.shared
    private let gitEngine = GitEngine()

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
            // Set base branch from default if provided (drag-drop case)
            if let defaultBase = defaultBaseBranch {
                baseBranch = defaultBase
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
            guard let repo = appState.currentRepository,
                  let remoteURL = repo.remotes.first?.fetchURL else {
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

            // Post notification to refresh PR data across the app
            NotificationCenter.default.post(name: .pullRequestCreated, object: newPR)
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: repo.path)

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
        guard let repo = appState.currentRepository else { return }

        isGeneratingAI = true
        error = nil

        do {
            // Determine the base branch - use selection or detect default
            let base: String
            if let selected = baseBranch, !selected.isEmpty {
                base = selected
            } else {
                // Try to detect default branch
                base = await detectDefaultBranch(at: repo.path) ?? "main"
            }

            // Get diff using merge-base for accurate comparison
            let diff: String
            let commits: [Commit]

            do {
                // Get diff between base and current branch
                diff = try await gitEngine.getDiff(
                    from: base,
                    to: branch.name,
                    at: repo.path
                )
            } catch {
                // Fallback: get unstaged diff
                diff = try await gitEngine.getDiff(for: nil, staged: false, at: repo.path)
            }

            do {
                // Get commits unique to this branch
                commits = try await gitEngine.getCommits(
                    at: repo.path,
                    branch: "\(base)..\(branch.name)",
                    limit: 10
                )
            } catch {
                // Fallback: get recent commits on current branch
                commits = try await gitEngine.getCommits(
                    at: repo.path,
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
