import SwiftUI

struct WelcomeView: View {
    let onOpen: () -> Void
    let onClone: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()

            // App Icon
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(AppTheme.accent)

            // Welcome text
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Welcome to GitMac")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)

                Text("A modern Git client for macOS")
                    .font(.title3)
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Action buttons
            HStack(spacing: DesignTokens.Spacing.lg) {
                WelcomeButton(
                    title: "Open Repository",
                    icon: "folder",
                    action: onOpen
                )

                WelcomeButton(
                    title: "Clone Repository",
                    icon: "arrow.down.circle",
                    action: onClone
                )
            }

            Spacer()

            // Recent repositories
            RecentRepositoriesSection()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

struct WelcomeButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.accent)

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(width: 160, height: 100)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.lg)
        }
        .buttonStyle(.plain)
    }
}

struct RecentRepositoriesSection: View {
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Recent Repositories")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)

            if recentReposManager.recentRepos.isEmpty {
                Text("No recent repositories")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.vertical, DesignTokens.Spacing.lg)
            } else {
                ForEach(recentReposManager.recentRepos.prefix(5), id: \.path) { repo in
                    RecentRepoRow(repo: repo)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 400)
    }
}

struct RecentRepoRow: View {
    let repo: RecentRepository
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        Button {
            Task {
                await appState.openRepository(at: repo.path)
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(repo.path)
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(repo.lastOpened, style: .relative)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
