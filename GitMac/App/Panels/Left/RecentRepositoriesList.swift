//
//  RecentRepositoriesList.swift
//  GitMac
//
//  Extracted from ContentView.swift
//  Contains: RecentRepositoriesList, MiniSidebarSection, ActionButton
//

import SwiftUI
import Foundation
import AppKit

// MARK: - Recent Repositories List
struct RecentRepositoriesList: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @ObservedObject private var groupsService = RepoGroupsService.shared

    @State private var expandedGroups: Set<String> = ["favorites", "recent"]
    @State private var showCloneSheet = false
    @State private var showInitSheet = false
    @State private var showGroupManagement = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // FAVORITES Section
            if !groupsService.favorites.isEmpty {
                MiniSidebarSection(
                    title: "FAVORITES",
                    icon: "star.fill",
                    iconColor: .yellow,
                    isExpanded: expandedGroups.contains("favorites")
                ) {
                    expandedGroups.toggle("favorites")
                } content: {
                    ForEach(Array(groupsService.favorites), id: \.self) { repoPath in
                        if let repo = recentReposManager.recentRepos.first(where: { $0.path == repoPath }) {
                            SidebarRepoRow(
                                repoPath: repoPath,
                                repoName: repo.name,
                                isActive: appState.currentRepository?.path == repoPath,
                                isFavorite: true
                            )
                        } else {
                            SidebarRepoRow(
                                repoPath: repoPath,
                                repoName: URL(fileURLWithPath: repoPath).lastPathComponent,
                                isActive: appState.currentRepository?.path == repoPath,
                                isFavorite: true
                            )
                        }
                    }
                }
            }

            // GROUPS Sections
            ForEach(groupsService.groups.sorted(by: { $0.sortOrder < $1.sortOrder })) { group in
                if !group.repos.isEmpty {
                    MiniSidebarSection(
                        title: group.name.uppercased(),
                        icon: "folder.fill",
                        iconColor: Color(hex: group.color),
                        isExpanded: expandedGroups.contains(group.id)
                    ) {
                        expandedGroups.toggle(group.id)
                    } content: {
                        ForEach(group.repos, id: \.self) { repoPath in
                            if let repo = recentReposManager.recentRepos.first(where: { $0.path == repoPath }) {
                                SidebarRepoRow(
                                    repoPath: repoPath,
                                    repoName: repo.name,
                                    isActive: appState.currentRepository?.path == repoPath,
                                    isFavorite: groupsService.isFavorite(repoPath),
                                    groupBadge: GroupBadge(group: group)
                                )
                            } else {
                                SidebarRepoRow(
                                    repoPath: repoPath,
                                    repoName: URL(fileURLWithPath: repoPath).lastPathComponent,
                                    isActive: appState.currentRepository?.path == repoPath,
                                    isFavorite: groupsService.isFavorite(repoPath),
                                    groupBadge: GroupBadge(group: group)
                                )
                            }
                        }
                    }
                }
            }

            // RECENT Section
            if !recentReposManager.recentRepos.isEmpty {
                MiniSidebarSection(
                    title: "RECENT",
                    icon: "clock.fill",
                    iconColor: .secondary,
                    isExpanded: expandedGroups.contains("recent")
                ) {
                    expandedGroups.toggle("recent")
                } content: {
                    ForEach(recentReposManager.recentRepos.filter { repo in
                        // Only show repos not in favorites or groups
                        !groupsService.favorites.contains(repo.path) &&
                        groupsService.getGroupsForRepo(repo.path).isEmpty
                    }) { repo in
                        SidebarRepoRow(
                            repoPath: repo.path,
                            repoName: repo.name,
                            isActive: appState.currentRepository?.path == repo.path,
                            isFavorite: false
                        )
                    }
                }
            }

            // Empty State
            if recentReposManager.recentRepos.isEmpty && groupsService.favorites.isEmpty && groupsService.groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.textMuted)
                    Text("No repositories yet")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Divider()
                .padding(.vertical, 4)

            // Action Buttons
            VStack(spacing: 4) {
                ActionButton(icon: "folder.badge.plus", title: "Open Repository") {
                    openRepository()
                }

                ActionButton(icon: "arrow.down.circle", title: "Clone Repository") {
                    showCloneSheet = true
                }

                ActionButton(icon: "plus.circle", title: "Init Repository") {
                    showInitSheet = true
                }

                ActionButton(icon: "folder.badge.gearshape", title: "Manage Groups") {
                    showGroupManagement = true
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showCloneSheet) {
            CloneRepositorySheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showInitSheet) {
            InitRepositorySheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showGroupManagement) {
            GroupManagementSheet()
                .environmentObject(appState)
        }
    }

    private func openRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository folder"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                await appState.openRepository(at: url.path)
            }
        }
    }
}

// MARK: - Mini Sidebar Section (for repository groups)
struct MiniSidebarSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 10)
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundColor(iconColor)
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10))
                Spacer()
            }
            .foregroundColor(isHovered ? AppTheme.textPrimary : AppTheme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
