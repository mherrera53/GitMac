import SwiftUI

struct WorktreeListView: View {
    @Environment(AppState.self) var appState
    @StateObject private var manager = WorktreeManager.shared
    @State private var showAddSheet = false
    @State private var selectedWorktree: Worktree?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("WORKTREES")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button {
                        Task { await manager.refresh(at: appState.currentRepository?.path) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(AppTheme.textMuted.opacity(0.1))

            // Worktree list
            if manager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if manager.worktrees.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "folder.badge.plus")
                        .font(DesignTokens.Typography.iconXL)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("No worktrees")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(manager.worktrees) { worktree in
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
            await manager.refresh(at: appState.currentRepository?.path)
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            Task { await manager.refresh(at: newPath) }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWorktreeSheet()
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
            try? await manager.removeWorktree(worktree)
        }
    }

    private func toggleLock(_ worktree: Worktree) {
        Task {
            if worktree.isLocked {
                try? await manager.unlockWorktree(worktree)
            } else {
                try? await manager.lockWorktree(worktree)
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
                .foregroundStyle(worktree.isMain ? AppTheme.info : AppTheme.accentPurple)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(worktree.name)
                        .font(DesignTokens.Typography.callout.weight(worktree.isMain ? .semibold : .regular))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    if worktree.isLocked {
                        Image(systemName: "lock.fill")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(AppTheme.warning)
                    }

                    if worktree.isMain {
                        Text("main")
                            .font(DesignTokens.Typography.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.info)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxs / 2)
                            .background(AppTheme.info.opacity(0.2))
                            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                    }
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let branch = worktree.branch {
                        Image(systemName: "arrow.triangle.branch")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(branch)
                            .font(DesignTokens.Typography.caption2)
                    } else if worktree.isDetached {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(AppTheme.warning)
                        Text("detached")
                            .font(DesignTokens.Typography.caption2)
                    }

                    Text(worktree.shortSHA)
                        .font(DesignTokens.Typography.caption2.monospacedDigit())
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            // Actions (on hover)
            if isHovered && !worktree.isMain {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in new tab")

                    Button(action: onLock) {
                        Image(systemName: worktree.isLocked ? "lock.open" : "lock")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(worktree.isLocked ? "Unlock" : "Lock")

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.error)
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
    @Environment(AppState.self) var appState
    @StateObject private var manager = WorktreeManager.shared

    @State private var worktreePath = ""
    @State private var selectedBranch = ""
    @State private var createNewBranch = false
    @State private var newBranchName = ""
    @State private var isDetached = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Text("Add Worktree")
                .font(DesignTokens.Typography.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Worktree path
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Worktree Path")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        DSTextField(placeholder: "Path for new worktree", text: $worktreePath)
                            .padding(DesignTokens.Spacing.md)
                            .background(AppTheme.textMuted.opacity(0.15))
                            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))

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
                    DSToggle("Create new branch", isOn: $createNewBranch)

                    if createNewBranch {
                        DSTextField(placeholder: "New branch name", text: $newBranchName)
                            .padding(DesignTokens.Spacing.md)
                            .background(AppTheme.textMuted.opacity(0.15))
                            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
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

                    DSToggle("Detached HEAD", isOn: $isDetached)
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
        Task {
            _ = try? await manager.addWorktree(
                path: worktreePath,
                branch: createNewBranch ? nil : (selectedBranch.isEmpty ? nil : selectedBranch),
                newBranch: createNewBranch ? newBranchName : nil,
                detach: isDetached
            )
            dismiss()
        }
    }
}

// MARK: - Create Worktree From Commit Sheet
struct CreateWorktreeFromCommitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState
    @StateObject private var manager = WorktreeManager.shared

    let commitSHA: String

    @State private var worktreePath = ""
    @State private var createNewBranch = false
    @State private var newBranchName = ""

    private var shortSHA: String { String(commitSHA.prefix(7)) }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Header
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accentPurple)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Create Worktree")
                        .font(DesignTokens.Typography.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("from commit \(shortSHA)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Worktree path
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Worktree Path")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        DSTextField(placeholder: "Path for new worktree", text: $worktreePath)
                            .padding(DesignTokens.Spacing.md)
                            .background(AppTheme.textMuted.opacity(0.15))
                            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))

                        Button("Browse") {
                            let panel = NSSavePanel()
                            panel.canCreateDirectories = true
                            panel.nameFieldStringValue = "worktree-\(shortSHA)"

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
                    DSToggle("Create new branch at this commit", isOn: $createNewBranch)

                    if createNewBranch {
                        DSTextField(placeholder: "New branch name", text: $newBranchName)
                            .padding(DesignTokens.Spacing.md)
                            .background(AppTheme.textMuted.opacity(0.15))
                            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
                    } else {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.warning)
                            Text("Worktree will be in detached HEAD state")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
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
                .disabled(worktreePath.isEmpty || (createNewBranch && newBranchName.isEmpty))
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 450)
        .background(AppTheme.background)
    }

    private func createWorktree() {
        Task {
            if createNewBranch && !newBranchName.isEmpty {
                // Create worktree with new branch at commit
                _ = try? await manager.addWorktree(
                    path: worktreePath,
                    branch: commitSHA,
                    newBranch: newBranchName,
                    detach: false
                )
            } else {
                // Create detached worktree at commit
                _ = try? await manager.addWorktreeFromCommit(
                    path: worktreePath,
                    commitSHA: commitSHA
                )
            }
            dismiss()
        }
    }
}
