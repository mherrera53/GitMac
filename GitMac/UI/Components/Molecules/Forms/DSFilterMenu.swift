//
//  DSFilterMenu.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Filter Menu Molecule
//  Combines Filter Button + Dropdown Menu with Options
//

import SwiftUI

/// Filter option model for menu items
struct DSFilterOption: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let icon: String?
    let value: String

    init(label: String, icon: String? = nil, value: String? = nil) {
        self.label = label
        self.icon = icon
        self.value = value ?? label
    }
}

/// Filter menu molecule with dropdown selection
/// Provides filtering functionality with visual feedback
struct DSFilterMenu: View {
    let label: String
    @Binding var selectedFilter: String?
    let options: [DSFilterOption]
    let showBadge: Bool

    @State private var isExpanded = false

    init(
        label: String = "Filter",
        selectedFilter: Binding<String?>,
        options: [DSFilterOption],
        showBadge: Bool = true
    ) {
        self.label = label
        self._selectedFilter = selectedFilter
        self.options = options
        self.showBadge = showBadge
    }

    var body: some View {
        Menu {
            // Clear filter option
            if selectedFilter != nil {
                Button {
                    selectedFilter = nil
                } label: {
                    Label("Clear Filter", systemImage: "xmark.circle")
                }
                Divider()
            }

            // Filter options
            ForEach(options) { option in
                Button {
                    selectedFilter = option.value
                } label: {
                    HStack {
                        if let icon = option.icon {
                            Image(systemName: icon)
                        }
                        Text(option.label)

                        Spacer()

                        if selectedFilter == option.value {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Filter icon
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: DesignTokens.Size.iconMD))

                // Label
                Text(selectedFilterLabel)
                    .font(DesignTokens.Typography.callout)

                // Badge indicator
                if showBadge && selectedFilter != nil {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 6, height: 6)
                }

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: DesignTokens.Size.iconSM))
                    .foregroundColor(AppTheme.textMuted)
            }
            .foregroundColor(selectedFilter != nil ? AppTheme.accent : AppTheme.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                selectedFilter != nil
                    ? AppTheme.accent.opacity(0.1)
                    : AppTheme.backgroundSecondary
            )
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(
                        selectedFilter != nil ? AppTheme.accent : AppTheme.backgroundTertiary,
                        lineWidth: 1
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var selectedFilterLabel: String {
        if let selected = selectedFilter,
           let option = options.first(where: { $0.value == selected }) {
            return option.label
        }
        return label
    }
}

// MARK: - Previews

#Preview("Filter Menu States") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        Text("No Filter Selected")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textMuted)
        DSFilterMenu(
            selectedFilter: .constant(nil),
            options: [
                DSFilterOption(label: "All", icon: "circle", value: "all"),
                DSFilterOption(label: "Active", icon: "circle.fill", value: "active"),
                DSFilterOption(label: "Archived", icon: "archivebox", value: "archived")
            ]
        )

        Text("Filter Selected")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textMuted)
        DSFilterMenu(
            selectedFilter: .constant("active"),
            options: [
                DSFilterOption(label: "All", icon: "circle", value: "all"),
                DSFilterOption(label: "Active", icon: "circle.fill", value: "active"),
                DSFilterOption(label: "Archived", icon: "archivebox", value: "archived")
            ]
        )

        Text("Without Badge")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textMuted)
        DSFilterMenu(
            selectedFilter: .constant("active"),
            options: [
                DSFilterOption(label: "All", icon: "circle", value: "all"),
                DSFilterOption(label: "Active", icon: "circle.fill", value: "active")
            ],
            showBadge: false
        )
    }
    .padding()
    .frame(width: 300)
}

#Preview("Git Context Examples") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Branch Filter")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSFilterMenu(
                label: "Branch Type",
                selectedFilter: .constant(nil),
                options: [
                    DSFilterOption(label: "All Branches", icon: "arrow.triangle.branch", value: "all"),
                    DSFilterOption(label: "Local", icon: "laptopcomputer", value: "local"),
                    DSFilterOption(label: "Remote", icon: "cloud", value: "remote"),
                    DSFilterOption(label: "Stale", icon: "clock", value: "stale")
                ]
            )
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Commit Filter")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSFilterMenu(
                label: "Commit Type",
                selectedFilter: .constant("feat"),
                options: [
                    DSFilterOption(label: "All Commits", icon: "circle.grid.3x3", value: "all"),
                    DSFilterOption(label: "Features", icon: "star", value: "feat"),
                    DSFilterOption(label: "Bug Fixes", icon: "ladybug", value: "fix"),
                    DSFilterOption(label: "Refactors", icon: "arrow.triangle.2.circlepath", value: "refactor")
                ]
            )
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("File Status Filter")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSFilterMenu(
                label: "Status",
                selectedFilter: .constant("modified"),
                options: [
                    DSFilterOption(label: "All Files", icon: "doc", value: "all"),
                    DSFilterOption(label: "Modified", icon: "pencil", value: "modified"),
                    DSFilterOption(label: "Added", icon: "plus.circle", value: "added"),
                    DSFilterOption(label: "Deleted", icon: "trash", value: "deleted"),
                    DSFilterOption(label: "Untracked", icon: "questionmark.circle", value: "untracked")
                ]
            )
        }
    }
    .padding()
    .frame(width: 400)
}
