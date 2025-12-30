import SwiftUI

// MARK: - Kaleidoscope Diff View (Main Container)

/// Professional diff viewer matching Kaleidoscope design exactly
/// Features: file list sidebar (LEFT), Blocks/Fluid/Unified views, Swap A/B button
struct KaleidoscopeDiffView: View {
    let files: [FileDiff]
    @State private var selectedFile: FileDiff?
    @State private var viewMode: KaleidoscopeViewMode = .blocks
    @State private var showLineNumbers = true
    @State private var showWhitespace = false
    @State private var showFileList = true
    @State private var swappedAB = false // For Swap A/B functionality
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 400
    @State private var contentHeight: CGFloat = 1000

    @StateObject private var themeManager = ThemeManager.shared

    // Select first file by default
    init(files: [FileDiff]) {
        self.files = files
        self._selectedFile = State(initialValue: files.first)
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(spacing: 0) {
            // Toolbar (Kaleidoscope-style)
            kaleidoscopeToolbar

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)

            // Main content area
            HStack(spacing: 0) {
                // File list sidebar (LEFT side - Kaleidoscope style)
                if showFileList {
                    KaleidoscopeFileList(
                        files: files,
                        selectedFile: $selectedFile
                    )

                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)
                }

                // Diff view (main area)
                if let file = selectedFile {
                    diffContentView(for: file)
                        .frame(maxWidth: .infinity)
                } else {
                    emptyStateView
                }
            }
        }
        .background(theme.background)
    }

    // MARK: - Components

    private var kaleidoscopeToolbar: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // File List toggle (LEFT)
            ToolbarToggle(
                icon: "sidebar.left",
                isActive: showFileList,
                tooltip: "File List"
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFileList.toggle()
                }
            }

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 24)

            // View mode selector (Blocks/Fluid/Unified)
            viewModeSelector

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 24)

            // Swap A/B button (IMPORTANT Kaleidoscope feature!)
            Button {
                swappedAB.toggle()
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(DesignTokens.Typography.callout)
                    Text("Swap A/B")
                        .font(DesignTokens.Typography.caption.weight(.medium))
                }
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(AppTheme.accent.opacity(0.1))
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 24)

            // Options
            HStack(spacing: DesignTokens.Spacing.xs) {
                ToolbarToggle(
                    icon: "number",
                    isActive: showLineNumbers,
                    tooltip: "Line Numbers"
                ) {
                    showLineNumbers.toggle()
                }

                ToolbarToggle(
                    icon: "space",
                    isActive: showWhitespace,
                    tooltip: "Show Whitespace"
                ) {
                    showWhitespace.toggle()
                }
            }

            Spacer()

            // Current file info
            if let file = selectedFile {
                Text((file.displayPath as NSString).lastPathComponent)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                DiffStatsView.badges(
                    additions: file.additions,
                    deletions: file.deletions,
                    size: .small
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.toolbar)
    }

    private var viewModeSelector: some View {
        HStack(spacing: 2) {
            ForEach(KaleidoscopeViewMode.allCases, id: \.self) { mode in
                ViewModeButton(
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
    }

    @ViewBuilder
    private func diffContentView(for file: FileDiff) -> some View {
        let hunks = swappedAB ? swapHunks(file.hunks) : file.hunks

        switch viewMode {
        case .blocks:
            // Traditional side-by-side (like Split)
            KaleidoscopeSplitDiffView(
                hunks: hunks,
                showLineNumbers: showLineNumbers,
                scrollOffset: $scrollOffset,
                viewportHeight: $viewportHeight,
                contentHeight: $contentHeight
            )

        case .fluid:
            // Fluid view with connection lines (enhanced version)
            KaleidoscopeSplitDiffView(
                hunks: hunks,
                showLineNumbers: showLineNumbers,
                scrollOffset: $scrollOffset,
                viewportHeight: $viewportHeight,
                contentHeight: $contentHeight
            )

        case .unified:
            // True Unified view with A/B labels in margin
            KaleidoscopeUnifiedView(
                hunks: hunks,
                showLineNumbers: showLineNumbers,
                scrollOffset: $scrollOffset,
                viewportHeight: $viewportHeight,
                contentHeight: $contentHeight
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)

            Text("No file selected")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(AppTheme.textPrimary)

            Text("Select a file from the list to view changes")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func swapHunks(_ hunks: [DiffHunk]) -> [DiffHunk] {
        // Swap A and B sides by reversing line types
        hunks.map { hunk in
            DiffHunk(
                header: hunk.header,
                oldStart: hunk.newStart,
                oldLines: hunk.newLines,
                newStart: hunk.oldStart,
                newLines: hunk.oldLines,
                lines: hunk.lines.map { line in
                    var newLine = line
                    if line.type == .addition {
                        newLine = DiffLine(
                            type: .deletion,
                            content: line.content,
                            oldLineNumber: line.newLineNumber,
                            newLineNumber: line.oldLineNumber
                        )
                    } else if line.type == .deletion {
                        newLine = DiffLine(
                            type: .addition,
                            content: line.content,
                            oldLineNumber: line.newLineNumber,
                            newLineNumber: line.oldLineNumber
                        )
                    }
                    return newLine
                }
            )
        }
    }

    private var changesOnlyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ForEach(fileDiff.hunks) { hunk in
                    VStack(alignment: .leading, spacing: 0) {
                        // Hunk header
                        Text(hunk.header)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .foregroundColor(AppTheme.accent)
                            .padding(DesignTokens.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.accent.opacity(0.08))

                        // Only show changed lines
                        ForEach(hunk.lines.filter { $0.type != .context }) { line in
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: line.type == .addition ? "plus" : "minus")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(line.type == .addition ? AppTheme.diffAddition : AppTheme.diffDeletion)

                                Text(line.content)
                                    .font(DesignTokens.Typography.diffLine)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 4)
                            .background(line.type == .addition ? AppTheme.diffAdditionBg : AppTheme.diffDeletionBg)
                        }
                    }
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.lg)
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func updateVersionSelection() {
        if let commitA = selectedCommitA {
            selectedVersionA = commitA.sha
        }
        if let commitB = selectedCommitB {
            selectedVersionB = commitB.sha
        }
    }
}

// MARK: - Kaleidoscope View Mode (Exact names from Kaleidoscope)

enum KaleidoscopeViewMode: String, CaseIterable {
    case blocks = "Blocks"
    case fluid = "Fluid"
    case unified = "Unified"

    var icon: String {
        switch self {
        case .blocks: return "rectangle.split.2x1"
        case .fluid: return "point.3.connected.trianglepath.dotted"
        case .unified: return "rectangle.stack"
        }
    }
}

// MARK: - View Mode Button

struct ViewModeButton: View {
    let mode: KaleidoscopeViewMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: mode.icon)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)

                Text(mode.rawValue)
                    .font(DesignTokens.Typography.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(isSelected ? AppTheme.accent : (isHovered ? AppTheme.hover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Toolbar Toggle

struct ToolbarToggle: View {
    let icon: String
    let isActive: Bool
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(isActive ? AppTheme.accent.opacity(0.15) : (isHovered ? AppTheme.hover : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(isHovered ? AppTheme.hover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#if DEBUG
struct KaleidoscopeDiffView_Previews: PreviewProvider {
    static var sampleCommits: [Commit] {
        [
            Commit(
                id: UUID(),
                sha: "380fe8c2a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
                shortSHA: "380fe8c2",
                message: "Add new feature for user authentication\n\nThis commit adds OAuth2 support and improves security.",
                summary: "Add new feature for user authentication",
                body: "This commit adds OAuth2 support and improves security.",
                author: "Luke Sandberg",
                authorEmail: "luke@example.com",
                authorDate: Date().addingTimeInterval(-3600),
                committer: "Luke Sandberg",
                committerEmail: "luke@example.com",
                committerDate: Date().addingTimeInterval(-3600),
                parentSHAs: []
            ),
            Commit(
                id: UUID(),
                sha: "1300acfeb2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1",
                shortSHA: "1300acfe",
                message: "Fix authentication bug in login flow",
                summary: "Fix authentication bug in login flow",
                body: nil,
                author: "Niklas Mischkulnig",
                authorEmail: "niklas@example.com",
                authorDate: Date().addingTimeInterval(-7200),
                committer: "Niklas Mischkulnig",
                committerEmail: "niklas@example.com",
                committerDate: Date().addingTimeInterval(-7200),
                parentSHAs: []
            ),
        ]
    }

    static var sampleDiff: FileDiff {
        FileDiff(
            oldPath: "turbopack/crates/turbopack-core/src/resolve/mod.rs",
            newPath: "turbopack/crates/turbopack-core/src/resolve/mod.rs",
            status: .modified,
            hunks: [
                DiffHunk(
                    header: "@@ -16,8 +16,9 @@ use turbo_tasks::{",
                    oldStart: 16,
                    oldLines: 8,
                    newStart: 16,
                    newLines: 9,
                    lines: [
                        DiffLine(type: .context, content: "use turbo_tasks::{", oldLineNumber: 16, newLineNumber: 16),
                        DiffLine(type: .deletion, content: "    TryJoinIterExt, Value, Vc, trace::TraceRawVcs,", oldLineNumber: 17, newLineNumber: nil),
                        DiffLine(type: .addition, content: "    trace::TraceRawVcs, TryJoinIterExt, Value, Vc,", oldLineNumber: nil, newLineNumber: 17),
                        DiffLine(type: .context, content: "};", oldLineNumber: 18, newLineNumber: 18),
                    ]
                ),
            ],
            additions: 39,
            deletions: 15
        )
    }

    static var previews: some View {
        KaleidoscopeDiffView(
            fileDiff: sampleDiff,
            commits: sampleCommits
        )
        .frame(width: 1400, height: 800)
    }
}
#endif
