import SwiftUI

// MARK: - Linear Connected View

struct LinearConnectedView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let teams: [LinearTeam]
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected")
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if !teams.isEmpty {
                    Text("\(teams.count) teams")
                        .foregroundColor(AppTheme.textSecondary)
                }
                DSButton("Disconnect", variant: .danger, size: .sm, action: onDisconnect)
            }

            if !teams.isEmpty {
                ForEach(teams) { team in
                    HStack {
                        Text(team.key)
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .foregroundColor(AppTheme.textSecondary)
                        Text(team.name)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }

            Link("Open Linear", destination: URL(string: "https://linear.app")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}

// MARK: - Linear Login Settings View

struct LinearLoginSettingsView: View {
    @Binding var apiKey: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        DSSecureField(placeholder: "API Key", text: $apiKey)

        if let error = error {
            Text(error)
                .foregroundColor(AppTheme.error)
                .font(DesignTokens.Typography.caption)
        }

        HStack {
            DSButton(variant: .primary, size: .sm, isDisabled: apiKey.isEmpty || isLoading) {
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

            Link("Get API Key", destination: URL(string: "https://linear.app/settings/api")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}
