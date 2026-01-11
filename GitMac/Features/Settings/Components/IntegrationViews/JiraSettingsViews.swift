import SwiftUI

// MARK: - Jira Connected View

struct JiraConnectedView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let projects: [JiraProject]
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected")
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if !projects.isEmpty {
                    Text("\(projects.count) projects")
                        .foregroundColor(AppTheme.textSecondary)
                }
                DSButton("Disconnect", variant: .danger, size: .sm, action: onDisconnect)
            }

            if !projects.isEmpty {
                ForEach(projects.prefix(5)) { project in
                    HStack {
                        Text(project.key)
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .foregroundColor(AppTheme.textSecondary)
                        Text(project.name)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                if projects.count > 5 {
                    Text("and \(projects.count - 5) more...")
                        .foregroundColor(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
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
                .foregroundColor(AppTheme.error)
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
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            Link("Get API Token", destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}
