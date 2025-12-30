import SwiftUI

// MARK: - Diff View Mode

enum DiffViewMode: String, CaseIterable {
    case split = "Split"
    case inline = "Inline"
    case hunk = "Hunk"
    case preview = "Preview"
    case kaleidoscopeBlocks = "Blocks"     // Kaleidoscope split with connection lines
    case kaleidoscopeFluid = "Fluid"       // Kaleidoscope split (cleaner)
    case kaleidoscopeUnified = "Unified"   // Kaleidoscope unified with A/B labels

    var icon: String {
        switch self {
        case .split: return "rectangle.split.2x1"
        case .inline: return "rectangle.stack"
        case .hunk: return "text.alignleft"
        case .preview: return "eye"
        case .kaleidoscopeBlocks: return "square.split.2x1.fill"
        case .kaleidoscopeFluid: return "square.split.2x1"
        case .kaleidoscopeUnified: return "rectangle.stack.fill"
        }
    }

    /// Modes available for regular files
    static var standardModes: [DiffViewMode] {
        [.split, .inline, .hunk]
    }

    /// Modes available for markdown files (includes preview)
    static var markdownModes: [DiffViewMode] {
        [.split, .inline, .hunk, .preview]
    }

    /// Kaleidoscope-style modes (professional diff viewing)
    static var kaleidoscopeModes: [DiffViewMode] {
        [.kaleidoscopeBlocks, .kaleidoscopeFluid, .kaleidoscopeUnified]
    }

    /// All modes including Kaleidoscope
    static var allModes: [DiffViewMode] {
        standardModes + kaleidoscopeModes
    }

    /// Check if this is a Kaleidoscope mode
    var isKaleidoscopeMode: Bool {
        switch self {
        case .kaleidoscopeBlocks, .kaleidoscopeFluid, .kaleidoscopeUnified:
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
    var isMarkdown: Bool = false
    @Binding var showMinimap: Bool
    var extraActions: [ToolbarAction] = []

    struct ToolbarAction: Identifiable {
        let id = UUID()
        let icon: String
        let tooltip: String
        let action: () -> Void
    }

    /// Available modes based on file type
    private var availableModes: [DiffViewMode] {
        isMarkdown ? DiffViewMode.markdownModes : DiffViewMode.standardModes
    }

    var body: some View {
        HStack(spacing: 16) {
            // File info
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.accent)

                Text(filename)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            // Stats badges
            DiffStatsView.badges(additions: additions, deletions: deletions, size: .medium)

            Spacer()

            // Extra actions
            if !extraActions.isEmpty {
                ForEach(extraActions) { action in
                    ToolbarButton(
                        icon: action.icon,
                        isActive: false,
                        tooltip: action.tooltip,
                        action: action.action
                    )
                }

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 20)
            }

            // View options
            HStack(spacing: 4) {
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
            }

            // Divider
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 20)

            // View mode selector
            HStack(spacing: 2) {
                ForEach(availableModes, id: \.self) { mode in
                    DiffModeButton(
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
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Diff Mode Button

/// View mode selector button (Split, Inline, Hunk, Preview)
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
                    .fill(isSelected ? AppTheme.accent : (isHovered ? AppTheme.hover : SwiftUI.Color.clear))
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
        HStack(spacing: 16) {
            // File info
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.accent)

                Text(filename)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            // Stats badges
            DiffStatsView.badges(additions: additions, deletions: deletions, size: .medium)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                isMarkdown: false,
                showMinimap: .constant(true)
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
                isMarkdown: true,
                showMinimap: .constant(false)
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
                isMarkdown: false,
                showMinimap: .constant(true),
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
