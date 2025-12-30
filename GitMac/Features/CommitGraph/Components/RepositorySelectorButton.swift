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
                                Image(systemName: "folder.fill")
                                Text(repo.name)
                                Spacer()
                                if repo.path == currentRepo?.path {
                                    Image(systemName: "checkmark")
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
                Label("Open Repository...", systemImage: "folder.badge.plus")
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "folder.fill")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(theme.text)

                Text(currentRepo?.name ?? "No Repository")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(theme.text)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textMuted)
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
