import SwiftUI

// MARK: - Jira Connected View

struct JiraConnectedView: View {
    @Environment(ThemeManager.self) private var themeManager
    let projects: [JiraProject]
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
                Text("Connected")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !projects.isEmpty {
                    Text("\(projects.count) projects")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                DSButton("Disconnect", variant: .danger, size: .sm, action: onDisconnect)
            }

            if !projects.isEmpty {
                ForEach(projects.prefix(5)) { project in
                    HStack {
                        Text(project.key)
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(project.name)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                if projects.count > 5 {
                    Text("and \(projects.count - 5) more...")
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Jira Login Settings View

struct JiraLoginSettingsView: View {
    @Binding var siteUrl: String
    @Binding var email: String
    @Binding var apiToken: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        DSTextField(placeholder: "Site URL (e.g. yourcompany.atlassian.net)", text: $siteUrl)

        DSTextField(placeholder: "Email", text: $email)

        DSSecureField(placeholder: "API Token", text: $apiToken)

        if let error = error {
            Text(error)
                .foregroundStyle(AppTheme.error)
                .font(DesignTokens.Typography.caption)
        }

        HStack {
            DSButton(variant: .primary, size: .sm, isDisabled: siteUrl.isEmpty || email.isEmpty || apiToken.isEmpty || isLoading) {
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

            Link("Get API Token", destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}
