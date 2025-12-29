//
//  DSListItem.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: List Item Molecule
//

import SwiftUI

/// Generic list item component - Icon + Title + Subtitle + Trailing content
struct DSListItem<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing
    let action: (() -> Void)?

    @State private var isHovered = false

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
        self.action = action
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            leading()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            trailing()
        }
        .padding(DesignTokens.Spacing.md)
        .background(isHovered ? AppTheme.backgroundSecondary : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fastEasing) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            action?()
        }
    }
}

// MARK: - Previews

#Preview("List Item - Basic") {
    VStack(spacing: 0) {
        DSListItem(
            title: "main",
            subtitle: "Current branch"
        )

        DSListItem(
            title: "develop",
            subtitle: "Development branch"
        )

        DSListItem(
            title: "feature/new-ui",
            subtitle: "Feature branch"
        )
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("List Item - With Icons") {
    VStack(spacing: 0) {
        DSListItem(
            title: "main",
            subtitle: "Last commit 2 hours ago"
        ) {
            DSIcon("arrow.triangle.branch", size: .md, color: AppTheme.success)
        } trailing: {
            DSIcon("checkmark.circle.fill", size: .sm, color: AppTheme.success)
        }

        DSListItem(
            title: "feature/login",
            subtitle: "Last commit yesterday"
        ) {
            DSIcon("arrow.triangle.branch", size: .md, color: AppTheme.accent)
        } trailing: {
            DSIcon("clock", size: .sm, color: AppTheme.textMuted)
        }

        DSListItem(
            title: "hotfix/critical-bug",
            subtitle: "Last commit 5 days ago"
        ) {
            DSIcon("arrow.triangle.branch", size: .md, color: AppTheme.error)
        } trailing: {
            DSIcon("exclamationmark.triangle.fill", size: .sm, color: AppTheme.warning)
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("List Item - With Actions") {
    VStack(spacing: 0) {
        DSListItem(
            title: "README.md",
            subtitle: "Modified 2 minutes ago"
        ) {
            DSIcon("doc.text.fill", size: .md, color: AppTheme.fileMarkdown)
        } trailing: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                DSStatusBadge("M", variant: .warning, size: .sm)
                DSIcon("chevron.right", size: .sm, color: AppTheme.textMuted)
            }
        } action: {
            print("README.md tapped")
        }

        DSListItem(
            title: "src/main.swift",
            subtitle: "Added to staging"
        ) {
            DSIcon("doc.text.fill", size: .md, color: AppTheme.fileSwift)
        } trailing: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                DSStatusBadge("A", variant: .success, size: .sm)
                DSIcon("chevron.right", size: .sm, color: AppTheme.textMuted)
            }
        } action: {
            print("main.swift tapped")
        }

        DSListItem(
            title: "old-file.txt",
            subtitle: "Deleted"
        ) {
            DSIcon("doc.text.fill", size: .md, color: AppTheme.textMuted)
        } trailing: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                DSStatusBadge("D", variant: .error, size: .sm)
                DSIcon("chevron.right", size: .sm, color: AppTheme.textMuted)
            }
        } action: {
            print("old-file.txt tapped")
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("List Item - Commits") {
    VStack(spacing: 0) {
        DSListItem(
            title: "Add new authentication system",
            subtitle: "John Doe - 2 hours ago"
        ) {
            Circle()
                .fill(AppTheme.success)
                .frame(width: 8, height: 8)
        } trailing: {
            Text("a3f5b2c")
                .font(DesignTokens.Typography.commitHash)
                .foregroundColor(AppTheme.textMuted)
        } action: {
            print("Commit tapped")
        }

        DSListItem(
            title: "Fix login bug in production",
            subtitle: "Jane Smith - yesterday"
        ) {
            Circle()
                .fill(AppTheme.error)
                .frame(width: 8, height: 8)
        } trailing: {
            Text("d8e91fc")
                .font(DesignTokens.Typography.commitHash)
                .foregroundColor(AppTheme.textMuted)
        } action: {
            print("Commit tapped")
        }
    }
    .padding()
    .background(AppTheme.background)
}
