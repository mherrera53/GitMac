//
//  TerminalNLInputView.swift
//  GitMac
//
//  Natural Language Terminal Input View
//  Warp AI-style command translation interface
//

import SwiftUI

// MARK: - Natural Language Input View

struct TerminalNLInputView: View {
    @StateObject private var nlService = TerminalNLTranslationService.shared
    @Binding var selectedCommand: String?
    @State private var inputText: String = ""
    @State private var isTranslating = false
    @State private var translationResult: NLCommandResponse?
    @State private var showingAlternatives = false
    @State private var showingExplanation = false
    
    let context: NLContext
    let onExecute: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Input header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppTheme.accent)
                    .font(.system(size: 16, weight: .medium))
                
                Text("AI Command")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                if isTranslating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Input field
            HStack(spacing: 8) {
                TextField(
                    "Describe what you want to do...",
                    text: $inputText,
                    axis: .vertical
                )
                .textFieldStyle(NLTextFieldStyle())
                .onSubmit {
                    Task {
                        await translateInput()
                    }
                }
                
                // Translate button
                Button(action: {
                    Task {
                        await translateInput()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(inputText.isEmpty ? AppTheme.textTertiary : AppTheme.accent)
                }
                .disabled(inputText.isEmpty || isTranslating)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            
            // Translation result
            if let result = translationResult {
                translationResultView(result)
            }
        }
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Translation Result View
    
    @ViewBuilder
    private func translationResultView(_ result: NLCommandResponse) -> some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
                .padding(.horizontal, 12)
            
            // Main result
            VStack(alignment: .leading, spacing: 8) {
                // Command with execute button
                HStack(spacing: 8) {
                    Button(action: {
                        selectedCommand = result.command
                        onExecute(result.command)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 12, weight: .medium))
                            
                            Text(result.command)
                                .font(.system(size: 13, weight: .medium, family: .monospaced))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Category badge
                    Text(result.category.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(4)
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(Double(index) < result.confidence * 5 ? AppTheme.accent : AppTheme.border)
                        }
                    }
                }
                
                // Explanation
                Text(result.explanation)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Warnings
                if !result.warnings.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.warning)
                            .font(.system(size: 12))
                        
                        Text(result.warnings.joined(separator: " "))
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.warning)
                    }
                    .padding(.top, 4)
                }
                
                // Alternatives button
                if !result.alternatives.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingAlternatives.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showingAlternatives ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                            
                            Text("Alternatives (\(result.alternatives.count))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                    
                    if showingAlternatives {
                        alternativesView(result.alternatives)
                    }
                }
                
                // Actions
                HStack(spacing: 12) {
                    // Copy command
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.command, forType: .string)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                            Text("Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Explain command
                    Button(action: {
                        Task {
                            await explainCommand(result.command)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("Explain")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(12)
            
            // Explanation view
            if showingExplanation {
                explanationView()
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Alternatives View
    
    @ViewBuilder
    private func alternativesView(_ alternatives: [String]) -> some View {
        VStack(spacing: 4) {
            ForEach(alternatives, id: \.self) { alternative in
                Button(action: {
                    selectedCommand = alternative
                    onExecute(alternative)
                }) {
                    HStack {
                        Image(systemName: "terminal")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textTertiary)
                        
                        Text(alternative)
                            .font(.system(size: 12, family: .monospaced))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Explanation View
    
    @ViewBuilder
    private func explanationView() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
                .padding(.horizontal, 12)
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppTheme.accent)
                    .font(.system(size: 14))
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command Explanation")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // This would be populated by the explanation service
                    Text("Loading explanation...")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .opacity(0.7)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingExplanation = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
        }
    }
    
    // MARK: - Methods
    
    private func translateInput() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isTranslating = true
        translationResult = nil
        
        do {
            let result = try await nlService.translateToCommand(
                input: inputText,
                context: context
            )
            
            withAnimation(.easeInOut(duration: 0.3)) {
                translationResult = result
            }
        } catch {
            print("❌ Translation failed: \(error.localizedDescription)")
            // Could show error state here
        }
        
        isTranslating = false
    }
    
    private func explainCommand(_ command: String) async {
        showingExplanation = true
        
        do {
            let explanation = try await nlService.explainCommand(command, context: context)
            // Update the explanation view with the result
            // This would require state management to update the view
        } catch {
            print("❌ Explanation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Custom Text Field Style

struct NLTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.background)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

// MARK: - Preview

#if DEBUG
struct TerminalNLInputView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalNLInputView(
            selectedCommand: .constant(nil),
            context: NLContext(
                workingDirectory: "/Users/mario/Sites/localhost/GitMac",
                gitBranch: "main",
                recentCommands: ["git status", "git add .", "git commit -m 'test'"],
                environment: [:],
                osType: "macOS"
            ),
            onExecute: { command in
                print("Execute: \(command)")
            }
        )
        .padding()
        .frame(width: 400)
        .previewDisplayName("Natural Language Input")
    }
}
#endif
