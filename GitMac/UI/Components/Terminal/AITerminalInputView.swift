import SwiftUI

struct AITerminalInputView: View {
    @ObservedObject var enhancedViewModel: GhosttyEnhancedViewModel
    var onExecute: (String) -> Void
    @State private var inputHeight: CGFloat = 40
    @FocusState private var isFocused: Bool
    
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
                .background(Color(hex: "1e1e2e").opacity(0.95)) // Darker, solid background
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
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
                    .background(Color(hex: "313244")) // Surface0
                    .foregroundColor(Color(hex: "89b4fa")) // Blue
                    
                    // Arrow separator
                    Image(systemName: "chevron.right") // Simplified separator for now
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "313244"))
                        .background(enhancedViewModel.currentRepoPath != nil ? Color(hex: "45475a") : Color(hex: "1e1e2e"))
                    
                    // Git Branch Pill (if applicable)
                    if let _ = enhancedViewModel.currentRepoPath {
                        HStack(spacing: 6) {
                            Image(systemName: "git.branch")
                                .font(.system(size: 10))
                            // Ideally fetch dynamic branch name, placeholder for visual check
                            Text("main") 
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "45475a")) // Surface1
                        .foregroundColor(Color(hex: "a6e3a1")) // Green
                        
                        // Ending arrow
                        Image(systemName: "chevron.right")
                             .font(.system(size: 10, weight: .bold))
                             .foregroundColor(Color(hex: "45475a"))
                             .background(Color(hex: "1e1e2e")) // Input bg
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.leading, 6)
                .padding(.vertical, 6)

                // Input Field
                TextField("I want to...", text: $enhancedViewModel.currentInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
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
                        .foregroundColor(Color(hex: "cba6f7")) // Mauve
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .background(Color(hex: "1e1e2e")) // Base
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color(hex: "cba6f7").opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

}
