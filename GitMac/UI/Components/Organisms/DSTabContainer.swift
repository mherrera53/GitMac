//
//  DSTabContainer.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

/// Tab info model for DSTabContainer
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

/// Tab container organism with selector de tabs superior
///
/// Componente estándar para interfaces con tabs que muestra:
/// - Selector de tabs horizontal con iconos y títulos
/// - Área de contenido dinámico basado en tab seleccionado
/// - Diseño consistente con Design System
///
/// Ejemplo de uso:
/// ```swift
/// let tabs = [
///     DSTabInfo(id: "github", title: "GitHub", icon: "bolt.circle.fill"),
///     DSTabInfo(id: "aws", title: "AWS", icon: "cloud.fill")
/// ]
///
/// DSTabContainer(tabs: tabs, selectedTab: $selectedTab) { tabId in
///     switch tabId {
///     case "github": GitHubView()
///     case "aws": AWSView()
///     default: EmptyView()
///     }
/// }
/// ```
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
