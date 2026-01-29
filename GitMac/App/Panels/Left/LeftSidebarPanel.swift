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
                            .foregroundStyle(AppTheme.accent)
                            .font(.system(size: 12))
                        Text(repo.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(appState.selectedBranch?.name ?? repo.currentBranch?.name ?? "No Branch")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
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
        // Configure PR tracker when repository changes
        .task(id: appState.currentRepository?.path) {
            if let path = appState.currentRepository?.path {
                await BranchPRTracker.shared.configure(forRepoAt: path)
            }
        }
    }

    @ViewBuilder
    private var navigatorContent: some View {
        switch selectedNavigator {
        case .repositories:
            RepositoryHierarchicalNavigator()

        case .branches, .remote:
            // Unified branch view - shows both local and remote branches in one list
            // Branch search bar
            if appState.currentRepository != nil {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)

                    DSTextField(placeholder: "Search branches...", text: $branchSearchText)
                        .font(.system(size: 11))

                    if !branchSearchText.isEmpty {
                        Button(action: { branchSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }

            // All branches: local first (current at top), then remote
            // Uses cached sorted lists from AppState (updated on repo refresh)
            let localBranches = branchSearchText.isEmpty
                ? appState.sortedLocalBranches
                : appState.sortedLocalBranches.filter {
                    $0.name.localizedStandardContains(branchSearchText)
                }

            ForEach(localBranches) { branch in
                SidebarBranchRow(branch: branch)
            }

            // Remote branches
            let remoteBranches = branchSearchText.isEmpty
                ? appState.sortedRemoteBranches
                : appState.sortedRemoteBranches.filter {
                    $0.name.localizedStandardContains(branchSearchText)
                }

            if !remoteBranches.isEmpty {
                HStack {
                    Text("Remote")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.top, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.xxs)

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
