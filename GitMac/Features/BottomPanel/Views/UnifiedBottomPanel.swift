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
    @State private var visitedTerminalTabs: Set<UUID> = []
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

            // Terminal sessions belong to their tabs, not to the current selection.
            // Unvisited restored tabs remain lazy; closing a tab removes its session.
            ZStack {
                ForEach(panelManager.openTabs.filter { $0.type == .terminal &&
                    TerminalSessionVisibility.shouldMount(isVisited: visitedTerminalTabs.contains($0.id),
                        isActive: $0.id == panelManager.activeTabId, isPanelVisible: panelManager.isPanelVisible) }) { tab in
                    let isActive = panelManager.isPanelVisible && tab.id == panelManager.activeTabId
                    BottomPanelContent(tab: tab, isActive: isActive)
                        .environment(appState)
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                }
                if panelManager.isPanelVisible {
                    if let activeTab = panelManager.openTabs.first(where: { $0.id == panelManager.activeTabId }), activeTab.type != .terminal {
                        BottomPanelContent(tab: activeTab).environment(appState).id(activeTab.id)
                    } else if panelManager.activeTabId == nil {
                        EmptyPanelView()
                    }
                }
            }
            .frame(maxHeight: panelManager.isPanelVisible ? .infinity : 0)
            .clipped()

        }
        .frame(height: panelManager.isPanelVisible ? displayedHeight : 28)
        .background(AppTheme.panel)
        .onAppear { rememberActiveTerminal() }
        .onChange(of: panelManager.activeTabId) { _, _ in rememberActiveTerminal() }
        .onChange(of: panelManager.isPanelVisible) { _, visible in if visible { rememberActiveTerminal() } }
        .onChange(of: panelManager.openTabs.map(\.id)) { _, ids in
            visitedTerminalTabs.formIntersection(ids)
        }
        .onChange(of: panelManager.panelHeight) { _, newHeight in
            // Auto-save height changes
            panelManager.saveState()
        }
    }

    private func rememberActiveTerminal() {
        guard panelManager.isPanelVisible else { return }
        if let tab = panelManager.openTabs.first(where: { $0.id == panelManager.activeTabId && $0.type == .terminal }) {
            visitedTerminalTabs.insert(tab.id)
        }
    }
}

/// A restored tab is metadata until the user first opens it. An opened session
/// remains mounted while hidden so its process and pending work survive.
enum TerminalSessionVisibility {
    static func shouldMount(isVisited: Bool, isActive: Bool, isPanelVisible: Bool) -> Bool {
        isVisited || (isActive && isPanelVisible)
    }
}
