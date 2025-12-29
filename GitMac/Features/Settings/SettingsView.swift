import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AccountsSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.circle")
                }

            IntegrationsSettingsView()
                .tabItem {
                    Label("Integrations", systemImage: "square.grid.2x2")
                }

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain")
                }

            GitConfigView()
                .tabItem {
                    Label("Git", systemImage: "arrow.triangle.branch")
                }

            KeyboardShortcutsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            SubscriptionSettingsView()
                .tabItem {
                    Label("Subscription", systemImage: "star.fill")
                }
        }
        .frame(width: 650, height: 550)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("defaultClonePath") private var defaultClonePath = "~/Developer"
    @AppStorage("confirmBeforePush") private var confirmBeforePush = true
    @AppStorage("confirmBeforeForce") private var confirmBeforeForce = true

    var body: some View {
        Form {
            Section("Appearance") {
                // Theme selector with icons
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(Theme.allCases.filter { $0 != .custom }) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            themeManager.setTheme(theme)
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)

                // Custom theme button
                Button {
                    ThemeEditorWindowController.shared.showWindow()
                } label: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(AppTheme.accent)
                        Text("Customize Colors...")
                        Spacer()
                        if themeManager.currentTheme == .custom {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.success)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Startup") {
                Toggle("Open at login", isOn: $openAtLogin)
                Toggle("Show in menu bar", isOn: $showInMenuBar)
            }

            Section("Repositories") {
                HStack {
                    TextField("Default clone path", text: $defaultClonePath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true

                        panel.begin { response in
                            if response == .OK {
                                Task { @MainActor in
                                    defaultClonePath = panel.url?.path ?? defaultClonePath
                                }
                            }
                        }
                    }
                }
            }

            Section("Confirmations") {
                Toggle("Confirm before pushing", isOn: $confirmBeforePush)
                Toggle("Confirm before force operations", isOn: $confirmBeforeForce)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Accounts Settings

struct AccountsSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
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
        let theme = Color.Theme(self.themeManager.colors)

        return Form {
            Section("GitHub") {
                if isGitHubConnected, let user = githubUser {
                    // Connected state
                    HStack {
                        AsyncImage(url: URL(string: user.avatarUrl)) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(theme.text)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading) {
                            Text(user.name ?? user.login)
                                .fontWeight(.semibold)
                            Text("@\(user.login)")
                                .font(.caption)
                                .foregroundColor(theme.text)
                        }

                        Spacer()

                        Button("Disconnect") {
                            Task {
                                try? await githubService.logout()
                                isGitHubConnected = false
                                githubUser = nil
                            }
                        }
                        .foregroundColor(AppTheme.error)
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
                            .font(DesignTokens.Typography.headline)

                        Text("Sign in to enable pull requests, issues, and repository features.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(theme.text)

                        // OAuth Login (recommended)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Sign in with Browser (Recommended)")
                                .font(DesignTokens.Typography.subheadline)
                                .fontWeight(.medium)

                            Text("Uses GitHub's secure OAuth flow. Supports 2FA.")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(theme.text)

                            Button {
                                startOAuthFlow()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.forward.app")
                                        .foregroundColor(theme.textSecondary)
                                    Text("Sign in with GitHub")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                        }

                        Divider()

                        // Personal Access Token (alternative)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Or use Personal Access Token")
                                .font(DesignTokens.Typography.subheadline)
                                .fontWeight(.medium)

                            SecureField("Personal Access Token", text: $githubToken)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button("Generate Token") {
                                    NSWorkspace.shared.open(URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:user")!)
                                }

                                Spacer()

                                Button("Connect") {
                                    connectGitHub()
                                }
                                .disabled(githubToken.isEmpty || isLoading)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(AppTheme.error)
                                .font(DesignTokens.Typography.caption)
                        }
                    }
                }
            }

            Section("OAuth Configuration") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("To use OAuth sign-in, you need a GitHub OAuth App Client ID.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)

                    if oauthConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.success)
                            Text("Client ID configured")
                            Spacer()
                            Button("Change") {
                                oauthConfigured = false
                                oauthClientId = ""
                            }
                        }
                    } else {
                        HStack {
                            TextField("OAuth Client ID", text: $oauthClientId)
                                .textFieldStyle(.roundedBorder)

                            Button("Save") {
                                Task {
                                    await githubOAuth.setClientId(oauthClientId)
                                    oauthConfigured = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(oauthClientId.isEmpty)
                        }
                    }

                    Button("Create OAuth App on GitHub") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/settings/developers")!)
                    }
                    .font(DesignTokens.Typography.caption)
                }
            }

            Section("Required Scopes") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Label("repo - Full control of private repositories", systemImage: "checkmark.circle")
                    Label("user - Read user profile data", systemImage: "checkmark.circle")
                    Label("read:org - Read organization membership", systemImage: "checkmark.circle")
                }
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)
            }
        }
        .formStyle(.grouped)
        .padding()
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
    @StateObject private var themeManager = ThemeManager.shared
    let userCode: String
    let verificationUri: String
    let onCancel: () -> Void

    @State private var copied = false

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "link.circle.fill")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.accent)

            Text("Enter this code on GitHub")
                .font(DesignTokens.Typography.headline)

            // User code - large and copyable
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(userCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(4)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copied ? theme.accent : theme.textSecondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(AppTheme.textSecondary.opacity(0.1))
            .cornerRadius(DesignTokens.CornerRadius.lg)

            if copied {
                Text("Copied!")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.success)
            }

            Text("Waiting for authorization...")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)

            ProgressView()
                .scaleEffect(0.8)

            HStack {
                Button("Open GitHub") {
                    if let url = URL(string: verificationUri) {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
            }
        }
        .padding()
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedProvider: AIService.AIProvider = .anthropic
    @State private var selectedModel = "claude-3-haiku-20240307"
    @State private var apiKeys: [AIService.AIProvider: String] = [:]
    @State private var configuredProviders: Set<AIService.AIProvider> = []
    @State private var isLoading = false
    @State private var successMessage: String?

    private let aiService = AIService()

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return Form {
            Section("API Keys") {
                ForEach(AIService.AIProvider.allCases) { provider in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Image(systemName: providerIcon(provider))
                                .foregroundColor(providerColor(provider))
                            Text(provider.displayName)
                                .fontWeight(.medium)

                            Spacer()

                            if configuredProviders.contains(provider) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.success)
                            }
                        }

                        HStack {
                            SecureField("API Key", text: binding(for: provider))
                                .textFieldStyle(.roundedBorder)

                            Button(configuredProviders.contains(provider) ? "Update" : "Save") {
                                saveAPIKey(for: provider)
                            }
                            .disabled((apiKeys[provider] ?? "").isEmpty)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }

            Section("Preferred Provider") {
                if configuredProviders.isEmpty {
                    Text("Add an API key above to enable AI features")
                        .foregroundColor(theme.text)
                } else {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(Array(configuredProviders), id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    Picker("Model", selection: $selectedModel) {
                        ForEach(selectedProvider.models) { model in
                            Text(model.name).tag(model.id)
                        }
                    }

                    Button("Set as Default") {
                        Task {
                            try? await aiService.setProvider(selectedProvider, model: selectedModel)
                            successMessage = "Default provider updated"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                successMessage = nil
                            }
                        }
                    }

                    if let message = successMessage {
                        Text(message)
                            .foregroundColor(AppTheme.success)
                            .font(DesignTokens.Typography.caption)
                    }
                }
            }

            Section("AI Features") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    FeatureRow(
                        icon: "text.bubble",
                        title: "Commit Messages",
                        description: "Generate commit messages from your changes"
                    )
                    FeatureRow(
                        icon: "doc.text",
                        title: "PR Descriptions",
                        description: "Auto-generate pull request descriptions"
                    )
                    FeatureRow(
                        icon: "exclamationmark.triangle",
                        title: "Conflict Resolution",
                        description: "AI-assisted merge conflict suggestions"
                    )
                    FeatureRow(
                        icon: "questionmark.circle",
                        title: "Explain Changes",
                        description: "Get explanations for commits and diffs"
                    )
                }
            }

            Section("Get API Keys") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        Label("OpenAI API Keys", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://console.anthropic.com/")!) {
                        Label("Anthropic Console", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://makersuite.google.com/app/apikey")!) {
                        Label("Google AI Studio", systemImage: "link")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            await loadConfiguredProviders()
        }
    }

    private func binding(for provider: AIService.AIProvider) -> Binding<String> {
        Binding(
            get: { apiKeys[provider] ?? "" },
            set: { apiKeys[provider] = $0 }
        )
    }

    private func saveAPIKey(for provider: AIService.AIProvider) {
        guard let key = apiKeys[provider], !key.isEmpty else { return }

        Task {
            try? await aiService.setAPIKey(key, for: provider)
            configuredProviders.insert(provider)
            apiKeys[provider] = ""
        }
    }

    private func loadConfiguredProviders() async {
        let providers = await aiService.getConfiguredProviders()
        configuredProviders = Set(providers)

        // Load saved default provider and model
        let savedProvider = await aiService.getCurrentProvider()
        let savedModel = await aiService.getCurrentModel()

        if configuredProviders.contains(savedProvider) {
            selectedProvider = savedProvider
            selectedModel = savedModel
        } else if let first = providers.first {
            selectedProvider = first
            selectedModel = first.models.first?.id ?? ""
        }
    }

    private func providerIcon(_ provider: AIService.AIProvider) -> String {
        switch provider {
        case .openai: return "sparkles"
        case .anthropic: return "brain.head.profile"
        case .gemini: return "diamond"
        }
    }

    private func providerColor(_ provider: AIService.AIProvider) -> Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .gemini: return .blue
        }
    }
}

struct FeatureRow: View {
    @StateObject private var themeManager = ThemeManager.shared
    let icon: String
    let title: String
    let description: String

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accent)
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)
            }
        }
    }
}

// MARK: - Git Config

struct GitConfigView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var defaultBranch = "main"
    @AppStorage("autoFetch") private var autoFetch = true
    @AppStorage("autoFetchInterval") private var autoFetchInterval = 5
    @AppStorage("pruneOnFetch") private var pruneOnFetch = true
    @State private var isLoading = true
    @State private var saveStatus: String?

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return Form {
            Section("User") {
                TextField("Name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: userName) { _, newValue in
                        saveGitConfig(key: "user.name", value: newValue)
                    }
                TextField("Email", text: $userEmail)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: userEmail) { _, newValue in
                        saveGitConfig(key: "user.email", value: newValue)
                    }

                Text("These values are used for commits in repositories without local config")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)

                if let status = saveStatus {
                    Text(status)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.success)
                }
            }

            Section("Defaults") {
                TextField("Default branch name", text: $defaultBranch)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: defaultBranch) { _, newValue in
                        saveGitConfig(key: "init.defaultBranch", value: newValue)
                    }
            }

            Section("Fetching") {
                Toggle("Auto-fetch in background", isOn: $autoFetch)

                if autoFetch {
                    Picker("Fetch interval", selection: $autoFetchInterval) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                }

                Toggle("Prune remote-tracking branches on fetch", isOn: $pruneOnFetch)
            }

            Section("Email Aliases") {
                EmailAliasesView()
            }
        }
        .formStyle(.grouped)
        .padding()
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
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settings = EmailAliasSettings.shared
    @State private var newAlias = ""

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Add email aliases to show your avatar on commits with different emails")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)

            HStack {
                TextField("Email alias (e.g. work@company.com)", text: $newAlias)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    settings.addAlias(newAlias)
                    newAlias = ""
                }
                .disabled(newAlias.isEmpty)
            }

            if !settings.aliases.isEmpty {
                ForEach(settings.aliases, id: \.self) { alias in
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(theme.text)
                        Text(alias)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            settings.removeAlias(alias)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.text)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                }
            }
        }
    }
}

// MARK: - Keyboard Shortcuts

struct KeyboardShortcutsView: View {
    var body: some View {
        Form {
            Section("Repository") {
                ShortcutRow(action: "Open Repository", shortcut: "⌘O")
                ShortcutRow(action: "Clone Repository", shortcut: "⇧⌘N")
                ShortcutRow(action: "Fetch", shortcut: "⇧⌘F")
                ShortcutRow(action: "Pull", shortcut: "⇧⌘P")
                ShortcutRow(action: "Push", shortcut: "⇧⌘U")
            }

            Section("Staging") {
                ShortcutRow(action: "Stage All", shortcut: "⇧⌘A")
                ShortcutRow(action: "Commit", shortcut: "⌘↩")
                ShortcutRow(action: "Amend Commit", shortcut: "⌥⌘↩")
            }

            Section("Branches") {
                ShortcutRow(action: "New Branch", shortcut: "⇧⌘B")
                ShortcutRow(action: "Merge", shortcut: "⇧⌘M")
                ShortcutRow(action: "Rebase", shortcut: "⇧⌘R")
            }

            Section("Stash") {
                ShortcutRow(action: "Stash Changes", shortcut: "⌥⌘S")
                ShortcutRow(action: "Pop Stash", shortcut: "⇧⌥⌘S")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(AppTheme.textSecondary.opacity(0.2))
                .cornerRadius(DesignTokens.CornerRadius.sm)
        }
    }
}

// MARK: - Integrations Settings

struct IntegrationsSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var workspaceManager = WorkspaceSettingsManager.shared
    @StateObject private var recentReposManager = RecentRepositoriesManager.shared

    // Taiga state
    @State private var isTaigaConnected = false
    @State private var taigaUsername = ""
    @State private var taigaPassword = ""
    @State private var taigaProjects: [TaigaProject] = []
    @State private var isLoadingTaiga = false
    @State private var taigaError: String?

    // Microsoft Planner state
    @State private var isPlannerConnected = false
    @State private var plannerPlans: [PlannerPlan] = []
    @State private var isLoadingPlanner = false
    @State private var plannerError: String?

    // Linear state
    @State private var isLinearConnected = false
    @State private var linearApiKey = ""
    @State private var linearTeams: [LinearTeam] = []
    @State private var isLoadingLinear = false
    @State private var linearError: String?

    // Jira state
    @State private var isJiraConnected = false
    @State private var jiraSiteUrl = ""
    @State private var jiraEmail = ""
    @State private var jiraApiToken = ""
    @State private var jiraProjects: [JiraProject] = []
    @State private var isLoadingJira = false
    @State private var jiraError: String?

    // Notion state
    @State private var isNotionConnected = false
    @State private var notionToken = ""
    @State private var notionDatabases: [NotionDatabase] = []
    @State private var isLoadingNotion = false
    @State private var notionError: String?

    // AWS state
    @State private var isAWSConnected = false
    @State private var awsAccessKeyId = ""
    @State private var awsSecretAccessKey = ""
    @State private var awsSessionToken = ""  // For MFA/2FA
    @State private var awsRegion = "us-east-1"
    @State private var isLoadingAWS = false
    @State private var awsError: String?
    @State private var awsProjects: [String] = []

    // Current repo
    @State private var selectedRepoPath: String?

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return Form {
            // Repository selection
            Section("Repository") {
                if recentReposManager.recentRepos.isEmpty {
                    Text("Open a repository to configure integrations")
                        .foregroundColor(theme.text)
                } else {
                    Picker("Configure for", selection: $selectedRepoPath) {
                        ForEach(recentReposManager.recentRepos) { repo in
                            Text(repo.name).tag(Optional(repo.path))
                        }
                    }
                    .onAppear {
                        if selectedRepoPath == nil {
                            selectedRepoPath = recentReposManager.recentRepos.first?.path
                        }
                    }
                }
            }

            // Taiga Integration
            Section("Taiga") {
                if isTaigaConnected {
                    TaigaConnectedView(
                        selectedRepoPath: selectedRepoPath,
                        projects: taigaProjects,
                        workspaceManager: workspaceManager,
                        onDisconnect: disconnectTaiga
                    )
                } else {
                    TaigaLoginView(
                        username: $taigaUsername,
                        password: $taigaPassword,
                        isLoading: isLoadingTaiga,
                        error: taigaError,
                        onLogin: loginTaiga
                    )
                }
            }

            // Microsoft Planner Integration
            Section("Microsoft Planner") {
                if isPlannerConnected {
                    PlannerConnectedView(
                        selectedRepoPath: selectedRepoPath,
                        plans: plannerPlans,
                        workspaceManager: workspaceManager,
                        onDisconnect: disconnectPlanner
                    )
                } else {
                    PlannerLoginView(
                        isLoading: isLoadingPlanner,
                        error: plannerError,
                        onLogin: loginPlanner
                    )
                }
            }

            // Linear Integration
            Section("Linear") {
                if isLinearConnected {
                    LinearConnectedView(
                        teams: linearTeams,
                        onDisconnect: disconnectLinear
                    )
                } else {
                    LinearLoginSettingsView(
                        apiKey: $linearApiKey,
                        isLoading: isLoadingLinear,
                        error: linearError,
                        onLogin: loginLinear
                    )
                }
            }

            // Jira Integration
            Section("Jira") {
                if isJiraConnected {
                    JiraConnectedView(
                        projects: jiraProjects,
                        onDisconnect: disconnectJira
                    )
                } else {
                    JiraLoginSettingsView(
                        siteUrl: $jiraSiteUrl,
                        email: $jiraEmail,
                        apiToken: $jiraApiToken,
                        isLoading: isLoadingJira,
                        error: jiraError,
                        onLogin: loginJira
                    )
                }
            }

            // Notion Integration
            Section("Notion") {
                if isNotionConnected {
                    NotionConnectedView(
                        databases: notionDatabases,
                        onDisconnect: disconnectNotion
                    )
                } else {
                    NotionLoginSettingsView(
                        token: $notionToken,
                        isLoading: isLoadingNotion,
                        error: notionError,
                        onLogin: loginNotion
                    )
                }
            }

            // AWS CodeBuild Integration
            Section("AWS CodeBuild") {
                if isAWSConnected {
                    AWSConnectedView(
                        region: awsRegion,
                        projects: awsProjects,
                        selectedRepoPath: selectedRepoPath,
                        workspaceManager: workspaceManager,
                        onDisconnect: disconnectAWS,
                        onRefresh: refreshAWSProjects
                    )
                } else {
                    AWSLoginView(
                        accessKeyId: $awsAccessKeyId,
                        secretAccessKey: $awsSecretAccessKey,
                        sessionToken: $awsSessionToken,
                        region: $awsRegion,
                        isLoading: isLoadingAWS,
                        error: awsError,
                        onConnect: connectAWS
                    )
                }
            }

            // Available integrations
            Section("Other Integrations") {
                ForEach(IntegrationType.allCases.filter { !$0.isAvailable }) { integration in
                    HStack {
                        Image(systemName: integration.icon)
                            .foregroundColor(Color(hex: integration.color))
                            .frame(width: 24)
                        Text(integration.rawValue)
                        Spacer()
                        Text("Coming Soon")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(theme.text)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(AppTheme.textSecondary.opacity(0.2))
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            await loadState()
        }
    }

    private func repoName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private func loadState() async {
        // Set initial selected repo
        if selectedRepoPath == nil, let first = recentReposManager.recentRepos.first {
            selectedRepoPath = first.path
        }

        // Check Taiga connection
        if let token = try? await KeychainManager.shared.getTaigaToken(), !token.isEmpty {
            isTaigaConnected = true
            await TaigaService.shared.setToken(token)
            if let userIdStr = try? await KeychainManager.shared.getTaigaUserId(),
               let userId = Int(userIdStr) {
                await TaigaService.shared.setUserId(userId)
            }
            await loadTaigaProjects()
        }

        // Check Planner connection
        if let token = try? await KeychainManager.shared.getPlannerToken(), !token.isEmpty {
            await MicrosoftPlannerService.shared.setAccessToken(token)
            isPlannerConnected = true
            await loadPlannerPlans()
        }

        // Check Linear connection
        if let token = try? await KeychainManager.shared.getLinearToken(), !token.isEmpty {
            await LinearService.shared.setAccessToken(token)
            isLinearConnected = true
            await loadLinearTeams()
        }

        // Check Jira connection
        if let token = try? await KeychainManager.shared.getJiraToken(),
           let cloudId = try? await KeychainManager.shared.getJiraCloudId(),
           !token.isEmpty, !cloudId.isEmpty {
            await JiraService.shared.setAccessToken(token)
            await JiraService.shared.setCloudId(cloudId)
            isJiraConnected = true
            await loadJiraProjects()
        }

        // Check Notion connection
        if let token = try? await KeychainManager.shared.getNotionToken(), !token.isEmpty {
            await NotionService.shared.setAccessToken(token)
            isNotionConnected = true
            await loadNotionDatabases()
        }

        // Check AWS connection
        await loadAWSState()
    }

    private func loginTaiga() {
        isLoadingTaiga = true
        taigaError = nil

        Task {
            do {
                try await TaigaService.shared.authenticate(username: taigaUsername, password: taigaPassword)
                isTaigaConnected = true
                taigaPassword = ""
                await loadTaigaProjects()
            } catch {
                taigaError = error.localizedDescription
            }
            isLoadingTaiga = false
        }
    }

    private func loadTaigaProjects() async {
        do {
            taigaProjects = try await TaigaService.shared.listProjects()
        } catch {
            taigaError = "Failed to load projects"
        }
    }

    private func disconnectTaiga() {
        Task {
            try? await KeychainManager.shared.deleteTaigaToken()
            isTaigaConnected = false
            taigaProjects = []
        }
    }

    private func loginPlanner() {
        isLoadingPlanner = true
        plannerError = nil

        Task {
            // For Microsoft OAuth, we need to implement device flow
            // For now, show info about how to get a token
            plannerError = "Use Microsoft Azure AD to obtain an access token"
            isLoadingPlanner = false
        }
    }

    private func loadPlannerPlans() async {
        do {
            plannerPlans = try await MicrosoftPlannerService.shared.listPlans()
        } catch {
            plannerError = "Failed to load plans"
        }
    }

    private func disconnectPlanner() {
        Task {
            try? await KeychainManager.shared.deletePlannerToken()
            isPlannerConnected = false
            plannerPlans = []
        }
    }

    // MARK: - Linear Functions

    private func loginLinear() {
        isLoadingLinear = true
        linearError = nil

        Task {
            do {
                try await KeychainManager.shared.saveLinearToken(linearApiKey)
                await LinearService.shared.setAccessToken(linearApiKey)
                // Test connection
                _ = try await LinearService.shared.listTeams()
                isLinearConnected = true
                linearApiKey = ""
                await loadLinearTeams()
            } catch {
                linearError = error.localizedDescription
            }
            isLoadingLinear = false
        }
    }

    private func loadLinearTeams() async {
        do {
            linearTeams = try await LinearService.shared.listTeams()
        } catch {
            linearError = "Failed to load teams"
        }
    }

    private func disconnectLinear() {
        Task {
            try? await KeychainManager.shared.deleteLinearToken()
            isLinearConnected = false
            linearTeams = []
        }
    }

    // MARK: - Jira Functions

    private func loginJira() {
        isLoadingJira = true
        jiraError = nil

        Task {
            do {
                // Create Basic auth token
                let credentials = "\(jiraEmail):\(jiraApiToken)"
                let encodedCredentials = Data(credentials.utf8).base64EncodedString()
                let basicToken = "Basic \(encodedCredentials)"

                var cleanSiteUrl = jiraSiteUrl.trimmingCharacters(in: .whitespaces)
                if !cleanSiteUrl.hasPrefix("https://") {
                    cleanSiteUrl = "https://\(cleanSiteUrl)"
                }

                let cloudId = cleanSiteUrl
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: ".atlassian.net", with: "")
                    .replacingOccurrences(of: "/", with: "")

                try await KeychainManager.shared.saveJiraToken(basicToken)
                try await KeychainManager.shared.saveJiraCloudId(cloudId)
                try await KeychainManager.shared.saveJiraSiteUrl(cleanSiteUrl)

                await JiraService.shared.setAccessToken(basicToken, cloudId: cloudId, siteUrl: cleanSiteUrl)

                isJiraConnected = true
                jiraApiToken = ""
                await loadJiraProjects()
            } catch {
                jiraError = error.localizedDescription
            }
            isLoadingJira = false
        }
    }

    private func loadJiraProjects() async {
        do {
            jiraProjects = try await JiraService.shared.listProjects()
        } catch {
            jiraError = "Failed to load projects"
        }
    }

    private func disconnectJira() {
        Task {
            try? await KeychainManager.shared.deleteJiraCredentials()
            isJiraConnected = false
            jiraProjects = []
        }
    }

    // MARK: - Notion Functions

    private func loginNotion() {
        isLoadingNotion = true
        notionError = nil

        Task {
            do {
                try await KeychainManager.shared.saveNotionToken(notionToken)
                await NotionService.shared.setAccessToken(notionToken)
                // Test connection
                _ = try await NotionService.shared.search()
                isNotionConnected = true
                notionToken = ""
                await loadNotionDatabases()
            } catch {
                notionError = error.localizedDescription
            }
            isLoadingNotion = false
        }
    }

    private func loadNotionDatabases() async {
        do {
            notionDatabases = try await NotionService.shared.listDatabases()
        } catch {
            notionError = "Failed to load databases"
        }
    }

    private func disconnectNotion() {
        Task {
            try? await KeychainManager.shared.deleteNotionToken()
            isNotionConnected = false
            notionDatabases = []
        }
    }

    // MARK: - AWS Functions

    private func connectAWS() {
        isLoadingAWS = true
        awsError = nil

        Task {
            do {
                // Save credentials to keychain
                try await KeychainManager.shared.saveAWSCredentials(
                    accessKeyId: awsAccessKeyId,
                    secretAccessKey: awsSecretAccessKey,
                    sessionToken: awsSessionToken.isEmpty ? nil : awsSessionToken,
                    region: awsRegion
                )

                // Write to ~/.aws/credentials and ~/.aws/config
                try writeAWSCredentialsToFile()

                // Test connection
                let result = await testAWSConnection()
                if result.success {
                    isAWSConnected = true
                    awsProjects = result.projects
                } else {
                    awsError = result.error ?? "Connection failed"
                }
            } catch {
                awsError = error.localizedDescription
            }

            isLoadingAWS = false
        }
    }

    private func writeAWSCredentialsToFile() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let awsDir = homeDir.appendingPathComponent(".aws")

        // Create .aws directory if needed
        try FileManager.default.createDirectory(at: awsDir, withIntermediateDirectories: true)

        // Write credentials file
        var credentialsContent = "[default]\n"
        credentialsContent += "aws_access_key_id = \(awsAccessKeyId)\n"
        credentialsContent += "aws_secret_access_key = \(awsSecretAccessKey)\n"
        if !awsSessionToken.isEmpty {
            credentialsContent += "aws_session_token = \(awsSessionToken)\n"
        }

        let credentialsPath = awsDir.appendingPathComponent("credentials")
        try credentialsContent.write(to: credentialsPath, atomically: true, encoding: .utf8)

        // Write config file
        let configContent = "[default]\nregion = \(awsRegion)\noutput = json\n"
        let configPath = awsDir.appendingPathComponent("config")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
    }

    private func testAWSConnection() async -> (success: Bool, projects: [String], error: String?) {
        // Test with STS get-caller-identity
        let identityResult = runAWSCommand(["sts", "get-caller-identity"])
        if !identityResult.success {
            return (false, [], identityResult.output)
        }

        // List CodeBuild projects
        let projectsResult = runAWSCommand(["codebuild", "list-projects", "--output", "json"])
        if projectsResult.success {
            if let data = projectsResult.output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let projects = json["projects"] as? [String] {
                return (true, projects, nil)
            }
        }

        return (true, [], nil)  // Connected but no projects
    }

    private func runAWSCommand(_ arguments: [String]) -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aws")
        process.arguments = arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return (true, output)
            } else {
                return (false, error.isEmpty ? output : error)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func disconnectAWS() {
        Task {
            try? await KeychainManager.shared.deleteAWSCredentials()

            // Remove credentials files
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let credentialsPath = homeDir.appendingPathComponent(".aws/credentials")
            let configPath = homeDir.appendingPathComponent(".aws/config")
            try? FileManager.default.removeItem(at: credentialsPath)
            try? FileManager.default.removeItem(at: configPath)

            isAWSConnected = false
            awsProjects = []
            awsAccessKeyId = ""
            awsSecretAccessKey = ""
            awsSessionToken = ""
        }
    }

    private func refreshAWSProjects() {
        Task {
            isLoadingAWS = true
            let result = await testAWSConnection()
            awsProjects = result.projects
            isLoadingAWS = false
        }
    }

    private func loadAWSState() async {
        if let creds = try? await KeychainManager.shared.getAWSCredentials() {
            awsAccessKeyId = creds.accessKeyId
            awsSecretAccessKey = creds.secretAccessKey
            awsSessionToken = creds.sessionToken ?? ""
            awsRegion = creds.region

            let result = await testAWSConnection()
            isAWSConnected = result.success
            awsProjects = result.projects
        }
    }
}

// MARK: - AWS Settings Views

struct AWSConnectedView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let region: String
    let projects: [String]
    let selectedRepoPath: String?
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void
    let onRefresh: () -> Void

    @State private var selectedProject: String = ""

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected")
                Spacer()
                Text(region)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(theme.warning.opacity(0.2))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                Button("Disconnect", role: .destructive, action: onDisconnect)
            }

            if !projects.isEmpty {
                // Project assignment for current repo
                if let repoPath = selectedRepoPath {
                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.xs)

                    Text("Assign to \(URL(fileURLWithPath: repoPath).lastPathComponent):")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)

                    Picker("CodeBuild Project", selection: $selectedProject) {
                        Text("None").tag("")
                        ForEach(projects, id: \.self) { project in
                            Text(project).tag(project)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedProject) { _, newValue in
                        workspaceManager.setCodeBuildProject(
                            for: repoPath,
                            projectName: newValue.isEmpty ? nil : newValue
                        )
                    }
                    .onAppear {
                        let config = workspaceManager.getConfig(for: repoPath)
                        selectedProject = config.codeBuildProjectName ?? ""
                    }

                    if !selectedProject.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.success)
                                .font(DesignTokens.Typography.caption)
                            Text("Only builds from '\(selectedProject)' will show for this repo")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(theme.text)
                        }
                    }

                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.xs)
                }

                Text("Available Projects (\(projects.count)):")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)

                ForEach(projects, id: \.self) { project in
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(AppTheme.warning)
                            .frame(width: 20)
                        Text(project)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            } else {
                Text("No CodeBuild projects found")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)
            }
        }
    }
}

struct AWSLoginView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Binding var accessKeyId: String
    @Binding var secretAccessKey: String
    @Binding var sessionToken: String
    @Binding var region: String
    let isLoading: Bool
    let error: String?
    let onConnect: () -> Void

    let regions = ["us-east-1", "us-east-2", "us-west-1", "us-west-2", "eu-west-1", "eu-central-1", "ap-southeast-1", "ap-northeast-1"]

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            TextField("Access Key ID", text: $accessKeyId)
                .textFieldStyle(.roundedBorder)

            SecureField("Secret Access Key", text: $secretAccessKey)
                .textFieldStyle(.roundedBorder)

            SecureField("Session Token (MFA/2FA)", text: $sessionToken)
                .textFieldStyle(.roundedBorder)

            Text("Required if using MFA/2FA authentication")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)

            Picker("Region", selection: $region) {
                ForEach(regions, id: \.self) { r in
                    Text(r).tag(r)
                }
            }
            .pickerStyle(.menu)

            if let error = error {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.error)
            }

            Button(action: onConnect) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("Connect")
                }
            }
            .disabled(accessKeyId.isEmpty || secretAccessKey.isEmpty || isLoading)

            Link("Get AWS credentials", destination: URL(string: "https://console.aws.amazon.com/iam/home#/security_credentials")!)
                .font(DesignTokens.Typography.caption)

            Text("For MFA: Run `aws sts get-session-token --serial-number arn:aws:iam::ACCOUNT:mfa/USER --token-code CODE` to get session token")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(theme.text)
        }
    }
}

// MARK: - Linear Settings Views

struct LinearConnectedView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let teams: [LinearTeam]
    let onDisconnect: () -> Void

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected")
                Spacer()
                if !teams.isEmpty {
                    Text("\(teams.count) teams")
                        .foregroundColor(theme.text)
                }
                Button("Disconnect", role: .destructive, action: onDisconnect)
            }

            if !teams.isEmpty {
                ForEach(teams) { team in
                    HStack {
                        Text(team.key)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .foregroundColor(theme.text)
                        Text(team.name)
                    }
                }
            }

            Link("Open Linear", destination: URL(string: "https://linear.app")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}

struct LinearLoginSettingsView: View {
    @Binding var apiKey: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        SecureField("API Key", text: $apiKey)
            .textFieldStyle(.roundedBorder)

        if let error = error {
            Text(error)
                .foregroundColor(AppTheme.error)
                .font(DesignTokens.Typography.caption)
        }

        HStack {
            Button(action: onLogin) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Connect")
                }
            }
            .disabled(apiKey.isEmpty || isLoading)

            Link("Get API Key", destination: URL(string: "https://linear.app/settings/api")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}

// MARK: - Jira Settings Views

struct JiraConnectedView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let projects: [JiraProject]
    let onDisconnect: () -> Void

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected")
                Spacer()
                if !projects.isEmpty {
                    Text("\(projects.count) projects")
                        .foregroundColor(theme.text)
                }
                Button("Disconnect", role: .destructive, action: onDisconnect)
            }

            if !projects.isEmpty {
                ForEach(projects.prefix(5)) { project in
                    HStack {
                        Text(project.key)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .foregroundColor(theme.text)
                        Text(project.name)
                    }
                }
                if projects.count > 5 {
                    Text("and \(projects.count - 5) more...")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)
                }
            }
        }
    }
}

struct JiraLoginSettingsView: View {
    @Binding var siteUrl: String
    @Binding var email: String
    @Binding var apiToken: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        TextField("Site URL (e.g. yourcompany.atlassian.net)", text: $siteUrl)
            .textFieldStyle(.roundedBorder)

        TextField("Email", text: $email)
            .textFieldStyle(.roundedBorder)

        SecureField("API Token", text: $apiToken)
            .textFieldStyle(.roundedBorder)

        if let error = error {
            Text(error)
                .foregroundColor(AppTheme.error)
                .font(DesignTokens.Typography.caption)
        }

        HStack {
            Button(action: onLogin) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Connect")
                }
            }
            .disabled(siteUrl.isEmpty || email.isEmpty || apiToken.isEmpty || isLoading)

            Link("Get API Token", destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
                .font(DesignTokens.Typography.caption)
        }
    }
}

// MARK: - Notion Settings Views

struct NotionConnectedView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let databases: [NotionDatabase]
    let onDisconnect: () -> Void

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected")
                Spacer()
                if !databases.isEmpty {
                    Text("\(databases.count) databases")
                        .foregroundColor(theme.text)
                }
                Button("Disconnect", role: .destructive, action: onDisconnect)
            }

            if !databases.isEmpty {
                ForEach(databases.prefix(5)) { db in
                    Text(db.displayTitle)
                }
                if databases.count > 5 {
                    Text("and \(databases.count - 5) more...")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)
                }
            } else {
                Text("Share databases with your integration to see them here")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)
            }
        }
    }
}

struct NotionLoginSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Binding var token: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SecureField("Integration Token", text: $token)
                .textFieldStyle(.roundedBorder)

            if let error = error {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .font(DesignTokens.Typography.caption)
            }

            HStack {
                Button(action: onLogin) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Connect")
                    }
                }
                .disabled(token.isEmpty || isLoading)

                Link("Create Integration", destination: URL(string: "https://www.notion.so/my-integrations")!)
                    .font(DesignTokens.Typography.caption)
            }

            Text("Remember to share your databases with the integration")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)
        }
    }
}

// MARK: - Taiga Views

struct TaigaLoginView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Binding var username: String
    @Binding var password: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(Color(hex: "4DC8A8"))
                Text("Connect to Taiga")
                    .font(DesignTokens.Typography.headline)
            }

            Text("Link your Taiga account to sync user stories, tasks, and issues.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)

            TextField("Username or Email", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Create Account") {
                    NSWorkspace.shared.open(URL(string: "https://tree.taiga.io/register")!)
                }
                .font(DesignTokens.Typography.caption)

                Spacer()

                Button("Sign In") {
                    onLogin()
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
            }

            if let error = error {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .font(DesignTokens.Typography.caption)
            }
        }
    }
}

struct TaigaConnectedView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let selectedRepoPath: String?
    let projects: [TaigaProject]
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void

    @State private var selectedProjectId: Int?

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected to Taiga")
                    .fontWeight(.medium)
                Spacer()
                Button("Disconnect") {
                    onDisconnect()
                }
                .foregroundColor(AppTheme.error)
            }

            if let repoPath = selectedRepoPath {
                let config = workspaceManager.getConfig(for: repoPath)

                Picker("Project for this repository", selection: $selectedProjectId) {
                    Text("None").tag(nil as Int?)
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .onChange(of: selectedProjectId) { _, newValue in
                    let projectName = projects.first(where: { $0.id == newValue })?.name
                    workspaceManager.setTaigaProject(for: repoPath, projectId: newValue, projectName: projectName)
                }
                .onAppear {
                    selectedProjectId = config.taigaProjectId
                }

                if let projectName = config.taigaProjectName {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Color(hex: "4DC8A8"))
                        Text("Linked to: \(projectName)")
                            .font(DesignTokens.Typography.caption)
                    }
                }
            } else {
                Text("Select a repository to assign a project")
                    .foregroundColor(theme.text)
                    .font(DesignTokens.Typography.caption)
            }
        }
    }
}

// MARK: - Planner Views

struct PlannerLoginView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    @State private var clientId = ""
    @State private var hasClientId = false
    @State private var isAuthenticating = false
    @State private var deviceCode: MicrosoftOAuth.DeviceCodeResponse?
    @State private var authError: String?

    private let microsoftOAuth = MicrosoftOAuth.shared

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(Color(hex: "0078D4"))
                Text("Connect to Microsoft Planner")
                    .font(DesignTokens.Typography.headline)
            }

            Text("Link your Microsoft 365 account to sync Planner tasks and boards.")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)

            if let deviceCode = deviceCode {
                // Waiting for user authorization
                MicrosoftOAuthWaitingView(
                    userCode: deviceCode.userCode,
                    verificationUri: deviceCode.verificationUri,
                    onCancel: {
                        Task { await microsoftOAuth.cancelAuthentication() }
                        self.deviceCode = nil
                        isAuthenticating = false
                    }
                )
            } else if !hasClientId {
                // Need to configure Client ID
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Configure Azure AD App")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    Text("Register an app in Azure AD and enter the Client ID.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)

                    TextField("Application (client) ID", text: $clientId)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Register App in Azure") {
                            NSWorkspace.shared.open(URL(string: "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")!)
                        }
                        .font(DesignTokens.Typography.caption)

                        Spacer()

                        Button("Save") {
                            Task {
                                await microsoftOAuth.setClientId(clientId)
                                hasClientId = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(clientId.isEmpty)
                    }

                    Text("Required: Enable 'Allow public client flows' in Azure AD")
                        .font(.caption2)
                        .foregroundColor(theme.text)
                }
            } else {
                // Ready to authenticate
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                        Text("Azure AD configured")
                            .font(.caption)

                        Spacer()

                        Button("Change") {
                            hasClientId = false
                            clientId = ""
                        }
                        .font(.caption)
                    }

                    Button {
                        startOAuth()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(theme.textSecondary)
                            Text("Sign in with Microsoft")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "0078D4"))
                    .disabled(isAuthenticating)
                }
            }

            if let error = authError ?? error {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .font(.caption)
            }

            Text("Required scopes: Tasks.ReadWrite, Group.Read.All, User.Read")
                .font(.caption2)
                .foregroundColor(theme.text)
        }
        .task {
            hasClientId = await microsoftOAuth.hasClientId
        }
    }

    private func startOAuth() {
        isAuthenticating = true
        authError = nil

        Task {
            do {
                let response = try await microsoftOAuth.startAuthentication()
                deviceCode = response

                // Open browser
                microsoftOAuth.openVerificationPage(uri: response.verificationUri)

                // Wait for authorization
                _ = try await microsoftOAuth.waitForAuthentication(deviceCode: response)

                // Success!
                deviceCode = nil
                isAuthenticating = false
                onLogin()
            } catch let error as MicrosoftOAuthError {
                authError = error.localizedDescription
                deviceCode = nil
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                deviceCode = nil
                isAuthenticating = false
            }
        }
    }
}

// MARK: - Microsoft OAuth Waiting View

struct MicrosoftOAuthWaitingView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let userCode: String
    let verificationUri: String
    let onCancel: () -> Void

    @State private var copied = false

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "link.circle.fill")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(Color(hex: "0078D4"))

            Text("Enter this code on Microsoft")
                .font(DesignTokens.Typography.headline)

            HStack(spacing: DesignTokens.Spacing.md) {
                Text(userCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copied ? theme.accent : theme.textSecondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(AppTheme.textSecondary.opacity(0.1))
            .cornerRadius(DesignTokens.CornerRadius.lg)

            if copied {
                Text("Copied!")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.success)
            }

            ProgressView()
                .scaleEffect(0.8)

            Text("Waiting for authorization...")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(theme.text)

            HStack {
                Button("Open Microsoft") {
                    if let url = URL(string: verificationUri) {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
            }
        }
        .padding()
    }
}

struct PlannerConnectedView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let selectedRepoPath: String?
    let plans: [PlannerPlan]
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void

    @State private var selectedPlanId: String?

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
                Text("Connected to Microsoft Planner")
                    .fontWeight(.medium)
                Spacer()
                Button("Disconnect") {
                    onDisconnect()
                }
                .foregroundColor(AppTheme.error)
            }

            if let repoPath = selectedRepoPath {
                let config = workspaceManager.getConfig(for: repoPath)

                Picker("Plan for this repository", selection: $selectedPlanId) {
                    Text("None").tag(nil as String?)
                    ForEach(plans) { plan in
                        Text(plan.title).tag(Optional(plan.id))
                    }
                }
                .onChange(of: selectedPlanId) { _, newValue in
                    let planName = plans.first(where: { $0.id == newValue })?.title
                    workspaceManager.setPlannerPlan(for: repoPath, planId: newValue, planName: planName)
                }
                .onAppear {
                    selectedPlanId = config.plannerPlanId
                }

                if let planName = config.plannerPlanName {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(Color(hex: "0078D4"))
                        Text("Linked to: \(planName)")
                            .font(DesignTokens.Typography.caption)
                    }
                }
            } else {
                Text("Select a repository to assign a plan")
                    .foregroundColor(theme.text)
                    .font(DesignTokens.Typography.caption)
            }
        }
    }
}

// MARK: - Subscription Settings

struct SubscriptionSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var storeManager = StoreManager.shared
    @State private var showSubscriptionSheet = false

    var body: some View {
        let theme = Color.Theme(self.themeManager.colors)

        return Form {
            Section("Current Plan") {
                if storeManager.isProUser {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppTheme.warning)
                        VStack(alignment: .leading) {
                            Text("GitMac Pro")
                                .fontWeight(.semibold)
                            Text(storeManager.subscriptionStatus.description)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(theme.text)
                        }
                        Spacer()
                        Button("Manage") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(theme.text)
                        VStack(alignment: .leading) {
                            Text("Free Plan")
                                .fontWeight(.semibold)
                            Text("Limited features")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(theme.text)
                        }
                        Spacer()
                        Button("Upgrade to Pro") {
                            showSubscriptionSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Pro Features") {
                ForEach(StoreManager.ProFeature.allCases, id: \.self) { feature in
                    HStack {
                        Image(systemName: feature.icon)
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(feature.rawValue)
                            Text(feature.description)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(theme.text)
                        }
                        Spacer()
                        if storeManager.isProUser {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.success)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundColor(theme.text)
                        }
                    }
                }
            }

            Section("Pricing") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Annual")
                        Spacer()
                        Text(storeManager.formattedAnnualPrice + "/year")
                            .foregroundColor(theme.text)
                    }
                    HStack {
                        Text("Monthly")
                        Spacer()
                        Text(storeManager.formattedMonthlyPrice + "/month")
                            .foregroundColor(theme.text)
                    }
                }

                Text("Subscriptions auto-renew unless cancelled 24 hours before the end of the current period.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)
            }

            Section {
                Button("Restore Purchases") {
                    Task {
                        await storeManager.restorePurchases()
                    }
                }

                Link("Terms of Service", destination: URL(string: "https://gitmac.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://gitmac.app/privacy")!)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionView()
        }
    }
}

// MARK: - Theme Button

struct ThemeButton: View {
    @StateObject private var themeManager = ThemeManager.shared
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let colors = Color.Theme(self.themeManager.colors)

        return Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                Image(systemName: theme.icon)
                    .font(.system(size: DesignTokens.Size.iconXL))
                    .foregroundColor(isSelected ? .white : iconColor)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg + DesignTokens.Spacing.xxs)
                            .fill(isSelected ? colors.accent : AppTheme.textSecondary.opacity(0.15))
                    )

                Text(theme.displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        switch theme {
        case .system: return .gray
        case .light: return .orange
        case .dark: return .indigo
        case .custom: return .purple
        }
    }
}

// #Preview {
//     SettingsView()
// }
