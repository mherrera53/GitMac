import SwiftUI

struct AITerminalInputView: View {
    @ObservedObject var enhancedViewModel: GhosttyEnhancedViewModel
    var onExecute: (String) -> Void
    @State private var inputHeight: CGFloat = 40
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let DESKTOP_PADDING: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // Suggestions Popover (Floating above, Warp-style)
            if !enhancedViewModel.aiSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(enhancedViewModel.aiSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        Button {
                            onExecute(suggestion.command)
                            enhancedViewModel.aiSuggestions.removeAll()
                            enhancedViewModel.currentInput = ""
                        } label: {
                            HStack(spacing: 12) {
                                // Icon
                                ZStack {
                                    Circle()
                                        .fill(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent.opacity(0.2) : Color.clear)
                                        .frame(width: 24, height: 24)

                                    Image(systemName: suggestion.category == "Git" ? "git.branch" : "terminal")
                                        .font(.system(size: 10))
                                        .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent : AppTheme.textSecondary)
                                }

                                // Text
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.command)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? .white : AppTheme.textPrimary)

                                    if !suggestion.description.isEmpty {
                                        Text(suggestion.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? .white.opacity(0.8) : AppTheme.textSecondary)
                                    }
                                }

                                Spacer()

                                // Shortcut Hint
                                if index == enhancedViewModel.selectedSuggestionIndex {
                                    Text("↵")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(index == enhancedViewModel.selectedSuggestionIndex ? .white.opacity(0.6) : AppTheme.textMuted)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(index == enhancedViewModel.selectedSuggestionIndex ? AppTheme.accent : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AppTheme.backgroundSecondary.opacity(0.98))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 16, x: 0, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Warp-like Input Block
            HStack(spacing: 0) {
                // Prompt Area
                HStack(spacing: 0) {
                    // Directory Pill
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                        Text(URL(fileURLWithPath: enhancedViewModel.currentDirectory).lastPathComponent)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.backgroundTertiary)
                    .foregroundColor(AppTheme.info)

                    // Arrow separator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                        .background(enhancedViewModel.currentRepoPath != nil ? AppTheme.backgroundTertiary : AppTheme.backgroundSecondary)

                    // Git Branch Pill (if applicable)
                    if let _ = enhancedViewModel.currentRepoPath {
                        HStack(spacing: 6) {
                            Image(systemName: "git.branch")
                                .font(.system(size: 10))
                            Text("main")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.backgroundTertiary)
                        .foregroundColor(AppTheme.success)

                        // Ending arrow
                        Image(systemName: "chevron.right")
                             .font(.system(size: 10, weight: .bold))
                             .foregroundColor(AppTheme.textMuted)
                             .background(AppTheme.backgroundSecondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.leading, 6)
                .padding(.vertical, 6)

                // Input Field
                TextField("I want to...", text: $enhancedViewModel.currentInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .focused($isFocused)
                    .onSubmit {
                        if !enhancedViewModel.currentInput.isEmpty {
                            onExecute(enhancedViewModel.currentInput)
                            enhancedViewModel.currentInput = ""
                        }
                    }

                // AI Sparkles (Warp "AI Command Search" trigger)
                Button(action: {
                    // Trigger AI mode
                }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.accentPurple)
                        .padding(8)
                        .background(AppTheme.hover)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? AppTheme.accent.opacity(0.5) : AppTheme.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

}
