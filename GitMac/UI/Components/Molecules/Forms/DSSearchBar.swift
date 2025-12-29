//
//  DSSearchBar.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Search Bar Molecule
//  Combines Search Field + Optional Filter Button
//

import SwiftUI

/// Search bar molecule with integrated search field and optional filter button
/// Provides a complete search experience with optional filtering capabilities
struct DSSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let showFilterButton: Bool
    let onFilterTap: (() -> Void)?
    let onSubmit: (() -> Void)?

    init(
        searchText: Binding<String>,
        placeholder: String = "Search...",
        showFilterButton: Bool = false,
        onFilterTap: (() -> Void)? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.showFilterButton = showFilterButton
        self.onFilterTap = onFilterTap
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Search field atom
            DSSearchField(
                placeholder: placeholder,
                text: $searchText,
                onSubmit: onSubmit
            )

            // Filter button (optional)
            if showFilterButton {
                DSIconButton(
                    iconName: "line.3.horizontal.decrease.circle",
                    variant: .ghost,
                    size: .md
                ) {
                    onFilterTap?()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Search Bar States") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        Text("Empty State")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textMuted)
        DSSearchBar(
            searchText: .constant("")
        )

        Text("With Text")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textMuted)
        DSSearchBar(
            searchText: .constant("git commit")
        )

        Text("Custom Placeholder")
            .font(DesignTokens.Typography.caption)
            .foregroundColor(AppTheme.textMuted)
        DSSearchBar(
            searchText: .constant(""),
            placeholder: "Search files..."
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("With Filter Button") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        DSSearchBar(
            searchText: .constant(""),
            showFilterButton: true,
            onFilterTap: {
                print("Filter tapped")
            }
        )

        DSSearchBar(
            searchText: .constant("feature/"),
            placeholder: "Search branches...",
            showFilterButton: true,
            onFilterTap: {
                print("Filter tapped")
            }
        )

        DSSearchBar(
            searchText: .constant("fix: "),
            placeholder: "Search commits...",
            showFilterButton: true,
            onFilterTap: {
                print("Filter tapped")
            }
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Git Context Examples") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Branch Search")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSSearchBar(
                searchText: .constant(""),
                placeholder: "Search branches...",
                showFilterButton: true
            )
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Commit History")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSSearchBar(
                searchText: .constant(""),
                placeholder: "Search commits...",
                showFilterButton: true
            )
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("File Search")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
            DSSearchBar(
                searchText: .constant(""),
                placeholder: "Search files...",
                showFilterButton: false
            )
        }
    }
    .padding()
    .frame(width: 400)
}
