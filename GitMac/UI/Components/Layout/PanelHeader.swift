//
//  PanelHeader.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

/// Generic reusable panel header component
/// Consolidates duplicate headers from Notion, Linear, Jira, Taiga, and Planner panels
struct PanelHeader<Selector: View, Actions: View>: View {
    let title: String
    let icon: String
    let iconColor: Color

    @ViewBuilder let selector: () -> Selector
    @ViewBuilder let actions: () -> Actions

    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Logo
                Image(systemName: icon)
                    .foregroundColor(iconColor)

                Text(title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)

                // Custom selector
                selector()

                Spacer()

                // Custom actions
                actions()

                // Close button (always present)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }
}

// MARK: - Convenience Initializers

/// Convenience init without selector or actions
extension PanelHeader where Selector == EmptyView, Actions == EmptyView {
    init(
        title: String,
        icon: String,
        iconColor: Color = AppTheme.textPrimary,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.selector = { EmptyView() }
        self.actions = { EmptyView() }
        self.onClose = onClose
    }
}

/// Convenience init with only actions, no selector
extension PanelHeader where Selector == EmptyView {
    init(
        title: String,
        icon: String,
        iconColor: Color = AppTheme.textPrimary,
        @ViewBuilder actions: @escaping () -> Actions,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.selector = { EmptyView() }
        self.actions = actions
        self.onClose = onClose
    }
}

/// Convenience init with only selector, no actions
extension PanelHeader where Actions == EmptyView {
    init(
        title: String,
        icon: String,
        iconColor: Color = AppTheme.textPrimary,
        @ViewBuilder selector: @escaping () -> Selector,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.selector = selector
        self.actions = { EmptyView() }
        self.onClose = onClose
    }
}

// MARK: - Standard Actions Component

/// Standard panel header actions (refresh + settings)
struct PanelHeaderActions: View {
    let onRefresh: (() async -> Void)?
    let onSettings: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let refresh = onRefresh {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(DesignTokens.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textMuted)
            }

            if let settings = onSettings {
                Button(action: settings) {
                    Image(systemName: "gearshape")
                        .font(DesignTokens.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textMuted)
            }
        }
    }
}

// MARK: - Previews

#Preview("Simple Header") {
    PanelHeader(
        title: "Notion",
        icon: "doc.text.fill",
        iconColor: AppTheme.textPrimary,
        onClose: {}
    )
}

#Preview("Header with Actions") {
    PanelHeader(
        title: "Linear",
        icon: "line.3.horizontal",
        iconColor: Color(hex: "5E6AD2"),
        actions: {
            PanelHeaderActions(
                onRefresh: { print("Refresh") },
                onSettings: { print("Settings") }
            )
        },
        onClose: {
            print("Close")
        }
    )
}

#Preview("Header with Selector") {
    PanelHeader(
        title: "Jira",
        icon: "square.grid.2x2",
        iconColor: Color(hex: "0052CC"),
        selector: {
            Picker("", selection: .constant("Project 1")) {
                Text("Project 1").tag("Project 1")
                Text("Project 2").tag("Project 2")
            }
            .frame(maxWidth: 200)
            .labelsHidden()
        },
        onClose: {
            print("Close")
        }
    )
}

#Preview("Full Header") {
    PanelHeader(
        title: "Planner",
        icon: "checklist",
        iconColor: Color(hex: "0078D4")
    ) {
        Picker("", selection: .constant("Plan 1")) {
            Text("Plan 1").tag("Plan 1")
            Text("Plan 2").tag("Plan 2")
        }
        .frame(maxWidth: 200)
        .labelsHidden()
    } actions: {
        PanelHeaderActions(
            onRefresh: { print("Refresh") },
            onSettings: { print("Settings") }
        )
    } onClose: {
        print("Close")
    }
}
