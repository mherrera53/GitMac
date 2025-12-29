//
//  DSActionBar.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Action Bar Molecule
//  Horizontal Button Group for Form Actions
//

import SwiftUI

/// Action bar alignment options
enum DSActionBarAlignment {
    case leading
    case trailing
    case center
    case spaceBetween
}

/// Action item model for button configuration
struct DSActionItem: Identifiable {
    let id = UUID()
    let label: String
    let icon: String?
    let variant: DSButtonVariant
    let isDestructive: Bool
    let action: () async -> Void

    init(
        label: String,
        icon: String? = nil,
        variant: DSButtonVariant = .secondary,
        isDestructive: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.label = label
        self.icon = icon
        self.variant = variant
        self.isDestructive = isDestructive
        self.action = action
    }
}

/// Action bar molecule with horizontal button layout
/// Provides consistent spacing and alignment for form actions
struct DSActionBar: View {
    let actions: [DSActionItem]
    let alignment: DSActionBarAlignment
    let spacing: CGFloat

    init(
        actions: [DSActionItem],
        alignment: DSActionBarAlignment = .trailing,
        spacing: CGFloat = DesignTokens.Spacing.sm
    ) {
        self.actions = actions
        self.alignment = alignment
        self.spacing = spacing
    }

    var body: some View {
        Group {
            switch alignment {
            case .leading:
                HStack(spacing: spacing) {
                    actionButtons
                    Spacer()
                }
            case .trailing:
                HStack(spacing: spacing) {
                    Spacer()
                    actionButtons
                }
            case .center:
                HStack(spacing: spacing) {
                    Spacer()
                    actionButtons
                    Spacer()
                }
            case .spaceBetween:
                HStack(spacing: spacing) {
                    actionButtons
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.background)
    }

    @ViewBuilder
    private var actionButtons: some View {
        ForEach(actions) { action in
            DSButton(
                variant: action.isDestructive ? .danger : action.variant,
                size: .md,
                action: action.action
            ) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let icon = action.icon {
                        Image(systemName: icon)
                            .font(.system(size: DesignTokens.Size.iconMD))
                    }
                    Text(action.label)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Action Bar Alignments") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Leading Alignment")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {},
                    DSActionItem(label: "Save", variant: .primary) {}
                ],
                alignment: .leading
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Trailing Alignment (Default)")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {},
                    DSActionItem(label: "Save", variant: .primary) {}
                ],
                alignment: .trailing
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Center Alignment")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {},
                    DSActionItem(label: "Save", variant: .primary) {}
                ],
                alignment: .center
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Space Between")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {},
                    DSActionItem(label: "Save", variant: .primary) {}
                ],
                alignment: .spaceBetween
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
    .padding()
}

#Preview("Action Bar Variants") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Single Action")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Save Changes", icon: "checkmark", variant: .primary) {}
                ]
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Two Actions")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {},
                    DSActionItem(label: "Confirm", icon: "checkmark", variant: .primary) {}
                ]
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Multiple Actions with Icons")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", icon: "xmark", variant: .ghost) {},
                    DSActionItem(label: "Save Draft", icon: "doc", variant: .secondary) {},
                    DSActionItem(label: "Publish", icon: "paperplane", variant: .primary) {}
                ]
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Destructive Action")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {},
                    DSActionItem(label: "Delete", icon: "trash", isDestructive: true) {}
                ]
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
    .padding()
}

#Preview("Git Context Examples") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Commit Actions")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {
                        print("Cancel commit")
                    },
                    DSActionItem(label: "Commit & Push", icon: "arrow.up.circle", variant: .primary) {
                        print("Commit and push")
                    }
                ]
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Branch Actions")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {
                        print("Cancel")
                    },
                    DSActionItem(label: "Create Branch", icon: "arrow.triangle.branch", variant: .primary) {
                        print("Create branch")
                    }
                ]
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Merge Actions")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {
                        print("Cancel")
                    },
                    DSActionItem(label: "Abort Merge", icon: "xmark.circle", isDestructive: true) {
                        print("Abort merge")
                    },
                    DSActionItem(label: "Complete Merge", icon: "checkmark.circle", variant: .primary) {
                        print("Complete merge")
                    }
                ],
                alignment: .spaceBetween
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Stash Actions")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSActionBar(
                actions: [
                    DSActionItem(label: "Cancel", variant: .ghost) {
                        print("Cancel")
                    },
                    DSActionItem(label: "Stash Changes", icon: "archivebox", variant: .primary) {
                        print("Stash changes")
                    }
                ]
            )
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
    .padding()
}
