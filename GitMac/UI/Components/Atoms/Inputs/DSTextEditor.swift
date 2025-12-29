//
//  DSTextEditor.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Design System Multi-line Text Editor Component
//

import SwiftUI

struct DSTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let state: DSTextFieldState
    let errorMessage: String?
    let minHeight: CGFloat

    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        state: DSTextFieldState = .normal,
        errorMessage: String? = nil,
        minHeight: CGFloat = 100
    ) {
        self.placeholder = placeholder
        self._text = text
        self.state = state
        self.errorMessage = errorMessage
        self.minHeight = minHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.sm + 2)
                }

                // Text Editor
                TextEditor(text: $text)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(foregroundColor)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(DesignTokens.Spacing.xs)
                    .disabled(state == .disabled)
                    .focused($isFocused)
            }
            .frame(minHeight: minHeight)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(borderColor, lineWidth: 1)
            )

            if let error = errorMessage, state == .error {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.error)
            }
        }
    }

    private var foregroundColor: Color {
        state == .disabled ? AppTheme.textMuted : AppTheme.textPrimary
    }

    private var backgroundColor: Color {
        state == .disabled ? AppTheme.backgroundTertiary : AppTheme.backgroundSecondary
    }

    private var borderColor: Color {
        switch state {
        case .normal:
            return isFocused ? AppTheme.accent : AppTheme.backgroundTertiary
        case .focused:
            return AppTheme.accent
        case .error:
            return AppTheme.error
        case .disabled:
            return AppTheme.backgroundTertiary
        }
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSTextEditor(placeholder: "Enter your message...", text: .constant(""))
        DSTextEditor(
            placeholder: "With text",
            text: .constant("This is a multi-line\ntext editor component\nwith multiple lines.")
        )
        DSTextEditor(
            placeholder: "Error state",
            text: .constant(""),
            state: .error,
            errorMessage: "Message cannot be empty"
        )
        DSTextEditor(
            placeholder: "Disabled",
            text: .constant("Cannot edit this"),
            state: .disabled,
            minHeight: 80
        )
    }
    .padding()
    .frame(width: 400)
}
