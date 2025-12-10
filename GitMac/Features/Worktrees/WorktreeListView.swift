import SwiftUI

struct WorktreeListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = WorktreeListViewModel()
    @State private var showAddSheet = false
    @State private var selectedWorktree: Worktree?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("WORKTREES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.secondary)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.refresh(at: appState.currentRepository?.path) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            // Worktree list
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if viewModel.worktrees.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(Color.secondary)
                    Text("No worktrees")
                        .font(.system(size: 11))
                        .foregroundColor(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.worktrees) { worktree in
                            WorktreeRow(
                                worktree: worktree,
                                isSelected: selectedWorktree?.id == worktree.id,
                                onSelect: { selectedWorktree = worktree },
                                onOpen: { openWorktree(worktree) },
                                onRemove: { removeWorktree(worktree) },
                                onLock: { toggleLock(worktree) }
                            )
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.refresh(at: appState.currentRepository?.path)
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            Task { await viewModel.refresh(at: newPath) }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWorktreeSheet(viewModel: viewModel)
        }
    }

    private func openWorktree(_ worktree: Worktree) {
        Task {
            await appState.openRepository(at: worktree.path)
        }
    }

    private func removeWorktree(_ worktree: Worktree) {
        guard !worktree.isMain else { return }
        Task {
            if let path = appState.currentRepository?.path {
                await viewModel.removeWorktree(worktree, at: path)
            }
        }
    }

    private func toggleLock(_ worktree: Worktree) {
        Task {
            if let path = appState.currentRepository?.path {
                if worktree.isLocked {
                    await viewModel.unlockWorktree(worktree, at: path)
                } else {
                    await viewModel.lockWorktree(worktree, at: path)
                }
            }
        }
    }
}

// MARK: - Worktree Row
struct WorktreeRow: View {
    let worktree: Worktree
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void
    let onLock: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: worktree.isMain ? "house.fill" : "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(worktree.isMain ? Color.blue : Color.purple)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(worktree.name)
                        .font(.system(size: 12, weight: worktree.isMain ? .semibold : .regular))
                        .foregroundColor(Color.primary)
                        .lineLimit(1)

                    if worktree.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color.orange)
                    }

                    if worktree.isMain {
                        Text("main")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 4) {
                    if let branch = worktree.branch {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                        Text(branch)
                            .font(.system(size: 10))
                    } else if worktree.isDetached {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 9))
                        Text("detached")
                            .font(.system(size: 10))
                    }

                    Text(worktree.shortSHA)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(Color.secondary)
            }

            Spacer()

            // Actions (on hover)
            if isHovered && !worktree.isMain {
                HStack(spacing: 4) {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in new tab")

                    Button(action: onLock) {
                        Image(systemName: worktree.isLocked ? "lock.open" : "lock")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(worktree.isLocked ? "Unlock" : "Lock")

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(Color.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove worktree")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.2) : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onOpen() }
    }
}

// MARK: - Add Worktree Sheet
struct AddWorktreeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: WorktreeListViewModel

    @State private var worktreePath = ""
    @State private var selectedBranch = ""
    @State private var createNewBranch = false
    @State private var newBranchName = ""
    @State private var isDetached = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Worktree")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.primary)

            VStack(alignment: .leading, spacing: 12) {
                // Worktree path
                VStack(alignment: .leading, spacing: 4) {
                    Text("Worktree Path")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.secondary)
                    HStack {
                        TextField("Path for new worktree", text: $worktreePath)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)

                        Button("Browse") {
                            let panel = NSSavePanel()
                            panel.canCreateDirectories = true
                            panel.nameFieldStringValue = "worktree"
                            if panel.runModal() == .OK {
                                worktreePath = panel.url?.path ?? ""
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Branch options
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Create new branch", isOn: $createNewBranch)
                        .toggleStyle(.checkbox)

                    if createNewBranch {
                        TextField("New branch name", text: $newBranchName)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)
                    } else {
                        // Select existing branch
                        Picker("Branch", selection: $selectedBranch) {
                            Text("Select branch...").tag("")
                            if let repo = appState.currentRepository {
                                ForEach(repo.branches.filter { !$0.isRemote }) { branch in
                                    Text(branch.name).tag(branch.name)
                                }
                            }
                        }
                    }

                    Toggle("Detached HEAD", isOn: $isDetached)
                        .toggleStyle(.checkbox)
                        .disabled(createNewBranch)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Create Worktree") {
                    createWorktree()
                }
                .buttonStyle(.borderedProminent)
                .disabled(worktreePath.isEmpty || (!createNewBranch && selectedBranch.isEmpty && !isDetached))
            }
        }
        .padding(24)
        .frame(width: 450)
        .background(Color.gray.opacity(0.05))
    }

    private func createWorktree() {
        guard let repoPath = appState.currentRepository?.path else { return }

        Task {
            await viewModel.addWorktree(
                path: worktreePath,
                branch: createNewBranch ? nil : (selectedBranch.isEmpty ? nil : selectedBranch),
                newBranch: createNewBranch ? newBranchName : nil,
                detach: isDetached,
                at: repoPath
            )
            dismiss()
        }
    }
}

// MARK: - View Model
@MainActor
class WorktreeListViewModel: ObservableObject {
    @Published var worktrees: [Worktree] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let engine = GitEngine()

    func refresh(at path: String?) async {
        guard let path = path else {
            worktrees = []
            return
        }

        isLoading = true
        do {
            worktrees = try await engine.listWorktrees(at: path)
        } catch {
            errorMessage = error.localizedDescription
            worktrees = []
        }
        isLoading = false
    }

    func addWorktree(path: String, branch: String?, newBranch: String?, detach: Bool, at repoPath: String) async {
        isLoading = true
        do {
            _ = try await engine.addWorktree(
                path: path,
                branch: branch,
                newBranch: newBranch,
                detach: detach,
                at: repoPath
            )
            await refresh(at: repoPath)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func removeWorktree(_ worktree: Worktree, at repoPath: String) async {
        isLoading = true
        do {
            try await engine.removeWorktree(path: worktree.path, force: false, at: repoPath)
            await refresh(at: repoPath)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func lockWorktree(_ worktree: Worktree, at repoPath: String) async {
        do {
            try await engine.lockWorktree(path: worktree.path, at: repoPath)
            await refresh(at: repoPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlockWorktree(_ worktree: Worktree, at repoPath: String) async {
        do {
            try await engine.unlockWorktree(path: worktree.path, at: repoPath)
            await refresh(at: repoPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
