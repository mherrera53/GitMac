//
//  DSExpandableItem.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Expandable List Item Molecule
//

import SwiftUI

/// Expandable list item component with collapse/expand functionality
struct DSExpandableItem<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let badge: String?
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool
    @State private var isHovered = false

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        badge: String? = nil,
        isExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.badge = badge
        self._isExpanded = State(initialValue: isExpanded)
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DesignTokens.Spacing.md) {
                // Chevron
                DSIcon(
                    isExpanded ? "chevron.down" : "chevron.right",
                    size: .sm,
                    color: AppTheme.textMuted
                )
                .frame(width: DesignTokens.Size.iconMD)

                // Icon (optional)
                if let icon = icon {
                    DSIcon(icon, size: .md, color: AppTheme.accent)
                }

                // Title + Subtitle
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(title)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .fontWeight(.medium)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                // Badge (optional)
                if let badge = badge {
                    Text(badge)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
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
                withAnimation(DesignTokens.Animation.spring) {
                    isExpanded.toggle()
                }
            }

            // Expandable Content
            if isExpanded {
                content()
                    .padding(.leading, DesignTokens.Spacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Previews

#Preview("Expandable Item - Basic") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSExpandableItem(
            title: "Local Branches",
            badge: "5"
        ) {
            VStack(spacing: 0) {
                DSListItem(title: "main", subtitle: "Current branch")
                DSListItem(title: "develop", subtitle: "Development")
                DSListItem(title: "feature/login", subtitle: "In progress")
                DSListItem(title: "feature/ui-redesign", subtitle: "In progress")
                DSListItem(title: "hotfix/bug-123", subtitle: "Ready to merge")
            }
        }

        DSExpandableItem(
            title: "Remote Branches",
            badge: "3"
        ) {
            VStack(spacing: 0) {
                DSListItem(title: "origin/main", subtitle: "Up to date")
                DSListItem(title: "origin/develop", subtitle: "2 commits ahead")
                DSListItem(title: "origin/staging", subtitle: "1 commit behind")
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Expandable Item - With Icons") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSExpandableItem(
            title: "Modified Files",
            subtitle: "3 files changed",
            icon: "pencil.circle.fill",
            badge: "3",
            isExpanded: true
        ) {
            VStack(spacing: 0) {
                DSListItem(title: "ContentView.swift", subtitle: "12 lines changed") {
                    DSIcon("doc.text.fill", size: .sm, color: AppTheme.fileSwift)
                }
                DSListItem(title: "ViewModel.swift", subtitle: "5 lines changed") {
                    DSIcon("doc.text.fill", size: .sm, color: AppTheme.fileSwift)
                }
                DSListItem(title: "README.md", subtitle: "2 lines changed") {
                    DSIcon("doc.text.fill", size: .sm, color: AppTheme.fileMarkdown)
                }
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }

        DSExpandableItem(
            title: "Staged Files",
            subtitle: "Ready to commit",
            icon: "checkmark.circle.fill",
            badge: "2"
        ) {
            VStack(spacing: 0) {
                DSListItem(title: "AppDelegate.swift", subtitle: "New file") {
                    DSIcon("doc.text.fill", size: .sm, color: AppTheme.fileSwift)
                }
                DSListItem(title: "Config.json", subtitle: "Modified") {
                    DSIcon("doc.text.fill", size: .sm, color: AppTheme.fileJSON)
                }
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Expandable Item - Commits by Author") {
    VStack(spacing: DesignTokens.Spacing.md) {
        DSExpandableItem(
            title: "John Doe",
            subtitle: "Last commit 2 hours ago",
            icon: "person.circle.fill",
            badge: "12",
            isExpanded: true
        ) {
            VStack(spacing: 0) {
                DSListItem(
                    title: "Add authentication system",
                    subtitle: "2 hours ago"
                ) {
                    Circle().fill(AppTheme.success).frame(width: 6, height: 6)
                } trailing: {
                    Text("a3f5b2c")
                        .font(DesignTokens.Typography.commitHash)
                        .foregroundColor(AppTheme.textMuted)
                }

                DSListItem(
                    title: "Update dependencies",
                    subtitle: "5 hours ago"
                ) {
                    Circle().fill(AppTheme.info).frame(width: 6, height: 6)
                } trailing: {
                    Text("d8e91fc")
                        .font(DesignTokens.Typography.commitHash)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }

        DSExpandableItem(
            title: "Jane Smith",
            subtitle: "Last commit yesterday",
            icon: "person.circle.fill",
            badge: "8"
        ) {
            VStack(spacing: 0) {
                DSListItem(
                    title: "Fix critical bug",
                    subtitle: "yesterday"
                ) {
                    Circle().fill(AppTheme.error).frame(width: 6, height: 6)
                } trailing: {
                    Text("c2d4a1b")
                        .font(DesignTokens.Typography.commitHash)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Expandable Item - Interactive") {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.sm) {
            DSExpandableItem(
                title: "Workspace",
                subtitle: "Unstaged changes",
                icon: "folder.fill",
                badge: "7"
            ) {
                VStack(spacing: 0) {
                    ForEach(1..<8) { i in
                        DSListItem(title: "File \(i).swift", subtitle: "Modified")
                    }
                }
                .padding(.top, DesignTokens.Spacing.sm)
            }

            DSExpandableItem(
                title: "Staging Area",
                subtitle: "Ready to commit",
                icon: "tray.fill",
                badge: "3"
            ) {
                VStack(spacing: 0) {
                    ForEach(1..<4) { i in
                        DSListItem(title: "File \(i).swift", subtitle: "Staged")
                    }
                }
                .padding(.top, DesignTokens.Spacing.sm)
            }
        }
        .padding()
    }
    .frame(height: 400)
    .background(AppTheme.background)
}
