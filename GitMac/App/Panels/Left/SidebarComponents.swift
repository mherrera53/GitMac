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
                .foregroundColor(branchIconColor)

            // Branch name (show display name for remote to strip origin/)
            Text(branch.isRemote ? branch.displayName : branch.name)
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)

            if branch.isProtected {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.warning)
                    .help("Protected branch")
            }

            Spacer()

            if branch.isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.success)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(branch.isRemote ? "Remote branch" : "Branch") \(branch.isRemote ? branch.displayName : branch.name)\(branch.isCurrent ? ", current" : "")")
        .accessibilityAddTraits(branch.isCurrent ? [.isSelected] : [])
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
                            .foregroundColor(pr.draft ? .gray : (pr.state == "open" ? .green : .purple))
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
                    do {
                        try await appState.gitService.deleteBranch(named: branch.name)
                        // Refresh branchManager to update sidebar immediately
                        await appState.branchManager?.refresh()
                        await appState.refresh()
                    } catch {
                        NotificationManager.shared.error("Delete failed", detail: error.localizedDescription)
                    }
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
        // Check for uncommitted changes
        if let status = appState.currentRepository?.status {
            let hasChanges = !status.staged.isEmpty || !status.unstaged.isEmpty || !status.untracked.isEmpty
            if hasChanges {
                // Auto stash -> checkout -> pop (to avoid accumulating stashes)
                await performCheckoutWithAutoStash()
                return
            }
        }

        // No changes, proceed with checkout using GitService
        do {
            try await appState.gitService.checkoutBranch(branch)
            // Refresh appState to sync the updated repository to tabs
            await appState.refresh()
            // Update selected branch to the checked out branch
            appState.selectedBranch = branch
            let targetName = branch.isRemote ? branch.displayName : branch.name
            NotificationManager.shared.success("Checked out", detail: targetName)
        } catch {
            NotificationManager.shared.error("Checkout failed", detail: error.localizedDescription)
        }
    }

    private func performCheckoutWithAutoStash() async {
        do {
            try await appState.gitService.checkoutBranchWithAutoStash(branch)
            // Refresh appState to sync the updated repository to tabs
            await appState.refresh()
            // Update selected branch to the checked out branch
            appState.selectedBranch = branch
            let targetName = branch.isRemote ? branch.displayName : branch.name
            NotificationManager.shared.success("Checked out", detail: targetName)
        } catch {
            NotificationManager.shared.error("Checkout failed", detail: error.localizedDescription)
        }
    }

    private func mergePR(_ pr: GitHubPullRequest, method: MergeMethod) async {
        do {
            try await prTracker.mergePR(pr, method: method)
            // Refresh repository and branchManager after merge for immediate UI update
            try? await appState.gitService.refresh()
            await appState.branchManager?.refresh()
            await appState.refresh()
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
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 12)

                Image(systemName: "network")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)

                Text(remote.name)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)

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
                .foregroundColor(AppTheme.accent)

            Text(stash.message)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
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
                .foregroundColor(AppTheme.warning)

            Text(tag.name)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
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
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.info)

            Text(repoName)
                .font(.system(size: 10))
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
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
                        .foregroundColor(isFavorite ? .yellow : AppTheme.textMuted)
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
        .cornerRadius(DesignTokens.CornerRadius.sm)
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
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.info)

            Text(repo.name)
                .font(.system(size: 11))
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
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

