import SwiftUI

struct EnhancedTerminalPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyViewModel()
    @StateObject private var enhancedViewModel = GhosttyEnhancedViewModel()
    @State private var inputHeight: CGFloat = 40

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            terminalView
            suggestionsOverlay
            loadingIndicator
        }
        .background(AppTheme.background)
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

    @ViewBuilder
    private var suggestionsOverlay: some View {
        if !enhancedViewModel.aiSuggestions.isEmpty && !enhancedViewModel.currentInput.isEmpty {
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
            .padding(.bottom, 80)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enhancedViewModel.aiSuggestions.count)
        }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        if enhancedViewModel.isLoadingAI && !enhancedViewModel.currentInput.isEmpty {
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
            .padding(.bottom, 80)
            .transition(.opacity.combined(with: .scale))
        }
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
}
