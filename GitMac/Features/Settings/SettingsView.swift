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
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("defaultClonePath") private var defaultClonePath = "~/Developer"
    @AppStorage("confirmBeforePush") private var confirmBeforePush = true
    @AppStorage("confirmBeforeForce") private var confirmBeforeForce = true

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
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

                        if panel.runModal() == .OK {
                            defaultClonePath = panel.url?.path ?? defaultClonePath
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
            Section("GitHub") {
                if isGitHubConnected, let user = githubUser {
                    // Connected state
                    HStack {
                        AsyncImage(url: URL(string: user.avatarUrl)) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading) {
                            Text(user.name ?? user.login)
                                .fontWeight(.semibold)
                            Text("@\(user.login)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Disconnect") {
                            Task {
                                try? await githubService.logout()
                                isGitHubConnected = false
                                githubUser = nil
                            }
                        }
                        .foregroundColor(.red)
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Connect to GitHub")
                            .font(.headline)

                        Text("Sign in to enable pull requests, issues, and repository features.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // OAuth Login (recommended)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sign in with Browser (Recommended)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Uses GitHub's secure OAuth flow. Supports 2FA.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                startOAuthFlow()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Sign in with GitHub")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                        }

                        Divider()

                        // Personal Access Token (alternative)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Or use Personal Access Token")
                                .font(.subheadline)
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
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }

            Section("OAuth Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To use OAuth sign-in, you need a GitHub OAuth App Client ID.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if oauthConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
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
                    .font(.caption)
                }
            }

            Section("Required Scopes") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("repo - Full control of private repositories", systemImage: "checkmark.circle")
                    Label("user - Read user profile data", systemImage: "checkmark.circle")
                    Label("read:org - Read organization membership", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
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
    let userCode: String
    let verificationUri: String
    let onCancel: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Enter this code on GitHub")
                .font(.headline)

            // User code - large and copyable
            HStack(spacing: 12) {
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
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            if copied {
                Text("Copied!")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Text("Waiting for authorization...")
                .font(.caption)
                .foregroundColor(.secondary)

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
    @State private var selectedProvider: AIService.AIProvider = .anthropic
    @State private var selectedModel = "claude-3-haiku-20240307"
    @State private var apiKeys: [AIService.AIProvider: String] = [:]
    @State private var configuredProviders: Set<AIService.AIProvider> = []
    @State private var isLoading = false
    @State private var successMessage: String?

    private let aiService = AIService()

    var body: some View {
        Form {
            Section("API Keys") {
                ForEach(AIService.AIProvider.allCases) { provider in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: providerIcon(provider))
                                .foregroundColor(providerColor(provider))
                            Text(provider.displayName)
                                .fontWeight(.medium)

                            Spacer()

                            if configuredProviders.contains(provider) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
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
                    .padding(.vertical, 4)
                }
            }

            Section("Preferred Provider") {
                if configuredProviders.isEmpty {
                    Text("Add an API key above to enable AI features")
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }

            Section("AI Features") {
                VStack(alignment: .leading, spacing: 8) {
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
                VStack(alignment: .leading, spacing: 8) {
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
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Git Config

struct GitConfigView: View {
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
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let status = saveStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.green)
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
    @StateObject private var settings = EmailAliasSettings.shared
    @State private var newAlias = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add email aliases to show your avatar on commits with different emails")
                .font(.caption)
                .foregroundColor(.secondary)

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
                            .foregroundColor(.secondary)
                        Text(alias)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            settings.removeAlias(alias)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
    }
}

// MARK: - Integrations Settings

struct IntegrationsSettingsView: View {
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

    // Current repo
    @State private var selectedRepoPath: String?

    var body: some View {
        Form {
            // Repository selection
            Section("Repository") {
                if recentReposManager.recentRepos.isEmpty {
                    Text("Open a repository to configure integrations")
                        .foregroundColor(.secondary)
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
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
            if let userId = try? await KeychainManager.shared.getTaigaUserId() {
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
}

// MARK: - Linear Settings Views

struct LinearConnectedView: View {
    let teams: [LinearTeam]
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Connected")
            Spacer()
            if !teams.isEmpty {
                Text("\(teams.count) teams")
                    .foregroundColor(.secondary)
            }
            Button("Disconnect", role: .destructive, action: onDisconnect)
        }

        if !teams.isEmpty {
            ForEach(teams) { team in
                HStack {
                    Text(team.key)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    Text(team.name)
                }
            }
        }

        Link("Open Linear", destination: URL(string: "https://linear.app")!)
            .font(.caption)
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
                .foregroundColor(.red)
                .font(.caption)
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
                .font(.caption)
        }
    }
}

// MARK: - Jira Settings Views

struct JiraConnectedView: View {
    let projects: [JiraProject]
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Connected")
            Spacer()
            if !projects.isEmpty {
                Text("\(projects.count) projects")
                    .foregroundColor(.secondary)
            }
            Button("Disconnect", role: .destructive, action: onDisconnect)
        }

        if !projects.isEmpty {
            ForEach(projects.prefix(5)) { project in
                HStack {
                    Text(project.key)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    Text(project.name)
                }
            }
            if projects.count > 5 {
                Text("and \(projects.count - 5) more...")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                .foregroundColor(.red)
                .font(.caption)
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
                .font(.caption)
        }
    }
}

// MARK: - Notion Settings Views

struct NotionConnectedView: View {
    let databases: [NotionDatabase]
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Connected")
            Spacer()
            if !databases.isEmpty {
                Text("\(databases.count) databases")
                    .foregroundColor(.secondary)
            }
            Button("Disconnect", role: .destructive, action: onDisconnect)
        }

        if !databases.isEmpty {
            ForEach(databases.prefix(5)) { db in
                Text(db.displayTitle)
            }
            if databases.count > 5 {
                Text("and \(databases.count - 5) more...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Share databases with your integration to see them here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NotionLoginSettingsView: View {
    @Binding var token: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        SecureField("Integration Token", text: $token)
            .textFieldStyle(.roundedBorder)

        if let error = error {
            Text(error)
                .foregroundColor(.red)
                .font(.caption)
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
                .font(.caption)
        }

        Text("Remember to share your databases with the integration")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Taiga Views

struct TaigaLoginView: View {
    @Binding var username: String
    @Binding var password: String
    let isLoading: Bool
    let error: String?
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(Color(hex: "4DC8A8"))
                Text("Connect to Taiga")
                    .font(.headline)
            }

            Text("Link your Taiga account to sync user stories, tasks, and issues.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Username or Email", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Create Account") {
                    NSWorkspace.shared.open(URL(string: "https://tree.taiga.io/register")!)
                }
                .font(.caption)

                Spacer()

                Button("Sign In") {
                    onLogin()
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
            }

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}

struct TaigaConnectedView: View {
    let selectedRepoPath: String?
    let projects: [TaigaProject]
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void

    @State private var selectedProjectId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to Taiga")
                    .fontWeight(.medium)
                Spacer()
                Button("Disconnect") {
                    onDisconnect()
                }
                .foregroundColor(.red)
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
                            .font(.caption)
                    }
                }
            } else {
                Text("Select a repository to assign a project")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Planner Views

struct PlannerLoginView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(Color(hex: "0078D4"))
                Text("Connect to Microsoft Planner")
                    .font(.headline)
            }

            Text("Link your Microsoft 365 account to sync Planner tasks and boards.")
                .font(.caption)
                .foregroundColor(.secondary)

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configure Azure AD App")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Register an app in Azure AD and enter the Client ID.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Application (client) ID", text: $clientId)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Register App in Azure") {
                            NSWorkspace.shared.open(URL(string: "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")!)
                        }
                        .font(.caption)

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
                        .foregroundColor(.secondary)
                }
            } else {
                // Ready to authenticate
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
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
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Text("Required scopes: Tasks.ReadWrite, Group.Read.All, User.Read")
                .font(.caption2)
                .foregroundColor(.secondary)
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
    let userCode: String
    let verificationUri: String
    let onCancel: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "0078D4"))

            Text("Enter this code on Microsoft")
                .font(.headline)

            HStack(spacing: 12) {
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
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            if copied {
                Text("Copied!")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            ProgressView()
                .scaleEffect(0.8)

            Text("Waiting for authorization...")
                .font(.caption)
                .foregroundColor(.secondary)

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
    let selectedRepoPath: String?
    let plans: [PlannerPlan]
    @ObservedObject var workspaceManager: WorkspaceSettingsManager
    let onDisconnect: () -> Void

    @State private var selectedPlanId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to Microsoft Planner")
                    .fontWeight(.medium)
                Spacer()
                Button("Disconnect") {
                    onDisconnect()
                }
                .foregroundColor(.red)
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
                            .font(.caption)
                    }
                }
            } else {
                Text("Select a repository to assign a plan")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Subscription Settings

struct SubscriptionSettingsView: View {
    @StateObject private var storeManager = StoreManager.shared
    @State private var showSubscriptionSheet = false

    var body: some View {
        Form {
            Section("Current Plan") {
                if storeManager.isProUser {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading) {
                            Text("GitMac Pro")
                                .fontWeight(.semibold)
                            Text(storeManager.subscriptionStatus.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading) {
                            Text("Free Plan")
                                .fontWeight(.semibold)
                            Text("Limited features")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(feature.rawValue)
                            Text(feature.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if storeManager.isProUser {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Pricing") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Annual")
                        Spacer()
                        Text(storeManager.formattedAnnualPrice + "/year")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Monthly")
                        Spacer()
                        Text(storeManager.formattedMonthlyPrice + "/month")
                            .foregroundColor(.secondary)
                    }
                }

                Text("Subscriptions auto-renew unless cancelled 24 hours before the end of the current period.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

// #Preview {
//     SettingsView()
// }
