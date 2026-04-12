import SwiftUI

// MARK: - Linear Connected View

struct LinearConnectedView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let teams: [LinearTeam]
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
                Text("Connected")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !teams.isEmpty {
                    Text("\(teams.count) teams")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                DSButton("Disconnect", variant: .danger, size: .sm, action: onDisconnect)
            }

            if !teams.isEmpty {
                ForEach(teams) { team in
                    HStack {
                        Text(team.key)
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(team.name)
                            .foregroundStyle(AppTheme.textPrimary)
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
                .foregroundStyle(AppTheme.error)
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
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }

            Link("Get API Key", destination: URL(string: "https://linear.app/settings/api")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}
