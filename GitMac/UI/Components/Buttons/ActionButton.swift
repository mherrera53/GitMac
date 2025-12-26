import SwiftUI

// MARK: - Action Button

/// Unified action button with loading state and hover effects
/// Replaces HeaderActionButton and FileActionButton with a single configurable component
struct ActionButton: View {
    let icon: String
    let color: Color
    let size: ButtonSize
    let tooltip: String
    let action: () async -> Void

    @State private var isLoading = false
    @State private var isHovered = false

    enum ButtonSize {
        case compact    // 20x20 (was FileActionButton)
        case standard   // 24x24 (was HeaderActionButton)
        case large      // 32x32

        var frameSize: CGFloat {
            switch self {
            case .compact: return 20
            case .standard: return 24
            case .large: return 32
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .compact: return 14
            case .standard: return 16
            case .large: return 20
            }
        }

        var progressScale: CGFloat {
            switch self {
            case .compact: return 0.5
            case .standard: return 0.6
            case .large: return 0.8
            }
        }
    }

    var body: some View {
        Button {
            guard !isLoading else { return }
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(size.progressScale)
                        .frame(width: size.iconSize, height: size.iconSize)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize))
                        .foregroundColor(foregroundColor)
                }
            }
            .frame(width: size.frameSize, height: size.frameSize)
            .background(backgroundColor)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        if size == .compact {
            return isHovered ? color : color.opacity(0.8)
        } else {
            return color
        }
    }

    private var backgroundColor: Color {
        isHovered ? color.opacity(0.15) : Color.clear
    }
}

// MARK: - Convenience Initializers

extension ActionButton {
    /// Creates a standard-sized action button (24x24)
    init(
        icon: String,
        color: Color = AppTheme.accent,
        tooltip: String,
        action: @escaping () async -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = .standard
        self.tooltip = tooltip
        self.action = action
    }

    // MARK: - Common Actions

    /// Stage action button
    static func stage(tooltip: String = "Stage", action: @escaping () async -> Void) -> ActionButton {
        ActionButton(
            icon: "plus.circle.fill",
            color: AppTheme.success,
            size: .compact,
            tooltip: tooltip,
            action: action
        )
    }

    /// Unstage action button
    static func unstage(tooltip: String = "Unstage", action: @escaping () async -> Void) -> ActionButton {
        ActionButton(
            icon: "minus.circle.fill",
            color: AppTheme.warning,
            size: .compact,
            tooltip: tooltip,
            action: action
        )
    }

    /// Discard action button
    static func discard(tooltip: String = "Discard", action: @escaping () async -> Void) -> ActionButton {
        ActionButton(
            icon: "trash",
            color: AppTheme.error,
            size: .compact,
            tooltip: tooltip,
            action: action
        )
    }

    /// Refresh action button
    static func refresh(tooltip: String = "Refresh", action: @escaping () async -> Void) -> ActionButton {
        ActionButton(
            icon: "arrow.clockwise",
            color: AppTheme.accent,
            size: .standard,
            tooltip: tooltip,
            action: action
        )
    }

    /// Expand all action button
    static func expandAll(tooltip: String = "Expand All", action: @escaping () async -> Void) -> ActionButton {
        ActionButton(
            icon: "arrow.down.right.and.arrow.up.left",
            color: AppTheme.accent,
            size: .standard,
            tooltip: tooltip,
            action: action
        )
    }

    /// Collapse all action button
    static func collapseAll(tooltip: String = "Collapse All", action: @escaping () async -> Void) -> ActionButton {
        ActionButton(
            icon: "arrow.up.left.and.arrow.down.right",
            color: AppTheme.accent,
            size: .standard,
            tooltip: tooltip,
            action: action
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ActionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Sizes
            HStack(spacing: 8) {
                ActionButton(
                    icon: "plus.circle",
                    color: .blue,
                    size: .compact,
                    tooltip: "Compact"
                ) {}

                ActionButton(
                    icon: "plus.circle",
                    color: .blue,
                    size: .standard,
                    tooltip: "Standard"
                ) {}

                ActionButton(
                    icon: "plus.circle",
                    color: .blue,
                    size: .large,
                    tooltip: "Large"
                ) {}
            }

            // Common actions
            HStack(spacing: 8) {
                ActionButton.stage {}
                ActionButton.unstage {}
                ActionButton.discard {}
                ActionButton.refresh {}
            }

            // Different colors
            HStack(spacing: 8) {
                ActionButton(icon: "star.fill", color: .green, tooltip: "Green") {}
                ActionButton(icon: "heart.fill", color: .red, tooltip: "Red") {}
                ActionButton(icon: "bolt.fill", color: .orange, tooltip: "Orange") {}
            }
        }
        .padding()
    }
}
#endif
