import SwiftUI
import AppKit

// MARK: - Large File Diff View (Paginated for performance)

/// High-performance diff view for large files with pagination
struct LargeFileDiffViewWrapper: View {
    @StateObject private var themeManager = ThemeManager.shared

    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat

    // Pagination settings
    private static let initialLineLimit = 1000
    private static let loadMoreIncrement = 2000

    @State private var displayedLineCount: Int = LargeFileDiffViewWrapper.initialLineLimit
    @State private var isLoadingMore = false

    // Total line count
    private var totalLineCount: Int {
        hunks.reduce(0) { $0 + $1.lines.count + 1 } // +1 for hunk header
    }

    // Only compute lines up to displayedLineCount
    private var visibleLines: [LargeDiffLine] {
        var result: [LargeDiffLine] = []
        var lineId = 0
        var totalAdded = 0

        for (hunkIndex, hunk) in hunks.enumerated() {
            guard totalAdded < displayedLineCount else { break }

            // Add hunk header
            lineId += 1
            result.append(LargeDiffLine(
                id: lineId,
                type: .hunkHeader,
                content: hunk.header,
                oldLineNumber: nil,
                newLineNumber: nil,
                hunkIndex: hunkIndex
            ))
            totalAdded += 1

            // Add lines up to limit
            for line in hunk.lines {
                guard totalAdded < displayedLineCount else { break }

                lineId += 1
                result.append(LargeDiffLine(
                    id: lineId,
                    type: line.type,
                    content: line.content,
                    oldLineNumber: line.oldLineNumber,
                    newLineNumber: line.newLineNumber,
                    hunkIndex: hunkIndex
                ))
                totalAdded += 1
            }
        }

        return result
    }

    private var hasMoreLines: Bool {
        displayedLineCount < totalLineCount
    }

    private var remainingLines: Int {
        max(0, totalLineCount - displayedLineCount)
    }

    var body: some View {
        UnifiedDiffScrollView(scrollOffset: $scrollOffset, viewportHeight: $viewportHeight) {
            LazyVStack(spacing: 0) {
                ForEach(visibleLines) { line in
                    LargeDiffLineView(line: line, showLineNumbers: showLineNumbers)
                }

                // Load more button
                if hasMoreLines {
                    Button(action: loadMore) {
                        HStack {
                            if isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: DesignTokens.Size.iconMD, height: DesignTokens.Size.iconMD)
                            }
                            Text("Load \(min(remainingLines, Self.loadMoreIncrement)) more lines (\(remainingLines) remaining)")
                                .font(DesignTokens.Typography.callout)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(AppTheme.backgroundSecondary)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accent)
                }
            }
        }

        .background(AppTheme.background)
    }

    private func loadMore() {
        isLoadingMore = true
        // Use async to avoid blocking UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            displayedLineCount += Self.loadMoreIncrement
            isLoadingMore = false
        }
    }
}

/// Line model for large diff view
private struct LargeDiffLine: Identifiable {
    let id: Int
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let hunkIndex: Int
}

/// Simple line view for large diffs (minimal overhead)
private struct LargeDiffLineView: View {
    @StateObject private var themeManager = ThemeManager.shared

    let line: LargeDiffLine
    let showLineNumbers: Bool

    var body: some View {
        HStack(spacing: 0) {
            if line.type == .hunkHeader {
                // Hunk header
                Text(line.content)
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(AppTheme.info)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(AppTheme.info.opacity(0.1))
            } else {
                // Regular line
                if showLineNumbers {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Text(line.oldLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 35, alignment: .trailing)
                        Text(line.newLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 35, alignment: .trailing)
                    }
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                    .padding(.trailing, DesignTokens.Spacing.xs)
                }

                Text(prefix)
                    .font(DesignTokens.Typography.diffLine)
                    .foregroundColor(prefixColor)
                    .frame(width: 14)

                Text(line.content)
                    .font(DesignTokens.Typography.diffLine)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
        .background(backgroundColor)
    }

    private var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    private var prefixColor: SwiftUI.Color {
        let theme = Color.Theme(themeManager.colors)
        switch line.type {
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        default: return .secondary
        }
    }

    private var textColor: SwiftUI.Color {
        let theme = Color.Theme(themeManager.colors)
        switch line.type {
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        default: return theme.text
        }
    }

    private var backgroundColor: SwiftUI.Color {
        let theme = Color.Theme(themeManager.colors)
        switch line.type {
        case .addition: return theme.diffAdditionBg
        case .deletion: return theme.diffDeletionBg
        default: return .clear
        }
    }
}

/// Custom NSView for high-performance diff rendering
/// Only draws visible lines for O(1) scroll performance
class LargeFileDiffNSView: NSView {
    static let lineHeight: CGFloat = 18
    static let lineNumberWidth: CGFloat = 80
    static let prefixWidth: CGFloat = 16
    static let padding: CGFloat = 8

    private let themeManager = ThemeManager.shared

    var hunks: [DiffHunk] = []
    var showLineNumbers: Bool = true

    private struct LayoutItem {
        enum Kind {
            case hunkHeader(Int)
            case line(hunkIndex: Int, lineIndex: Int)
        }
        let kind: Kind
        let y: CGFloat
    }

    private var layoutItems: [LayoutItem] = []
    var totalHeight: CGFloat = 0

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: totalHeight)
    }

    func recalculateLayout() {
        layoutItems.removeAll()
        var y: CGFloat = 0

        for (hunkIndex, hunk) in hunks.enumerated() {
            // Hunk header
            layoutItems.append(LayoutItem(kind: .hunkHeader(hunkIndex), y: y))
            y += Self.lineHeight + 4

            // Lines
            for (lineIndex, _) in hunk.lines.enumerated() {
                layoutItems.append(LayoutItem(kind: .line(hunkIndex: hunkIndex, lineIndex: lineIndex), y: y))
                y += Self.lineHeight
            }

            y += 4 // Spacing between hunks
        }

        totalHeight = max(y, 100)
        // Set both frame height and width to ensure proper scrolling
        let currentWidth = max(frame.size.width, 800)
        frame = NSRect(x: 0, y: 0, width: currentWidth, height: totalHeight)
        invalidateIntrinsicContentSize()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Background
        context.setFillColor(NSColor(AppTheme.background).cgColor)
        context.fill(dirtyRect)

        let visibleMinY = dirtyRect.minY
        let visibleMaxY = dirtyRect.maxY

        // Only draw visible items
        for item in layoutItems {
            let itemTop = item.y
            let itemBottom = item.y + Self.lineHeight

            guard itemBottom >= visibleMinY && itemTop <= visibleMaxY else { continue }

            switch item.kind {
            case .hunkHeader(let hunkIndex):
                drawHunkHeader(hunkIndex: hunkIndex, at: item.y, width: bounds.width, context: context)
            case .line(let hunkIndex, let lineIndex):
                if hunkIndex < hunks.count && lineIndex < hunks[hunkIndex].lines.count {
                    drawLine(hunks[hunkIndex].lines[lineIndex], at: item.y, width: bounds.width, context: context)
                }
            }
        }
    }

    private func drawHunkHeader(hunkIndex: Int, at y: CGFloat, width: CGFloat, context: CGContext) {
        guard hunkIndex < hunks.count else { return }
        let hunk = hunks[hunkIndex]

        // Background
        let rect = CGRect(x: 0, y: y, width: width, height: Self.lineHeight + 4)
        context.setFillColor(NSColor.cyan.withAlphaComponent(0.1).cgColor)
        context.fill(rect)

        // Text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.cyan
        ]
        let textRect = CGRect(x: Self.padding, y: y + 2, width: width - Self.padding * 2, height: Self.lineHeight)
        (hunk.header as NSString).draw(in: textRect, withAttributes: attrs)
    }

    private func drawLine(_ line: DiffLine, at y: CGFloat, width: CGFloat, context: CGContext) {
        let rect = CGRect(x: 0, y: y, width: width, height: Self.lineHeight)

        // Background
        let bgColor: NSColor
        switch line.type {
        case .addition: bgColor = NSColor.systemGreen.withAlphaComponent(0.1)
        case .deletion: bgColor = NSColor.systemRed.withAlphaComponent(0.1)
        default: bgColor = .clear
        }
        if bgColor != .clear {
            context.setFillColor(bgColor.cgColor)
            context.fill(rect)
        }

        var x: CGFloat = Self.padding

        // Line numbers
        if showLineNumbers {
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.6)
            ]

            let oldNum = line.oldLineNumber.map { String($0) } ?? ""
            let oldRect = CGRect(x: x, y: y, width: 35, height: Self.lineHeight)
            (oldNum as NSString).draw(in: oldRect, withAttributes: numAttrs)

            let newNum = line.newLineNumber.map { String($0) } ?? ""
            let newRect = CGRect(x: x + 38, y: y, width: 35, height: Self.lineHeight)
            (newNum as NSString).draw(in: newRect, withAttributes: numAttrs)

            x += Self.lineNumberWidth
        }

        // Prefix
        let prefix: String
        let prefixColor: NSColor
        switch line.type {
        case .addition: prefix = "+"; prefixColor = .systemGreen
        case .deletion: prefix = "-"; prefixColor = .systemRed
        case .context: prefix = " "; prefixColor = .secondaryLabelColor
        case .hunkHeader: prefix = "@"; prefixColor = .cyan
        }

        let prefixAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: prefixColor
        ]
        let prefixRect = CGRect(x: x, y: y, width: Self.prefixWidth, height: Self.lineHeight)
        (prefix as NSString).draw(in: prefixRect, withAttributes: prefixAttrs)
        x += Self.prefixWidth

        // Content
        let contentColor: NSColor
        switch line.type {
        case .addition: contentColor = .systemGreen
        case .deletion: contentColor = .systemRed
        default: contentColor = .textColor
        }

        let contentAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: contentColor
        ]
        let contentRect = CGRect(x: x, y: y, width: width - x - Self.padding, height: Self.lineHeight)
        (line.content as NSString).draw(in: contentRect, withAttributes: contentAttrs)
    }
}
