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
                                onDelete: {
                                    selectedBranch = branch
                                    showDeleteAlert = true
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
                    try? await viewModel.gitService.stash()
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
        isLoading = true
        do {
            try await gitService.merge(branch: branch.name, noFastForward: noFastForward)
        } catch {
            self.error = error.localizedDescription
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
    var onDelete: () -> Void = {}

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
        .contextMenu {
            Button("Checkout") { onCheckout() }
                .disabled(branch.isHead)

            Divider()

            Button("Merge into current branch...") { onMerge() }
                .disabled(branch.isHead)

            Button("Rebase current branch onto this...") { onRebase() }
                .disabled(branch.isHead)

            Divider()

            Button("Rename...") { }

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

// #Preview {
//     BranchListView()
//         .environmentObject(AppState())
//         .frame(width: 300, height: 500)
// }
