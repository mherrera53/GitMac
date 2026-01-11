import SwiftUI

// MARK: - Notion Connected View

struct NotionConnectedView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let databases: [NotionDatabase]
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected")
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if !databases.isEmpty {
                    Text("\(databases.count) databases")
                        .foregroundColor(AppTheme.textSecondary)
                }
                DSButton("Disconnect", variant: .danger, size: .sm, action: onDisconnect)
            }

            if !databases.isEmpty {
                ForEach(databases.prefix(5)) { db in
                    Text(db.displayTitle)
                        .foregroundColor(AppTheme.textPrimary)
                }
                if databases.count > 5 {
                    Text("and \(databases.count - 5) more...")
                        .foregroundColor(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                Text("Share databases with your integration to see them here")
                    .foregroundColor(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Notion Login Settings View

struct NotionLoginSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var token: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            DSSecureField(placeholder: "Integration Token", text: $token)

            if let error = error {
                Text(error)
                    .foregroundColor(AppTheme.error)
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
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }

                Link("Create Integration", destination: URL(string: "https://www.notion.so/my-integrations")!)
                    .font(DesignTokens.Typography.caption)
            }

            Text("Remember to share your databases with the integration")
                .foregroundColor(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}
