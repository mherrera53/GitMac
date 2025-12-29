//
//  DSSearchField.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Design System Search Input Component
//

import SwiftUI

struct DSSearchField: View {
    let placeholder: String
    @Binding var text: String
    let disabled: Bool
    let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    init(
        placeholder: String = "Search...",
        text: Binding<String>,
        disabled: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.disabled = disabled
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignTokens.Sizing.Icon.md))
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 20)

            // Text field
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.body)
                .foregroundColor(foregroundColor)
                .disabled(disabled)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            // Clear button (only visible when there's text)
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DesignTokens.Sizing.Icon.md))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(backgroundColor)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }

    private var foregroundColor: Color {
        disabled ? AppTheme.textMuted : AppTheme.textPrimary
    }

    private var backgroundColor: Color {
        disabled ? AppTheme.backgroundTertiary : AppTheme.backgroundSecondary
    }

    private var borderColor: Color {
        isFocused ? AppTheme.accent : AppTheme.backgroundTertiary
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.xl) {
        Text("Search Field States")
            .font(DesignTokens.Typography.headline)

        DSSearchField(text: .constant(""))

        DSSearchField(text: .constant("Search query"))

        DSSearchField(
            placeholder: "Find files...",
            text: .constant("Component")
        )

        DSSearchField(
            placeholder: "Disabled",
            text: .constant(""),
            disabled: true
        )

        DSSearchField(
            placeholder: "With submit action",
            text: .constant(""),
            onSubmit: {
                print("Search submitted")
            }
        )
    }
    .padding()
    .frame(width: 300)
}
