import SwiftUI

// MARK: - Kaleidoscope-style Split Diff View

/// Enhanced split diff view with connected change visualization
struct KaleidoscopeSplitDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    var showConnectionLines: Bool = true
    var isFluidMode: Bool = false  // Fluid vs Blocks mode
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat

    @StateObject private var themeManager = ThemeManager.shared

    private var pairedLines: [DiffPairWithConnection] {
        var pairs: [DiffPairWithConnection] = []
        var pairId = 0

        for hunk in hunks {
            pairId += 1
            pairs.append(DiffPairWithConnection(
                id: pairId,
                left: nil,
                right: nil,
                hunkHeader: hunk.header,
                connectionType: .none
            ))

            var i = 0
            let lines = hunk.lines

            while i < lines.count {
                let line = lines[i]

                if line.type == .context {
                    pairId += 1
                    pairs.append(DiffPairWithConnection(
                        id: pairId,
                        left: line,
                        right: line,
                        hunkHeader: nil,
                        connectionType: .none
                    ))
                    i += 1
                } else {
                    // Collect block of changes
                    var deletions: [DiffLine] = []
                    var additions: [DiffLine] = []

                    // Consume consecutive deletions
                    var j = i
                    while j < lines.count && lines[j].type == .deletion {
                        deletions.append(lines[j])
                        j += 1
                    }

                    // Consume consecutive additions
                    var k = j
                    while k < lines.count && lines[k].type == .addition {
                        additions.append(lines[k])
                        k += 1
                    }

                    let maxCount = max(deletions.count, additions.count)

                    if maxCount > 0 {
                        for idx in 0..<maxCount {
                            pairId += 1
                            let left = idx < deletions.count ? deletions[idx] : nil
                            let right = idx < additions.count ? additions[idx] : nil

                            // Determine connection type
                            let connectionType: ConnectionType
                            if left != nil && right != nil {
                                connectionType = .change
                            } else if left != nil {
                                connectionType = .deletion
                            } else {
                                connectionType = .addition
                            }

                            pairs.append(DiffPairWithConnection(
                                id: pairId,
                                left: left,
                                right: right,
                                hunkHeader: nil,
                                connectionType: connectionType
                            ))
                        }

                        i = k
                    } else {
                        i += 1
                    }
                }
            }
        }
        return pairs
    }

    var body: some View {
        GeometryReader { geometry in
            // Single synchronized ScrollView for both sides
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                GeometryReader { scrollGeometry in
                    Color.clear.preference(
                        key: DiffScrollOffsetKey.self,
                        value: -scrollGeometry.frame(in: .named("scroll")).minY
                    )
                }
                .frame(height: 0)
                HStack(spacing: 0) {
                    // Left pane (old) - OPTIMIZED with LazyVStack
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(pairedLines) { pair in
                            if let header = pair.hunkHeader {
                                KaleidoscopeHunkHeader(header: header)
                            } else if let line = pair.left {
                                KaleidoscopeDiffLine(
                                    line: line,
                                    side: .left,
                                    showLineNumber: showLineNumbers,
                                    pairedLine: pair.right
                                )
                            } else {
                                EmptyDiffLine(showLineNumber: showLineNumbers)
                            }
                        }
                    }
                    .frame(width: (geometry.size.width - 62) / 2)

                    // Center divider with connection lines
                    ZStack(alignment: .leading) {
                        // Background for connection area
                        Rectangle()
                            .fill(AppTheme.backgroundSecondary.opacity(0.5))
                            .frame(width: 60)

                        // Vertical divider
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(width: 1)
                            .offset(x: 30)

                        // Connection lines
                        ConnectionLinesView(
                            pairs: pairedLines,
                            lineHeight: 22,
                            isFluidMode: isFluidMode
                        )
                        .frame(width: 60)
                    }
                    .frame(width: 62, height: CGFloat(pairedLines.count) * 22)

                    // Right pane (new) - OPTIMIZED with LazyVStack
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(pairedLines) { pair in
                            if let header = pair.hunkHeader {
                                KaleidoscopeHunkHeader(header: header)
                            } else if let line = pair.right {
                                KaleidoscopeDiffLine(
                                    line: line,
                                    side: .right,
                                    showLineNumber: showLineNumbers,
                                    pairedLine: pair.left
                                )
                            } else {
                                EmptyDiffLine(showLineNumber: showLineNumbers)
                            }
                        }
                    }
                    .frame(width: (geometry.size.width - 62) / 2)
                }
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: ContentHeightKey.self,
                            value: contentGeometry.size.height
                        )
                    }
                )
            }
            .background(AppTheme.background)
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ContentHeightKey.self) { height in
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

    // MARK: - Connection Lines Drawing

    private func drawConnectionLines(
        context: GraphicsContext,
        size: CGSize,
        pairs: [DiffPairWithConnection],
        lineHeight: CGFloat
    ) {
        var yOffset: CGFloat = 0

        for pair in pairs {
            if pair.hunkHeader != nil {
                yOffset += lineHeight
                continue
            }

            let centerY = yOffset + lineHeight / 2

            switch pair.connectionType {
            case .change:
                // Kaleidoscope-style curved connection line
                var path = Path()
                path.move(to: CGPoint(x: 5, y: centerY))

                // Smooth bezier curve
                let controlPoint1 = CGPoint(x: size.width * 0.25, y: centerY)
                let controlPoint2 = CGPoint(x: size.width * 0.75, y: centerY)

                path.addCurve(
                    to: CGPoint(x: size.width - 5, y: centerY),
                    control1: controlPoint1,
                    control2: controlPoint2
                )

                context.stroke(
                    path,
                    with: .color(Color.blue.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

            case .deletion:
                // Deletion indicator - short line from left
                var path = Path()
                path.move(to: CGPoint(x: 5, y: centerY))
                path.addLine(to: CGPoint(x: 20, y: centerY))

                context.stroke(
                    path,
                    with: .color(AppTheme.diffDeletion.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

            case .addition:
                // Addition indicator - short line from right
                var path = Path()
                path.move(to: CGPoint(x: size.width - 20, y: centerY))
                path.addLine(to: CGPoint(x: size.width - 5, y: centerY))

                context.stroke(
                    path,
                    with: .color(AppTheme.diffAddition.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

            case .none:
                break
            }

            yOffset += lineHeight
        }
    }
}

// MARK: - Diff Pair with Connection

struct DiffPairWithConnection: Identifiable {
    let id: Int
    let left: DiffLine?
    let right: DiffLine?
    let hunkHeader: String?
    let connectionType: ConnectionType
}

enum ConnectionType {
    case none
    case change
    case deletion
    case addition
}

// MARK: - Kaleidoscope Diff Line

struct KaleidoscopeDiffLine: View {
    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let pairedLine: DiffLine?

    @StateObject private var themeManager = ThemeManager.shared

    private var lineNumber: Int? {
        side == .left ? line.oldLineNumber : line.newLineNumber
    }

    // Character-level highlighting (Kaleidoscope-style)
    private var highlightedContent: AttributedString {
        guard let paired = pairedLine,
              line.type != .context,
              paired.type != .context else {
            return AttributedString(line.content)
        }

        let oldContent = line.type == .deletion ? line.content : paired.content
        let newContent = line.type == .addition ? line.content : paired.content

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
            if showLineNumber {
                Text(lineNumber.map { String($0) } ?? "")
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(theme.textMuted)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.xs)
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
        .frame(height: 22)
        .background(backgroundColor(theme: theme))
    }

    // MARK: - Helpers

    private var changeIndicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@@"
        }
    }

    private func indicatorColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        default: return theme.textMuted
        }
    }

    private func backgroundColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return AppTheme.diffAdditionBg
        case .deletion: return AppTheme.diffDeletionBg
        case .context, .hunkHeader: return Color.clear
        }
    }

    private func lineNumberBackground(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return AppTheme.diffLineNumberBg
        case .deletion: return AppTheme.diffLineNumberBg
        case .context, .hunkHeader: return theme.backgroundSecondary
        }
    }

    private func textColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        case .context, .hunkHeader: return theme.text
        }
    }
}

// MARK: - Kaleidoscope Hunk Header

struct KaleidoscopeHunkHeader: View {
    let header: String
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "text.alignleft")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.accent)

            Text(header)
                .font(DesignTokens.Typography.commitHash)
                .foregroundColor(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 22)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(AppTheme.accent.opacity(0.08))
    }
}

// MARK: - Empty Diff Line

struct EmptyDiffLine: View {
    let showLineNumber: Bool
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: 0) {
            if showLineNumber {
                Text("")
                    .font(DesignTokens.Typography.commitHash)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.xs)
                    .background(theme.backgroundSecondary)
            }

            Rectangle()
                .fill(theme.backgroundSecondary.opacity(0.3))
                .frame(maxWidth: .infinity)
        }
        .frame(height: 22)
    }
}

// MARK: - Connection Lines View (Professional Quality)

struct ConnectionLinesView: View {
    let pairs: [DiffPairWithConnection]
    let lineHeight: CGFloat
    var isFluidMode: Bool = false

    var body: some View {
        Canvas { context, size in
            var yOffset: CGFloat = 0

            for pair in pairs {
                let centerY = yOffset + lineHeight / 2

                switch pair.connectionType {
                case .change:
                    // Professional curved connection - Kaleidoscope style
                    if isFluidMode {
                        drawFluidCurve(
                            context: context,
                            from: CGPoint(x: 0, y: centerY),
                            to: CGPoint(x: size.width, y: centerY),
                            color: Color(red: 0.2, green: 0.6, blue: 1.0)
                        )
                    } else {
                        drawBlocksCurve(
                            context: context,
                            from: CGPoint(x: 0, y: centerY),
                            to: CGPoint(x: size.width, y: centerY),
                            color: Color(red: 0.2, green: 0.6, blue: 1.0)
                        )
                    }

                case .deletion:
                    // Elegant deletion indicator
                    drawDeletionLine(
                        context: context,
                        at: centerY,
                        width: size.width
                    )

                case .addition:
                    // Elegant addition indicator
                    drawAdditionLine(
                        context: context,
                        at: centerY,
                        width: size.width
                    )

                case .none:
                    break
                }

                yOffset += lineHeight
            }
        }
    }

    // Fluid mode: Super smooth flowing curves
    private func drawFluidCurve(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)

        // Ultra-smooth flowing curve
        let distance = to.x - from.x
        let cp1 = CGPoint(x: from.x + distance * 0.25, y: from.y - 3)
        let cp2 = CGPoint(x: to.x - distance * 0.25, y: to.y + 3)

        path.addCurve(to: to, control1: cp1, control2: cp2)

        var contextCopy = context
        contextCopy.opacity = 0.9

        // Main line - thicker for fluid
        contextCopy.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )

        // Strong glow for fluid effect
        contextCopy.opacity = 0.4
        contextCopy.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }

    // Blocks mode: Cleaner, more structured curves
    private func drawBlocksCurve(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)

        // Cleaner S-curve
        let distance = to.x - from.x
        let cp1 = CGPoint(x: from.x + distance * 0.3, y: from.y)
        let cp2 = CGPoint(x: to.x - distance * 0.3, y: to.y)

        path.addCurve(to: to, control1: cp1, control2: cp2)

        var contextCopy = context
        contextCopy.opacity = 0.85

        // Main line
        contextCopy.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )

        // Subtle glow
        contextCopy.opacity = 0.25
        contextCopy.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawDeletionLine(context: GraphicsContext, at y: CGFloat, width: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: width * 0.35, y: y))

        var contextCopy = context
        contextCopy.opacity = 0.7

        contextCopy.stroke(
            path,
            with: .color(Color(red: 1.0, green: 0.3, blue: 0.3)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 2])
        )
    }

    private func drawAdditionLine(context: GraphicsContext, at y: CGFloat, width: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: width * 0.65, y: y))
        path.addLine(to: CGPoint(x: width, y: y))

        var contextCopy = context
        contextCopy.opacity = 0.7

        contextCopy.stroke(
            path,
            with: .color(Color(red: 0.3, green: 0.8, blue: 0.4)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 2])
        )
    }
}

// MARK: - Content Height Preference Key

struct ContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Preview

#if DEBUG
struct KaleidoscopeSplitDiffView_Previews: PreviewProvider {
    static var previews: some View {
        KaleidoscopeSplitDiffView(
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
