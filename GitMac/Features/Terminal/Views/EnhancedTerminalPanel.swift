import SwiftUI

enum TerminalViewMode: String, CaseIterable {
    case terminal = "Terminal"
    case blocks = "Blocks"
    case workflows = "Workflows"
}

struct EnhancedTerminalPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyViewModel()
    @StateObject private var enhancedViewModel = GhosttyEnhancedViewModel()
    @State private var inputHeight: CGFloat = 40
    @State private var viewMode: TerminalViewMode = .terminal
    @State private var showSessionSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with view mode switcher
            terminalToolbar

            // Main content based on view mode
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    contentView

                    // AI suggestions overlay (only in terminal mode)
                    if viewMode == .terminal {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                                .frame(height: 60) // Space from top

                            if !enhancedViewModel.aiSuggestions.isEmpty && !enhancedViewModel.currentInput.isEmpty {
                                suggestionsOverlay
                            } else if enhancedViewModel.isLoadingAI && !enhancedViewModel.currentInput.isEmpty {
                                loadingIndicator
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showSessionSheet) {
            if let currentSession = createCurrentSession() {
                SessionSharingSheet(session: currentSession)
            }
        }
        .onAppear {
             if let repoPath = appState.currentRepository?.path {
                 viewModel.setWorkingDirectory(repoPath)
                 enhancedViewModel.updateContext(repoPath: repoPath)
             }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
             if let path = newPath {
                 viewModel.setWorkingDirectory(path)
                 enhancedViewModel.updateContext(repoPath: path)
             }
        }
    }

    // MARK: - Toolbar

    private var terminalToolbar: some View {
        HStack(spacing: 12) {
            // View mode picker
            Picker("View Mode", selection: $viewMode) {
                ForEach(TerminalViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Spacer()

            // Session sharing button
            Button {
                showSessionSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Session")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.backgroundSecondary.opacity(0.5))
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .terminal:
            terminalView
        case .blocks:
            blocksView
        case .workflows:
            workflowsView
        }
    }

    private var blocksView: some View {
        TerminalBlocksView(viewModel: enhancedViewModel)
    }

    private var workflowsView: some View {
        TerminalWorkflowsView(viewModel: enhancedViewModel)
    }

    // MARK: - Subviews

    private var terminalView: some View {
        GhosttyEnhancedTerminalView(
            viewModel: viewModel,
            enhancedViewModel: enhancedViewModel,
            initialDirectory: appState.currentRepository?.path ?? NSHomeDirectory(),
            aiEnabled: true,
            repoPath: appState.currentRepository?.path
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionsOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(enhancedViewModel.aiSuggestions.prefix(5).enumerated()), id: \.offset) { index, suggestion in
                suggestionRow(suggestion: suggestion, index: index)

                if index < enhancedViewModel.aiSuggestions.count - 1 && index < 4 {
                    Divider()
                        .background(AppTheme.backgroundSecondary)
                }
            }
        }
        .background(suggestionBackground)
        .frame(maxWidth: 500)
        .padding(.leading, 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enhancedViewModel.aiSuggestions.count)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))

            Text("AI thinking...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(loadingBackground)
        .padding(.leading, 20)
        .transition(.opacity.combined(with: .scale))
    }

    private var suggestionBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppTheme.background.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
    }

    private var loadingBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppTheme.background.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
    }

    private func suggestionRow(suggestion: AICommandSuggestion, index: Int) -> some View {
        Button {
            applySuggestion(suggestion)
        } label: {
            HStack(spacing: 12) {
                suggestionIcon(index: index, isFromAI: suggestion.isFromAI)
                suggestionContent(suggestion: suggestion, index: index)
                Spacer()
                if index == enhancedViewModel.selectedSuggestionIndex {
                    shortcutHint
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func suggestionIcon(index: Int, isFromAI: Bool) -> some View {
        ZStack {
            Circle()
                .fill(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent.opacity(0.15) : Color.clear)
                .frame(width: 28, height: 28)

            Image(systemName: isFromAI ? "sparkles" : "terminal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent : AppTheme.textSecondary)
        }
    }

    private func suggestionContent(suggestion: AICommandSuggestion, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(suggestion.command)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.textPrimary : AppTheme.textSecondary)

            if !suggestion.description.isEmpty {
                Text(suggestion.description)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(2)
            }
        }
    }

    private var shortcutHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "return")
                .font(.system(size: 10, weight: .semibold))
            Text("enter")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(AppTheme.textMuted)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(4)
    }

    private func applySuggestion(_ suggestion: AICommandSuggestion) {
        // Clear current buffer
        enhancedViewModel.currentInput = ""
        enhancedViewModel.aiSuggestions.removeAll()

        // Send command to terminal
        viewModel.writeInput(suggestion.command + "\n")

        // Track command in history
        enhancedViewModel.trackCommand(suggestion.command)
    }

    // MARK: - Session Management

    private func createCurrentSession() -> TerminalSession? {
        guard !enhancedViewModel.trackedCommands.isEmpty else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let sessionName = "Session \(dateFormatter.string(from: Date()))"

        return TerminalSession(
            name: sessionName,
            commands: enhancedViewModel.trackedCommands
        )
    }
}
