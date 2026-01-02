import SwiftUI

struct RepositoryTabsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.openTabs) { tab in
                    RepositoryTabPill(
                        tab: tab,
                        isActive: appState.activeTabId == tab.id,
                        onSelect: {
                            appState.selectTab(tab.id)
                        },
                        onClose: {
                            appState.closeTab(tab.id)
                        }
                    )
                }

                // Add/Open Button
                Button(action: {
                     NotificationCenter.default.post(name: .openRepository, object: nil)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.backgroundSecondary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Open Repository")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .frame(height: 32)
    }
}

private struct RepositoryTabPill: View {
    let tab: RepositoryTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Repo Icon / Color
                if let color = getGroupColor(for: tab.repository.path) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                } else {
                    Image(systemName: "cube")
                        .font(.system(size: 10))
                        .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
                }

                // Repo Name
                Text(tab.repository.name)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)

                // Branch Indicator (Xcode-style)
                if isActive, let branch = tab.repository.currentBranch {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                        Text(branch.name)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(4)
                    .padding(.leading, 4)
                }

                // Close Button (visible on hover or active)
                if isActive || isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(isActive ? AppTheme.textSecondary : AppTheme.textMuted)
                            .frame(width: 14, height: 14)
                            .background(Color.black.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 16) // Pill shape
                    .fill(isActive ? AppTheme.backgroundSecondary : (isHovering ? AppTheme.backgroundTertiary : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? AppTheme.border : Color.clear, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private func getGroupColor(for repoPath: String) -> Color? {
        // Simple wrapper to access the service
        let groups = RepoGroupsService.shared.getGroupsForRepo(repoPath)
        return groups.first.map { Color(hex: $0.color) }
    }
}
