//
//  DSHeader.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Header Molecule
//

import SwiftUI

/// Header display component - Title + Subtitle + Actions
struct DSHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @ViewBuilder let actions: () -> Actions

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.actions = actions
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon + Text Content
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let icon = icon {
                    DSIcon(icon, size: .lg, color: AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(title)
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(AppTheme.textPrimary)
                        .fontWeight(.semibold)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // Actions
            actions()
        }
        .padding(DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}

// MARK: - Previews

#Preview("Header - Basic") {
    DSHeader(
        title: "Repository Overview",
        subtitle: "GitMac - main branch"
    )
    .padding()
    .background(AppTheme.background)
}

#Preview("Header - With Icon") {
    DSHeader(
        title: "Commits",
        subtitle: "156 commits in total",
        icon: "clock.arrow.circlepath"
    )
    .padding()
    .background(AppTheme.background)
}

#Preview("Header - With Actions") {
    DSHeader(
        title: "Branches",
        subtitle: "12 local, 8 remote",
        icon: "arrow.triangle.branch"
    ) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DSButton(variant: .ghost, size: .sm) {
                print("Refresh tapped")
            } label: {
                DSIcon("arrow.clockwise", size: .sm)
            }

            DSButton(variant: .primary, size: .sm) {
                print("New branch tapped")
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    DSIcon("plus", size: .sm)
                    Text("New Branch")
                }
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Header - Multiple Actions") {
    DSHeader(
        title: "Pull Requests",
        subtitle: "5 open, 23 closed",
        icon: "arrow.triangle.pull"
    ) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DSButton(variant: .ghost, size: .sm) {
                print("Filter tapped")
            } label: {
                DSIcon("line.3.horizontal.decrease.circle", size: .sm)
            }

            DSButton(variant: .ghost, size: .sm) {
                print("Sort tapped")
            } label: {
                DSIcon("arrow.up.arrow.down", size: .sm)
            }

            DSButton(variant: .primary, size: .sm) {
                print("Create PR tapped")
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    DSIcon("plus", size: .sm)
                    Text("Create PR")
                }
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Header - No Subtitle") {
    DSHeader(
        title: "Settings",
        icon: "gearshape.fill"
    ) {
        DSButton(variant: .ghost, size: .sm) {
            print("Reset tapped")
        } label: {
            Text("Reset")
        }
    }
    .padding()
    .background(AppTheme.background)
}
