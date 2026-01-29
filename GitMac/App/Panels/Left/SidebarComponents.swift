//
//  SidebarComponents.swift
//  GitMac
//
//  Extracted from ContentView.swift
//  Contains: SidebarBranchRow, SidebarRepoRow, RemoteSidebarRow, StashSidebarRow, TagSidebarRow
//

import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Sidebar Branch Row
struct SidebarBranchRow: View {
    let branch: Branch
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    @State private var showPRSheet = false
    @State private var showUncommittedAlert = false
    @State private var showForceCheckoutAlert = false

    // Drag & drop state
    @State private var isDropTarget = false
    @State private var showDragDropPRSheet = false

    // Use shared PR tracker for reactive updates
    @ObservedObject private var prTracker = BranchPRTracker.shared

    /// Get PR for this branch from the shared tracker
    private var branchPR: GitHubPullRequest? {
        prTracker.getPR(for: branch.name)
    }

    private var branchIconColor: Color {
        if branch.isRemote {
            return AppTheme.accentCyan
        } else if branch.isCurrent {
            return AppTheme.success
        } else {
            return AppTheme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator - not shown for remote branches
            if !branch.isRemote {
                Circle()
                    .fill(branch.isCurrent ? AppTheme.success : AppTheme.textMuted)
                    .frame(width: 8, height: 8)
            }

            // Icon: cloud for remote, branch for local
            Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundStyle(branchIconColor)

            // Branch name (show display name for remote to strip origin/)
            Text(branch.isRemote ? branch.displayName : branch.name)
                .font(.system(size: 12))
                .foregroundStyle(branch.isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            if branch.isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.success)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isDropTarget ? AppTheme.accent.opacity(0.2) : (isHovered ? AppTheme.hover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isDropTarget ? AppTheme.accent : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isDropTarget ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDropTarget)
        .onHover { isHovered = $0 }
        .onTapGesture {
            appState.selectedBranch = branch
        }
        .onDrag {
            return NSItemProvider(object: branch.name as NSString)
        }
        // Accept drops from CommitGraph BranchTransferable
        .onDrop(of: [.branchData, .text], isTargeted: $isDropTarget) { providers in
            handleDrop(providers: providers)
        }
        .contextMenu {
            Button {
                Task {
                    await performCheckout()
                }
            } label: {
                Label("Checkout", systemImage: "arrow.right.circle")
            }
            .disabled(branch.isCurrent)

            Divider()

            // Existing PR for this branch (from shared tracker)
            if let pr = branchPR {
                Menu {
                    if pr.state == "open" && !pr.draft {
                        Button {
                            Task { await mergePR(pr, method: .merge) }
                        } label: {
                            Label("Merge", systemImage: "arrow.triangle.merge")
                        }

                        Button {
                            Task { await mergePR(pr, method: .squash) }
                        } label: {
                            Label("Squash and Merge", systemImage: "square.stack.3d.up")
                        }

                        Button {
                            Task { await mergePR(pr, method: .rebase) }
                        } label: {
                            Label("Rebase and Merge", systemImage: "arrow.triangle.branch")
                        }

                        Divider()
                    }

                    Button {
                        if let url = URL(string: pr.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open in GitHub", systemImage: "safari")
                    }
                } label: {
                    HStack {
                        Image(systemName: pr.draft ? "doc.text" : (pr.state == "open" ? "arrow.triangle.pull" : "checkmark.circle.fill"))
                            .foregroundStyle(pr.draft ? .gray : (pr.state == "open" ? .green : .purple))
                        Text("PR #\(pr.number): \(pr.title)")
                    }
                }

                Divider()
            }

            Button {
                showPRSheet = true
            } label: {
                Label("Start a Pull Request", systemImage: "plus.circle")
            }

            Divider()

            Button {
                // TODO: Implement merge
            } label: {
                Label("Merge into current branch", systemImage: "arrow.triangle.merge")
            }
            .disabled(branch.isCurrent)

            Divider()

            Button(role: .destructive) {
                Task {
                    try? await appState.gitService.deleteBranch(named: branch.name)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(branch.isCurrent)
        }
        .sheet(isPresented: $showPRSheet) {
            CreatePullRequestSheet(branch: branch)
                .environmentObject(appState)
        }
        .alert("Uncommitted Changes", isPresented: $showUncommittedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stash & Checkout") {
                Task {
                    do {
                        _ = try await appState.gitService.stash(message: "Auto-stash before checkout to \(branch.name)")
                        try await appState.gitService.checkout(branch.name)
                    } catch {
                        // Stash & checkout failed silently
                    }
                }
            }
            Button("Force Checkout", role: .destructive) {
                Task {
                    try? await appState.gitService.checkoutForce(branch.name)
                }
            }
        } message: {
            Text("You have uncommitted changes. Commit them first, stash them, or force checkout (will discard changes).")
        }
        .sheet(isPresented: $showDragDropPRSheet) {
            // PR from current checkout branch → dropped-on branch
            if let currentBranch = appState.currentRepository?.currentBranch {
                CreatePullRequestSheet(
                    branch: currentBranch,
                    defaultBaseBranch: branch.name
                )
                .environmentObject(appState)
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard providers.first != nil else { return false }

        // Get the current branch - must be different from drop target
        guard let currentBranch = appState.currentRepository?.currentBranch?.name,
              currentBranch != branch.name else {
            // Can't create PR from same branch to itself
            return false
        }

        // Show PR creation sheet
        DispatchQueue.main.async {
            showDragDropPRSheet = true
        }

        return true
    }

    private func performCheckout() async {
        guard let path = appState.currentRepository?.path else { return }

        // Check for uncommitted changes
        if let status = appState.currentRepository?.status {
            let hasChanges = !status.staged.isEmpty || !status.unstaged.isEmpty || !status.untracked.isEmpty
            if hasChanges {
                // Auto stash -> checkout -> pop (to avoid accumulating stashes)
                await performCheckoutWithAutoStash()
                return
            }
        }

        // No changes, proceed with checkout
        let shell = ShellExecutor()
        let result: ShellResult

        if branch.isRemote {
            // For remote branches: create local tracking branch
            // origin/feature/foo -> feature/foo
            let localName = branch.displayName
            result = await shell.execute(
                "git",
                arguments: ["checkout", "-b", localName, "--track", branch.name],
                workingDirectory: path
            )
        } else {
            // For local branches: simple checkout
            result = await shell.execute(
                "git",
                arguments: ["checkout", branch.name],
                workingDirectory: path
            )
        }

        if result.isSuccess {
            await appState.refresh()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            NotificationManager.shared.success("Checked out", detail: branch.isRemote ? branch.displayName : branch.name)
        } else {
            let errorDetail = result.stderr
            if errorDetail.contains("already exists") {
                // Local branch already exists for remote - just checkout the local one
                let localCheckout = await shell.execute(
                    "git", arguments: ["checkout", branch.displayName],
                    workingDirectory: path
                )
                if localCheckout.isSuccess {
                    await appState.refresh()
                    NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                    NotificationManager.shared.success("Checked out", detail: branch.displayName)
                } else {
                    NotificationManager.shared.error("Checkout failed", detail: localCheckout.stderr)
                }
            } else if errorDetail.contains("pathspec") || errorDetail.contains("did not match") {
                NotificationManager.shared.errorWithFix(
                    "Branch not found",
                    detail: errorDetail,
                    fixTitle: "Fetch All",
                    fixHint: "Fetch from all remotes to update branch list",
                    fixAction: {
                        NotificationCenter.default.post(name: .fetch, object: nil)
                    }
                )
            } else {
                NotificationManager.shared.error("Checkout failed", detail: errorDetail)
            }
        }
    }

    private func performCheckoutWithAutoStash() async {
        guard let path = appState.currentRepository?.path else { return }

        let shell = ShellExecutor()

        // 1. Stash changes (including untracked files with -u)
        let stashResult = await shell.execute(
            "git",
            arguments: ["stash", "push", "-u", "-m", "Auto-stash for checkout to \(branch.name)"],
            workingDirectory: path
        )

        let didStash = stashResult.isSuccess && !stashResult.stdout.contains("No local changes")

        // If stash failed, show which files are blocking and offer options
        if !stashResult.isSuccess {
            let dirtyFiles = await getDirtyFileList(at: path, shell: shell)
            let fileList = dirtyFiles.prefix(8).joined(separator: "\n")
            let extra = dirtyFiles.count > 8 ? "\n...and \(dirtyFiles.count - 8) more" : ""

            if stashResult.stderr.contains("could not write index") {
                // Index corruption - offer rebuild
                NotificationManager.shared.errorWithFix(
                    "Checkout failed",
                    detail: "Cannot stash: index file is corrupt.\nFiles with changes:\n\(fileList)\(extra)",
                    fixTitle: "Rebuild Index",
                    fixHint: "Run 'git read-tree HEAD' to rebuild the index, then retry checkout",
                    fixAction: {
                        Task {
                            let rebuildResult = await shell.execute(
                                "git", arguments: ["read-tree", "HEAD"], workingDirectory: path
                            )
                            if rebuildResult.isSuccess {
                                NotificationManager.shared.success("Index rebuilt", detail: "Try checking out again")
                                await appState.refresh()
                            } else {
                                NotificationManager.shared.errorSimple("Rebuild failed", detail: rebuildResult.stderr)
                            }
                        }
                    }
                )
            } else {
                NotificationManager.shared.errorWithFix(
                    "Checkout failed",
                    detail: "Cannot stash changes: \(stashResult.stderr)\n\nFiles with changes:\n\(fileList)\(extra)",
                    fixTitle: "Force Checkout",
                    fixHint: "Discard local changes and checkout (destructive)",
                    fixAction: {
                        Task {
                            let forceResult = await shell.execute(
                                "git", arguments: ["checkout", "-f", branch.isRemote ? branch.displayName : branch.name],
                                workingDirectory: path
                            )
                            if forceResult.isSuccess {
                                await appState.refresh()
                                NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                                NotificationManager.shared.success("Checked out (forced)", detail: branch.isRemote ? branch.displayName : branch.name)
                            } else {
                                NotificationManager.shared.errorSimple("Force checkout failed", detail: forceResult.stderr)
                            }
                        }
                    }
                )
            }
            return
        }

        // 2. Perform checkout
        let checkoutResult: ShellResult
        let targetName: String

        if branch.isRemote {
            targetName = branch.displayName
            checkoutResult = await shell.execute(
                "git",
                arguments: ["checkout", "-b", targetName, "--track", branch.name],
                workingDirectory: path
            )
        } else {
            targetName = branch.name
            checkoutResult = await shell.execute(
                "git",
                arguments: ["checkout", branch.name],
                workingDirectory: path
            )
        }

        if checkoutResult.isSuccess {
            // 3. Pop stash if we stashed something
            if didStash {
                let popResult = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )

                if !popResult.isSuccess {
                    // Stash pop failed - likely merge conflicts
                    let conflictFiles = await getConflictFiles(at: path, shell: shell)
                    let conflictList = conflictFiles.prefix(8).joined(separator: "\n")
                    let extra = conflictFiles.count > 8 ? "\n...and \(conflictFiles.count - 8) more" : ""

                    await appState.refresh()
                    NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
                    // Switch to WIP/staging view so user can see conflicts
                    appState.selectedCommit = nil
                    appState.selectedStash = nil
                    appState.bumpStatusChange()
                    NotificationManager.shared.errorWithFix(
                        "Checked out '\(targetName)' with conflicts",
                        detail: "Your stashed changes conflict with this branch.\n\nConflicting files:\n\(conflictList)\(extra)\n\nChanges are saved in stash. Resolve in the staging panel.",
                        fixTitle: "Open Terminal",
                        fixHint: "Or resolve conflicts manually, then run 'git stash drop'",
                        fixAction: {
                            NotificationCenter.default.post(
                                name: Notification.Name("openTerminal"),
                                object: nil
                            )
                        }
                    )
                    return
                }
            }

            // 4. Refresh UI
            await appState.refresh()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: path)
            NotificationManager.shared.success("Checked out", detail: targetName)
        } else {
            // Checkout failed - restore stash
            if didStash {
                _ = await shell.execute(
                    "git", arguments: ["stash", "pop"], workingDirectory: path
                )
            }

            // Show error with file list
            let errorDetail = checkoutResult.stderr
            if errorDetail.contains("would be overwritten") || errorDetail.contains("uncommitted changes") {
                let dirtyFiles = await getDirtyFileList(at: path, shell: shell)
                let fileList = dirtyFiles.prefix(8).joined(separator: "\n")
                let extra = dirtyFiles.count > 8 ? "\n...and \(dirtyFiles.count - 8) more" : ""
                NotificationManager.shared.errorWithFix(
                    "Checkout failed",
                    detail: "Uncommitted changes would be overwritten:\n\(fileList)\(extra)",
                    fixTitle: "Commit or Stash First",
                    fixHint: "Commit or stash your changes before switching branches",
                    fixAction: {
                        // Show staging panel
                        appState.selectedCommit = nil
                        appState.selectedStash = nil
                        appState.bumpStatusChange()
                    }
                )
            } else {
                NotificationManager.shared.error("Checkout failed", detail: errorDetail)
            }
        }
    }

    /// Get list of dirty (modified/staged/untracked) files
    private func getDirtyFileList(at path: String, shell: ShellExecutor) async -> [String] {
        let result = await shell.execute(
            "git", arguments: ["status", "--porcelain", "--short"],
            workingDirectory: path
        )
        guard result.isSuccess else { return [] }
        return result.stdout.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { line in
                // Format: "XY filename" - extract just filename with status indicator
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let status = String(trimmed.prefix(2)).trimmingCharacters(in: .whitespaces)
                let file = String(trimmed.dropFirst(3))
                return "  \(status) \(file)"
            }
    }

    /// Get list of files with merge conflicts
    private func getConflictFiles(at path: String, shell: ShellExecutor) async -> [String] {
        let result = await shell.execute(
            "git", arguments: ["diff", "--name-only", "--diff-filter=U"],
            workingDirectory: path
        )
        guard result.isSuccess else { return [] }
        return result.stdout.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { "  \($0)" }
    }

    private func mergePR(_ pr: GitHubPullRequest, method: MergeMethod) async {
        do {
            try await prTracker.mergePR(pr, method: method)
            // Refresh repository after merge
            try? await appState.gitService.refresh()
        } catch {
            NotificationManager.shared.error(
                "Merge failed",
                detail: error.localizedDescription
            )
        }
    }
}

// MARK: - Remote Sidebar Row
struct RemoteSidebarRow: View {
    let remote: Remote
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 12)

                Image(systemName: "network")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(remote.name)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .onHover { isHovered = $0 }
            .onTapGesture { isExpanded.toggle() }

            if isExpanded {
                ForEach(remote.branches) { branch in
                    SidebarBranchRow(branch: branch)
                        .padding(.leading, 20)
                }
            }
        }
    }
}

// MARK: - Stash Sidebar Row
struct StashSidebarRow: View {
    let stash: Stash
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.accent)

            Text(stash.message)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Tag Sidebar Row
struct TagSidebarRow: View {
    let tag: Tag
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.warning)

            Text(tag.name)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Sidebar Repo Row (unified for all repo types)
struct SidebarRepoRow: View {
    let repoPath: String
    let repoName: String
    let isActive: Bool
    let isFavorite: Bool
    var groupBadge: GroupBadge? = nil

    @EnvironmentObject var appState: AppState
    @ObservedObject private var groupsService = RepoGroupsService.shared
    @State private var isHovered = false
    @State private var showGroupPicker = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundStyle(isActive ? AppTheme.accent : AppTheme.info)

            Text(repoName)
                .font(.system(size: 10))
                .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textSecondary)
                .lineLimit(1)

            if let badge = groupBadge {
                badge
            }

            Spacer()

            if isHovered {
                Button {
                    groupsService.toggleFavorite(repoPath)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundStyle(isFavorite ? .yellow : AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            if isActive {
                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isHovered ? AppTheme.hover : (isActive ? AppTheme.hover.opacity(0.5) : Color.clear))
        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
        .onHover { isHovered = $0 }
        .onTapGesture {
            Task {
                await appState.openRepository(at: repoPath)
            }
        }
        .contextMenu {
            Button("Toggle Favorite") {
                groupsService.toggleFavorite(repoPath)
            }

            Menu("Add to Group") {
                ForEach(groupsService.groups) { group in
                    Button(group.name) {
                        groupsService.addRepoToGroup(repoPath, groupId: group.id)
                    }
                }

                Divider()

                Button("Create New Group...") {
                    showGroupPicker = true
                }
            }

            if !groupsService.getGroupsForRepo(repoPath).isEmpty {
                Menu("Remove from Group") {
                    ForEach(groupsService.getGroupsForRepo(repoPath)) { group in
                        Button(group.name) {
                            groupsService.removeRepoFromGroup(repoPath, groupId: group.id)
                        }
                    }
                }
            }

            Divider()

            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repoPath)
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(repoPath, forType: .string)
            }

            Divider()

            Button("Remove from List", role: .destructive) {
                RecentRepositoriesManager.shared.removeRecent(path: repoPath)
            }
        }
    }
}

// Note: SidebarSection is defined in SidebarSection.swift

// MARK: - Sidebar Recent Repo Row
struct SidebarRecentRepoRow: View {
    let repo: RecentRepository
    let isActive: Bool
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill.badge.gearshape")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? AppTheme.accent : AppTheme.info)

            Text(repo.name)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            if isActive {
                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : (isActive ? AppTheme.hover.opacity(0.5) : Color.clear))
        .onHover { isHovered = $0 }
        .onTapGesture {
            Task {
                await appState.openRepository(at: repo.path)
            }
        }
        .contextMenu {
            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(repo.path, forType: .string)
            }
            Divider()
            Button("Remove from List", role: .destructive) {
                RecentRepositoriesManager.shared.removeRecent(path: repo.path)
            }
        }
    }
}

