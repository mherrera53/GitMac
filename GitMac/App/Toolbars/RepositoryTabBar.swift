import SwiftUI
import AppKit

// MARK: - Repository Tab Bar (Modern)
struct RepositoryTabBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 0) {
            // Tabs
            ScrollView(.horizontal) {
                HStack(spacing: 1) {
                    ForEach(appState.openTabs) { tab in
                        SingleRepoTab(tab: tab)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Repository info (current branch, status)
            if let repo = appState.currentRepository {
                HStack(spacing: 8) {
                    // Current branch
                    if let branch = repo.currentBranch {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.accent)
                            Text(branch.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.backgroundSecondary)
                        .clipShape(.rect(cornerRadius: 3))
                    }

                    // Uncommitted changes indicator
                    if !repo.status.staged.isEmpty || !repo.status.unstaged.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(AppTheme.warning)
                            Text("\(repo.status.staged.count + repo.status.unstaged.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(AppTheme.warning.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 3))
                    }
                }
                .padding(.horizontal, 8)
            }

            // Add new tab button
            Button {
                openNewRepository()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .help("Open Repository")
        }
        .frame(height: 32)
        .background(AppTheme.background)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func openNewRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository folder"
        panel.prompt = "Open"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                await appState.openRepository(at: url.path)
                recentReposManager.addRecent(path: url.path, name: url.lastPathComponent)
            }
        }
    }
}

// MARK: - Single Repo Tab
struct SingleRepoTab: View {
    let tab: RepositoryTab
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var groupsService = RepoGroupsService.shared
    @State private var isHovered = false

    var isActive: Bool {
        appState.activeTabId == tab.id
    }

    var groupColor: Color? {
        let groups = groupsService.getGroupsForRepo(tab.repository.path)
        guard let firstGroup = groups.first else { return nil }
        return SwiftUI.Color(hex: firstGroup.color)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Group color indicator (left side)
            if let color = groupColor {
                Rectangle()
                    .fill(color)
                    .frame(width: 2)
            }

            HStack(spacing: 6) {
                // Repo name - compact
                Text(tab.repository.name)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)

                // Close button (show on hover or if active)
                if isHovered || isActive {
                    Button {
                        appState.closeTab(tab.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isActive ? AppTheme.backgroundSecondary : (isHovered ? AppTheme.hover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isActive ? AppTheme.border : Color.clear, lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            appState.selectTab(tab.id)
        }
    }
}
