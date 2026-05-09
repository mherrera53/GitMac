import SwiftUI

struct AccountsSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var githubToken = ""
    @State private var isGitHubConnected = false
    @State private var githubUser: GitHubUser?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // OAuth Device Flow state
    @State private var showOAuthFlow = false
    @State private var deviceCodeResponse: GitHubOAuth.DeviceCodeResponse?
    @State private var isWaitingForAuth = false
    @State private var oauthClientId = ""
    @State private var oauthConfigured = false

    private let githubService = GitHubService()
    private let githubOAuth = GitHubOAuth.shared

    var body: some View {
        Form {
            SettingsSection(title: "GitHub") {
                if isGitHubConnected, let user = githubUser {
                    // Connected state
                    HStack {
                        AsyncImage(url: URL(string: user.avatarUrl)) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading) {
                            Text(user.name ?? user.login)
                                .foregroundStyle(AppTheme.textPrimary)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("@\(user.login)")
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        DSButton("Disconnect", variant: .danger, size: .sm) {
                            try? await githubService.logout()
                            isGitHubConnected = false
                            githubUser = nil
                        }
                    }
                } else if isWaitingForAuth, let deviceCode = deviceCodeResponse {
                    // OAuth Device Flow - Waiting for user to authorize
                    GitHubOAuthWaitingView(
                        userCode: deviceCode.userCode,
                        verificationUri: deviceCode.verificationUri,
                        onCancel: {
                            Task { await githubOAuth.cancelAuthentication() }
                            isWaitingForAuth = false
                            deviceCodeResponse = nil
                        }
                    )
                } else {
                    // Not connected - show login options
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        Text("Connect to GitHub")
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Sign in to enable pull requests, issues, and repository features.")
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        // OAuth Login (recommended)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Sign in with Browser (Recommended)")
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Uses GitHub's secure OAuth flow. Supports 2FA.")
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            DSButton(variant: .primary, isDisabled: isLoading) {
                                startOAuthFlow()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Sign in with GitHub")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        Divider()

                        // Personal Access Token (alternative)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Or use Personal Access Token")
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.textPrimary)

                            DSSecureField(placeholder: "Personal Access Token", text: $githubToken)

                            HStack {
                                DSButton("Generate Token", variant: .link, size: .sm) {
                                    NSWorkspace.shared.open(URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:user")!)
                                }

                                Spacer()

                                DSButton("Connect", variant: .primary, size: .sm, isDisabled: githubToken.isEmpty || isLoading) {
                                    connectGitHub()
                                }
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundStyle(AppTheme.error)
                                .font(DesignTokens.Typography.caption)
                        }
                    }
                }
            }

            SettingsSection(title: "OAuth Configuration") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("To use OAuth sign-in, you need a GitHub OAuth App Client ID.")
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    if oauthConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                            Text("Client ID configured")
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            DSButton("Change", variant: .link, size: .sm) {
                                oauthConfigured = false
                                oauthClientId = ""
                            }
                        }
                    } else {
                        HStack {
                            DSTextField(placeholder: "OAuth Client ID", text: $oauthClientId)

                            DSButton("Save", variant: .primary, size: .sm, isDisabled: oauthClientId.isEmpty) {
                                await githubOAuth.setClientId(oauthClientId)
                                oauthConfigured = true
                            }
                        }
                    }

                    DSButton("Create OAuth App on GitHub", variant: .link, size: .sm) {
                        NSWorkspace.shared.open(URL(string: "https://github.com/settings/developers")!)
                    }
                }
            }

            SettingsSection(title: "Required Scopes") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Label("repo - Full control of private repositories", systemImage: "checkmark.circle")
                    Label("user - Read user profile data", systemImage: "checkmark.circle")
                    Label("read:org - Read organization membership", systemImage: "checkmark.circle")
                }
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.background)
        .task {
            await checkGitHubConnection()
            oauthConfigured = await githubOAuth.hasClientId
        }
    }

    private func startOAuthFlow() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Request device code
                let response = try await githubOAuth.startAuthentication()
                deviceCodeResponse = response
                isWaitingForAuth = true
                isLoading = false

                // Open browser
                await githubOAuth.openVerificationPage()

                // Wait for authentication
                let token = try await githubOAuth.waitForAuthentication(deviceCode: response)

                // Save token and fetch user
                try await githubService.setToken(token)
                let user = try await githubService.getCurrentUser()

                await MainActor.run {
                    githubUser = user
                    isGitHubConnected = true
                    isWaitingForAuth = false
                    deviceCodeResponse = nil
                }
            } catch let error as GitHubOAuth.OAuthError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isWaitingForAuth = false
                    deviceCodeResponse = nil
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isWaitingForAuth = false
                    deviceCodeResponse = nil
                    isLoading = false
                }
            }
        }
    }

    private func connectGitHub() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await githubService.setToken(githubToken)
                let user = try await githubService.getCurrentUser()
                githubUser = user
                isGitHubConnected = true
                githubToken = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func checkGitHubConnection() async {
        if await githubService.isAuthenticated {
            do {
                githubUser = try await githubService.getCurrentUser()
                isGitHubConnected = true
            } catch {
                isGitHubConnected = false
            }
        }
    }
}

// MARK: - OAuth Waiting View

struct GitHubOAuthWaitingView: View {
    @Environment(ThemeManager.self) private var themeManager
    let userCode: String
    let verificationUri: String
    let onCancel: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "link.circle.fill")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundStyle(AppTheme.accent)

            Text("Enter this code on GitHub")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.headline)

            // User code - large and copyable
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(userCode)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.title1.bold().monospaced())
                    .tracking(4)

                DSIconButton(iconName: copied ? "checkmark" : "doc.on.doc", variant: .ghost, size: .sm) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }
            }
            .padding()
            .background(AppTheme.textSecondary.opacity(0.1))
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.lg))

            if copied {
                Text("Copied!")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.success)
            }

            Text("Waiting for authorization...")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ProgressView()
                .scaleEffect(0.8)

            HStack {
                DSButton("Open GitHub", variant: .primary, size: .sm) {
                    if let url = URL(string: verificationUri) {
                        NSWorkspace.shared.open(url)
                    }
                }

                DSButton("Cancel", variant: .secondary, size: .sm) {
                    onCancel()
                }
            }
        }
        .padding()
    }
}
