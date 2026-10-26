//
//  UnifiedBottomPanel.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct UnifiedBottomPanel: View {
    @Bindable var panelManager: BottomPanelManager
    @Environment(AppState.self) var appState
    var maximumHeight: CGFloat = DesignTokens.Layout.BottomPanel.maxHeight

    private var displayedHeight: CGFloat {
        DesignTokens.Layout.Responsive.bottomPanelHeight(preferred: panelManager.panelHeight, maximum: maximumHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle at the top (only when expanded)
            if panelManager.isPanelVisible {
                UniversalResizer(
                    dimension: Binding(get: { displayedHeight }, set: { panelManager.panelHeight = $0 }),
                    minDimension: min(DesignTokens.Layout.BottomPanel.minHeight, maximumHeight),
                    maxDimension: maximumHeight,
                    orientation: .vertical
                )
            }

            // Tab bar (always visible)
            BottomPanelTabBar(
                tabs: panelManager.openTabs,
                activeTabId: panelManager.activeTabId,
                onSelectTab: { panelManager.selectTab($0) },
                onCloseTab: { panelManager.closeTab($0) },
                onReorder: { source, dest in
                    panelManager.reorderTabs(from: source, to: dest)
                },
                onAddTab: {
                    // This is handled by the button's popover
                },
                onTogglePanel: { panelManager.togglePanel() }
            )

            // Content area (only when expanded)
            if panelManager.isPanelVisible {
                if let activeTab = panelManager.openTabs.first(where: { $0.id == panelManager.activeTabId }) {
                    BottomPanelContent(tab: activeTab)
                        .environment(appState)
                        .id(activeTab.id) // Force re-render when switching tabs
                } else {
                    EmptyPanelView()
                }
            }
        }
        .frame(height: panelManager.isPanelVisible ? displayedHeight : 28)
        .background(AppTheme.panel)
        .onChange(of: panelManager.panelHeight) { _, newHeight in
            // Auto-save height changes
            panelManager.saveState()
        }
    }
}
