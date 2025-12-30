//
//  XcodeToolbarButton.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Xcode-style toolbar button using DesignTokens
//

import SwiftUI

/// Xcode-style toolbar button with icon-only and icon+label variants
struct XcodeToolbarButton: View {
    let icon: String
    let label: String?
    let color: Color?
    let action: () -> Void
    let isEnabled: Bool

    @State private var isHovered = false
    @State private var isPressed = false

    /// Icon-only button
    init(
        icon: String,
        color: Color? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = nil
        self.color = color
        self.isEnabled = isEnabled
        self.action = action
    }

    /// Icon + label button
    init(
        icon: String,
        label: String,
        color: Color? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.color = color
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            if let label = label {
                // Icon + label variant
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))

                    Text(label)
                        .font(.system(size: DesignTokens.Toolbar.labelSize, weight: .regular))
                }
                .foregroundColor(buttonColor)
                .frame(
                    width: DesignTokens.Toolbar.iconLabelButtonSize.width,
                    height: DesignTokens.Toolbar.iconLabelButtonSize.height
                )
                .background(backgroundColor)
                .cornerRadius(DesignTokens.CornerRadius.sm)
            } else {
                // Icon-only variant
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))
                    .foregroundColor(buttonColor)
                    .frame(
                        width: DesignTokens.Toolbar.iconOnlyButtonSize.width,
                        height: DesignTokens.Toolbar.iconOnlyButtonSize.height
                    )
                    .background(backgroundColor)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity(isEnabled ? 1.0 : DesignTokens.Opacity.disabled)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    private var buttonColor: Color {
        if !isEnabled {
            return AppTheme.textSecondary
        }
        return color ?? AppTheme.textPrimary
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return Color.clear
        }
        if isHovered {
            return AppTheme.hover
        }
        return Color.clear
    }
}

// MARK: - Async Variant

/// Xcode-style toolbar button with async action support
struct XcodeToolbarButtonAsync: View {
    let icon: String
    let label: String?
    let color: Color?
    let action: () async -> Void
    let isEnabled: Bool

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var isLoading = false

    /// Icon-only button with async action
    init(
        icon: String,
        color: Color? = nil,
        isEnabled: Bool = true,
        action: @escaping () async -> Void
    ) {
        self.icon = icon
        self.label = nil
        self.color = color
        self.isEnabled = isEnabled
        self.action = action
    }

    /// Icon + label button with async action
    init(
        icon: String,
        label: String,
        color: Color? = nil,
        isEnabled: Bool = true,
        action: @escaping () async -> Void
    ) {
        self.icon = icon
        self.label = label
        self.color = color
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                Task {
                    isLoading = true
                    await action()
                    isLoading = false
                }
            }
        }) {
            if let label = label {
                // Icon + label variant
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(height: DesignTokens.Toolbar.iconSize)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))
                    }

                    Text(label)
                        .font(.system(size: DesignTokens.Toolbar.labelSize, weight: .regular))
                }
                .foregroundColor(buttonColor)
                .frame(
                    width: DesignTokens.Toolbar.iconLabelButtonSize.width,
                    height: DesignTokens.Toolbar.iconLabelButtonSize.height
                )
                .background(backgroundColor)
                .cornerRadius(DesignTokens.CornerRadius.sm)
            } else {
                // Icon-only variant
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: DesignTokens.Toolbar.iconSize, weight: .regular))
                    }
                }
                .foregroundColor(buttonColor)
                .frame(
                    width: DesignTokens.Toolbar.iconOnlyButtonSize.width,
                    height: DesignTokens.Toolbar.iconOnlyButtonSize.height
                )
                .background(backgroundColor)
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity((isEnabled && !isLoading) ? 1.0 : DesignTokens.Opacity.disabled)
        .disabled(!isEnabled || isLoading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed && !isLoading {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    private var buttonColor: Color {
        if !isEnabled || isLoading {
            return AppTheme.textSecondary
        }
        return color ?? AppTheme.textPrimary
    }

    private var backgroundColor: Color {
        if !isEnabled || isLoading {
            return Color.clear
        }
        if isHovered {
            return AppTheme.hover
        }
        return Color.clear
    }
}

// MARK: - Preview

#Preview("Toolbar Buttons") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            XcodeToolbarButton(icon: "arrow.uturn.backward") { }
            XcodeToolbarButton(icon: "arrow.uturn.forward") { }
            XcodeToolbarButton(icon: "arrow.down.circle", color: AppTheme.info) { }
            XcodeToolbarButton(icon: "arrow.up.circle.fill", color: AppTheme.accent) { }
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            XcodeToolbarButton(icon: "terminal.fill", label: "Terminal") { }
            XcodeToolbarButton(icon: "tag.fill", label: "Taiga", color: AppTheme.success) { }
            XcodeToolbarButton(icon: "checklist", label: "Planner", color: AppTheme.warning) { }
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            XcodeToolbarButton(icon: "arrow.down.circle", isEnabled: false) { }
            XcodeToolbarButtonAsync(icon: "arrow.down.circle.fill", color: AppTheme.success) { }
        }
    }
    .padding()
    .frame(height: DesignTokens.Toolbar.height)
    .background(VisualEffectBlur.toolbar)
}
