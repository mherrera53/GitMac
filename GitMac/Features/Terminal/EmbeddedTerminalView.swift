import SwiftUI
import AppKit
import SwiftTerm

// MARK: - Embedded Terminal View (SwiftTerm-based)

/// A real terminal emulator embedded in GitMac using SwiftTerm
struct EmbeddedTerminalView: View {
    @StateObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var appState: AppState
    @State private var showAIChat = false
    @State private var terminalKey = UUID() // For forcing refresh

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            EmbeddedTerminalToolbar(
                showAIChat: $showAIChat,
                onNewTab: { /* TODO: Tab support */ },
                onClear: { terminalKey = UUID() },
                onOpenLazygit: openLazygit,
                repoPath: appState.currentRepository?.path
            )

            // Terminal
            SwiftTermView(
                workingDirectory: appState.currentRepository?.path ?? NSHomeDirectory(),
                key: terminalKey
            )
            .id(terminalKey)
        }
        .sheet(isPresented: $showAIChat) {
            TerminalAIChatView(repoPath: appState.currentRepository?.path)
                .frame(width: 500, height: 600)
        }
    }

    private func openLazygit() {
        // Check if lazygit is installed and run it
        guard let path = appState.currentRepository?.path else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Terminal", path]
        task.environment = ["LAZYGIT_NEW_DIR_FILE": path]
        try? task.run()
    }
}

// MARK: - SwiftTerm NSView Wrapper

struct SwiftTermView: NSViewRepresentable {
    let workingDirectory: String
    let key: UUID

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)

        // Configure terminal appearance
        terminal.configureNativeColors()
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminal.nativeForegroundColor = NSColor.textPrimary
        terminal.nativeBackgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)

        // Set cursor style
        terminal.caretColor = NSColor.systemCyan
        terminal.caretTextColor = NSColor.windowBackgroundColor

        // Start shell in working directory
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        terminal.startProcess(executable: shell, args: [], environment: nil, execName: nil)

        // Change to working directory
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            terminal.send(txt: "cd \"\(workingDirectory)\" && clear\n")
        }

        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update working directory if changed
    }
}

// MARK: - Terminal Toolbar

struct EmbeddedTerminalToolbar: View {
    @Binding var showAIChat: Bool
    let onNewTab: () -> Void
    let onClear: () -> Void
    let onOpenLazygit: () -> Void
    var repoPath: String?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Terminal icon
            Image(systemName: "terminal.fill")
                .foregroundColor(AppTheme.textPrimary)

            Text("Terminal")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            // Lazygit button
            Button(action: onOpenLazygit) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(DesignTokens.Typography.caption2)
                    Text("lazygit")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(AppTheme.warning)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(AppTheme.warning.opacity(0.15))
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .buttonStyle(.plain)
            .help("Run lazygit in terminal")

            // AI Chat button
            Button(action: { showAIChat.toggle() }) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(DesignTokens.Typography.caption2)
                    Text("AI Chat")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(AppTheme.accentPurple)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(AppTheme.accentPurple.opacity(0.15))
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .buttonStyle(.plain)
            .help("Open AI Assistant")

            Divider()
                .frame(height: DesignTokens.Size.iconMD)

            // Clear button
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .buttonStyle(.plain)
            .help("Clear and restart terminal")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - AI Chat View

struct TerminalAIChatView: View {
    var repoPath: String?
    @State private var messages: [AIChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @StateObject private var aiService = AIService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(AppTheme.accentPurple)
                Text("AI Terminal Assistant")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        ForEach(messages) { message in
                            AIChatBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: DesignTokens.Spacing.sm) {
                DSTextField(placeholder: "Ask about git commands, errors, or code...", text: $inputText)
                    .padding(DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
                        .background(inputText.isEmpty ? AppTheme.textMuted : AppTheme.accentPurple)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
        }
    }

    private func sendMessage() {
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }

        // Add user message
        messages.append(AIChatMessage(role: .user, content: userText))
        inputText = ""
        isLoading = true

        Task {
            do {
                let context = buildContext()
                let response = try await aiService.chat(
                    messages: messages.map { ($0.role == .user ? "user" : "assistant", $0.content) },
                    systemPrompt: context
                )

                await MainActor.run {
                    messages.append(AIChatMessage(role: .assistant, content: response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(AIChatMessage(
                        role: .assistant,
                        content: "Error: \(error.localizedDescription)\n\nMake sure you have configured an AI provider in Settings."
                    ))
                    isLoading = false
                }
            }
        }
    }

    private func buildContext() -> String {
        var context = """
        You are a helpful Git and terminal assistant integrated into GitMac, a native macOS Git client.
        Help the user with:
        - Git commands and workflows
        - Terminal commands
        - Debugging errors
        - Code explanations

        Be concise and provide practical solutions. When suggesting commands, format them as code blocks.
        """

        if let path = repoPath {
            context += "\n\nThe user is working in repository: \(path)"
        }

        return context
    }
}

// MARK: - Chat Message Model

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role {
        case user
        case assistant
    }
}

// MARK: - Chat Bubble View

struct AIChatBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .foregroundColor(AppTheme.accentPurple)
                    .frame(width: DesignTokens.Size.iconXL, height: DesignTokens.Size.iconXL)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(message.content)
                    .textSelection(.enabled)
                    .font(DesignTokens.Typography.body)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
            .background(message.role == .user ? AppTheme.info.opacity(0.15) : AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.xl)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(AppTheme.accent)
                    .frame(width: DesignTokens.Size.iconXL, height: DesignTokens.Size.iconXL)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - AIService Chat Extension

extension AIService {
    func chat(messages: [(role: String, content: String)], systemPrompt: String) async throws -> String {
        // Use existing AI infrastructure
        let combinedPrompt = messages.map { "\($0.role): \($0.content)" }.joined(separator: "\n\n")
        return try await generateCommitMessage(diff: combinedPrompt, context: systemPrompt)
    }
}
