//
//  MinimalTerminalView.swift
//  GitMac
//
//  Minimalist terminal - just Ghostty with invisible AI integration
//

import SwiftUI
import AppKit

// MARK: - Minimal Terminal View

#if GHOSTTY_AVAILABLE
struct MinimalTerminalView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GhosttyViewModel()
    @StateObject private var enhancedViewModel = GhosttyEnhancedViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen Ghostty terminal
            GhosttyEnhancedTerminalView(
                viewModel: viewModel,
                enhancedViewModel: enhancedViewModel,
                initialDirectory: appState.currentRepository?.path ?? NSHomeDirectory(),
                aiEnabled: true,
                repoPath: appState.currentRepository?.path
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Subtle AI suggestions overlay
            if !enhancedViewModel.aiSuggestions.isEmpty {
                MinimalSuggestionsOverlay(
                    suggestions: enhancedViewModel.aiSuggestions,
                    selectedIndex: enhancedViewModel.selectedSuggestionIndex,
                    isLoading: enhancedViewModel.isLoadingAI,
                    onSelect: { suggestion in
                        enhancedViewModel.applySuggestion(suggestion, to: viewModel)
                    },
                    onDismiss: {
                        enhancedViewModel.aiSuggestions.removeAll()
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.15), value: enhancedViewModel.aiSuggestions.count)
            }

            // Loading indicator (very subtle)
            if enhancedViewModel.isLoadingAI && enhancedViewModel.aiSuggestions.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent.opacity(0.6)))
                    Text("...")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.background.opacity(0.9))
                .clipShape(.rect(cornerRadius: 6))
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .background(AppTheme.background)
        .onAppear {
            if let path = appState.currentRepository?.path {
                viewModel.setWorkingDirectory(path)
                enhancedViewModel.updateContext(repoPath: path)
            }
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                viewModel.setWorkingDirectory(path)
                enhancedViewModel.updateContext(repoPath: path)
            }
        }
    }
}
#endif

// MARK: - Minimal Suggestions Overlay

struct MinimalSuggestionsOverlay: View {
    let suggestions: [AICommandSuggestion]
    let selectedIndex: Int
    let isLoading: Bool
    let onSelect: (AICommandSuggestion) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.prefix(5).enumerated()), id: \.offset) { index, suggestion in
                MinimalSuggestionRow(
                    suggestion: suggestion,
                    isSelected: index == selectedIndex,
                    onSelect: { onSelect(suggestion) }
                )

                if index < min(suggestions.count, 5) - 1 {
                    Divider()
                        .background(AppTheme.border.opacity(0.3))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.background.opacity(0.95))
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: 500)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Minimal Suggestion Row

struct MinimalSuggestionRow: View {
    let suggestion: AICommandSuggestion
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // AI indicator (subtle)
                if suggestion.isFromAI {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.accent.opacity(0.7))
                } else {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }

                // Command
                Text(suggestion.command)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Description (truncated)
                if !suggestion.description.isEmpty {
                    Text(suggestion.description)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                        .frame(maxWidth: 150, alignment: .trailing)
                }

                // Shortcut hint
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "return")
                            .font(.system(size: 9, weight: .semibold))
                        Text("enter")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.accent.opacity(0.08) : (isHovered ? AppTheme.backgroundSecondary.opacity(0.5) : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#if DEBUG && GHOSTTY_AVAILABLE
struct MinimalTerminalView_Previews: PreviewProvider {
    static var previews: some View {
        MinimalTerminalView()
            .environmentObject(AppState())
            .frame(width: 800, height: 600)
    }
}
#endif
