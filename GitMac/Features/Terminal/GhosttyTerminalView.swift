import SwiftUI
import SwiftTerm

// MARK: - Ghostty-Style Terminal View

/// High-performance terminal view using SwiftTerm (Ghostty-like rendering)
struct GhosttyTerminalView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyTerminalViewModel()
    @State private var aiEnabled = true
    @State private var showAIChat = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar (Ghostty-style minimal)
            toolbarView

            // Terminal content
            ZStack {
                // SwiftTerm embedded view
                GhosttyTerminalRepresentable(viewModel: viewModel)
                    .background(GhosttyColors.background)

                // AI suggestions overlay (only when typing)
                if aiEnabled && !viewModel.currentInput.isEmpty {
                    VStack {
                        Spacer()
                        aiSuggestionsView
                    }
                }
            }

            // Status bar (Ghostty-style)
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

// MARK: - SwiftTerm NSViewRepresentable

struct GhosttyTerminalRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: GhosttyTerminalViewModel

    func makeNSView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)

        // Configure Ghostty-style appearance
        terminalView.font = NSFont(name: "JetBrainsMono-Regular", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.backgroundColor = NSColor(GhosttyColors.background)
        terminalView.cursorColor = NSColor(GhosttyColors.cursor)

        // Set delegate
        context.coordinator.terminalView = terminalView
        terminalView.terminalDelegate = context.coordinator

        // Start shell
        viewModel.startShell(terminalView: terminalView)

        return terminalView
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        var viewModel: GhosttyTerminalViewModel
        weak var terminalView: TerminalView?

        init(viewModel: GhosttyTerminalViewModel) {
            self.viewModel = viewModel
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            viewModel.handleResize(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {
            viewModel.terminalTitle = title
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                viewModel.currentDirectory = (dir as NSString).lastPathComponent
            }
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            viewModel.send(data: Data(data))
        }

        func scrolled(source: TerminalView, position: Double) {
            // Handle scroll
        }

        func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
            if let url = URL(string: link) {
                NSWorkspace.shared.open(url)
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

    // ANSI Colors (Ghostty Tokyo Night theme)
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
