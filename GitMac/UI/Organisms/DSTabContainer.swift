//
//  DSTabContainer.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Design System - Tab Container Organism
//  Contenedor con tabs superiores y contenido dinámico
//

import SwiftUI

/// Tab info model
struct DSTabInfo: Identifiable {
    let id: String
    let title: String
    let icon: String?

    init(id: String, title: String, icon: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

/// Tab container con selector de tabs superior
struct DSTabContainer<Content: View>: View {
    let tabs: [DSTabInfo]
    @Binding var selectedTab: String
    @ViewBuilder let content: (String) -> Content

    init(
        tabs: [DSTabInfo],
        selectedTab: Binding<String>,
        @ViewBuilder content: @escaping (String) -> Content
    ) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(tabs) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(AppTheme.backgroundSecondary.opacity(0.5))

            // Content area
            content(selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tabButton(for tab: DSTabInfo) -> some View {
        Button {
            selectedTab = tab.id
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = tab.icon {
                    DSIcon(icon, size: .sm, color: buttonTextColor(for: tab))
                }

                DSText(
                    tab.title,
                    variant: .callout,
                    color: buttonTextColor(for: tab)
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(buttonBackground(for: tab))
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }

    private func buttonBackground(for tab: DSTabInfo) -> Color {
        selectedTab == tab.id ? AppTheme.backgroundSecondary : Color.clear
    }

    private func buttonTextColor(for tab: DSTabInfo) -> Color {
        selectedTab == tab.id ? AppTheme.textPrimary : AppTheme.textSecondary
    }
}

// MARK: - Preview

#Preview("DSTabContainer") {
    struct PreviewWrapper: View {
        @State private var selectedTab = "github"

        var body: some View {
            DSTabContainer(
                tabs: [
                    DSTabInfo(id: "github", title: "GitHub", icon: "arrow.triangle.branch"),
                    DSTabInfo(id: "gitlab", title: "GitLab", icon: "arrow.triangle.merge"),
                    DSTabInfo(id: "bitbucket", title: "Bitbucket", icon: "ant")
                ],
                selectedTab: $selectedTab
            ) { tabId in
                DSEmptyState(
                    icon: "doc.text",
                    title: "\(tabId.capitalized) Content",
                    description: "Tab content for \(tabId)"
                )
                .background(AppTheme.background)
            }
            .frame(width: 600, height: 400)
            .background(AppTheme.background)
        }
    }

    return PreviewWrapper()
}
