//
//  DSEmptyState.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Empty State Molecule
//

import SwiftUI

/// Empty state display component - Icon + Title + Description + Action
struct DSEmptyState: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            DSIcon(icon, size: .lg, color: AppTheme.textMuted)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Text(description)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                DSButton(variant: .primary) {
                    action()
                } label: {
                    Text(actionTitle)
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Empty State - No Action") {
    DSEmptyState(
        icon: "tray",
        title: "No Items",
        description: "There are no items to display."
    )
    .frame(width: 400, height: 300)
    .background(AppTheme.background)
}

#Preview("Empty State - With Action") {
    DSEmptyState(
        icon: "plus.circle",
        title: "No Commits",
        description: "You haven't made any commits yet. Create your first commit to get started.",
        actionTitle: "Create Commit",
        action: { print("Create commit tapped") }
    )
    .frame(width: 400, height: 300)
    .background(AppTheme.background)
}

#Preview("Empty State - Repository") {
    DSEmptyState(
        icon: "folder",
        title: "No Repository Selected",
        description: "Select or create a repository to start working with Git.",
        actionTitle: "Open Repository",
        action: { print("Open repository tapped") }
    )
    .frame(width: 400, height: 300)
    .background(AppTheme.background)
}
