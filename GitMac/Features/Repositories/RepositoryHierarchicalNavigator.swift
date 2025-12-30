//
//  RepositoryHierarchicalNavigator.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Xcode-style hierarchical navigation for repositories with horizontal breadcrumbs
//

import SwiftUI

// MARK: - Navigation Level

enum RepoNavigationLevel: Equatable {
    case root
    case favorites
    case group(id: String, name: String)
    case recent

    var title: String {
        switch self {
        case .root:
            return "Repositories"
        case .favorites:
            return "Favorites"
        case .group(_, let name):
            return name
        case .recent:
            return "Recent"
        }
    }

    var icon: String {
        switch self {
        case .root:
            return "folder.fill"
        case .favorites:
            return "star.fill"
        case .group:
            return "folder.fill"
        case .recent:
            return "clock.fill"
        }
    }
}

// MARK: - Horizontal Breadcrumb Bar

struct RepositoryBreadcrumbBar: View {
    let navigationPath: [RepoNavigationLevel]
    let onNavigate: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(navigationPath.enumerated()), id: \.offset) { index, level in
                    Button(action: { onNavigate(index) }) {
                        HStack(spacing: 4) {
                            Image(systemName: level.icon)
                                .font(.system(size: 11))
                            Text(level.title)
                                .font(.system(size: 11, weight: index == navigationPath.count - 1 ? .semibold : .regular))
                        }
                        .foregroundColor(index == navigationPath.count - 1 ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(index == navigationPath.count - 1 ? AppTheme.hover.opacity(0.5) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    if index < navigationPath.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 24)
        .background(AppTheme.backgroundSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Horizontal Action Bar

struct RepositoryActionBar: View {
    let onOpenRepo: () -> Void
    let onCloneRepo: () -> Void
    let onInitRepo: () -> Void
    let onManageGroups: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ActionBarButton(icon: "folder.badge.plus", title: "Open", action: onOpenRepo)
                ActionBarButton(icon: "arrow.down.circle", title: "Clone", action: onCloneRepo)
                ActionBarButton(icon: "plus.circle", title: "Init", action: onInitRepo)

                Divider()
                    .frame(height: 16)

                ActionBarButton(icon: "folder.badge.gearshape", title: "Groups", action: onManageGroups)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 28)
        .background(AppTheme.backgroundSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 0.5)
        }
    }
}

struct ActionBarButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(isHovered ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Hierarchical Navigator Container

struct RepositoryHierarchicalNavigator: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @ObservedObject private var groupsService = RepoGroupsService.shared

    @State private var navigationPath: [RepoNavigationLevel] = [.root]
    @State private var showCloneSheet = false
    @State private var showInitSheet = false
    @State private var showGroupManagement = false

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb navigation
            RepositoryBreadcrumbBar(navigationPath: navigationPath) { index in
                // Navigate back to specific level
                navigationPath = Array(navigationPath.prefix(index + 1))
            }

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    currentLevelContent
                }
                .padding(.top, 8)
            }

            Spacer()

            // Action bar at bottom
            RepositoryActionBar(
                onOpenRepo: { openRepository() },
                onCloneRepo: { showCloneSheet = true },
                onInitRepo: { showInitSheet = true },
                onManageGroups: { showGroupManagement = true }
            )
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

    @ViewBuilder
    private var currentLevelContent: some View {
        switch navigationPath.last ?? .root {
        case .root:
            rootLevelContent
        case .favorites:
            favoritesContent
        case .group(let id, _):
            groupContent(groupId: id)
        case .recent:
            recentContent
        }
    }

    @ViewBuilder
    private var rootLevelContent: some View {
        // Show categories to navigate into
        if !groupsService.favorites.isEmpty {
            NavigationCategoryRow(
                icon: "star.fill",
                iconColor: .yellow,
                title: "Favorites",
                count: groupsService.favorites.count
            ) {
                navigationPath.append(.favorites)
            }
        }

        ForEach(groupsService.groups.sorted(by: { $0.sortOrder < $1.sortOrder })) { group in
            if !group.repos.isEmpty {
                NavigationCategoryRow(
                    icon: "folder.fill",
                    iconColor: Color(hex: group.color),
                    title: group.name,
                    count: group.repos.count
                ) {
                    navigationPath.append(.group(id: group.id, name: group.name))
                }
            }
        }

        if !recentReposManager.recentRepos.isEmpty {
            let ungroupedCount = recentReposManager.recentRepos.filter { repo in
                !groupsService.favorites.contains(repo.path) &&
                groupsService.getGroupsForRepo(repo.path).isEmpty
            }.count

            if ungroupedCount > 0 {
                NavigationCategoryRow(
                    icon: "clock.fill",
                    iconColor: .secondary,
                    title: "Recent",
                    count: ungroupedCount
                ) {
                    navigationPath.append(.recent)
                }
            }
        }

        // Empty state
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
    }

    @ViewBuilder
    private var favoritesContent: some View {
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

    @ViewBuilder
    private func groupContent(groupId: String) -> some View {
        if let group = groupsService.groups.first(where: { $0.id == groupId }) {
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

    @ViewBuilder
    private var recentContent: some View {
        ForEach(recentReposManager.recentRepos.filter { repo in
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

    private func openRepository() {
        NotificationCenter.default.post(name: .openRepository, object: nil)
    }
}

// MARK: - Navigation Category Row

struct NavigationCategoryRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
