import SwiftUI

// MARK: - Kaleidoscope Unified View

/// True Unified view with A/B labels in the left margin (Kaleidoscope-style)
struct KaleidoscopeUnifiedView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat

    @StateObject private var themeManager = ThemeManager.shared

    private var unifiedLines: [UnifiedLine] {
        var lines: [UnifiedLine] = []
        var lineId = 0

        for hunk in hunks {
            lineId += 1
            lines.append(UnifiedLine(
                id: lineId,
                content: hunk.header,
                type: .hunkHeader,
                side: .both,
                oldLineNumber: nil,
                newLineNumber: nil
            ))

            for line in hunk.lines {
                lineId += 1
                let side: UnifiedSide
                if line.type == .deletion {
                    side = .a
                } else if line.type == .addition {
                    side = .b
                } else {
                    side = .both
                }

                lines.append(UnifiedLine(
                    id: lineId,
                    content: line.content,
                    type: line.type,
                    side: side,
                    oldLineNumber: line.oldLineNumber,
                    newLineNumber: line.newLineNumber
                ))
            }
        }

        return lines
    }

    var body: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            GeometryReader { scrollGeometry in
                Color.clear.preference(
                    key: DiffScrollOffsetKey.self,
                    value: -scrollGeometry.frame(in: .named("scroll")).minY
                )
            }
            .frame(height: 0)

            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(unifiedLines) { line in
                    UnifiedLineRow(
                        line: line,
                        showLineNumber: showLineNumbers
                    )
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: UnifiedContentHeightKey.self,
                        value: geometry.size.height
                    )
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(UnifiedContentHeightKey.self) { height in
            contentHeight = height
        }
        .onPreferenceChange(DiffScrollOffsetKey.self) { offset in
            scrollOffset = offset
        }
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    viewportHeight = geo.size.height
                }
                .onChange(of: geo.size.height) { newHeight in
                    viewportHeight = newHeight
                }
            }
        )
    }
}

// MARK: - Unified Line Model

struct UnifiedLine: Identifiable {
    let id: Int
    let content: String
    let type: DiffLineType
    let side: UnifiedSide
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

enum UnifiedSide {
    case a      // Left side (deletions)
    case b      // Right side (additions)
    case both   // Context lines
}

// MARK: - Unified Line Row

struct UnifiedLineRow: View {
    let line: UnifiedLine
    let showLineNumber: Bool

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: 0) {
            // A/B label in left margin (Kaleidoscope-style)
            sideLabel
                .frame(width: 24)

            // Line numbers
            if showLineNumber {
                HStack(spacing: 4) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .font(DesignTokens.Typography.commitHash)
                        .foregroundColor(theme.textMuted)
                        .frame(width: 50, alignment: .trailing)

                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .font(DesignTokens.Typography.commitHash)
                        .foregroundColor(theme.textMuted)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .background(lineNumberBackground(theme: theme))
            }

            // Change indicator
            Text(changeIndicator)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(indicatorColor(theme: theme))
                .frame(width: 20)

            // Content
            Text(line.content)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(textColor(theme: theme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, DesignTokens.Spacing.sm)
        }
        .frame(height: 22)
        .background(backgroundColor(theme: theme))
    }

    // MARK: - Components

    @ViewBuilder
    private var sideLabel: some View {
        switch line.side {
        case .a:
            Text("A")
                .font(DesignTokens.Typography.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(AppTheme.accent)
                .cornerRadius(3)

        case .b:
            Text("B")
                .font(DesignTokens.Typography.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(AppTheme.info)
                .cornerRadius(3)

        case .both:
            Color.clear
        }
    }

    private var changeIndicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@@"
        }
    }

    // MARK: - Helpers

    private func indicatorColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        case .hunkHeader: return AppTheme.accent
        default: return theme.textMuted
        }
    }

    private func backgroundColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return AppTheme.diffAdditionBg
        case .deletion: return AppTheme.diffDeletionBg
        case .hunkHeader: return AppTheme.accent.opacity(0.08)
        case .context: return Color.clear
        }
    }

    private func lineNumberBackground(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition, .deletion: return AppTheme.diffLineNumberBg
        case .context, .hunkHeader: return theme.backgroundSecondary
        }
    }

    private func textColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        case .hunkHeader: return AppTheme.accent
        case .context: return theme.text
        }
    }
}

// MARK: - Content Height Preference Key

struct UnifiedContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Preview

#if DEBUG
struct KaleidoscopeUnifiedView_Previews: PreviewProvider {
    static var previews: some View {
        KaleidoscopeUnifiedView(
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
            showLineNumbers: true,
            scrollOffset: .constant(0),
            viewportHeight: .constant(400),
            contentHeight: .constant(800)
        )
        .frame(width: 1000, height: 600)
    }
}
#endif
