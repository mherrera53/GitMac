//
//  AICommandSuggestions.swift
//  GitMac
//
//  AI command suggestions overlay - Warp-style
//

import SwiftUI

// MARK: - AI Suggestions Overlay

struct AICommandSuggestionsOverlay: View {
    let suggestions: [AICommandSuggestion]
    let selectedIndex: Int
    let isLoading: Bool
    let onSelect: (AICommandSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Loading indicator
            if isLoading {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Getting AI suggestions...")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            }

            // Suggestions list
            ForEach(Array(suggestions.prefix(5).enumerated()), id: \.element.id) { index, suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    isSelected: index == selectedIndex,
                    onTap: { onSelect(suggestion) }
                )
            }
        }
        .frame(maxWidth: 600)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.98))
                .shadow(color: AppTheme.background.opacity(0.3), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, 60)
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {
    let suggestion: AICommandSuggestion
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Image(systemName: suggestion.isFromAI ? "sparkles" : "terminal")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(suggestion.isFromAI ? AppTheme.accent : AppTheme.accent)
                    .frame(width: DesignTokens.Size.iconLG)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    // Command
                    Text(suggestion.command)
                        .font(DesignTokens.Typography.body.monospaced())
                        .foregroundColor(AppTheme.textPrimary)

                    // Description
                    Text(suggestion.description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                // Confidence or shortcut hint
                if isSelected {
                    Text("↩")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(AppTheme.accent.opacity(0.15))
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                } else if suggestion.isFromAI {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Circle()
                            .fill(confidenceColor)
                            .frame(width: 6, height: 6)
                        Text("\(Int(suggestion.confidence * 100))%")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isSelected ? AppTheme.accent.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var confidenceColor: Color {
        if suggestion.confidence >= 0.8 { return .green }
        if suggestion.confidence >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Preview

#if DEBUG
struct AICommandSuggestionsOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            AICommandSuggestionsOverlay(
                suggestions: [
                    AICommandSuggestion(
                        command: "git commit -m \"Fix bug\"",
                        description: "Commit changes with a message",
                        confidence: 0.95,
                        isFromAI: true,
                        category: "Git"
                    ),
                    AICommandSuggestion(
                        command: "git add .",
                        description: "Stage all changes",
                        confidence: 0.85,
                        isFromAI: false,
                        category: "Git"
                    ),
                    AICommandSuggestion(
                        command: "git status",
                        description: "Show working tree status",
                        confidence: 0.70,
                        isFromAI: false,
                        category: "Git"
                    )
                ],
                selectedIndex: 0,
                isLoading: false,
                onSelect: { _ in }
            )
        }
        .frame(height: 400)
    }
}
#endif
