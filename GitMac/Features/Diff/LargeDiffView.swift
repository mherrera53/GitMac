import SwiftUI
import AppKit
import os.signpost

// MARK: - Large File Mode Diff View

/// High-performance diff view for large files
/// Uses NSView with constant row height for O(1) scroll performance
struct LargeDiffView: NSViewRepresentable {
    let hunks: [StreamingDiffHunk]
    let filePath: String
    let isStaged: Bool
    let options: DiffOptions

    var onExpandHunk: ((Int) -> Void)?
    var onCollapseHunk: ((Int) -> Void)?
    var onStageHunk: ((Int) -> Void)?
    var onDiscardHunk: ((Int) -> Void)?

    @Binding var searchQuery: String
    @Binding var currentMatchIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(AppTheme.background)

        let diffView = LargeDiffNSView(frame: .zero)
        diffView.coordinator = context.coordinator
        diffView.autoresizingMask = [.width]

        scrollView.documentView = diffView
        context.coordinator.diffView = diffView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let diffView = scrollView.documentView as? LargeDiffNSView else { return }

        diffView.hunks = hunks
        diffView.options = options
        diffView.searchQuery = searchQuery
        diffView.currentMatchIndex = currentMatchIndex

        diffView.recalculateLayout()
        diffView.needsDisplay = true
    }

    class Coordinator: NSObject {
        var parent: LargeDiffView
        weak var diffView: LargeDiffNSView?
        weak var scrollView: NSScrollView?

        init(_ parent: LargeDiffView) {
            self.parent = parent
        }

        func expandHunk(at index: Int) {
            parent.onExpandHunk?(index)
        }

        func collapseHunk(at index: Int) {
            parent.onCollapseHunk?(index)
        }

        func stageHunk(at index: Int) {
            parent.onStageHunk?(index)
        }

        func discardHunk(at index: Int) {
            parent.onDiscardHunk?(index)
        }
    }
}

// MARK: - NSView Implementation

/// Custom NSView for high-performance diff rendering
/// Uses direct CoreGraphics drawing with constant row height
class LargeDiffNSView: NSView {

    // MARK: - Configuration

    static let lineHeight: CGFloat = 18
    static let lineNumberWidth: CGFloat = 50
    static let gutterWidth: CGFloat = 20
    static let prefixWidth: CGFloat = 16
    static let horizontalPadding: CGFloat = 8

    private static let signpostLog = OSLog(subsystem: "com.gitmac.LargeDiffView", category: "Rendering")

    // MARK: - Data

    var hunks: [StreamingDiffHunk] = []
    var options: DiffOptions = .default
    var searchQuery: String = ""
    var currentMatchIndex: Int = 0

    weak var coordinator: LargeDiffView.Coordinator?

    // MARK: - Layout Cache

    private struct LayoutItem {
        enum ItemType {
            case hunkHeader(hunkIndex: Int)
            case line(hunkIndex: Int, lineIndex: Int)
            case collapsedIndicator(hunkIndex: Int, lineCount: Int)
        }

        let type: ItemType
        let yOffset: CGFloat
    }

    private var layoutItems: [LayoutItem] = []
    private var totalHeight: CGFloat = 0

    // MARK: - Rendering

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: totalHeight)
    }

    func recalculateLayout() {
        layoutItems.removeAll()
        var y: CGFloat = 0

        for (hunkIndex, hunk) in hunks.enumerated() {
            // Hunk header
            layoutItems.append(LayoutItem(type: .hunkHeader(hunkIndex: hunkIndex), yOffset: y))
            y += Self.lineHeight + 8 // Header has extra padding

            if hunk.isCollapsed {
                // Collapsed indicator
                let lineCount = hunk.lines?.count ?? hunk.estimatedLineCount
                layoutItems.append(LayoutItem(type: .collapsedIndicator(hunkIndex: hunkIndex, lineCount: lineCount), yOffset: y))
                y += Self.lineHeight
            } else if let lines = hunk.lines {
                // Expanded lines
                for (lineIndex, _) in lines.enumerated() {
                    layoutItems.append(LayoutItem(type: .line(hunkIndex: hunkIndex, lineIndex: lineIndex), yOffset: y))
                    y += Self.lineHeight
                }
            }

            y += 8 // Spacing between hunks
        }

        totalHeight = max(y, 100)
        frame.size.height = totalHeight
        invalidateIntrinsicContentSize()
    }

    override func draw(_ dirtyRect: NSRect) {
        os_signpost(.begin, log: Self.signpostLog, name: "Draw")
        defer { os_signpost(.end, log: Self.signpostLog, name: "Draw") }

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Background
        context.setFillColor(NSColor(AppTheme.background).cgColor)
        context.fill(dirtyRect)

        // Only draw visible items
        let visibleRange = dirtyRect.minY...dirtyRect.maxY

        for item in layoutItems {
            let itemTop = item.yOffset
            let itemBottom = item.yOffset + Self.lineHeight

            // Skip items outside visible range
            guard itemBottom >= visibleRange.lowerBound && itemTop <= visibleRange.upperBound else {
                continue
            }

            drawItem(item, in: context, width: bounds.width)
        }
    }

    private func drawItem(_ item: LayoutItem, in context: CGContext, width: CGFloat) {
        let y = item.yOffset

        switch item.type {
        case .hunkHeader(let hunkIndex):
            drawHunkHeader(hunkIndex: hunkIndex, at: y, width: width, context: context)

        case .line(let hunkIndex, let lineIndex):
            guard hunkIndex < hunks.count,
                  let lines = hunks[hunkIndex].lines,
                  lineIndex < lines.count else { return }
            drawLine(lines[lineIndex], at: y, width: width, context: context)

        case .collapsedIndicator(let hunkIndex, let lineCount):
            drawCollapsedIndicator(hunkIndex: hunkIndex, lineCount: lineCount, at: y, width: width, context: context)
        }
    }

    private func drawHunkHeader(hunkIndex: Int, at y: CGFloat, width: CGFloat, context: CGContext) {
        guard hunkIndex < hunks.count else { return }
        let hunk = hunks[hunkIndex]

        // Background
        let rect = CGRect(x: 0, y: y, width: width, height: Self.lineHeight + 8)
        context.setFillColor(NSColor(AppTheme.accent).withAlphaComponent(0.1).cgColor)
        context.fill(rect)

        // Header text
        let headerText = hunk.header
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(AppTheme.accent)
        ]

        let textRect = CGRect(x: Self.horizontalPadding, y: y + 4, width: width - Self.horizontalPadding * 2, height: Self.lineHeight)
        (headerText as NSString).draw(in: textRect, withAttributes: attrs)

        // Expand/Collapse indicator
        let indicatorText = hunk.isCollapsed ? "▶" : "▼"
        let indicatorAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor(AppTheme.textSecondary)
        ]
        let indicatorRect = CGRect(x: width - 30, y: y + 4, width: 20, height: Self.lineHeight)
        (indicatorText as NSString).draw(in: indicatorRect, withAttributes: indicatorAttrs)
    }

    private func drawLine(_ line: DiffLine, at y: CGFloat, width: CGFloat, context: CGContext) {
        let rect = CGRect(x: 0, y: y, width: width, height: Self.lineHeight)

        // Background color based on line type
        let bgColor: NSColor
        switch line.type {
        case .addition:
            bgColor = NSColor(AppTheme.accentGreen).withAlphaComponent(0.1)
        case .deletion:
            bgColor = NSColor(AppTheme.accentRed).withAlphaComponent(0.1)
        default:
            bgColor = .clear
        }

        if bgColor != .clear {
            context.setFillColor(bgColor.cgColor)
            context.fill(rect)
        }

        var x: CGFloat = Self.horizontalPadding

        // Line numbers
        let lineNumAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(AppTheme.textMuted)
        ]

        // Old line number
        let oldNum = line.oldLineNumber.map { String($0) } ?? ""
        let oldNumRect = CGRect(x: x, y: y, width: 35, height: Self.lineHeight)
        (oldNum as NSString).draw(in: oldNumRect, withAttributes: lineNumAttrs)
        x += 40

        // New line number
        let newNum = line.newLineNumber.map { String($0) } ?? ""
        let newNumRect = CGRect(x: x, y: y, width: 35, height: Self.lineHeight)
        (newNum as NSString).draw(in: newNumRect, withAttributes: lineNumAttrs)
        x += 40

        // Prefix
        let prefix: String
        let prefixColor: NSColor
        switch line.type {
        case .addition:
            prefix = "+"
            prefixColor = NSColor(AppTheme.accentGreen)
        case .deletion:
            prefix = "-"
            prefixColor = NSColor(AppTheme.accentRed)
        case .context:
            prefix = " "
            prefixColor = NSColor(AppTheme.textMuted)
        case .hunkHeader:
            prefix = "@"
            prefixColor = NSColor(AppTheme.accent)
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
        case .addition:
            contentColor = NSColor(AppTheme.accentGreen)
        case .deletion:
            contentColor = NSColor(AppTheme.accentRed)
        default:
            contentColor = NSColor(AppTheme.textPrimary)
        }

        let contentAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: contentColor
        ]

        let contentRect = CGRect(x: x, y: y, width: width - x - Self.horizontalPadding, height: Self.lineHeight)
        (line.content as NSString).draw(in: contentRect, withAttributes: contentAttrs)
    }

    private func drawCollapsedIndicator(hunkIndex: Int, lineCount: Int, at y: CGFloat, width: CGFloat, context: CGContext) {
        let rect = CGRect(x: Self.horizontalPadding, y: y, width: width - Self.horizontalPadding * 2, height: Self.lineHeight)

        // Background
        context.setFillColor(NSColor(AppTheme.backgroundSecondary).cgColor)
        context.fill(rect)

        // Text
        let text = "... \(lineCount) lines (click to expand)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(AppTheme.textMuted)
        ]

        let textRect = CGRect(x: Self.horizontalPadding + 8, y: y, width: width - Self.horizontalPadding * 2, height: Self.lineHeight)
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Find clicked item
        for item in layoutItems {
            let itemRect = CGRect(x: 0, y: item.yOffset, width: bounds.width, height: Self.lineHeight + 8)
            if itemRect.contains(location) {
                handleClick(on: item)
                return
            }
        }
    }

    private func handleClick(on item: LayoutItem) {
        switch item.type {
        case .hunkHeader(let hunkIndex):
            toggleHunk(at: hunkIndex)
        case .collapsedIndicator(let hunkIndex, _):
            coordinator?.expandHunk(at: hunkIndex)
        case .line:
            break // Could implement line selection here
        }
    }

    private func toggleHunk(at index: Int) {
        guard index < hunks.count else { return }
        if hunks[index].isCollapsed {
            coordinator?.expandHunk(at: index)
        } else {
            coordinator?.collapseHunk(at: index)
        }
    }

    // MARK: - Keyboard Navigation

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            scrollToPreviousHunk()
        case 125: // Down arrow
            scrollToNextHunk()
        case 36: // Enter - toggle expand/collapse
            toggleCurrentHunk()
        default:
            super.keyDown(with: event)
        }
    }

    private func scrollToPreviousHunk() {
        // Find previous hunk header
        guard let scrollView = superview?.superview as? NSScrollView else { return }
        let visibleY = scrollView.contentView.bounds.origin.y

        for item in layoutItems.reversed() {
            if case .hunkHeader = item.type, item.yOffset < visibleY - 10 {
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, item.yOffset - 20)))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                return
            }
        }
    }

    private func scrollToNextHunk() {
        guard let scrollView = superview?.superview as? NSScrollView else { return }
        let visibleY = scrollView.contentView.bounds.origin.y

        for item in layoutItems {
            if case .hunkHeader = item.type, item.yOffset > visibleY + 10 {
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: item.yOffset - 20))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                return
            }
        }
    }

    private func toggleCurrentHunk() {
        guard let scrollView = superview?.superview as? NSScrollView else { return }
        let visibleY = scrollView.contentView.bounds.origin.y

        // Find the hunk at current scroll position
        for item in layoutItems {
            if case .hunkHeader(let index) = item.type,
               item.yOffset >= visibleY && item.yOffset < visibleY + bounds.height {
                toggleHunk(at: index)
                return
            }
        }
    }
}

// MARK: - SwiftUI Wrapper for Integration

/// Container view that manages LargeDiffView with DiffEngine
struct OptimizedDiffView: View {
    let filePath: String
    let repoPath: String
    let staged: Bool

    @State private var hunks: [StreamingDiffHunk] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var options: DiffOptions = .default
    @State private var isLargeFileMode = false
    @State private var searchQuery = ""
    @State private var currentMatchIndex = 0

    private let diffEngine = DiffEngine()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading diff...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(DesignTokens.Typography.iconXXXL)
                        .foregroundColor(AppTheme.accentOrange)
                    Text("Failed to load diff")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hunks.isEmpty {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "doc.text")
                        .font(DesignTokens.Typography.iconXXXL)
                        .foregroundColor(AppTheme.textMuted)
                    Text("No changes")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLargeFileMode {
                // Use optimized NSView for large files
                LargeDiffView(
                    hunks: hunks,
                    filePath: filePath,
                    isStaged: staged,
                    options: options,
                    onExpandHunk: { index in expandHunk(at: index) },
                    onCollapseHunk: { index in collapseHunk(at: index) },
                    onStageHunk: nil, // TODO: Implement
                    onDiscardHunk: nil, // TODO: Implement
                    searchQuery: $searchQuery,
                    currentMatchIndex: $currentMatchIndex
                )
            } else {
                // Use standard SwiftUI view for smaller files
                StandardDiffContent(hunks: hunks, options: options)
            }
        }
        .background(AppTheme.background)
        .task {
            await loadDiff()
        }
    }

    private func loadDiff() async {
        isLoading = true
        error = nil

        do {
            // Preflight check
            let stats = try await diffEngine.preflight(file: filePath, staged: staged, at: repoPath)
            isLargeFileMode = stats.isLargeFile
            options = stats.suggestedOptions

            // Load hunks
            var loadedHunks: [StreamingDiffHunk] = []
            for try await hunk in diffEngine.diff(file: filePath, staged: staged, at: repoPath, options: options) {
                loadedHunks.append(hunk)
            }

            await MainActor.run {
                self.hunks = loadedHunks
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func expandHunk(at index: Int) {
        guard index < hunks.count else { return }
        hunks[index].isCollapsed = false
        // In LFM, might need to materialize lines here
    }

    private func collapseHunk(at index: Int) {
        guard index < hunks.count else { return }
        hunks[index].isCollapsed = true
    }
}

// MARK: - Standard Diff Content (SwiftUI)

/// SwiftUI-based diff view for smaller files
private struct StandardDiffContent: View {
    let hunks: [StreamingDiffHunk]
    let options: DiffOptions

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(hunks) { hunk in
                    if let diffHunk = hunk.toDiffHunk() {
                        CollapsibleHunkCard(
                            hunk: diffHunk,
                            hunkIndex: hunks.firstIndex(where: { $0.id == hunk.id }) ?? 0,
                            totalHunks: hunks.count,
                            showLineNumbers: true,
                            showActions: false,
                            isStaged: false,
                            isCollapsed: hunk.isCollapsed
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - LFM Status Badge

/// Shows Large File Mode status
struct LFMStatusBadge: View {
    let isActive: Bool
    let stats: DiffPreflightStats?

    var body: some View {
        if isActive {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.warning)
                Text("LFM")
                    .font(DesignTokens.Typography.caption2.weight(.semibold))
                if let stats = stats {
                    Text("(\(formatLines(stats.estimatedLines)) lines)")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            .foregroundColor(AppTheme.warning)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(AppTheme.warning.opacity(0.15))
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
    }

    private func formatLines(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
