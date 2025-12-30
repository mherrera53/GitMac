//
//  DSTextField.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Design System Text Input Component
//

import SwiftUI

enum DSTextFieldState {
    case normal, focused, error, disabled
}

struct DSTextField: View {
    let placeholder: String
    @Binding var text: String
    let state: DSTextFieldState
    let errorMessage: String?

    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        state: DSTextFieldState = .normal,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.state = state
        self.errorMessage = errorMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(placeholderColor)
                        .padding(.leading, DesignTokens.Spacing.sm)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(foregroundColor)
                    .padding(DesignTokens.Spacing.sm)
            }
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
            .disabled(state == .disabled)
            .focused($isFocused)

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

    private var placeholderColor: Color {
        state == .disabled ? AppTheme.textMuted.opacity(0.5) : AppTheme.textMuted
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
        DSTextField(placeholder: "Normal", text: .constant(""))
        DSTextField(placeholder: "With text", text: .constant("Hello"))
        DSTextField(placeholder: "Error", text: .constant(""), state: .error, errorMessage: "This field is required")
        DSTextField(placeholder: "Disabled", text: .constant(""), state: .disabled)
    }
    .padding()
    .frame(width: 300)
}
