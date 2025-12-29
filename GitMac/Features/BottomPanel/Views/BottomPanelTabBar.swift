//
//  BottomPanelTabBar.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct BottomPanelTabBar: View {
    let tabs: [BottomPanelTab]
    let activeTabId: UUID?
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void
    let onReorder: (IndexSet, Int) -> Void
    let onAddTab: () -> Void
    let onTogglePanel: () -> Void

    @State private var showAddMenu = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(tabs) { tab in
                        DSTabButton(
                            title: tab.displayTitle,
                            iconName: tab.type.icon,
                            isSelected: tab.id == activeTabId,
                            size: .sm,
                            onClose: {
                                onCloseTab(tab.id)
                            },
                            action: {
                                onSelectTab(tab.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.sm - 2)
            }

            Spacer()

            // Add button with menu
            Button(action: { showAddMenu.toggle() }) {
                Image(systemName: "plus")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: DesignTokens.Size.buttonHeightSM, height: DesignTokens.Size.buttonHeightSM)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .popover(isPresented: $showAddMenu, arrowEdge: .bottom) {
                PanelTypeMenu(
                    openTabs: tabs,
                    onSelectType: { type in
                        showAddMenu = false
                        // Create a new tab via callback
                        BottomPanelManager.shared.openTab(type: type)
                    }
                )
            }

            // Close panel button
            Button(action: onTogglePanel) {
                Image(systemName: "chevron.down")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: DesignTokens.Size.buttonHeightSM, height: DesignTokens.Size.buttonHeightSM)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .help("Close Panel")
        }
        .frame(height: 36)
        .background(AppTheme.toolbar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }
}

// Menu for selecting panel type to add
struct PanelTypeMenu: View {
    let openTabs: [BottomPanelTab]
    let onSelectType: (BottomPanelType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(BottomPanelType.allCases) { type in
                let isOpen = openTabs.contains(where: { $0.type == type && type != .terminal })

                Button(action: {
                    onSelectType(type)
                }) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: type.icon)
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(type.accentColor)
                            .frame(width: DesignTokens.Size.iconLG)

                        Text(type.displayName)
                            .font(DesignTokens.Typography.callout)

                        Spacer()

                        if isOpen {
                            Image(systemName: "checkmark")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm - 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    Rectangle()
                        .fill(Color.clear)
                        .onHover { hovering in
                            // Optional: add hover effect
                        }
                )
            }
        }
        .frame(width: 200)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.panel)
    }
}
