//
//  DSSecureField.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Design System Secure Password Input Component
//

import SwiftUI

struct DSSecureField: View {
    let placeholder: String
    @Binding var text: String
    let state: DSTextFieldState
    let errorMessage: String?

    @State private var isPasswordVisible = false
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
            HStack(spacing: 0) {
                Group {
                    if isPasswordVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.body)
                .foregroundColor(foregroundColor)
                .disabled(state == .disabled)
                .focused($isFocused)

                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: DesignTokens.Sizing.Icon.md))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(state == .disabled)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.sm)
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
        DSSecureField(placeholder: "Password", text: .constant(""))
        DSSecureField(placeholder: "With password", text: .constant("secret123"))
        DSSecureField(placeholder: "Error", text: .constant(""), state: .error, errorMessage: "Password is required")
        DSSecureField(placeholder: "Disabled", text: .constant("disabled"), state: .disabled)
    }
    .padding()
    .frame(width: 300)
}
