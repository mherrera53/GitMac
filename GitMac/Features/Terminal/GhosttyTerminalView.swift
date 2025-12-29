import SwiftUI

// MARK: - Ghostty-Style Terminal View
//
// CONDITIONAL COMPILATION:
// This file uses SwiftTerm for terminal rendering
// To enable, add: OTHER_SWIFT_FLAGS = -D GHOSTTY_AVAILABLE

#if GHOSTTY_AVAILABLE
import SwiftTerm

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

#else
// MARK: - Ghostty Stub (When Framework Not Available)

/// Stub view when Ghostty framework is not available
struct GhosttyTerminalView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Ghostty Terminal")
                .font(.title2)
                .foregroundColor(AppTheme.textPrimary)
            Text("SwiftTerm not available")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1a1b26"))
    }
}

// Stub ViewModel
class GhosttyTerminalViewModel: ObservableObject {}

#endif
