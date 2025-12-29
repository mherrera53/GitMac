import SwiftUI

/// Extension para agregar todas las funcionalidades nuevas a ContentView
/// Este archivo debe integrarse en ContentView.swift existente

// MARK: - Notification Names Extension
extension Notification.Name {
    static let showCommandPalette = Notification.Name("showCommandPalette")
    static let showFileFinder = Notification.Name("showFileFinder")
    static let openRepository = Notification.Name("openRepository")
    static let cloneRepository = Notification.Name("cloneRepository")
    static let toggleTerminal = Notification.Name("toggleTerminal")
    static let stageAll = Notification.Name("stageAll")
    static let unstageAll = Notification.Name("unstageAll")
    static let fetch = Notification.Name("fetch")
    static let pull = Notification.Name("pull")
    static let push = Notification.Name("push")
    static let newBranch = Notification.Name("newBranch")
    static let merge = Notification.Name("merge")
    static let stash = Notification.Name("stash")
    static let popStash = Notification.Name("popStash")
}

// MARK: - Helper para usar NotificationManager
extension View {
    func showSuccessNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.success(message, detail: detail)
    }

    func showErrorNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.error(message, detail: detail)
    }

    func showWarningNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.warning(message, detail: detail)
    }

    func showInfoNotification(_ message: String, detail: String? = nil) {
        NotificationManager.shared.info(message, detail: detail)
    }
}
