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
                HStack(spacing: DesignTokens.BottomBar.tabSpacing) {
                    ForEach(tabs) { tab in
                        XcodeBottomBarTab(
                            icon: tab.type.icon,
                            title: tab.displayTitle,
                            color: tab.type.accentColor,
                            isSelected: tab.id == activeTabId,
                            onTap: {
                                onSelectTab(tab.id)
                            },
                            onClose: {
                                onCloseTab(tab.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
            }

            Spacer()

            // Add button with menu
            Button(action: { showAddMenu.toggle() }) {
                Image(systemName: "plus")
                    .font(.system(size: DesignTokens.BottomBar.controlIconSize))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(
                        width: DesignTokens.BottomBar.controlButtonSize,
                        height: DesignTokens.BottomBar.controlButtonSize
                    )
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
                    .font(.system(size: DesignTokens.BottomBar.controlIconSize))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(
                        width: DesignTokens.BottomBar.controlButtonSize,
                        height: DesignTokens.BottomBar.controlButtonSize
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .help("Close Panel")
        }
        .frame(height: DesignTokens.BottomBar.height)
        .background(AppTheme.backgroundSecondary)
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
