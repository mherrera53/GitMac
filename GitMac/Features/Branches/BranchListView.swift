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
                    _ = try? await viewModel.gitService.stash()
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
                CreatePRFromDragDropSheet(
                    headBranch: headBranch.name,
                    baseBranch: baseBranch.name,
                    repository: appState.currentRepository
                )
            }
        }
        .task {
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _ in
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .repositoryDidRefresh)) { notification in
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
    }

    // MARK: - Subviews

    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search branches...", text: $searchText)
                .textFieldStyle(.plain)

            Button {
                showNewBranchSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New branch")
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var branchListContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                localBranchesSection
                remoteBranchesSection
            }
        }
    }

    private var localBranchesSection: some View {
        Section {
            if localBranchesExpanded {
                ForEach(filteredLocalBranches) { branch in
                    branchRowView(for: branch)
                }
            }
        } header: {
            SectionHeader(
                title: "Local",
                count: filteredLocalBranches.count,
                icon: "arrow.triangle.branch",
                isExpanded: $localBranchesExpanded
            )
        }
    }

    private var remoteBranchesSection: some View {
        Section {
            if remoteBranchesExpanded {
                ForEach(groupedRemoteBranches.keys.sorted(), id: \.self) { remote in
                    remoteGroupView(for: remote)
                }
            }
        } header: {
            SectionHeader(
                title: "Remote",
                count: filteredRemoteBranches.count,
                icon: "network",
                isExpanded: $remoteBranchesExpanded
            )
        }
    }

    private func branchRowView(for branch: Branch) -> some View {
        Group {
            BranchRow(
                branch: branch,
                isSelected: selectedBranch?.id == branch.id,
                onSelect: { selectedBranch = branch },
                onCheckout: { Task { await viewModel.checkout(branch) } },
                onMerge: {
                    selectedBranch = branch
                    showMergeSheet = true
                },
                onDelete: {
                    selectedBranch = branch
                    showDeleteAlert = true
                },
                onPush: { Task { await viewModel.push(branch) } },
                onPull: { Task { await viewModel.pull(branch) } },
                onRebase: {
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
                    .foregroundColor(.orange)
                Text(remote)
                    .fontWeight(.medium)
                Text("(\(groupedRemoteBranches[remote]?.count ?? 0))")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Filtered Data

    var filteredLocalBranches: [Branch] {
        if searchText.isEmpty {
            return viewModel.localBranches
        }
        return viewModel.localBranches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredRemoteBranches: [Branch] {
        if searchText.isEmpty {
            return viewModel.remoteBranches
        }
        return viewModel.remoteBranches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var groupedRemoteBranches: [String: [Branch]] {
        Dictionary(grouping: filteredRemoteBranches) { branch in
            branch.remoteName ?? "origin"
        }
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
            do {
                try await viewModel.gitService.merge(branch: dragged.name)
            } catch {
                // Error handling - could show an error alert
                print("Merge failed: \(error)")
            }

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

            // Then rebase it onto the dragged branch
            do {
                try await viewModel.gitService.rebase(onto: dragged.name)
            } catch {
                // Error handling - could show an error alert
                print("Rebase failed: \(error)")
            }

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

// MARK: - Create PR from Drag & Drop

struct CreatePRFromDragDropSheet: View {
    let headBranch: String
    let baseBranch: String
    let repository: Repository?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var prBody = ""
    @State private var isDraft = false
    @State private var isGenerating = false
    @State private var selectedReviewers: Set<String> = []
    @State private var selectedLabels: Set<String> = []
    @State private var availableReviewers: [GitHubUser] = []
    @State private var availableLabels: [GitHubLabel] = []

    private let aiService = AIService()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Pull Request")
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: 8) {
                        Text(headBranch)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(baseBranch)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                Button {
                    Task { await generateWithAI() }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView().scaleEffect(0.7)
                            Text("Generating...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Generate with AI")
                        }
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title").font(.caption).foregroundColor(.secondary)
                        TextField("Enter PR title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $prBody)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Toggle("Create as draft", isOn: $isDraft)
                }
                .padding(.horizontal)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Pull Request") {
                    Task {
                        await createPR()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || isGenerating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 600, height: 550)
        .task {
            await loadMetadata()
        }
    }

    private func generateWithAI() async {
        isGenerating = true
        do {
            guard let repoPath = repository?.path else { return }
            let gitService = GitService()
            let diff = try await gitService.getDiff(from: baseBranch, to: headBranch)
            let commits = try await gitService.getCommits(branch: headBranch, limit: 20)

            async let generatedTitle = aiService.generatePRTitle(commits: commits, diff: diff)
            async let generatedDescription = aiService.generatePRDescription(
                diff: diff,
                commits: commits,
                template: nil
            )

            title = try await generatedTitle
            prBody = try await generatedDescription
        } catch {
            print("Failed to generate: \(error)")
        }
        isGenerating = false
    }

    private func createPR() async {
        guard let repo = repository,
              let remote = repo.remotes.first(where: { $0.isGitHub }),
              let ownerRepo = remote.ownerAndRepo else { return }

        do {
            let githubService = GitHubService()
            let newPR = try await githubService.createPullRequest(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo,
                title: title,
                body: prBody,
                head: headBranch,
                base: baseBranch,
                draft: isDraft
            )

            NotificationManager.shared.success(
                "PR #\(newPR.number) created",
                detail: title
            )
        } catch {
            NotificationManager.shared.error(
                "Failed to create PR",
                detail: error.localizedDescription
            )
        }
    }

    private func loadMetadata() async {
        guard let repo = repository,
              let remote = repo.remotes.first(where: { $0.isGitHub }),
              let ownerRepo = remote.ownerAndRepo else { return }

        do {
            let githubService = GitHubService()
            availableReviewers = try await githubService.getCollaborators(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo
            )
            availableLabels = try await githubService.getLabels(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo
            )
        } catch {
            print("Failed to load metadata: \(error)")
        }
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

    func loadBranches(from repo: Repository) {
        localBranches = repo.branches.sorted { lhs, rhs in
            if lhs.isHead { return true }
            if rhs.isHead { return false }
            return lhs.name < rhs.name
        }
        remoteBranches = repo.remoteBranches.sorted { $0.name < $1.name }

        // Debug: log branch counts
        print("🔍 Loaded \(localBranches.count) local branches")
        print("🌐 Loaded \(remoteBranches.count) remote branches:")
        remoteBranches.forEach { print("  - \($0.name)") }
    }

    @Published var uncommittedFiles: [String] = []
    @Published var showUncommittedWarning = false
    @Published var pendingCheckoutBranch: Branch?

    func checkout(_ branch: Branch) async {
        // Check for uncommitted changes first
        let changes = await checkUncommittedChanges()
        if !changes.isEmpty {
            // Auto stash → checkout → pop (to avoid accumulating stashes)
            await performCheckoutWithAutoStash(branch.name)
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

    private func performCheckout(_ branchName: String) async {
        isLoading = true
        do {
            try await gitService.checkout(branchName)
            try await gitService.refresh()
            NotificationManager.shared.success(
                "Switched to '\(branchName)'",
                detail: nil
            )
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: gitService.currentRepository?.path)
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
                            try? await self.gitService.stash()
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
        guard let path = gitService.currentRepository?.path else { return }
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
            try await gitService.checkout(branchName)

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

            // 4. Refresh UI to update graph and branch indicator
            try await gitService.refresh()
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
        guard let path = gitService.currentRepository?.path else { return [] }
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
        // Create local branch from remote and checkout
        let localName = branch.displayName
        isLoading = true
        do {
            _ = try await gitService.createBranch(named: localName, from: branch.name, checkout: true)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createBranch(name: String, from: String, checkout: Bool) async {
        isLoading = true
        do {
            _ = try await gitService.createBranch(named: name, from: from, checkout: checkout)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteBranch(_ branch: Branch, force: Bool = false) async {
        isLoading = true
        do {
            try await gitService.deleteBranch(named: branch.name, force: force)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func merge(_ branch: Branch, noFastForward: Bool = false) async {
        let currentBranch = gitService.currentRepository?.currentBranch?.name ?? "HEAD"
        isLoading = true
        do {
            try await gitService.merge(branch: branch.name, noFastForward: noFastForward)

            // Track successful merge
            RemoteOperationTracker.shared.recordMerge(
                success: true,
                sourceBranch: branch.name,
                targetBranch: currentBranch
            )
        } catch {
            self.error = error.localizedDescription

            // Track failed merge
            RemoteOperationTracker.shared.recordMerge(
                success: false,
                sourceBranch: branch.name,
                targetBranch: currentBranch,
                error: error.localizedDescription
            )
        }
        isLoading = false
    }

    func rebase(onto branch: Branch) async {
        isLoading = true
        do {
            try await gitService.rebase(onto: branch.name)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func push(_ branch: Branch) async {
        isLoading = true
        do {
            if branch.isHead {
                try await gitService.push()
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
                            try? await self.gitService.pull(rebase: true)
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
        isLoading = true
        do {
            if branch.isHead {
                try await gitService.pull()
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
                            try? await self.gitService.stash()
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
        HStack(spacing: 8) {
            Image(systemName: "cloud")
                .foregroundColor(.orange)
                .frame(width: 16)

            Text(branch.displayName)

            Spacer()

            if isHovered {
                Button {
                    onCheckout()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help("Checkout as local branch")
            }
        }
        .padding(.horizontal, 12)
        .padding(.leading, 20)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
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
        VStack(spacing: 16) {
            Text("Create New Branch")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Branch name", text: $branchName)
                    .textFieldStyle(.roundedBorder)

                Picker("Based on", selection: $baseBranch) {
                    Text("Current HEAD").tag("HEAD")
                    ForEach(viewModel.localBranches) { branch in
                        Text(branch.name).tag(branch.name)
                    }
                }

                Toggle("Checkout after creating", isOn: $checkoutAfterCreate)
            }

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
        VStack(spacing: 16) {
            Text("Merge Branch")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Merge '\(sourceBranch.name)' into current branch")
                    .fontWeight(.medium)

                Toggle("Create merge commit (no fast-forward)", isOn: $noFastForward)
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
        VStack(spacing: 16) {
            Text("Rebase Branch")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Rebase current branch onto '\(ontoBranch.name)'")
                    .fontWeight(.medium)

                Text("This will replay your commits on top of the target branch.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Warning: This rewrites commit history")
                        .font(.caption)
                        .foregroundColor(.orange)
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
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var prBody = ""
    @State private var baseBranch = "main"
    @State private var isDraft = false
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Pull Request")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                // Branches
                HStack {
                    VStack(alignment: .leading) {
                        Text("From")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(branch.name)
                            .fontWeight(.medium)
                    }
                    .frame(minWidth: 100)

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading) {
                        Text("To")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $baseBranch) {
                            Text("main").tag("main")
                            Text("master").tag("master")
                            Text("develop").tag("develop")
                        }
                        .labelsHidden()
                    }
                }

                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                    TextEditor(text: $prBody)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                Toggle("Create as draft", isOn: $isDraft)

                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task { await createPR() }
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Create Pull Request")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || isCreating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
        .onAppear {
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

            let githubService = GitHubService()
            _ = try await githubService.createPullRequest(
                owner: owner,
                repo: repoName,
                title: title,
                body: prBody.isEmpty ? nil : prBody,
                head: branch.name,
                base: baseBranch,
                draft: isDraft
            )

            dismiss()
        } catch {
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
}

extension Notification.Name {
    static let renameBranch = Notification.Name("renameBranch")
}
