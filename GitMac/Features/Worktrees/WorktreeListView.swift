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
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button {
                        Task { await viewModel.refresh(at: appState.currentRepository?.path) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(AppTheme.textMuted.opacity(0.1))

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
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "folder.badge.plus")
                        .font(DesignTokens.Typography.iconXL)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("No worktrees")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xl)
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
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Status icon
            Image(systemName: worktree.isMain ? "house.fill" : "folder.fill")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(worktree.isMain ? AppTheme.info : AppTheme.accentPurple)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(worktree.name)
                        .font(DesignTokens.Typography.callout.weight(worktree.isMain ? .semibold : .regular))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    if worktree.isLocked {
                        Image(systemName: "lock.fill")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.warning)
                    }

                    if worktree.isMain {
                        Text("main")
                            .font(DesignTokens.Typography.caption2.weight(.medium))
                            .foregroundColor(AppTheme.info)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxs / 2)
                            .background(AppTheme.info.opacity(0.2))
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let branch = worktree.branch {
                        Image(systemName: "arrow.triangle.branch")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(branch)
                            .font(DesignTokens.Typography.caption2)
                    } else if worktree.isDetached {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.warning)
                        Text("detached")
                            .font(DesignTokens.Typography.caption2)
                    }

                    Text(worktree.shortSHA)
                        .font(DesignTokens.Typography.caption2.monospacedDigit())
                }
                .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            // Actions (on hover)
            if isHovered && !worktree.isMain {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in new tab")

                    Button(action: onLock) {
                        Image(systemName: worktree.isLocked ? "lock.open" : "lock")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(worktree.isLocked ? "Unlock" : "Lock")

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.error)
                    }
                    .buttonStyle(.plain)
                    .help("Remove worktree")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(isSelected ? AppTheme.info.opacity(0.2) : (isHovered ? AppTheme.textMuted.opacity(0.1) : Color.clear))
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
        VStack(spacing: DesignTokens.Spacing.xl) {
            Text("Add Worktree")
                .font(DesignTokens.Typography.title3.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Worktree path
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Worktree Path")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                    HStack {
                        TextField("Path for new worktree", text: $worktreePath)
                            .textFieldStyle(.plain)
                            .padding(DesignTokens.Spacing.md)
                            .background(AppTheme.textMuted.opacity(0.15))
                            .cornerRadius(DesignTokens.CornerRadius.md)

                        Button("Browse") {
                            let panel = NSSavePanel()
                            panel.canCreateDirectories = true
                            panel.nameFieldStringValue = "worktree"

                            panel.begin { response in
                                if response == .OK {
                                    Task { @MainActor in
                                        worktreePath = panel.url?.path ?? ""
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Branch options
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Toggle("Create new branch", isOn: $createNewBranch)
                        .toggleStyle(.checkbox)

                    if createNewBranch {
                        TextField("New branch name", text: $newBranchName)
                            .textFieldStyle(.plain)
                            .padding(DesignTokens.Spacing.md)
                            .background(AppTheme.textMuted.opacity(0.15))
                            .cornerRadius(DesignTokens.CornerRadius.md)
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
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 450)
        .background(AppTheme.textMuted.opacity(0.05))
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
