import SwiftUI

// MARK: - Diff Side Enum

enum DiffSide {
    case left   // Old version
    case right  // New version
}

// MARK: - Fast Diff Line (Split View)

/// Optimized diff line rendering for split view
/// Shows one side (left or right) with optional word-level highlighting
struct FastDiffLine: View {
    @StateObject private var themeManager = ThemeManager.shared

    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let paired: DiffLine?

    var body: some View {
        HStack(spacing: 0) {
            // Kaleidoscope-style block marker (6px bar, flush to left edge)
            Rectangle()
                .fill(blockMarkerColor)
                .frame(width: 6)

            if showLineNumber {
                Text(lineNumber)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.Theme(themeManager.colors).diffLineNumber)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.leading, 8)
                    .padding(.trailing, 8)
            } else {
                Spacer().frame(width: 8) // Espacio después del marker cuando no hay line numbers
            }

            Text(indicator)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 16)

            // Use simple text for speed, word-level diff only when needed
            if shouldHighlightWords, let p = paired {
                highlightedText(old: side == .left ? line.content : p.content,
                               new: side == .right ? line.content : p.content)
                    .padding(.trailing, 8)
            } else {
                Text(line.content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(textColor)
                    .padding(.trailing, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .background(backgroundColor)
        .frame(height: 22)
    }

    private var blockMarkerColor: Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAddition
        case .deletion: return Color.Theme(themeManager.colors).diffDeletion
        default: return .clear
        }
    }

    private var shouldHighlightWords: Bool {
        paired != nil && line.type != .context && paired?.type != .context
    }

    private var lineNumber: String {
        switch side {
        case .left: return line.oldLineNumber.map { "\($0)" } ?? ""
        case .right: return line.newLineNumber.map { "\($0)" } ?? ""
        }
    }

    private var indicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    private var indicatorColor: SwiftUI.Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAddition
        case .deletion: return Color.Theme(themeManager.colors).diffDeletion
        default: return AppTheme.textMuted
        }
    }

    private var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAddition
        case .deletion: return Color.Theme(themeManager.colors).diffDeletion
        default: return AppTheme.textPrimary
        }
    }

    private var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAdditionBg
        case .deletion: return Color.Theme(themeManager.colors).diffDeletionBg
        default: return .clear
        }
    }

    @ViewBuilder
    private func highlightedText(old: String, new: String) -> some View {
        let result = WordLevelDiff.compare(oldLine: old, newLine: new)
        let segments = side == .left ? result.oldSegments : result.newSegments

        HStack(spacing: 0) {
            ForEach(segments) { seg in
                Text(seg.text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(segmentColor(seg.type))
                    .background(segmentBg(seg.type))
            }
        }
    }

    private func segmentColor(_ type: DiffSegment.SegmentType) -> SwiftUI.Color {
        switch type {
        case .added: return Color.Theme(themeManager.colors).diffAddition
        case .removed: return Color.Theme(themeManager.colors).diffDeletion
        default: return textColor
        }
    }

    private func segmentBg(_ type: DiffSegment.SegmentType) -> SwiftUI.Color {
        switch type {
        case .added: return Color.Theme(themeManager.colors).diffChangeBg
        case .removed: return Color.Theme(themeManager.colors).diffChangeBg
        default: return .clear
        }
    }
}

// MARK: - Fast Inline Line (Unified View)

/// Optimized diff line rendering for inline/unified view
/// Shows both old and new line numbers
struct FastInlineLine: View {
    @StateObject private var themeManager = ThemeManager.shared

    let line: DiffLine
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Kaleidoscope-style block marker (6px bar, flush to left edge)
            Rectangle()
                .fill(blockMarkerColor)
                .frame(width: 6)

            if showLineNumber {
                HStack(spacing: 2) {
                    Text(line.oldLineNumber.map { "\($0)" } ?? "")
                        .frame(width: 35, alignment: .trailing)
                    Text(line.newLineNumber.map { "\($0)" } ?? "")
                        .frame(width: 35, alignment: .trailing)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.Theme(themeManager.colors).diffLineNumber)
                .padding(.leading, 8)
                .padding(.trailing, 8)
            } else {
                Spacer().frame(width: 8) // Espacio después del marker cuando no hay line numbers
            }

            Text(indicator)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 16)

            Text(line.content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor)
                .padding(.trailing, 8)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .background(backgroundColor)
        .frame(height: 22)
    }

    private var blockMarkerColor: Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAddition
        case .deletion: return Color.Theme(themeManager.colors).diffDeletion
        default: return .clear
        }
    }

    private var indicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    private var indicatorColor: SwiftUI.Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAddition
        case .deletion: return Color.Theme(themeManager.colors).diffDeletion
        default: return AppTheme.textMuted
        }
    }

    private var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAddition
        case .deletion: return Color.Theme(themeManager.colors).diffDeletion
        default: return AppTheme.textPrimary
        }
    }

    private var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return Color.Theme(themeManager.colors).diffAdditionBg
        case .deletion: return Color.Theme(themeManager.colors).diffDeletionBg
        default: return .clear
        }
    }
}

// MARK: - Fast Empty Line

/// Renders an empty line placeholder in split view
/// Used when one side has content but the other doesn't
struct FastEmptyLine: View {
    @StateObject private var themeManager = ThemeManager.shared

    let showLineNumber: Bool
    var isDeleted: Bool = false  // True when line was deleted on this side
    var isAdded: Bool = false    // True when line was added on other side

    var body: some View {
        HStack(spacing: 0) {
            // Add 6px left space to align with marker
            Spacer().frame(width: 6)

            if showLineNumber {
                Text("")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.3))
                    .frame(width: 45, alignment: .trailing)
                    .padding(.leading, 8)
                    .padding(.trailing, 8)
            } else {
                Spacer().frame(width: 8)
            }

            // Show visual indicator for missing lines
            if isDeleted || isAdded {
                // Diagonal stripes pattern to indicate "no content here"
                ZStack {
                    // Background color
                    Rectangle()
                        .fill(isDeleted ? Color.Theme(themeManager.colors).diffDeletion.opacity(0.05) : Color.Theme(themeManager.colors).diffAddition.opacity(0.05))

                    // Diagonal pattern
                    GeometryReader { geo in
                        Path { path in
                            let spacing: CGFloat = 8
                            for x in stride(from: -geo.size.height, through: geo.size.width, by: spacing) {
                                path.move(to: CGPoint(x: x, y: geo.size.height))
                                path.addLine(to: CGPoint(x: x + geo.size.height, y: 0))
                            }
                        }
                        .stroke(
                            isDeleted ? Color.Theme(themeManager.colors).diffDeletion.opacity(0.15) : Color.Theme(themeManager.colors).diffAddition.opacity(0.15),
                            lineWidth: 1
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(" ")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
        .background(AppTheme.textMuted.opacity(0.03))
    }
}

// MARK: - Preview

#if DEBUG
struct DiffLineView_Previews: PreviewProvider {
    static let additionLine = DiffLine(
        type: .addition,
        content: "    func newFunction() {",
        oldLineNumber: nil,
        newLineNumber: 42
    )

    static let deletionLine = DiffLine(
        type: .deletion,
        content: "    func oldFunction() {",
        oldLineNumber: 41,
        newLineNumber: nil
    )

    static let contextLine = DiffLine(
        type: .context,
        content: "    // Comment line",
        oldLineNumber: 40,
        newLineNumber: 40
    )

    static var previews: some View {
        VStack(spacing: 16) {
            // Split view lines
            VStack(alignment: .leading, spacing: 4) {
                Text("Split View - Left Side").font(.headline)
                FastDiffLine(line: deletionLine, side: .left, showLineNumber: true, paired: additionLine)
                FastDiffLine(line: contextLine, side: .left, showLineNumber: true, paired: nil)
                FastEmptyLine(showLineNumber: true, isDeleted: false, isAdded: true)
            }

            Divider()

            // Split view lines
            VStack(alignment: .leading, spacing: 4) {
                Text("Split View - Right Side").font(.headline)
                FastDiffLine(line: additionLine, side: .right, showLineNumber: true, paired: deletionLine)
                FastDiffLine(line: contextLine, side: .right, showLineNumber: true, paired: nil)
                FastEmptyLine(showLineNumber: true, isDeleted: true, isAdded: false)
            }

            Divider()

            // Inline view lines
            VStack(alignment: .leading, spacing: 4) {
                Text("Inline View").font(.headline)
                FastInlineLine(line: deletionLine, showLineNumber: true)
                FastInlineLine(line: additionLine, showLineNumber: true)
                FastInlineLine(line: contextLine, showLineNumber: true)
            }
        }
        .padding()
        .frame(width: 600)
    }
}
#endif
