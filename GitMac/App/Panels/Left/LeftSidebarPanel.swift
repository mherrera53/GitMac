//
//  LeftSidebarPanel.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI
import Foundation

// MARK: - Left Sidebar Panel (Modern)
struct LeftSidebarPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedNavigator: SidebarNavigator = .branches
    @State private var branchSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Repository & Branch Header (Previously in Toolbar)
            if let repo = appState.currentRepository {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppTheme.accent)
                            .font(.system(size: 12))
                        Text(repo.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                        Text(appState.selectedBranch?.name ?? repo.currentBranch?.name ?? "No Branch")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                // Background removed to allow material to show through

                Divider()
            }



            // Xcode-style horizontal navigator tabs
            XcodeSidebarNavigatorBar(selectedNavigator: $selectedNavigator)

            // Navigator content
            List {
               navigatorContent
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRepositories)) { _ in selectedNavigator = .repositories }
        .onReceive(NotificationCenter.default.publisher(for: .showBranches)) { _ in selectedNavigator = .branches }
        .onReceive(NotificationCenter.default.publisher(for: .showRemotes)) { _ in selectedNavigator = .remote }
        .onReceive(NotificationCenter.default.publisher(for: .showStashes)) { _ in selectedNavigator = .stashes }
        .onReceive(NotificationCenter.default.publisher(for: .showTags)) { _ in selectedNavigator = .tags }
        .onReceive(NotificationCenter.default.publisher(for: .showWorktrees)) { _ in selectedNavigator = .worktrees }
    }

    @ViewBuilder
    private var navigatorContent: some View {
        switch selectedNavigator {
        case .repositories:
            RepositoryHierarchicalNavigator()

        case .branches:
            // Branch search bar
            if appState.currentRepository != nil {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)

                    DSTextField(placeholder: "Search branches...", text: $branchSearchText)
                        .font(.system(size: 11))

                    if !branchSearchText.isEmpty {
                        Button(action: { branchSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(.quaternary) // Use semantic system material/color
                .cornerRadius(DesignTokens.CornerRadius.md)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }

            // Local branches
            if let repo = appState.currentRepository {
                let allLocal = repo.branches.filter { !$0.isRemote }
                let localBranches = branchSearchText.isEmpty ? allLocal : allLocal.filter {
                    $0.name.localizedCaseInsensitiveContains(branchSearchText)
                }

                let mainBranch = localBranches.first { $0.name == "master" || $0.name == "main" }
                let currentBranch = localBranches.first { $0.isCurrent && $0.name != "master" && $0.name != "main" }
                let otherBranches = localBranches
                    .filter { !$0.isCurrent && $0.name != "master" && $0.name != "main" }

                if let main = mainBranch {
                    SidebarBranchRow(branch: main)
                }

                if let current = currentBranch {
                    SidebarBranchRow(branch: current)
                }

                ForEach(Array(otherBranches)) { branch in
                    SidebarBranchRow(branch: branch)
                }
            }

        case .remote:
            if let repo = appState.currentRepository {
                let allRemote = repo.remoteBranches
                let filteredRemote = branchSearchText.isEmpty ? allRemote : allRemote.filter {
                    $0.name.localizedCaseInsensitiveContains(branchSearchText)
                }
                let remoteBranches = filteredRemote.sorted { $0.name < $1.name }
                ForEach(remoteBranches) { branch in
                    SidebarBranchRow(branch: branch)
                }
            }

        case .stashes:
            if let repo = appState.currentRepository {
                ForEach(repo.stashes) { stash in
                    StashSidebarRow(stash: stash)
                }
            }

        case .tags:
            if let repo = appState.currentRepository {
                ForEach(repo.tags) { tag in
                    TagSidebarRow(tag: tag)
                }
            }

        case .cicd:
            CICDSidebarSection()

        case .worktrees:
            WorktreeSidebarSection()

        case .submodules:
            SubmoduleSidebarSection()

        case .hooks:
            GitHooksSidebarSection()
        }
    }
}
