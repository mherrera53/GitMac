import SwiftUI
import AppKit

// MARK: - Diff View Mode

enum DiffViewMode: String, CaseIterable {
    case split = "Split"
    case inline = "Inline"
    case hunk = "Hunk"
    case preview = "Preview"
    case kaleidoscopeBlocks = "Blocks"     // Kaleidoscope split with connection lines

    var icon: String {
        switch self {
        case .split: return "rectangle.split.2x1"
        case .inline: return "rectangle.stack"
        case .hunk: return "text.alignleft"
        case .preview: return "eye"
        case .kaleidoscopeBlocks: return "square.split.2x1.fill"
        }
    }

    /// Modes available for regular files (Blocks first, then standard modes)
    /// Note: Preview is now a separate modal button, not a view mode
    static var standardModes: [DiffViewMode] {
        [.kaleidoscopeBlocks, .split, .inline, .hunk]
    }

    /// Modes available for files supporting preview (same as standard now)
    static var previewableModes: [DiffViewMode] {
        [.kaleidoscopeBlocks, .split, .inline, .hunk]
    }

    /// All modes for the selector (Preview is now modal, not here)
    static var allModes: [DiffViewMode] {
        [.kaleidoscopeBlocks, .split, .inline, .hunk]
    }

    /// Check if this is a Kaleidoscope mode
    var isKaleidoscopeMode: Bool {
        switch self {
        case .kaleidoscopeBlocks:
            return true
        default:
            return false
        }
    }
}

// MARK: - Diff Toolbar (Modern Style)

/// Main toolbar for diff views
/// Shows file info, stats, view options, and mode selector
struct DiffToolbar: View {
    let filename: String
    let additions: Int
    let deletions: Int
    @Binding var viewMode: DiffViewMode
    @Binding var showLineNumbers: Bool
    @Binding var wordWrap: Bool
    var isPreviewable: Bool = false
    @Binding var showMinimap: Bool
    @Binding var ignoreWhitespace: Bool
    @Binding var contextLines: Int
    var showHistoryButton: Bool = true
    var showBlameButton: Bool = true
    var filePath: String? = nil  // Full path for opening file
    var onHistoryTap: (() -> Void)? = nil
    var onBlameTap: (() -> Void)? = nil
    var onEditTap: (() -> Void)? = nil  // Edit in built-in editor
    var onPreviewTap: (() -> Void)? = nil  // Preview modal
    var onClose: (() -> Void)? = nil
    var extraActions: [ToolbarAction] = []

    struct ToolbarAction: Identifiable {
        let id = UUID()
        let icon: String
        let tooltip: String
        let action: () -> Void
    }

    /// Available modes based on file type
    private var availableModes: [DiffViewMode] {
        if isPreviewable {
            return DiffViewMode.previewableModes
        }
        return DiffViewMode.standardModes
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // File info
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.accent)

                Text(filename)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Stats badges
            DiffStatsView.badges(additions: additions, deletions: deletions, size: .medium)

            Spacer(minLength: DesignTokens.Spacing.md)

            // History and Blame buttons
            HStack(spacing: DesignTokens.Spacing.xs) {
                if showHistoryButton {
                    ToolbarButton(
                        icon: "clock.arrow.circlepath",
                        isActive: false,
                        tooltip: "Show History"
                    ) {
                        onHistoryTap?()
                    }
                }

                if showBlameButton {
                    ToolbarButton(
                        icon: "person.text.rectangle",
                        isActive: false,
                        tooltip: "Show Blame"
                    ) {
                        onBlameTap?()
                    }
                }
            }

            // Extra actions
            if !extraActions.isEmpty {
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 20)

                ForEach(extraActions) { action in
                    ToolbarButton(
                        icon: action.icon,
                        isActive: false,
                        tooltip: action.tooltip,
                        action: action.action
                    )
                }
            }

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 20)

            // View options
            HStack(spacing: DesignTokens.Spacing.xs) {
                ToolbarButton(
                    icon: "number",
                    isActive: showLineNumbers,
                    tooltip: "Line numbers"
                ) {
                    showLineNumbers.toggle()
                }

                ToolbarButton(
                    icon: "text.word.spacing",
                    isActive: wordWrap,
                    tooltip: "Word wrap"
                ) {
                    wordWrap.toggle()
                }

                ToolbarButton(
                    icon: "chart.bar.doc.horizontal",
                    isActive: showMinimap,
                    tooltip: "Minimap"
                ) {
                    showMinimap.toggle()
                }

                ToolbarButton(
                    icon: "space",
                    isActive: ignoreWhitespace,
                    tooltip: "Ignore whitespace"
                ) {
                    ignoreWhitespace.toggle()
                }

                // Context lines selector
                Menu {
                    ForEach([3, 5, 10, 25], id: \.self) { count in
                        Button {
                            contextLines = count
                        } label: {
                            HStack {
                                Text("\(count) lines")
                                if contextLines == count {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Button {
                        contextLines = 9999
                    } label: {
                        HStack {
                            Text("All")
                            if contextLines == 9999 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(contextLines == 9999 ? "All" : "\(contextLines)")")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(height: 28)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                    )
                }
                .menuStyle(.borderlessButton)
                .frame(width: 52)
                .help("Context lines")
            }

            // View mode selector (compact icon-only)
            HStack(spacing: 2) {
                ForEach(availableModes, id: \.self) { mode in
                    DiffModeIconButton(
                        mode: mode,
                        isSelected: viewMode == mode
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewMode = mode
                        }
                    }
                }
            }
            .padding(3)
            .background(AppTheme.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.md)

            // Preview button - opens preview modal
            if let onPreview = onPreviewTap {
                ToolbarButton(
                    icon: "eye",
                    isActive: false,
                    tooltip: "Preview"
                ) {
                    onPreview()
                }
            }

            // Edit and Open buttons
            if let path = filePath {
                // Edit button - opens in built-in editor
                if let onEdit = onEditTap {
                    ToolbarButton(
                        icon: "pencil.and.outline",
                        isActive: false,
                        tooltip: "Edit"
                    ) {
                        onEdit()
                    }
                }

                // Open button - opens file with default Mac app
                ToolbarButton(
                    icon: "arrow.up.forward.app",
                    isActive: false,
                    tooltip: "Open"
                ) {
                    let url = URL(fileURLWithPath: path)
                    NSWorkspace.shared.open(url)
                }
            }

            // Close button (if provided)
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.toolbar)
    }
}

// MARK: - Toolbar Button

/// Toggle button for toolbar options (line numbers, word wrap, minimap)
struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? AppTheme.accent.opacity(0.15) : (isHovered ? AppTheme.hover : SwiftUI.Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}

// MARK: - Diff Mode Button

/// Compact icon-only mode selector button with tooltip
struct DiffModeIconButton: View {
    let mode: DiffViewMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: mode.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? AppTheme.accent : (isHovered ? AppTheme.hover : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(mode.rawValue)
    }
}

/// View mode selector button with text (for wider layouts)
struct DiffModeButton: View {
    let mode: DiffViewMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? AppTheme.accent : (isHovered ? AppTheme.hover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Convenience Initializers

extension DiffToolbar {
    /// Creates a minimal toolbar without options
    static func minimal(
        filename: String,
        additions: Int,
        deletions: Int
    ) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // File info
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.accent)

                Text(filename)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Stats badges
            DiffStatsView.badges(additions: additions, deletions: deletions, size: .medium)

            Spacer(minLength: DesignTokens.Spacing.md)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.toolbar)
    }
}

// MARK: - Preview

#if DEBUG
struct DiffToolbar_Previews: PreviewProvider {
    @State static var viewMode: DiffViewMode = .split
    @State static var showLineNumbers = true
    @State static var wordWrap = false
    @State static var showMinimap = true
    @State static var ignoreWhitespace = false
    @State static var contextLines = 3

    static var previews: some View {
        VStack(spacing: 0) {
            // Full toolbar (regular file)
            DiffToolbar(
                filename: "src/components/Button.tsx",
                additions: 42,
                deletions: 15,
                viewMode: .constant(.split),
                showLineNumbers: .constant(true),
                wordWrap: .constant(false),
                isPreviewable: false,
                showMinimap: .constant(true),
                ignoreWhitespace: .constant(false),
                contextLines: .constant(3)
            )

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            // Toolbar with markdown preview option
            DiffToolbar(
                filename: "README.md",
                additions: 10,
                deletions: 3,
                viewMode: .constant(.preview),
                showLineNumbers: .constant(true),
                wordWrap: .constant(true),
                isPreviewable: true,
                showMinimap: .constant(false),
                ignoreWhitespace: .constant(false),
                contextLines: .constant(3)
            )

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            // Toolbar with extra actions
            DiffToolbar(
                filename: "package.json",
                additions: 5,
                deletions: 2,
                viewMode: .constant(.inline),
                showLineNumbers: .constant(true),
                wordWrap: .constant(false),
                isPreviewable: false,
                showMinimap: .constant(true),
                ignoreWhitespace: .constant(false),
                contextLines: .constant(3),
                extraActions: [
                    DiffToolbar.ToolbarAction(icon: "arrow.clockwise", tooltip: "Refresh") { print("Refresh") },
                    DiffToolbar.ToolbarAction(icon: "arrow.up.doc", tooltip: "Stage File") { print("Stage") }
                ]
            )

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            // Minimal toolbar
            DiffToolbar.minimal(
                filename: "simple.txt",
                additions: 1,
                deletions: 1
            )

            Spacer()
        }
        .frame(width: 800, height: 400)
        .background(AppTheme.background)
    }
}
#endif
