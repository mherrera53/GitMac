//
//  BottomPanelManager.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

@MainActor
class BottomPanelManager: ObservableObject {
    static let shared = BottomPanelManager()

    @Published var openTabs: [BottomPanelTab] = []
    @Published var activeTabId: UUID?
    @Published var isPanelVisible: Bool = false
    @Published var panelHeight: CGFloat = 300

    private let userDefaults = UserDefaults.standard
    private let openTabsKey = "bottomPanelOpenTabs"
    private let activeTabKey = "bottomPanelActiveTab"
    private let visibilityKey = "bottomPanelVisible"
    private let heightKey = "bottomPanelHeight"

    private init() {
        restoreState()
    }

    // MARK: - Tab Management

    func openTab(type: BottomPanelType, customTitle: String? = nil) {
        NSLog("🟢 [BottomPanel] openTab called for type: \(type.rawValue)")
        NSLog("🟢 [BottomPanel] Current openTabs count: \(openTabs.count)")
        NSLog("🟢 [BottomPanel] isPanelVisible: \(isPanelVisible)")

        // Si ya existe un tab de este tipo (excepto Terminal), seleccionarlo
        if type != .terminal, let existingTab = openTabs.first(where: { $0.type == type }) {
            NSLog("🟡 [BottomPanel] Tab already exists, selecting it")
            selectTab(existingTab.id)
            if !isPanelVisible {
                isPanelVisible = true
            }
            return
        }

        // Crear nuevo tab
        let newTab = BottomPanelTab(type: type, customTitle: customTitle)
        openTabs.append(newTab)
        activeTabId = newTab.id
        isPanelVisible = true
        NSLog("🟢 [BottomPanel] Created new tab. openTabs count: \(openTabs.count), isPanelVisible: \(isPanelVisible)")
        saveState()
    }

    func closeTab(_ tabId: UUID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabId }) else { return }
        openTabs.remove(at: index)

        // Si cerramos el tab activo, seleccionar otro
        if activeTabId == tabId {
            if !openTabs.isEmpty {
                activeTabId = index > 0 ? openTabs[index - 1].id : openTabs.first?.id
            } else {
                activeTabId = nil
                isPanelVisible = false
            }
        }

        saveState()
    }

    func selectTab(_ tabId: UUID) {
        guard openTabs.contains(where: { $0.id == tabId }) else { return }
        activeTabId = tabId
        if !isPanelVisible {
            isPanelVisible = true
        }
        saveState()
    }

    func reorderTabs(from source: IndexSet, to destination: Int) {
        openTabs.move(fromOffsets: source, toOffset: destination)
        saveState()
    }

    func togglePanel() {
        isPanelVisible.toggle()
        saveState()
    }

    func togglePanel(_ type: BottomPanelType) {
        // Si existe un tab de este tipo y está activo y visible, cerrarlo
        if let existingTab = openTabs.first(where: { $0.type == type }),
           activeTabId == existingTab.id,
           isPanelVisible {
            closeTab(existingTab.id)
        } else {
            // Caso contrario, abrirlo
            openTab(type: type)
        }
    }

    func closeAllTabs() {
        openTabs.removeAll()
        activeTabId = nil
        isPanelVisible = false
        saveState()
    }

    // MARK: - Persistence

    func saveState() {
        if let encoded = try? JSONEncoder().encode(openTabs) {
            userDefaults.set(encoded, forKey: openTabsKey)
        }
        if let activeId = activeTabId {
            userDefaults.set(activeId.uuidString, forKey: activeTabKey)
        }
        userDefaults.set(isPanelVisible, forKey: visibilityKey)
        userDefaults.set(panelHeight, forKey: heightKey)
    }

    func restoreState() {
        // Restaurar tabs
        if let data = userDefaults.data(forKey: openTabsKey),
           let tabs = try? JSONDecoder().decode([BottomPanelTab].self, from: data) {
            openTabs = tabs
        }

        // Restaurar tab activo
        if let activeIdString = userDefaults.string(forKey: activeTabKey),
           let uuid = UUID(uuidString: activeIdString) {
            activeTabId = uuid
        }

        // Restaurar visibilidad y altura
        isPanelVisible = userDefaults.bool(forKey: visibilityKey)
        let savedHeight = userDefaults.double(forKey: heightKey)
        panelHeight = savedHeight > 0 ? savedHeight : 300
    }
}
