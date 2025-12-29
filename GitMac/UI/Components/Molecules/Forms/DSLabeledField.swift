//
//  DSLabeledField.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Labeled Field Molecule
//  Combines Label + Input + Error Message
//

import SwiftUI

/// Labeled text field molecule that combines label, text field, and error display
/// Provides a complete form field experience with validation feedback
struct DSLabeledField: View {
    let label: String
    let isRequired: Bool
    @Binding var text: String
    let placeholder: String
    let errorMessage: String?
    let isSecure: Bool

    init(
        label: String,
        isRequired: Bool = false,
        text: Binding<String>,
        placeholder: String = "",
        errorMessage: String? = nil,
        isSecure: Bool = false
    ) {
        self.label = label
        self.isRequired = isRequired
        self._text = text
        self.placeholder = placeholder
        self.errorMessage = errorMessage
        self.isSecure = isSecure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Label with optional required indicator
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Text(label)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.textPrimary)

                if isRequired {
                    Text("*")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.error)
                }
            }

            // Text field with error state
            if isSecure {
                DSSecureField(
                    placeholder: placeholder,
                    text: $text,
                    state: errorMessage != nil ? .error : .normal,
                    errorMessage: errorMessage
                )
            } else {
                DSTextField(
                    placeholder: placeholder,
                    text: $text,
                    state: errorMessage != nil ? .error : .normal,
                    errorMessage: errorMessage
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Normal Fields") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        DSLabeledField(
            label: "Email",
            isRequired: true,
            text: .constant(""),
            placeholder: "Enter your email"
        )

        DSLabeledField(
            label: "Username",
            text: .constant("johndoe"),
            placeholder: "Enter username"
        )

        DSLabeledField(
            label: "Repository Name",
            isRequired: true,
            text: .constant(""),
            placeholder: "my-awesome-project"
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Error States") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        DSLabeledField(
            label: "Email",
            isRequired: true,
            text: .constant("invalid"),
            placeholder: "Enter your email",
            errorMessage: "Please enter a valid email address"
        )

        DSLabeledField(
            label: "Password",
            isRequired: true,
            text: .constant(""),
            placeholder: "Enter password",
            errorMessage: "Password is required",
            isSecure: true
        )

        DSLabeledField(
            label: "Commit Message",
            isRequired: true,
            text: .constant(""),
            placeholder: "Describe your changes",
            errorMessage: "Commit message cannot be empty"
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Secure Field") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        DSLabeledField(
            label: "Password",
            isRequired: true,
            text: .constant(""),
            placeholder: "Enter password",
            isSecure: true
        )

        DSLabeledField(
            label: "Confirm Password",
            isRequired: true,
            text: .constant(""),
            placeholder: "Re-enter password",
            isSecure: true
        )
    }
    .padding()
    .frame(width: 400)
}
