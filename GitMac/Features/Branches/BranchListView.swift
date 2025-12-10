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

    var body: some View {
        VStack(spacing: 0) {
            // Search and actions
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

            Divider()

            // Branch list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Local branches
                    Section {
                        ForEach(filteredLocalBranches) { branch in
                            BranchRow(
                                branch: branch,
                                isSelected: selectedBranch?.id == branch.id,
                                onSelect: { selectedBranch = branch },
                                onCheckout: { Task { await viewModel.checkout(branch) } },
                                onMerge: {
                                    selectedBranch = branch
                                    showMergeSheet = true
                                },
                                onRebase: {
                                    selectedBranch = branch
                                    showRebaseSheet = true
                                },
                                onRename: {
                                    // TODO: Implement Rename Sheet
                                    NotificationCenter.default.post(name: .renameBranch, object: branch)
                                },
                                onPush: { Task { await viewModel.push(branch) } },
                                onPull: { Task { await viewModel.pull(branch) } },
                                onDelete: {
                                    selectedBranch = branch
                                    showDeleteAlert = true
                                },
                                onStartPR: {
                                    selectedBranch = branch
                                    showPRSheet = true
                                }
                            )
                        }
                    } header: {
                        SectionHeader(title: "Local", count: filteredLocalBranches.count, icon: "arrow.triangle.branch")
                    }

                    // Remote branches
                    Section {
                        ForEach(groupedRemoteBranches.keys.sorted(), id: \.self) { remote in
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
                    } header: {
                        SectionHeader(title: "Remote", count: filteredRemoteBranches.count, icon: "network")
                    }
                }
            }
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
        .task {
            if let repo = appState.currentRepository {
                viewModel.loadBranches(from: repo)
            }
        }
    }

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
    }

    @Published var uncommittedFiles: [String] = []
    @Published var showUncommittedWarning = false
    @Published var pendingCheckoutBranch: Branch?

    func checkout(_ branch: Branch) async {
        // Check for uncommitted changes first
        let changes = await checkUncommittedChanges()
        if !changes.isEmpty {
            uncommittedFiles = changes
            pendingCheckoutBranch = branch
            showUncommittedWarning = true
            return
        }

        await performCheckout(branch.name)
    }

    func forceCheckout() async {
        guard let branch = pendingCheckoutBranch else { return }
        await performCheckout(branch.name)
        showUncommittedWarning = false
        pendingCheckoutBranch = nil
    }

    private func performCheckout(_ branchName: String) async {
        isLoading = true
        do {
            try await gitService.checkout(branchName)
        } catch {
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
            // Only support pushing HEAD for now or we need to pass branch name to gitService.push
            if branch.isHead {
                try await gitService.push()

                // Track successful push
                RemoteOperationTracker.shared.recordPush(
                    success: true,
                    branch: branch.name,
                    remote: "origin"
                )
            }
        } catch {
            self.error = error.localizedDescription

            // Track failed push
            RemoteOperationTracker.shared.recordPush(
                success: false,
                branch: branch.name,
                remote: "origin",
                error: error.localizedDescription
            )
        }
        isLoading = false
    }

    func pull(_ branch: Branch) async {
        isLoading = true
        do {
            if branch.isHead {
                try await gitService.pull()

                // Track successful pull
                RemoteOperationTracker.shared.recordPull(
                    success: true,
                    branch: branch.name,
                    remote: "origin"
                )
            }
        } catch {
            self.error = error.localizedDescription

            // Track failed pull
            RemoteOperationTracker.shared.recordPull(
                success: false,
                branch: branch.name,
                remote: "origin",
                error: error.localizedDescription
            )
        }
        isLoading = false
    }
}

// MARK: - Subviews

struct SectionHeader: View {
    let title: String
    let count: Int
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .fontWeight(.semibold)
            Text("(\(count))")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct BranchRow: View {
    let branch: Branch
    let isSelected: Bool
    var onSelect: () -> Void = {}
    var onCheckout: () -> Void = {}
    var onMerge: () -> Void = {}
    var onRebase: () -> Void = {}
    var onRename: () -> Void = {}
    var onPush: () -> Void = {}
    var onPull: () -> Void = {}
    var onDelete: () -> Void = {}
    var onStartPR: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Branch icon
            Image(systemName: branch.isHead ? "checkmark.circle.fill" : "arrow.triangle.branch")
                .foregroundColor(branch.isHead ? .green : .blue)
                .frame(width: 16)

            // Branch name
            Text(branch.name)
                .fontWeight(branch.isHead ? .semibold : .regular)

            // Upstream info
            if let upstream = branch.upstream {
                Text(upstream.statusText)
                    .font(.caption)
                    .foregroundColor(upstream.hasChanges ? .orange : .green)
            }

            Spacer()

            // Actions on hover
            if isHovered && !branch.isHead {
                HStack(spacing: 4) {
                    Button {
                        onCheckout()
                    } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Checkout")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !branch.isHead { onCheckout() }
        }
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .contextMenu {
            Button("Checkout") { onCheckout() }
                .disabled(branch.isHead)

            if branch.isHead {
                Divider()
                Button { onPull() } label: { Label("Pull", systemImage: "arrow.down") }
                Button { onPush() } label: { Label("Push", systemImage: "arrow.up") }
            }
            
            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(branch.name, forType: .string)
            } label: {
                Label("Copy Branch Name", systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                onStartPR()
            } label: {
                Label("Start a Pull Request", systemImage: "arrow.triangle.pull")
            }

            Divider()

            Button("Merge into current branch...") { onMerge() }
                .disabled(branch.isHead)

            Button("Rebase current branch onto this...") { onRebase() }
                .disabled(branch.isHead)

            Divider()

            Button("Rename...") { onRename() }

            Divider()

            Button("Delete", role: .destructive) { onDelete() }
                .disabled(branch.isHead || branch.isMainBranch)
        }
    }
}

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
