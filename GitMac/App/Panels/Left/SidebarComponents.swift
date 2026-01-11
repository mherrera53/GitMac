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

// MARK: - Sidebar Branch Row
struct SidebarBranchRow: View {
    let branch: Branch
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    @State private var showPRSheet = false
    @State private var branchPRs: [GitHubPullRequest] = []
    @State private var isLoadingPRs = false
    @State private var showUncommittedAlert = false
    @State private var showForceCheckoutAlert = false

    private let githubService = GitHubService()

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(branch.isCurrent ? AppTheme.success : AppTheme.textMuted)
                .frame(width: 8, height: 8)

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? AppTheme.success : AppTheme.textSecondary)

            Text(branch.name)
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            if branch.isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.success)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture {
            appState.selectedBranch = branch
        }
        .onDrag {
            return NSItemProvider(object: branch.name as NSString)
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

            // Existing PRs for this branch
            if !branchPRs.isEmpty {
                ForEach(branchPRs) { pr in
                    Menu {
                        if pr.state == "open" {
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
                            Image(systemName: pr.state == "open" ? "arrow.triangle.pull" : "checkmark.circle.fill")
                                .foregroundColor(pr.state == "open" ? .green : .purple)
                            Text("PR #\(pr.number): \(pr.title)")
                        }
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
        .onAppear {
            loadBranchPRs()
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
                        print("Stash & checkout failed: \(error)")
                    }
                }
            }
            Button("Force Checkout", role: .destructive) {
                Task {
                    do {
                        try await appState.gitService.checkoutForce(branch.name)
                    } catch {
                        print("Force checkout failed: \(error)")
                    }
                }
            }
        } message: {
            Text("You have uncommitted changes. Commit them first, stash them, or force checkout (will discard changes).")
        }
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

        // No changes, proceed with checkout
        do {
            try await appState.gitService.checkout(branch.name)
            await appState.refresh()
            NotificationCenter.default.post(name: .repositoryDidRefresh, object: appState.currentRepository?.path)
        } catch {
            print("Checkout failed: \(error)")
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

        // 2. Perform checkout
        do {
            try await appState.gitService.checkout(branch.name)

            // 3. Pop stash if we stashed something
            if didStash {
                let popResult = await shell.execute(
                    "git",
                    arguments: ["stash", "pop"],
                    workingDirectory: path
                )

                if !popResult.isSuccess {
                    print("Stash pop failed - changes remain in stash")
                }
            }

            // 4. Refresh UI to update graph and branch indicator
            await appState.refresh()
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
            print("Checkout failed: \(error)")
        }
    }

    private func loadBranchPRs() {
        guard !isLoadingPRs else { return }
        isLoadingPRs = true

        Task {
            guard let repo = appState.currentRepository,
                  let remoteURL = repo.remotes.first?.fetchURL else {
                isLoadingPRs = false
                return
            }

            let (owner, repoName) = parseGitHubURL(remoteURL)
            guard !owner.isEmpty, !repoName.isEmpty else {
                isLoadingPRs = false
                return
            }

            do {
                let allPRs = try await githubService.listPullRequests(
                    owner: owner,
                    repo: repoName,
                    state: .all
                )
                // Filter PRs that have this branch as head
                branchPRs = allPRs.filter { $0.head.ref == branch.name }
            } catch {
                // Silently fail
            }

            isLoadingPRs = false
        }
    }

    private func parseGitHubURL(_ url: String) -> (owner: String, repo: String) {
        let cleanURL = url
            .replacingOccurrences(of: "git@github.com:", with: "")
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")

        let parts = cleanURL.components(separatedBy: "/")
        guard parts.count >= 2 else { return ("", "") }

        return (parts[0], parts[1])
    }

    private func mergePR(_ pr: GitHubPullRequest, method: MergeMethod) async {
        guard let repo = appState.currentRepository,
              let remoteURL = repo.remotes.first?.fetchURL else {
            return
        }

        let (owner, repoName) = parseGitHubURL(remoteURL)
        guard !owner.isEmpty, !repoName.isEmpty else {
            return
        }

        do {
            try await githubService.mergePullRequest(
                owner: owner,
                repo: repoName,
                number: pr.number,
                mergeMethod: method
            )
            // Reload PRs after merge
            loadBranchPRs()
            // Refresh git status
            try? await appState.gitService.refresh()
        } catch {
            print("Failed to merge PR: \(error)")
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
