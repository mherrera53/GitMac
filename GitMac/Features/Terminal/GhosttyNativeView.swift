import SwiftUI
import AppKit

// MARK: - Ghostty Native Terminal View

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
        HStack(spacing: 12) {
            // Directory indicator
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                Text(viewModel.currentDirectory)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(GhosttyColors.textMuted)

            Spacer()

            // AI Chat
            Button {
                showAIChat.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
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
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("AI")
                        .font(.system(size: 9, weight: .medium))
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
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(GhosttyColors.textMuted)
            .help("Clear Terminal")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundColor(GhosttyColors.accent)

                            Text(suggestion.command)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(GhosttyColors.textPrimary)

                            if let desc = suggestion.description {
                                Text("- \(desc)")
                                    .font(.system(size: 10))
                                    .foregroundColor(GhosttyColors.textMuted)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(index == viewModel.selectedSuggestionIndex ? GhosttyColors.selection : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(GhosttyColors.backgroundSecondary.opacity(0.95))
        .cornerRadius(8)
        .shadow(radius: 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Status Bar

    private var statusBarView: some View {
        HStack(spacing: 12) {
            // Command count
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.system(size: 9))
                Text("\(viewModel.commandCount) commands")
                    .font(.system(size: 9))
            }

            Spacer()

            // GPU indicator
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 9))
                Text("GPU")
                    .font(.system(size: 9))
            }
            .foregroundColor(GhosttyColors.green)

            // Running indicator
            if viewModel.isRunning {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Running...")
                        .font(.system(size: 9))
                }
                .foregroundColor(GhosttyColors.accent)
            }
        }
        .foregroundColor(GhosttyColors.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
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

// MARK: - Ghostty Color Scheme

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

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        r = (int >> 16) & 0xFF
        g = (int >> 8) & 0xFF
        b = int & 0xFF
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - AI Command Suggestion Model

struct AICommandSuggestion: Identifiable {
    let id = UUID()
    let command: String
    let description: String?
}
