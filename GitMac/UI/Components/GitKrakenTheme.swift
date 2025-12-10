import SwiftUI

/// GitKraken-style theme colors for consistent UI
enum GitKrakenTheme {
    // MARK: - Primary Colors
    static let accent = Color.blue
    static let accentGreen = Color.green
    static let accentRed = Color.red
    static let accentOrange = Color.orange
    static let accentPurple = Color.purple
    static let accentYellow = Color.yellow
    static let accentCyan = Color.cyan

    // MARK: - Background Colors
    static let background = Color(nsColor: .windowBackgroundColor)
    static let backgroundSecondary = Color(nsColor: .controlBackgroundColor)
    static let backgroundTertiary = Color.gray.opacity(0.15)
    static let panel = Color.gray.opacity(0.05)
    static let toolbar = Color(nsColor: .controlBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor)

    // MARK: - Text Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textMuted = Color.secondary.opacity(0.7)

    // MARK: - Interactive Colors
    static let hover = Color.gray.opacity(0.1)
    static let selection = Color.blue.opacity(0.2)
    static let border = Color.gray.opacity(0.3)

    // MARK: - Semantic Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    // MARK: - Branch/Lane Colors
    static let laneColors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .pink, .yellow]
}
