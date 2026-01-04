import SwiftUI

// MARK: - Warp-style AI Input Bar

struct WarpAIInputBar: View {
    @Binding var inputText: String
    @Binding var result: NLCommandResponse?
    let isTranslating: Bool
    let onTranslate: () async -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // AI input bar
            HStack(spacing: 12) {
                // AI icon with glow effect
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
                
                // Input field
                TextField("Ask Warp AI...", text: $inputText, axis: .vertical)
                    .font(.system(size: 14))
                    .textFieldStyle(WarpAIInputStyle())
                    .lineLimit(1...3)
                    .onSubmit {
                        Task {
                            await onTranslate()
                        }
                    }
                
                // Action button
                Group {
                    if isTranslating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                    } else {
                        Button(action: {
                            Task {
                                await onTranslate()
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(inputText.isEmpty ? AppTheme.textTertiary : AppTheme.accent)
                        }
                        .disabled(inputText.isEmpty)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.inputBackground)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.3), AppTheme.accent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .shadow(color: AppTheme.accent.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            
            // Results card (if any)
            if let result = result {
                WarpAIResultCard(result: result)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Warp AI Result Card

struct WarpAIResultCard: View {
    let result: NLCommandResponse
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Category badge
                Text(result.category.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(6)
                
                Spacer()
                
                // Confidence stars
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < Int(result.confidence * 5) ? "star.fill" : "star")
                            .font(.system(size: 8))
                            .foregroundColor(i < Int(result.confidence * 5) ? AppTheme.accent : AppTheme.border)
                    }
                }
            }
            
            // Command card
            HStack(spacing: 12) {
                // Execute button
                Button(action: {
                    // Execute command
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.command, forType: .string)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        
                        Text(result.command)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.command, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Explanation
            Text(result.explanation)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Alternatives
            if !result.alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alternatives")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 6) {
                        ForEach(result.alternatives, id: \.self) { alt in
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(alt, forType: .string)
                            }) {
                                Text(alt)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.backgroundTertiary)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Warnings
            if !result.warnings.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text(result.warnings.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background(AppTheme.background)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.border.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Warp AI Input Style

struct WarpAIInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.clear)
            .foregroundColor(AppTheme.textPrimary)
    }
}
