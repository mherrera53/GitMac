import SwiftUI
import AppKit

// MARK: - Ghostty Native Terminal View
//
// CONDITIONAL COMPILATION:
// To enable Ghostty integration, add the following to your Xcode build settings:
// - Swift Compiler - Custom Flags: OTHER_SWIFT_FLAGS = -D GHOSTTY_AVAILABLE
// - Ensure GhosttyKit.xcframework is in the Frameworks/ folder
//
// CI builds will skip this code since GHOSTTY_AVAILABLE won't be defined

#if GHOSTTY_AVAILABLE

/// Native Ghostty terminal integration with AI features
struct GhosttyNativeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyViewModel()
    @State private var aiEnabled = true
    @State private var showAIChat = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar (Ghostty-style minimal)
            toolbarView

            // Native Ghostty terminal
            ZStack {
                GhosttyTerminalRepresentable(viewModel: viewModel)
                    .background(GhosttyColors.background)

                // AI suggestions overlay
                if aiEnabled && !viewModel.currentInput.isEmpty {
                    VStack {
                        Spacer()
                        aiSuggestionsView
                    }
                }
            }

            // Status bar
            statusBarView
        }
        .onAppear {
            if let repoPath = appState.currentRepository?.path {
                viewModel.setWorkingDirectory(repoPath)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                viewModel.setWorkingDirectory(path)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Directory indicator
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "folder")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                Text(viewModel.currentDirectory)
                    .font(DesignTokens.Typography.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(GhosttyColors.textMuted)

            Spacer()

            // AI Chat
            Button {
                showAIChat.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(GhosttyColors.accent)
            .help("AI Assistant")
            .popover(isPresented: $showAIChat) {
                TerminalAIChatView(repoPath: appState.currentRepository?.path)
                    .frame(width: 400, height: 500)
            }

            // AI Toggle
            Toggle(isOn: $aiEnabled) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("AI")
                        .font(DesignTokens.Typography.caption2)
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .foregroundColor(aiEnabled ? GhosttyColors.accent : GhosttyColors.textMuted)
            .help("AI Suggestions")

            // Clear
            Button {
                viewModel.clearTerminal()
            } label: {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(GhosttyColors.textMuted)
            .help("Clear Terminal")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(GhosttyColors.backgroundSecondary)
    }

    // MARK: - AI Suggestions

    private var aiSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.aiSuggestions.isEmpty {
                ForEach(Array(viewModel.aiSuggestions.prefix(5).enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        viewModel.applySuggestion(suggestion)
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "sparkles")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(GhosttyColors.accent)

                            Text(suggestion.command)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(GhosttyColors.textPrimary)

                            if let desc = suggestion.description {
                                Text("- \(desc)")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(GhosttyColors.textMuted)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                        .background(index == viewModel.selectedSuggestionIndex ? GhosttyColors.selection : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(GhosttyColors.backgroundSecondary.opacity(0.95))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .shadow(radius: DesignTokens.CornerRadius.md)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.md)
    }

    // MARK: - Status Bar

    private var statusBarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Command count
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "terminal")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(viewModel.commandCount) commands")
                    .font(DesignTokens.Typography.caption2)
            }

            Spacer()

            // GPU indicator
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "figure.run")
                    .font(DesignTokens.Typography.caption2)
                Text("GPU")
                    .font(DesignTokens.Typography.caption2)
            }
            .foregroundColor(GhosttyColors.green)

            // Running indicator
            if viewModel.isRunning {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: DesignTokens.Size.iconSM, height: DesignTokens.Size.iconSM)
                    Text("Running...")
                        .font(DesignTokens.Typography.caption2)
                }
                .foregroundColor(GhosttyColors.accent)
            }
        }
        .foregroundColor(GhosttyColors.textMuted)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(GhosttyColors.backgroundSecondary)
    }
}

// MARK: - Ghostty NSViewRepresentable

struct GhosttyTerminalRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: GhosttyViewModel

    func makeNSView(context: Context) -> NSView {
        // Configure Ghostty with Tokyo Night theme
        var config = ghostty_config_options_t()
        config.font_family = strdup("JetBrains Mono")
        config.font_size = 13
        config.theme = strdup("tokyo-night")
        config.gpu_renderer = true

        // Create Ghostty terminal instance
        guard let terminal = GhosttyTerminal(config: config) else {
            // Fallback to a placeholder view if Ghostty fails
            let errorView = NSTextField(labelWithString: "Ghostty not available")
            errorView.textColor = .red
            errorView.alignment = .center
            return errorView
        }

        // Free allocated strings
        if let fontFamily = config.font_family {
            free(UnsafeMutableRawPointer(mutating: fontFamily))
        }
        if let theme = config.theme {
            free(UnsafeMutableRawPointer(mutating: theme))
        }

        // Store terminal reference
        context.coordinator.terminal = terminal
        viewModel.terminal = terminal

        // Set up callbacks
        terminal.onTitleChange = { title in
            viewModel.terminalTitle = title
        }

        terminal.onDirectoryChange = { directory in
            viewModel.currentDirectory = (directory as NSString).lastPathComponent
        }

        // Return the native Ghostty view
        guard let terminalView = terminal.terminalView else {
            let errorView = NSTextField(labelWithString: "Failed to create terminal view")
            errorView.textColor = .red
            return errorView
        }

        return terminalView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Handle updates if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject {
        var viewModel: GhosttyViewModel
        var terminal: GhosttyTerminal?

        init(viewModel: GhosttyViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            terminal?.cleanup()
        }
    }
}

// MARK: - Ghostty ViewModel

class GhosttyViewModel: ObservableObject {
    @Published var currentInput = ""
    @Published var currentDirectory = "~"
    @Published var terminalTitle = "Terminal"
    @Published var commandCount = 0
    @Published var isRunning = false
    @Published var aiSuggestions: [AICommandSuggestion] = []
    @Published var selectedSuggestionIndex = 0

    weak var terminal: GhosttyTerminal?

    private var suggestionDebounceTask: Task<Void, Never>?
    private var suggestionCache: [String: [AICommandSuggestion]] = [:]

    func setWorkingDirectory(_ path: String) {
        terminal?.setWorkingDirectory(path)
        currentDirectory = (path as NSString).lastPathComponent
    }

    func clearTerminal() {
        // Send clear command to terminal
        terminal?.writeInput("\u{0C}") // Form feed (Ctrl+L)
    }

    func applySuggestion(_ suggestion: AICommandSuggestion) {
        terminal?.writeInput(suggestion.command + "\n")
        aiSuggestions.removeAll()
        currentInput = ""
        commandCount += 1
    }

    func fetchAISuggestions(for input: String, repoPath: String?) {
        // Check cache
        if let cached = suggestionCache[input] {
            aiSuggestions = cached
            return
        }

        // Debounce AI requests
        suggestionDebounceTask?.cancel()
        suggestionDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            do {
                let suggestions = try await AIService.shared.getGitCommandSuggestions(
                    input: input,
                    repoPath: repoPath
                )

                await MainActor.run {
                    self.aiSuggestions = suggestions
                    self.suggestionCache[input] = suggestions
                }
            } catch {
                print("[Ghostty] AI suggestion error: \(error)")
            }
        }
    }
}

#else
// MARK: - Ghostty Stub (When Framework Not Available)

/// Stub view when Ghostty framework is not available
struct GhosttyNativeView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Ghostty Terminal")
                .font(.title2)
                .foregroundColor(AppTheme.textPrimary)
            Text("GhosttyKit framework not available")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1a1b26"))
    }
}

#endif

// MARK: - Ghostty Color Scheme (Shared)

enum GhosttyColors {
    static let background = Color(hex: "1a1b26")
    static let backgroundSecondary = Color(hex: "16161e")
    static let textPrimary = Color(hex: "c0caf5")
    static let textMuted = Color(hex: "565f89")
    static let accent = Color(hex: "7aa2f7")
    static let cursor = Color(hex: "c0caf5")
    static let selection = Color(hex: "283457")

    // ANSI Colors (Tokyo Night theme)
    static let black = Color(hex: "15161e")
    static let red = Color(hex: "f7768e")
    static let green = Color(hex: "9ece6a")
    static let yellow = Color(hex: "e0af68")
    static let blue = Color(hex: "7aa2f7")
    static let magenta = Color(hex: "bb9af7")
    static let cyan = Color(hex: "7dcfff")
    static let white = Color(hex: "a9b1d6")
}

// MARK: - AI Command Suggestion Model

struct AICommandSuggestion: Identifiable {
    let id = UUID()
    let command: String
    let description: String?
}
