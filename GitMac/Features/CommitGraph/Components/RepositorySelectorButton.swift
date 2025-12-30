import SwiftUI

struct RepositorySelectorButton: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showPicker = false

    var body: some View {
        let theme = Color.Theme(themeManager.colors)
        let currentRepo = appState.currentRepository

        return Menu {
            // Recent repositories
            if !appState.recentRepositories.isEmpty {
                Section("Recent") {
                    ForEach(appState.recentRepositories.prefix(5)) { repo in
                        Button {
                            Task {
                                await appState.openRepository(path: repo.path)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill.badge.gearshape")
                                    .symbolRenderingMode(.hierarchical)
                                Text(repo.name)
                                Spacer()
                                if repo.path == currentRepo?.path {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.success)
                                        .symbolRenderingMode(.multicolor)
                                }
                            }
                        }
                    }
                }

                Divider()
            }

            Button {
                showPicker = true
            } label: {
                Label("Open Repository...", systemImage: "plus.rectangle.on.folder.fill")
                    .symbolRenderingMode(.hierarchical)
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: currentRepo != nil ? "folder.fill.badge.gearshape" : "folder.badge.questionmark")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(currentRepo != nil ? AppTheme.accent : theme.textMuted)
                    .symbolRenderingMode(.hierarchical)

                Text(currentRepo?.name ?? "No Repository")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(theme.text)
                    .lineLimit(1)

                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textMuted)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(theme.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .menuStyle(.borderlessButton)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task {
                    await appState.openRepository(path: url.path)
                }
            }
        }
    }
}
