//
//  UnifiedBottomPanel.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct UnifiedBottomPanel: View {
    @ObservedObject var panelManager: BottomPanelManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle at the top
            UniversalResizer(
                dimension: $panelManager.panelHeight,
                minDimension: 100,
                maxDimension: 600,
                orientation: .vertical
            )

            // Tab bar
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

            // Content area
            if let activeTab = panelManager.openTabs.first(where: { $0.id == panelManager.activeTabId }) {
                BottomPanelContent(tab: activeTab)
                    .environmentObject(appState)
                    .id(activeTab.id) // Force re-render when switching tabs
            } else {
                EmptyPanelView()
            }
        }
        .frame(height: panelManager.panelHeight)
        .background(AppTheme.panel)
        .onChange(of: panelManager.panelHeight) { _, newHeight in
            // Auto-save height changes
            panelManager.saveState()
        }
    }
}
