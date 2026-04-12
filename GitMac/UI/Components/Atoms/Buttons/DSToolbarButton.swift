//
//  DSToolbarButton.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 2: Toolbar Button Atom
//

import SwiftUI

/// Toolbar toggle button with active state
struct DSToolbarButton: View {
    let iconName: String
    let tooltip: String
    let isActive: Bool
    let isDisabled: Bool
    let action: () async -> Void

    @State private var isLoading = false
    @State private var isHovered = false

    init(
        iconName: String,
        tooltip: String = "",
        isActive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.iconName = iconName
        self.tooltip = tooltip
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button {
            guard !isLoading && !isDisabled else { return }
            isLoading = true  // Set immediately to prevent double-clicks
            Task {
                await action()
                isLoading = false
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: DesignTokens.Size.iconMD))
                }
            }
            .frame(width: DesignTokens.Size.buttonHeightMD, height: DesignTokens.Size.buttonHeightMD)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(borderColor, lineWidth: isActive ? 1.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltip)
    }

    // MARK: - Colors

    private var foregroundColor: Color {
        if isDisabled {
            return AppTheme.textMuted
        }

        if isActive {
            return AppTheme.accent
        }

        return isHovered ? AppTheme.textPrimary : AppTheme.textSecondary
    }

    private var backgroundColor: Color {
        if isDisabled {
            return Color.clear
        }

        if isActive {
            return AppTheme.accent.opacity(0.1)
        }

        return isHovered ? AppTheme.backgroundSecondary.opacity(0.5) : Color.clear
    }

    private var borderColor: Color {
        isActive ? AppTheme.accent : Color.clear
    }
}

// MARK: - Previews

#Preview("Toolbar Buttons") {
    HStack(spacing: DesignTokens.Spacing.sm) {
        DSToolbarButton(iconName: "sidebar.left", tooltip: "Toggle Sidebar") {
            Logger.debug("Sidebar clicked")
        }

        DSToolbarButton(iconName: "list.bullet", tooltip: "List View", isActive: true) {
            Logger.debug("List clicked")
        }

        DSToolbarButton(iconName: "square.grid.2x2", tooltip: "Grid View") {
            Logger.debug("Grid clicked")
        }

        DSToolbarButton(iconName: "gearshape", tooltip: "Settings", isDisabled: true) {
            Logger.debug("Settings clicked")
        }
    }
    .padding()
}

#Preview("Toolbar States") {
    VStack(spacing: DesignTokens.Spacing.md) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text("Normal:")
                .font(DesignTokens.Typography.body)
            DSToolbarButton(iconName: "star") {
                Logger.debug("Normal clicked")
            }
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            Text("Active:")
                .font(DesignTokens.Typography.body)
            DSToolbarButton(iconName: "star", isActive: true) {
                Logger.debug("Active clicked")
            }
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            Text("Disabled:")
                .font(DesignTokens.Typography.body)
            DSToolbarButton(iconName: "star", isDisabled: true) {
                Logger.debug("Disabled clicked")
            }
        }
    }
    .padding()
}

#Preview("Toolbar Group") {
    HStack(spacing: DesignTokens.Spacing.xs) {
        DSToolbarButton(iconName: "arrow.left", tooltip: "Back") {
            Logger.debug("Back")
        }

        DSToolbarButton(iconName: "arrow.right", tooltip: "Forward") {
            Logger.debug("Forward")
        }

        Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1, height: DesignTokens.Size.buttonHeightMD)

        DSToolbarButton(iconName: "arrow.clockwise", tooltip: "Refresh") {
            Logger.debug("Refresh")
        }

        Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1, height: DesignTokens.Size.buttonHeightMD)

        DSToolbarButton(iconName: "magnifyingglass", tooltip: "Search") {
            Logger.debug("Search")
        }
    }
    .padding()
}
