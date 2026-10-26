import SwiftUI

// Only UI colors are substituted in the headless core-module test build.
// No Git models, parsers, process execution or operations are replaced.
enum AppTheme {
    @MainActor static let success = Color.green
    @MainActor static let warning = Color.orange
    @MainActor static let error = Color.red
    @MainActor static let accent = Color.blue
    @MainActor static let backgroundTertiary = Color.gray
    @MainActor static let backgroundSecondary = Color.gray
    @MainActor static let info = Color.blue
    @MainActor static let textPrimary = Color.primary
    @MainActor static let textSecondary = Color.secondary
    @MainActor static let textMuted = Color.secondary
    @MainActor static let border = Color.gray
    @MainActor static let hover = Color.gray.opacity(0.1)
    @MainActor static let graphLaneColors: [Color] = [.blue, .green, .orange, .purple]
}

// The app-level notification declaration lives beside the application entry
// point, which this isolated module must not initialize.
extension Notification.Name {
    static let repositoryDidRefresh = Notification.Name("repositoryDidRefresh")
}
