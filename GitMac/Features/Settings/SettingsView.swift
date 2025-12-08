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
        }
        .frame(width: 600, height: 450)
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

        if let first = providers.first {
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
    @State private var autoFetch = true
    @State private var autoFetchInterval = 5
    @State private var prunOnFetch = true

    var body: some View {
        Form {
            Section("User") {
                TextField("Name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                TextField("Email", text: $userEmail)
                    .textFieldStyle(.roundedBorder)

                Text("These values are used for commits in repositories without local config")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Defaults") {
                TextField("Default branch name", text: $defaultBranch)
                    .textFieldStyle(.roundedBorder)
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

                Toggle("Prune remote-tracking branches on fetch", isOn: $prunOnFetch)
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

        if nameResult.isSuccess {
            userName = nameResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if emailResult.isSuccess {
            userEmail = emailResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
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

// #Preview {
//     SettingsView()
// }
