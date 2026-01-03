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
        KaleidoscopePairingEngine.calculateUnifiedLines(from: hunks)
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

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(unifiedLines) { line in
                    UnifiedLineRow(
                        line: line,
                        showLineNumber: showLineNumbers
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(DiffScrollOffsetKey.self) { offset in
            scrollOffset = offset
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        viewportHeight = geo.size.height
                        updateContentHeight()
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        viewportHeight = newHeight
                    }
                    .onChange(of: hunks) { _, _ in
                        updateContentHeight()
                    }
            }
        )
    }

    private func updateContentHeight() {
        let height = CGFloat(unifiedLines.count) * 24
        if contentHeight != height {
            contentHeight = height
        }
    }
}



// MARK: - Unified Line Row

struct UnifiedLineRow: View {
    let line: UnifiedLine
    let showLineNumber: Bool

    @StateObject private var themeManager = ThemeManager.shared

    // Character-level highlighting (Kaleidoscope-style)
    private var highlightedContent: AttributedString {
        guard let paired = line.pairedContent,
              line.type != .context,
              line.type != .hunkHeader else {
            return AttributedString(line.content)
        }

        let oldContent = line.type == .deletion ? line.content : paired
        let newContent = line.type == .addition ? line.content : paired

        let diffResult = WordLevelDiff.compare(oldLine: oldContent, newLine: newContent)
        let segments = line.type == .deletion ? diffResult.oldSegments : diffResult.newSegments

        var result = AttributedString()

        for segment in segments {
            var segmentAttr = AttributedString(segment.text)

            switch segment.type {
            case .unchanged:
                break
            case .added:
                segmentAttr.backgroundColor = AppTheme.diffAddition.opacity(0.4)
                segmentAttr.foregroundColor = AppTheme.diffAddition
            case .removed:
                segmentAttr.backgroundColor = AppTheme.diffDeletion.opacity(0.4)
                segmentAttr.foregroundColor = AppTheme.diffDeletion
            case .changed:
                let color = line.type == .addition ? AppTheme.diffAddition : AppTheme.diffDeletion
                segmentAttr.backgroundColor = color.opacity(0.4)
            }

            result.append(segmentAttr)
        }

        return result
    }

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

            // Content with character-level highlighting
            Text(highlightedContent)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(textColor(theme: theme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, DesignTokens.Spacing.sm)
        }
        .frame(height: 24)
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
                .frame(width: 14, height: 14)
                .background(AppTheme.accent)
                .cornerRadius(2)

        case .b:
            Text("B")
                .font(DesignTokens.Typography.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 14, height: 14)
                .background(AppTheme.info)
                .cornerRadius(2)

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
