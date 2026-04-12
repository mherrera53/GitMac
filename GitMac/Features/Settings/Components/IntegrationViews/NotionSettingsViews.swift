import SwiftUI

// MARK: - Notion Connected View

struct NotionConnectedView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let databases: [NotionDatabase]
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
                Text("Connected")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !databases.isEmpty {
                    Text("\(databases.count) databases")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                DSButton("Disconnect", variant: .danger, size: .sm, action: onDisconnect)
            }

            if !databases.isEmpty {
                ForEach(databases.prefix(5)) { db in
                    Text(db.displayTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                if databases.count > 5 {
                    Text("and \(databases.count - 5) more...")
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                Text("Share databases with your integration to see them here")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Notion Login Settings View

struct NotionLoginSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var token: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            DSSecureField(placeholder: "Integration Token", text: $token)

            if let error = error {
                Text(error)
                    .foregroundStyle(AppTheme.error)
                    .font(DesignTokens.Typography.caption)
            }

            HStack {
                DSButton(variant: .primary, size: .sm, isDisabled: token.isEmpty || isLoading) {
                    onLogin()
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Connect")
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }

                Link("Create Integration", destination: URL(string: "https://www.notion.so/my-integrations")!)
                    .font(DesignTokens.Typography.caption)
            }

            Text("Remember to share your databases with the integration")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
