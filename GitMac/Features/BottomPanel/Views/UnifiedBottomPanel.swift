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

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle at the top (only when expanded)
            if panelManager.isPanelVisible {
                UniversalResizer(
                    dimension: $panelManager.panelHeight,
                    minDimension: 100,
                    maxDimension: 600,
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
        .frame(height: panelManager.isPanelVisible ? panelManager.panelHeight : 28)
        .background(AppTheme.panel)
        .onChange(of: panelManager.panelHeight) { _, newHeight in
            // Auto-save height changes
            panelManager.saveState()
        }
    }
}
