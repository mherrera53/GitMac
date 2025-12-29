import SwiftUI
import AppKit
import os.signpost

// MARK: - Performance Logging

private let renderLog = OSLog(subsystem: "com.gitmac", category: "diff.render")

// MARK: - Tiled Diff View

/// Ultra-high-performance diff view using direct CoreText drawing
/// For files > 50k lines with constant line height and O(1) viewport calculation
struct TiledDiffView: NSViewRepresentable {
    let fileDiff: FileDiff
    let options: DiffOptions
    @Binding var scrollPosition: CGFloat
    @Binding var selectedHunk: Int?
    
    func makeNSView(context: Context) -> NSScrollView {
        let contentView = TiledDiffContentView()
        contentView.fileDiff = fileDiff
        contentView.options = options
        contentView.coordinator = context.coordinator
        
        let scrollView = NSScrollView()
        scrollView.documentView = contentView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Enable layer-backed rendering for maximum performance
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.copiesOnScroll = false
        
        // Set up notification for scroll changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let contentView = scrollView.documentView as? TiledDiffContentView else { return }
        
        contentView.fileDiff = fileDiff
        contentView.options = options
        contentView.setNeedsDisplay(contentView.visibleRect)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: TiledDiffView
        
        init(_ parent: TiledDiffView) {
            self.parent = parent
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView else { return }
            DispatchQueue.main.async {
                self.parent.scrollPosition = clipView.bounds.origin.y
            }
        }
    }
}

// MARK: - Tiled Diff Content View

/// NSView that draws diff lines directly with CoreText
class TiledDiffContentView: NSView {
    @StateObject private var themeManager = ThemeManager.shared

    var fileDiff: FileDiff? {
        didSet {
            calculateLayout()
            invalidateIntrinsicContentSize()
            setNeedsDisplay(bounds)
        }
    }
    
    var options: DiffOptions = .default
    weak var coordinator: TiledDiffView.Coordinator?
    
    // Layout constants
    private let lineHeight: CGFloat = 22
    private let lineNumberWidth: CGFloat = 60
    private let gutterWidth: CGFloat = DesignTokens.Spacing.xs
    private let indicatorWidth: CGFloat = 20
    private let contentMargin: CGFloat = DesignTokens.Spacing.md
    
    // Cached layout
    private var totalLines: Int = 0
    private var lineOffsets: [Int] = []  // Cumulative line counts per hunk
    private var hunkRanges: [(hunkIndex: Int, lineRange: Range<Int>)] = []
    
    // Colors (adapt to light/dark mode)
    private var textColor: NSColor {
        NSColor.textColor
    }
    
    private var lineNumberColor: NSColor {
        NSColor.secondaryLabelColor
    }
    
    private var additionColor: NSColor {
        NSColor.systemGreen
    }
    
    private var deletionColor: NSColor {
        NSColor.systemRed
    }
    
    private var contextBgColor: NSColor {
        NSColor.controlBackgroundColor.blended(withFraction: 0.5, of: NSColor.textBackgroundColor) ?? NSColor.controlBackgroundColor
    }
    
    override var isFlipped: Bool { true }  // Top-down coordinate system
    
    override var intrinsicContentSize: NSSize {
        let width: CGFloat = 2000  // Reasonable max width for code
        let height = CGFloat(totalLines) * lineHeight
        return NSSize(width: width, height: height)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let fileDiff = fileDiff else { return }
        
        let signpostID = OSSignpostID(log: renderLog)
        os_signpost(.begin, log: renderLog, name: "diff.render", signpostID: signpostID)
        
        defer {
            os_signpost(.end, log: renderLog, name: "diff.render", signpostID: signpostID)
        }
        
        // Clear background
        contextBgColor.setFill()
        dirtyRect.fill()
        
        // Calculate visible line range (O(1) thanks to constant height)
        let visibleLines = calculateVisibleLineRange(dirtyRect)
        
        // Draw only visible lines
        drawVisibleLines(fileDiff: fileDiff, range: visibleLines)
    }
    
    // MARK: - Layout Calculation
    
    private func calculateLayout() {
        guard let fileDiff = fileDiff else {
            totalLines = 0
            lineOffsets = []
            hunkRanges = []
            return
        }
        
        totalLines = 0
        lineOffsets = [0]
        hunkRanges = []
        
        for (hunkIndex, hunk) in fileDiff.hunks.enumerated() {
            let startLine = totalLines
            
            // Hunk header = 1 line
            totalLines += 1
            
            // Hunk lines
            let hunkLineCount = hunk.lines.count
            totalLines += hunkLineCount
            
            lineOffsets.append(totalLines)
            
            let endLine = totalLines
            hunkRanges.append((hunkIndex, startLine..<endLine))
        }
    }
    
    private func calculateVisibleLineRange(_ rect: NSRect) -> Range<Int> {
        let firstLine = max(0, Int(rect.minY / lineHeight))
        let lastLine = min(totalLines, Int(rect.maxY / lineHeight) + 1)
        return firstLine..<lastLine
    }
    
    // MARK: - Drawing
    
    private func drawVisibleLines(fileDiff: FileDiff, range: Range<Int>) {
        guard !fileDiff.hunks.isEmpty else { return }
        
        // Find which hunks are visible
        for (hunkIndex, hunk) in fileDiff.hunks.enumerated() {
            guard hunkIndex < hunkRanges.count else { continue }
            
            let (_, lineRange) = hunkRanges[hunkIndex]
            
            // Check if this hunk intersects with visible range
            guard lineRange.overlaps(range) else { continue }
            
            // Draw hunk header if visible
            if range.contains(lineRange.lowerBound) {
                drawHunkHeader(hunk: hunk, lineIndex: lineRange.lowerBound)
            }
            
            // Draw hunk lines
            let hunkLinesStart = lineRange.lowerBound + 1
            let visibleHunkLines = max(hunkLinesStart, range.lowerBound)..<min(lineRange.upperBound, range.upperBound)
            
            for lineIndex in visibleHunkLines {
                let lineInHunk = lineIndex - hunkLinesStart
                guard lineInHunk >= 0 && lineInHunk < hunk.lines.count else { continue }
                
                let line = hunk.lines[lineInHunk]
                drawLine(line: line, lineIndex: lineIndex)
            }
        }
    }
    
    private func drawHunkHeader(hunk: DiffHunk, lineIndex: Int) {
        let y = CGFloat(lineIndex) * lineHeight
        let rect = NSRect(x: 0, y: y, width: bounds.width, height: lineHeight)
        
        // Background
        NSColor.systemBlue.withAlphaComponent(0.1).setFill()
        rect.fill()
        
        // Text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.Typography.commitHash,
            .foregroundColor: NSColor.systemBlue
        ]

        let text = hunk.header as NSString
        let textRect = NSRect(x: contentMargin, y: y + DesignTokens.Spacing.xxs, width: bounds.width - contentMargin * 2, height: lineHeight - DesignTokens.Spacing.xxs)
        text.draw(in: textRect, withAttributes: attrs)
    }
    
    private func drawLine(line: DiffLine, lineIndex: Int) {
        let y = CGFloat(lineIndex) * lineHeight
        
        // Background color
        let bgColor: NSColor
        switch line.type {
        case .addition:
            bgColor = additionColor.withAlphaComponent(0.12)
        case .deletion:
            bgColor = deletionColor.withAlphaComponent(0.12)
        case .context, .hunkHeader:
            bgColor = .clear
        }
        
        if bgColor != .clear {
            bgColor.setFill()
            NSRect(x: 0, y: y, width: bounds.width, height: lineHeight).fill()
        }
        
        // Line numbers (old and new)
        drawLineNumbers(line: line, y: y)
        
        // Change indicator (+/−/ )
        drawChangeIndicator(line: line, y: y)
        
        // Line content
        drawLineContent(line: line, y: y)
    }
    
    private func drawLineNumbers(line: DiffLine, y: CGFloat) {
        let numberFont = DesignTokens.Typography.commitHash
        let attrs: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: lineNumberColor
        ]

        // Old line number
        let oldNum = line.oldLineNumber.map { String($0) } ?? ""
        let oldNumRect = NSRect(x: DesignTokens.Spacing.xxs, y: y + DesignTokens.Spacing.xxs, width: 28, height: lineHeight - DesignTokens.Spacing.xxs)
        (oldNum as NSString).draw(in: oldNumRect, withAttributes: attrs)

        // New line number
        let newNum = line.newLineNumber.map { String($0) } ?? ""
        let newNumRect = NSRect(x: 32, y: y + DesignTokens.Spacing.xxs, width: 28, height: lineHeight - DesignTokens.Spacing.xxs)
        (newNum as NSString).draw(in: newNumRect, withAttributes: attrs)
    }
    
    private func drawChangeIndicator(line: DiffLine, y: CGFloat) {
        let indicator: String
        let color: NSColor
        
        switch line.type {
        case .addition:
            indicator = "+"
            color = additionColor
        case .deletion:
            indicator = "-"
            color = deletionColor
        case .context:
            indicator = " "
            color = textColor
        case .hunkHeader:
            indicator = "@"
            color = NSColor.systemBlue
        }
        
        let font = DesignTokens.Typography.diffLine
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let rect = NSRect(x: lineNumberWidth + gutterWidth, y: y + 3, width: indicatorWidth, height: lineHeight - 3)
        (indicator as NSString).draw(in: rect, withAttributes: attrs)
    }
    
    private func drawLineContent(line: DiffLine, y: CGFloat) {
        let font = DesignTokens.Typography.diffLine
        let color: NSColor
        
        switch line.type {
        case .addition:
            color = additionColor
        case .deletion:
            color = deletionColor
        default:
            color = textColor
        }
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let x = lineNumberWidth + gutterWidth + indicatorWidth + contentMargin
        let rect = NSRect(x: x, y: y + 3, width: bounds.width - x - contentMargin, height: lineHeight - 3)
        (line.content as NSString).draw(in: rect, withAttributes: attrs)
    }
}

// MARK: - Wrapper with LFM Detection

/// Wrapper that automatically chooses TiledDiffView for large files
struct AdaptiveTiledDiffView: View {
    let fileDiff: FileDiff
    let options: DiffOptions
    @State private var scrollPosition: CGFloat = 0
    @State private var selectedHunk: Int? = nil
    
    private var shouldUseTiled: Bool {
        let totalLines = fileDiff.hunks.reduce(0) { $0 + 1 + $1.lines.count }
        return totalLines > 10_000  // Use tiled for > 10k lines
    }
    
    var body: some View {
        Group {
            if shouldUseTiled {
                VStack(spacing: 0) {
                    // Performance indicator
                    performanceIndicator
                    
                    TiledDiffView(
                        fileDiff: fileDiff,
                        options: options,
                        scrollPosition: $scrollPosition,
                        selectedHunk: $selectedHunk
                    )
                }
            } else {
                // Use regular SwiftUI-based diff view for smaller files
                Text("Use OptimizedSplitDiffView or OptimizedInlineDiffView here")
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }
    
    private var performanceIndicator: some View {
        let totalLines = fileDiff.hunks.reduce(0) { $0 + 1 + $1.lines.count }
        
        return HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "bolt.fill")
                .foregroundColor(AppTheme.warning)

            Text("High-Performance Mode")
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)

            Text("•")
                .foregroundColor(AppTheme.textPrimary)

            Text("\(totalLines) lines")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)

            Text("•")
                .foregroundColor(AppTheme.textPrimary)

            Text("Tiled rendering (O(1) scroll)")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.warning.opacity(0.1))
    }
}
