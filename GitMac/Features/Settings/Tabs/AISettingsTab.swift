import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var ollamaManager = OllamaProcessManager.shared
    @State private var selectedProvider: AIService.AIProvider = .anthropic
    @State private var selectedModel = "claude-3-haiku-20240307"
    @State private var apiKeys: [AIService.AIProvider: String] = [:]
    @State private var configuredProviders: Set<AIService.AIProvider> = []
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var ollamaURL: String = AIService.ollamaBaseURL
    @State private var ollamaTestResult: (success: Bool, message: String)?
    @State private var isTestingConnection = false

    private let aiService = AIService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            SettingsSection(title: "API Keys") {
                ForEach(AIService.AIProvider.allCases) { provider in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Image(systemName: providerIcon(provider))
                                .foregroundStyle(providerColor(provider))
                            Text(provider.displayName)
                                .foregroundStyle(AppTheme.textPrimary)
                                .fontWeight(.medium)

                            Spacer()

                            if configuredProviders.contains(provider) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                            }
                        }

                        // Ollama doesn't need API key - just check if running
                        if provider == .ollama {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                // URL Configuration
                                HStack {
                                    Text("Server URL:")
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    TextField("http://localhost:11434", text: $ollamaURL)
                                        .textFieldStyle(.roundedBorder)
                                        .font(DesignTokens.Typography.caption)
                                        .frame(maxWidth: 250)
                                        .onSubmit {
                                            AIService.ollamaBaseURL = ollamaURL
                                            Task { await loadConfiguredProviders() }
                                        }
                                    DSButton("Save", variant: .ghost, size: .sm) {
                                        AIService.ollamaBaseURL = ollamaURL
                                        await loadConfiguredProviders()
                                    }
                                }

                                // Status
                                HStack {
                                    if ollamaManager.isRunning {
                                        Image(systemName: "circle.fill")
                                            .foregroundStyle(AppTheme.success)
                                            .font(.system(size: 8))
                                        Text("Auto-started by GitMac")
                                            .font(DesignTokens.Typography.caption)
                                            .foregroundStyle(AppTheme.success)
                                    } else if configuredProviders.contains(.ollama) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.success)
                                        Text("Ollama connected at \(AIService.ollamaBaseURL)")
                                            .font(DesignTokens.Typography.caption)
                                            .foregroundStyle(AppTheme.success)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(AppTheme.error)
                                        Text("Ollama not detected. Install from ollama.ai")
                                            .font(DesignTokens.Typography.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    DSButton(isTestingConnection ? "Testing..." : "Test Connection", variant: .ghost, size: .sm, isDisabled: isTestingConnection) {
                                        isTestingConnection = true
                                        AIService.ollamaBaseURL = ollamaURL
                                        let result = await aiService.testOllamaConnection()
                                        ollamaTestResult = result
                                        await loadConfiguredProviders()
                                        isTestingConnection = false
                                    }
                                }

                                // Show test result
                                if let result = ollamaTestResult {
                                    HStack {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(result.success ? AppTheme.success : AppTheme.error)
                                        Text(result.message)
                                            .font(DesignTokens.Typography.caption)
                                            .foregroundStyle(result.success ? AppTheme.success : AppTheme.error)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        } else {
                            HStack {
                                DSSecureField(placeholder: "API Key", text: binding(for: provider))

                                DSButton(configuredProviders.contains(provider) ? "Update" : "Save", variant: .primary, size: .sm, isDisabled: (apiKeys[provider] ?? "").isEmpty) {
                                    saveAPIKey(for: provider)
                                }
                            }
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }

            SettingsSection(title: "Preferred Provider") {
                if configuredProviders.isEmpty {
                    Text("Add an API key above to enable AI features")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Provider")
                                .font(DesignTokens.Typography.callout)
                                .foregroundStyle(AppTheme.textSecondary)

                            DSPicker(
                                items: Array(configuredProviders),
                                selection: Binding(
                                    get: { selectedProvider },
                                    set: { if let provider = $0 { selectedProvider = provider } }
                                )
                            ) { provider in
                                Text(provider.displayName)
                            }
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Model")
                                .font(DesignTokens.Typography.callout)
                                .foregroundStyle(AppTheme.textSecondary)

                            DSPicker(
                                items: selectedProvider.models,
                                selection: Binding(
                                    get: {
                                        selectedProvider.models.first { $0.id == selectedModel }
                                    },
                                    set: { model in
                                        if let model = model {
                                            selectedModel = model.id
                                        }
                                    }
                                )
                            ) { model in
                                Text(model.name)
                            }
                        }

                        DSButton("Set as Default", variant: .primary, size: .sm) {
                            try? await aiService.setProvider(selectedProvider, model: selectedModel)
                            successMessage = "Default provider updated"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                successMessage = nil
                            }
                        }

                        if let message = successMessage {
                            Text(message)
                                .foregroundStyle(AppTheme.success)
                                .font(DesignTokens.Typography.caption)
                        }
                    }
                }
            }

            SettingsSection(title: "AI Features") {
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

            SettingsSection(title: "System Prompts") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    PromptEditor(
                        title: "Terminal Suggestions",
                        key: "ai.prompt.terminal_suggestions",
                        placeholders: "{{input}}, {{recent_context}}, {{repo_context}}",
                        defaultPrompt: """
                        You are a terminal command assistant. Suggest 3-5 relevant terminal commands based on the user's input.

                        User input: "{{input}}"
                        {{recent_context}}
                        {{repo_context}}

                        Return ONLY a JSON array of suggestions.
                        """
                    )

                    Divider()

                    PromptEditor(
                        title: "Terminal Error Explanation",
                        key: "ai.prompt.terminal_error",
                        placeholders: "{{command}}, {{error}}, {{repo_context}}",
                        defaultPrompt: """
                        You are a helpful terminal assistant. Explain this error and suggest a fix.

                        Command: {{command}}
                        Error output:
                        {{error}}
                        {{repo_context}}
                        """
                    )
                }
            }

            SettingsSection(title: "Get API Keys") {
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
        }
        .padding()
        .background(AppTheme.background)
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
        case .ollama: return "cpu"
        }
    }

    private func providerColor(_ provider: AIService.AIProvider) -> Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .gemini: return .blue
        case .ollama: return .purple
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text(title)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fontWeight(.medium)
                Text(description)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Prompt Editor

struct PromptEditor: View {
    let title: String
    let key: String
    let placeholders: String
    let defaultPrompt: String

    @State private var prompt: String = ""
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fontWeight(.medium)
                    Text("Placeholders: \(placeholders)")
                        .foregroundStyle(AppTheme.textSecondary)
                        .font(DesignTokens.Typography.caption)
                }

                Spacer()

                if prompt != defaultPrompt && !prompt.isEmpty {
                    DSButton("Reset", variant: .secondary, size: .sm) {
                        prompt = ""
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                }

                DSButton(isEditing ? "Done" : "Edit", variant: isEditing ? .primary : .secondary, size: .sm) {
                    isEditing.toggle()
                }
            }

            if isEditing {
                VStack(spacing: 0) {
                    TextEditor(text: $prompt)
                        .font(.custom("Menlo", size: 12))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(height: 150)
                        .padding(8)
                        .background(AppTheme.backgroundSecondary)
                        .clipShape(.rect(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
                .onChange(of: prompt) { _, newValue in
                    if newValue.isEmpty {
                        UserDefaults.standard.removeObject(forKey: key)
                    } else {
                        UserDefaults.standard.set(newValue, forKey: key)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary.opacity(0.3))
        .clipShape(.rect(cornerRadius: 8))
        .onAppear {
            if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
                prompt = stored
            } else {
                prompt = defaultPrompt
            }
        }
    }
}
