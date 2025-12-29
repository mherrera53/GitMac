import SwiftUI

// MARK: - Loading Button (DS Migration Wrapper)
// DEPRECATED: This is a legacy wrapper - use DSButton directly instead

/// A button that shows a loading indicator when an async action is in progress
/// MIGRATED TO DESIGN SYSTEM - This wrapper exists for backward compatibility only
struct LoadingButton<Label: View>: View {
    let action: () async -> Void
    let label: Label
    let loadingLabel: String?
    let style: LoadingButtonStyle

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
        DSButton(
            variant: style.dsVariant,
            size: .md,
            isDisabled: false,
            action: action,
            label: { label }
        )
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

    var dsVariant: DSButtonVariant {
        switch self {
        case .default: return .secondary
        case .primary: return .primary
        case .success: return .primary
        case .danger: return .danger
        case .warning: return .danger
        case .ghost: return .ghost
        case .outline: return .outline
        }
    }
}

// MARK: - Inline Action Buttons (for diff lines)
// MIGRATED TO DESIGN SYSTEM - Uses DSIconButton

struct LineActionButtons: View {
    let lineType: DiffLineType
    let onStage: (() async -> Void)?
    let onDiscard: (() async -> Void)?
    let onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 2) {
            // Copy button
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: DesignTokens.Size.iconMD))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: DesignTokens.Size.buttonHeightSM, height: DesignTokens.Size.buttonHeightSM)
            }
            .buttonStyle(.plain)
            .help("Copy line")

            // Stage button (only for additions/deletions)
            if lineType != .context, let stage = onStage {
                DSIconButton(
                    iconName: "plus.circle",
                    variant: .ghost,
                    size: .sm,
                    isDisabled: false,
                    action: stage
                )
                .help("Stage line")
            }

            // Discard button (only for additions/deletions)
            if lineType != .context, let discard = onDiscard {
                DSIconButton(
                    iconName: "trash",
                    variant: .ghost,
                    size: .sm,
                    isDisabled: false,
                    action: discard
                )
                .help("Discard line")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .fill(AppTheme.backgroundSecondary.opacity(0.95))
        )
        .opacity(isHovered ? 1 : 0)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Batch Action Bar
// MIGRATED TO DESIGN SYSTEM - Uses DSButton and DSCloseButton

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
                    .foregroundColor(AppTheme.accent)
                Text("\(selectedCount) selected")
                    .font(DesignTokens.Typography.callout.weight(.medium))
            }
            .foregroundColor(AppTheme.textPrimary)

            Spacer()

            // Actions
            HStack(spacing: 8) {
                DSButton(
                    variant: .primary,
                    size: .sm,
                    isDisabled: false,
                    action: onStageSelected
                ) {
                    Label("Stage", systemImage: "plus.circle")
                }

                DSButton(
                    variant: .danger,
                    size: .sm,
                    isDisabled: false,
                    action: onDiscardSelected
                ) {
                    Label("Discard", systemImage: "trash")
                }

                DSCloseButton(
                    size: .sm,
                    isDisabled: false,
                    action: onClearSelection
                )
                .help("Clear selection")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
        .background(AppTheme.accent.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(AppTheme.accent)
                .frame(height: 2),
            alignment: .top
        )
    }
}

// MARK: - Confirmation Dialog
// MIGRATED TO DESIGN SYSTEM - Uses DSButton

struct ConfirmationDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let confirmStyle: LoadingButtonStyle
    let onConfirm: () async -> Void
    let onCancel: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: confirmStyle == .danger ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(confirmStyle == .danger ? AppTheme.error : AppTheme.accent)

            // Title
            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)

            // Message
            Text(message)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            // Actions
            HStack(spacing: 12) {
                DSButton(
                    variant: .secondary,
                    size: .md,
                    isDisabled: false,
                    action: { onCancel() }
                ) {
                    Text("Cancel")
                        .frame(minWidth: 80)
                }

                DSButton(
                    variant: confirmStyle.dsVariant,
                    size: .md,
                    isDisabled: false,
                    action: onConfirm
                ) {
                    Text(confirmTitle)
                        .frame(minWidth: 80)
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.xl)
        .shadow(color: Color.Theme(themeManager.colors).shadow.opacity(0.3), radius: 20)
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

            // Icon-only button example
            LoadingButton(style: .ghost) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
            }

            // Compact action button example
            LoadingButton(style: .default) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11, weight: .medium))
                    Text("Stage")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}
#endif
