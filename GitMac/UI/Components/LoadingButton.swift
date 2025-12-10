import SwiftUI

// MARK: - Loading Button

/// A button that shows a loading indicator when an async action is in progress
struct LoadingButton<Label: View>: View {
    let action: () async -> Void
    let label: Label
    let loadingLabel: String?
    let style: LoadingButtonStyle

    @State private var isLoading = false

    init(
        style: LoadingButtonStyle = .default,
        loadingLabel: String? = nil,
        action: @escaping () async -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.style = style
        self.loadingLabel = loadingLabel
        self.action = action
        self.label = label()
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
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)

                    if let loadingText = loadingLabel {
                        Text(loadingText)
                    }
                } else {
                    label
                }
            }
            .frame(minWidth: isLoading ? 80 : nil)
        }
        .disabled(isLoading)
        .buttonStyle(LoadingButtonStyleModifier(style: style, isLoading: isLoading))
    }
}

// MARK: - Loading Button Styles

enum LoadingButtonStyle {
    case `default`
    case primary
    case success
    case danger
    case warning
    case ghost
    case outline

    var backgroundColor: Color {
        switch self {
        case .default: return GitKrakenTheme.backgroundSecondary
        case .primary: return GitKrakenTheme.accent
        case .success: return GitKrakenTheme.accentGreen
        case .danger: return GitKrakenTheme.accentRed
        case .warning: return GitKrakenTheme.accentOrange
        case .ghost: return Color.clear
        case .outline: return Color.clear
        }
    }

    var foregroundColor: Color {
        switch self {
        case .default: return GitKrakenTheme.textPrimary
        case .primary, .success, .danger, .warning: return .white
        case .ghost: return GitKrakenTheme.textSecondary
        case .outline: return GitKrakenTheme.accent
        }
    }

    var hoverBackgroundColor: Color {
        switch self {
        case .default: return GitKrakenTheme.hover
        case .primary: return GitKrakenTheme.accent.opacity(0.85)
        case .success: return GitKrakenTheme.accentGreen.opacity(0.85)
        case .danger: return GitKrakenTheme.accentRed.opacity(0.85)
        case .warning: return GitKrakenTheme.accentOrange.opacity(0.85)
        case .ghost: return GitKrakenTheme.hover
        case .outline: return GitKrakenTheme.accent.opacity(0.1)
        }
    }
}

struct LoadingButtonStyleModifier: ButtonStyle {
    let style: LoadingButtonStyle
    let isLoading: Bool

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(style.foregroundColor.opacity(isLoading ? 0.7 : 1))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered && !isLoading ? style.hoverBackgroundColor : style.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(style == .outline ? GitKrakenTheme.accent : Color.clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Icon Loading Button

struct IconLoadingButton: View {
    let icon: String
    let tooltip: String
    let style: LoadingButtonStyle
    let action: () async -> Void

    @State private var isLoading = false
    @State private var isHovered = false

    init(
        icon: String,
        tooltip: String,
        style: LoadingButtonStyle = .ghost,
        action: @escaping () async -> Void
    ) {
        self.icon = icon
        self.tooltip = tooltip
        self.style = style
        self.action = action
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
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .frame(width: 24, height: 24)
            .foregroundColor(style.foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? style.hoverBackgroundColor : style.backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Action Row Button (for staging area)

struct ActionRowButton: View {
    let title: String
    let icon: String
    let style: LoadingButtonStyle
    let compact: Bool
    let action: () async -> Void

    @State private var isLoading = false
    @State private var isHovered = false

    init(
        title: String,
        icon: String,
        style: LoadingButtonStyle = .default,
        compact: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.compact = compact
        self.action = action
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
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 10 : 11, weight: .medium))
                }

                if !compact {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, compact ? 4 : 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? style.hoverBackgroundColor : style.backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help(title)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Inline Action Buttons (for diff lines)

struct LineActionButtons: View {
    let lineType: DiffLineType
    let onStage: (() async -> Void)?
    let onDiscard: (() async -> Void)?
    let onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 2) {
            // Copy button
            IconLoadingButton(icon: "doc.on.doc", tooltip: "Copy line", style: .ghost) {
                onCopy()
            }

            // Stage button (only for additions/deletions)
            if lineType != .context, let stage = onStage {
                IconLoadingButton(icon: "plus.circle", tooltip: "Stage line", style: .ghost, action: stage)
            }

            // Discard button (only for additions/deletions)
            if lineType != .context, let discard = onDiscard {
                IconLoadingButton(icon: "trash", tooltip: "Discard line", style: .ghost, action: discard)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(GitKrakenTheme.backgroundSecondary.opacity(0.95))
        )
        .opacity(isHovered ? 1 : 0)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Batch Action Bar

struct BatchActionBar: View {
    let selectedCount: Int
    let onStageSelected: () async -> Void
    let onUnstageSelected: () async -> Void
    let onDiscardSelected: () async -> Void
    let onClearSelection: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection info
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(GitKrakenTheme.accent)
                Text("\(selectedCount) selected")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(GitKrakenTheme.textPrimary)

            Spacer()

            // Actions
            HStack(spacing: 8) {
                LoadingButton(style: .success, loadingLabel: "Staging...") {
                    await onStageSelected()
                } label: {
                    Label("Stage", systemImage: "plus.circle")
                }

                LoadingButton(style: .danger, loadingLabel: "Discarding...") {
                    await onDiscardSelected()
                } label: {
                    Label("Discard", systemImage: "trash")
                }

                Button {
                    onClearSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(GitKrakenTheme.textMuted)
                .help("Clear selection")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GitKrakenTheme.accent.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(GitKrakenTheme.accent)
                .frame(height: 2),
            alignment: .top
        )
    }
}

// MARK: - Confirmation Dialog

struct ConfirmationDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let confirmStyle: LoadingButtonStyle
    let onConfirm: () async -> Void
    let onCancel: () -> Void

    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: confirmStyle == .danger ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(confirmStyle == .danger ? GitKrakenTheme.accentRed : GitKrakenTheme.accent)

            // Title
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GitKrakenTheme.textPrimary)

            // Message
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(GitKrakenTheme.textSecondary)
                .multilineTextAlignment(.center)

            // Actions
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(GitKrakenTheme.backgroundSecondary)
                .cornerRadius(6)

                LoadingButton(style: confirmStyle, loadingLabel: "Processing...") {
                    isConfirming = true
                    await onConfirm()
                    isConfirming = false
                } label: {
                    Text(confirmTitle)
                        .frame(minWidth: 80)
                }
            }
        }
        .padding(24)
        .background(GitKrakenTheme.panel)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 20)
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct LoadingButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LoadingButton(style: .primary) {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            } label: {
                Label("Primary Button", systemImage: "star.fill")
            }

            LoadingButton(style: .success, loadingLabel: "Staging...") {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            } label: {
                Label("Stage All", systemImage: "plus.circle.fill")
            }

            LoadingButton(style: .danger, loadingLabel: "Discarding...") {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            } label: {
                Label("Discard", systemImage: "trash")
            }

            HStack {
                IconLoadingButton(icon: "plus.circle", tooltip: "Stage", style: .success) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }

                IconLoadingButton(icon: "trash", tooltip: "Discard", style: .danger) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        .padding()
        .background(GitKrakenTheme.background)
    }
}
#endif
