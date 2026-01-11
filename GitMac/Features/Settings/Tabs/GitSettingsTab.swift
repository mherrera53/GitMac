import SwiftUI

struct GitConfigView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var defaultBranch = "main"
    @AppStorage("autoFetch") private var autoFetch = true
    @AppStorage("autoFetchInterval") private var autoFetchInterval = 5
    @AppStorage("pruneOnFetch") private var pruneOnFetch = true
    @State private var isLoading = true
    @State private var saveStatus: String?

    var body: some View {
        Form {
            SettingsSection(title: "User") {
                DSTextField(placeholder: "Name", text: $userName)
                    .onChange(of: userName) { _, newValue in
                        saveGitConfig(key: "user.name", value: newValue)
                    }
                DSTextField(placeholder: "Email", text: $userEmail)
                    .onChange(of: userEmail) { _, newValue in
                        saveGitConfig(key: "user.email", value: newValue)
                    }

                Text("These values are used for commits in repositories without local config")
                    .foregroundColor(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)

                if let status = saveStatus {
                    Text(status)
                        .foregroundColor(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.success)
                }
            }

            SettingsSection(title: "Defaults") {
                DSTextField(placeholder: "Default branch name", text: $defaultBranch)
                    .onChange(of: defaultBranch) { _, newValue in
                        saveGitConfig(key: "init.defaultBranch", value: newValue)
                    }
            }

            SettingsSection(title: "Fetching") {
                DSToggle("Auto-fetch in background", isOn: $autoFetch)

                if autoFetch {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Fetch interval")
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(AppTheme.textSecondary)

                        DSPicker(
                            items: ["1 minute", "5 minutes", "10 minutes", "15 minutes", "30 minutes"],
                            selection: Binding(
                                get: {
                                    switch autoFetchInterval {
                                    case 1: return "1 minute"
                                    case 5: return "5 minutes"
                                    case 10: return "10 minutes"
                                    case 15: return "15 minutes"
                                    case 30: return "30 minutes"
                                    default: return "5 minutes"
                                    }
                                },
                                set: { value in
                                    guard let val = value else { return }
                                    switch val {
                                    case "1 minute": autoFetchInterval = 1
                                    case "5 minutes": autoFetchInterval = 5
                                    case "10 minutes": autoFetchInterval = 10
                                    case "15 minutes": autoFetchInterval = 15
                                    case "30 minutes": autoFetchInterval = 30
                                    default: autoFetchInterval = 5
                                    }
                                }
                            )
                        )
                    }
                }

                DSToggle("Prune remote-tracking branches on fetch", isOn: $pruneOnFetch)
            }

            SettingsSection(title: "Email Aliases") {
                EmailAliasesView()
            }
        }
        .padding()
        .background(AppTheme.background)
        .task {
            await loadGitConfig()
        }
    }

    private func loadGitConfig() async {
        let shell = ShellExecutor()
        let nameResult = await shell.execute("git", arguments: ["config", "--global", "user.name"])
        let emailResult = await shell.execute("git", arguments: ["config", "--global", "user.email"])
        let branchResult = await shell.execute("git", arguments: ["config", "--global", "init.defaultBranch"])

        if nameResult.isSuccess {
            userName = nameResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if emailResult.isSuccess {
            userEmail = emailResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if branchResult.isSuccess {
            defaultBranch = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        isLoading = false
    }

    private func saveGitConfig(key: String, value: String) {
        guard !isLoading, !value.isEmpty else { return }
        Task {
            let shell = ShellExecutor()
            let result = await shell.execute("git", arguments: ["config", "--global", key, value])
            if result.isSuccess {
                saveStatus = "Saved"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    saveStatus = nil
                }
            }
        }
    }
}

// MARK: - Email Aliases View

struct EmailAliasesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var settings = EmailAliasSettings.shared
    @State private var newAlias = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Add email aliases to show your avatar on commits with different emails")
                .foregroundColor(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)

            HStack {
                DSTextField(placeholder: "Email alias (e.g. work@company.com)", text: $newAlias)

                DSButton("Add", variant: .primary, size: .sm, isDisabled: newAlias.isEmpty) {
                    settings.addAlias(newAlias)
                    newAlias = ""
                }
            }

            if !settings.aliases.isEmpty {
                ForEach(settings.aliases, id: \.self) { alias in
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(AppTheme.textSecondary)
                        Text(alias)
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.body.monospaced())
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        DSIconButton(iconName: "xmark.circle.fill", variant: .ghost, size: .sm) {
                            settings.removeAlias(alias)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                }
            }
        }
    }
}
