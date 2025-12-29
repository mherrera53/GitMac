//
//  DSToggle.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Design System Toggle Component with Auto-styling
//

import SwiftUI

enum DSToggleStyle {
    case checkbox
    case `switch`
    case button
}

struct DSToggle: View {
    let label: String
    @Binding var isOn: Bool
    let style: DSToggleStyle
    let disabled: Bool

    init(
        _ label: String,
        isOn: Binding<Bool>,
        style: DSToggleStyle = .switch,
        disabled: Bool = false
    ) {
        self.label = label
        self._isOn = isOn
        self.style = style
        self.disabled = disabled
    }

    var body: some View {
        Group {
            switch style {
            case .checkbox:
                checkboxToggle
            case .switch:
                switchToggle
            case .button:
                buttonToggle
            }
        }
        .disabled(disabled)
        .opacity(disabled ? DesignTokens.Opacity.disabled : 1.0)
    }

    @ViewBuilder
    private var checkboxToggle: some View {
        Button(action: {
            isOn.toggle()
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .stroke(borderColor, lineWidth: 1)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                .fill(isOn ? AppTheme.accent : Color.clear)
                        )

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.buttonTextOnColor)
                    }
                }

                Text(label)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var switchToggle: some View {
        HStack {
            Text(label)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var buttonToggle: some View {
        Button(action: {
            isOn.toggle()
        }) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DesignTokens.Sizing.Icon.md))
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: DesignTokens.Sizing.Icon.md))
                }

                Text(label)
                    .font(DesignTokens.Typography.body)
            }
            .foregroundColor(isOn ? AppTheme.buttonTextOnColor : AppTheme.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isOn ? AppTheme.accent : AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(isOn ? Color.clear : AppTheme.backgroundTertiary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var borderColor: Color {
        isOn ? AppTheme.accent : AppTheme.backgroundTertiary
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.xl) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Checkbox Style")
                .font(DesignTokens.Typography.headline)

            DSToggle("Enable notifications", isOn: .constant(true), style: .checkbox)
            DSToggle("Dark mode", isOn: .constant(false), style: .checkbox)
            DSToggle("Disabled", isOn: .constant(false), style: .checkbox, disabled: true)
        }

        Divider()

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Switch Style")
                .font(DesignTokens.Typography.headline)

            DSToggle("Auto-save", isOn: .constant(true), style: .switch)
            DSToggle("Show hidden files", isOn: .constant(false), style: .switch)
            DSToggle("Disabled", isOn: .constant(true), style: .switch, disabled: true)
        }

        Divider()

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Button Style")
                .font(DesignTokens.Typography.headline)

            DSToggle("Feature enabled", isOn: .constant(true), style: .button)
            DSToggle("Feature disabled", isOn: .constant(false), style: .button)
            DSToggle("Disabled", isOn: .constant(false), style: .button, disabled: true)
        }
    }
    .padding()
    .frame(width: 300)
}
