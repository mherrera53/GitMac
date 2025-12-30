import SwiftUI
import Splash

// NOTE: The following components have been extracted to separate files in Features/Diff/Renderers:
// - WordLevelDiff (DiffSegment, WordLevelDiffResult, WordLevelDiff enum)
// - DiffLineContextMenu (View extensions for context menus)
// - DiffMinimap (OptimizedMinimapView, DiffScrollOffsetKey)
// - DiffScrollViews (UnifiedDiffScrollView, DiffPair, IdentifiedDiffLine)
// - DiffSyntaxHighlighter (SyntaxHighlightedText)
// - DiffParser (DiffParser struct)
// - DiffLineRenderers (DiffLineRow, InlineDiffLineRow, HunkLineRow, HunkHeaderRow, EmptyLineRow)
// - BinaryFileRenderers (BinaryFileView, ImagePreviewView, PDFPreviewView, GenericBinaryView, CheckerboardPattern)
// - LargeFileDiffRenderer (LargeFileDiffViewWrapper, LargeFileDiffNSView)

/// Complete diff viewer with multiple view modes - OPTIMIZED
struct DiffView: View {
    let fileDiff: FileDiff
    var repoPath: String? = nil
    @State private var viewMode: DiffViewMode = .split
    @State private var showLineNumbers = true
    @State private var wordWrap = false
    @State private var showMinimap = true
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 400
    @State private var contentHeight: CGFloat = 1000
    @StateObject private var themeManager = ThemeManager.shared

    // Calculate line count for accurate minimap
    // Calculate line count for accurate minimap
    private var totalLineCount: Int {
        var count = 0
        for hunk in fileDiff.hunks {
            count += 1 // hunk header

            if viewMode == .inline || viewMode == .preview {
                // Inline mode counts all lines
                count += hunk.lines.count
            } else {
                // Split mode collapses deletions and additions into single rows
                var i = 0
                let lines = hunk.lines
                while i < lines.count {
                    let line = lines[i]
                    if line.type == .context {
                        count += 1
                        i += 1
                    } else if line.type == .deletion {
                        var dels = 0
                        while i < lines.count && lines[i].type == .deletion { dels += 1; i += 1 }
                        var adds = 0
                        while i < lines.count && lines[i].type == .addition { adds += 1; i += 1 }
                        count += max(dels, adds)
                    } else if line.type == .addition {
                        count += 1
                        i += 1
                    } else {
                         i += 1
                    }
                }
            }
        }
        return max(count, 1)
    }

    // Threshold for "large file" - switch to optimized inline view
    // Threshold for "large file" - switch to optimized inline view
    private let largeFileLineThreshold = 20000

    private var isLargeFile: Bool {
        totalLineCount > largeFileLineThreshold
    }

    // Estimated content height (22px per line)
    private var estimatedContentHeight: CGFloat {
        CGFloat(visualRowCount) * 22.0
    }

    private var visualRowCount: Int {
        if viewMode == .split {
            // In split view, we pair simultaneous deletions and additions.
            // visualRows ≈ hunks + context + max(deletions, additions) in blocks
            var count = 0
            for hunk in fileDiff.hunks {
                count += 1 // Header
                
                var i = 0
                let lines = hunk.lines
                while i < lines.count {
                    let line = lines[i]
                    if line.type == .context {
                        count += 1
                        i += 1
                    } else {
                        // Block counting logic (matches OptimizedSplitDiffView)
                        var deletions = 0
                        var j = i
                        while j < lines.count && lines[j].type == .deletion {
                            deletions += 1
                            j += 1
                        }
                        
                        var additions = 0
                        var k = j
                        while k < lines.count && lines[k].type == .addition {
                            additions += 1
                            k += 1
                        }
                        
                        count += max(deletions, additions)
                        i = k
                        if i == j { i += 1 } // Safety
                    }
                }
            }
            return count
        } else {
            // Unified/Inline: just sum of lines + headers
            return fileDiff.hunks.reduce(0) { $0 + $1.lines.count + 1 }
        }
    }

    // Exact scroll position based on real physics
    private var scrollPosition: CGFloat {
        guard contentHeight > viewportHeight else { return 0 }
        return min(1, max(0, scrollOffset / (contentHeight - viewportHeight)))
    }

    private var viewportRatio: CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(1, max(0.05, viewportHeight / contentHeight))
    }

    private var isMarkdown: Bool {
        let ext = (fileDiff.displayPath as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "mdown"
    }

    private var previewContent: String {
        var lines: [String] = []
        for hunk in fileDiff.hunks {
            for line in hunk.lines {
                if line.type == .addition || line.type == .context {
                    lines.append(line.content)
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                DiffToolbar(
                    filename: fileDiff.displayPath,
                    additions: fileDiff.additions,
                    deletions: fileDiff.deletions,
                    viewMode: $viewMode,
                    showLineNumbers: $showLineNumbers,
                    wordWrap: $wordWrap,
                    isMarkdown: isMarkdown,
                    showMinimap: $showMinimap
                )

                // Large File Mode indicator
                if isLargeFile {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "bolt.fill")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(theme.warning)
                        Text("LFM")
                            .font(DesignTokens.Typography.caption2.weight(.semibold))
                        Text("(\(totalLineCount) lines)")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(theme.text)
                    }
                    .foregroundColor(AppTheme.warning)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(theme.warning.opacity(0.15))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .padding(.trailing, DesignTokens.Spacing.sm)
                }
            }

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                if fileDiff.isBinary {
                    BinaryFileView(filename: fileDiff.displayPath, repoPath: repoPath)
                } else if isLargeFile {
                    // Use high-performance NSView-based rendering for large files
                    LargeFileDiffViewWrapper(
                        hunks: fileDiff.hunks,
                        showLineNumbers: showLineNumbers,
                        scrollOffset: $scrollOffset,
                        viewportHeight: $viewportHeight
                    )
                } else {
                    switch viewMode {
                    case .split:
                        OptimizedSplitDiffView(
                            hunks: fileDiff.hunks,
                            showLineNumbers: showLineNumbers,
                            scrollOffset: $scrollOffset,
                            viewportHeight: $viewportHeight,
                            contentHeight: $contentHeight
                        )
                    case .inline:
                        OptimizedInlineDiffView(
                            hunks: fileDiff.hunks,
                            showLineNumbers: showLineNumbers,
                            scrollOffset: $scrollOffset,
                            viewportHeight: $viewportHeight,
                            contentHeight: $contentHeight
                        )
                    case .hunk:
                        HunkDiffView(
                            hunks: fileDiff.hunks,
                            showLineNumbers: showLineNumbers,
                            scrollOffset: $scrollOffset,
                            viewportHeight: $viewportHeight,
                            contentHeight: $contentHeight
                        )
                    case .preview:
                        MarkdownView(content: previewContent, fileName: fileDiff.displayPath)
                    case .kaleidoscopeBlocks, .kaleidoscopeFluid, .kaleidoscopeUnified:
                        // Placeholder - will be integrated in next phase
                        OptimizedSplitDiffView(
                            hunks: fileDiff.hunks,
                            showLineNumbers: showLineNumbers,
                            scrollOffset: $scrollOffset,
                            viewportHeight: $viewportHeight,
                            contentHeight: $contentHeight
                        )
                    }
                }

                if showMinimap && !fileDiff.isBinary && viewMode != .preview && !isLargeFile {
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)

                    OptimizedMinimapView(
                        hunks: fileDiff.hunks,
                        scrollPosition: scrollPosition,
                        viewportRatio: viewportRatio,
                        onScrollToPosition: { normalizedPos in
                            // Calculate new scroll offset from normalized position (0-1)
                            let maxScroll = max(0, contentHeight - viewportHeight)
                            scrollOffset = normalizedPos * maxScroll
                        }
                    )
                    .frame(width: 60)
                }
            }
            }

        .background(theme.background)
    }
}




// MARK: - Optimized Split Diff View

struct OptimizedSplitDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat
    @State private var viewWidth: CGFloat = 1000

    private var pairs: [DiffPair] {
        // ... (implementation hidden, same as before)
        var pairs: [DiffPair] = []
        var pairId = 0
        
        for hunk in hunks {
            pairId += 1
            pairs.append(DiffPair(id: pairId, left: nil, right: nil, hunkHeader: hunk.header))
            
            var i = 0
            let lines = hunk.lines
            
            while i < lines.count {
                let line = lines[i]
                
                if line.type == .context {
                    pairId += 1
                    pairs.append(DiffPair(id: pairId, left: line, right: line, hunkHeader: nil))
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
                            pairs.append(DiffPair(id: pairId, left: left, right: right, hunkHeader: nil))
                        }
                        
                        i = k
                    } else {
                        // Should technically not happen if log is correct, but safety advance
                        i += 1
                    }
                }
            }
        }
        return pairs
    }

    var body: some View {
        SynchronizedSplitDiffScrollView(
            scrollOffset: $scrollOffset,
            viewportHeight: $viewportHeight,
            contentHeight: $contentHeight,
            leftContent: {
                SplitDiffContentView(
                    pairs: pairs,
                    side: .left,
                    showLineNumbers: showLineNumbers
                )
            },
            rightContent: {
                SplitDiffContentView(
                    pairs: pairs,
                    side: .right,
                    showLineNumbers: showLineNumbers
                )
            }
        )
    }
}

// MARK: - Synchronized Split Diff Scroll View

/// NSViewRepresentable wrapper for split diff with synchronized horizontal and vertical scrolling
struct SynchronizedSplitDiffScrollView<LeftContent: View, RightContent: View>: NSViewRepresentable {
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat
    @ViewBuilder let leftContent: () -> LeftContent
    @ViewBuilder let rightContent: () -> RightContent

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()

        // Create left scroll view
        let leftScrollView = NSScrollView()
        leftScrollView.hasVerticalScroller = true
        leftScrollView.hasHorizontalScroller = true
        leftScrollView.autohidesScrollers = false
        leftScrollView.borderType = .noBorder
        leftScrollView.drawsBackground = false

        // Create right scroll view
        let rightScrollView = NSScrollView()
        rightScrollView.hasVerticalScroller = true
        rightScrollView.hasHorizontalScroller = true
        rightScrollView.autohidesScrollers = false
        rightScrollView.borderType = .noBorder
        rightScrollView.drawsBackground = false

        // Create hosting views for SwiftUI content
        let leftHostingView = NSHostingView(rootView: leftContent())
        let rightHostingView = NSHostingView(rootView: rightContent())

        leftScrollView.documentView = leftHostingView
        rightScrollView.documentView = rightHostingView

        // Store references in coordinator
        context.coordinator.leftScrollView = leftScrollView
        context.coordinator.rightScrollView = rightScrollView
        context.coordinator.containerView = containerView

        // Add scroll notification observers
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: leftScrollView.contentView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: rightScrollView.contentView
        )

        // Layout scroll views side by side with divider
        containerView.addSubview(leftScrollView)

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        containerView.addSubview(divider)

        containerView.addSubview(rightScrollView)

        // Store divider reference
        context.coordinator.divider = divider

        // Initialize viewport and content height after layout
        DispatchQueue.main.async {
            // Force initial layout
            containerView.needsLayout = true
            containerView.layoutSubtreeIfNeeded()

            // Update viewport height
            viewportHeight = containerView.bounds.height

            // Update content height from document views
            if let leftDocView = leftScrollView.documentView,
               let rightDocView = rightScrollView.documentView {
                let maxHeight = max(leftDocView.fittingSize.height, rightDocView.fittingSize.height)
                if maxHeight > 0 {
                    contentHeight = maxHeight
                }
            }
        }

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let leftScrollView = context.coordinator.leftScrollView,
              let rightScrollView = context.coordinator.rightScrollView,
              let divider = context.coordinator.divider else { return }

        // Update layout
        let frame = nsView.bounds
        let dividerWidth: CGFloat = 2
        let halfWidth = (frame.width - dividerWidth) / 2

        leftScrollView.frame = NSRect(x: 0, y: 0, width: halfWidth, height: frame.height)
        divider.frame = NSRect(x: halfWidth, y: 0, width: dividerWidth, height: frame.height)
        rightScrollView.frame = NSRect(x: halfWidth + dividerWidth, y: 0, width: halfWidth, height: frame.height)

        // Sync document view sizes (use max height for both)
        if let leftDocView = leftScrollView.documentView,
           let rightDocView = rightScrollView.documentView {
            let maxHeight = max(leftDocView.fittingSize.height, rightDocView.fittingSize.height)
            let leftWidth = max(leftDocView.fittingSize.width, halfWidth)
            let rightWidth = max(rightDocView.fittingSize.width, halfWidth)

            leftDocView.frame = NSRect(x: 0, y: 0, width: leftWidth, height: maxHeight)
            rightDocView.frame = NSRect(x: 0, y: 0, width: rightWidth, height: maxHeight)

            // Update contentHeight binding
            if maxHeight > 0 {
                contentHeight = maxHeight
            }
        }

        // Update viewport height
        if frame.height > 0 {
            viewportHeight = frame.height
        }

        // Handle programmatic scrolling from SwiftUI (e.g., minimap clicks)
        if !context.coordinator.isSyncing {
            let targetPoint = NSPoint(x: 0, y: scrollOffset)
            leftScrollView.contentView.scroll(to: targetPoint)
            rightScrollView.contentView.scroll(to: targetPoint)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: SynchronizedSplitDiffScrollView
        var isSyncing = false

        weak var leftScrollView: NSScrollView?
        weak var rightScrollView: NSScrollView?
        weak var containerView: NSView?
        weak var divider: NSView?

        private var lastScrollTime: Date = Date()
        private let scrollDebounceInterval: TimeInterval = 0.016 // ~60fps

        init(_ parent: SynchronizedSplitDiffScrollView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @MainActor @objc func scrollViewDidScroll(_ notification: Notification) {
            guard !isSyncing else { return }
            guard let clipView = notification.object as? NSClipView else { return }

            // Debounce rapid scroll events
            let now = Date()
            guard now.timeIntervalSince(lastScrollTime) >= scrollDebounceInterval else { return }
            lastScrollTime = now

            isSyncing = true
            defer { isSyncing = false }

            let scrollPosition = clipView.bounds.origin

            // Determine which scroll view triggered the event
            if clipView == leftScrollView?.contentView {
                // Left scrolled, sync to right
                rightScrollView?.contentView.scroll(to: scrollPosition)
            } else if clipView == rightScrollView?.contentView {
                // Right scrolled, sync to left
                leftScrollView?.contentView.scroll(to: scrollPosition)
            }

            // Update SwiftUI binding for minimap integration (already on main thread)
            parent.scrollOffset = max(0, scrollPosition.y)

            // Update viewport height if container is available
            if let container = containerView {
                parent.viewportHeight = container.bounds.height
            }
        }
    }
}

// MARK: - Split Diff Content View

/// Renders one side (left or right) of the split diff
struct SplitDiffContentView: View {
    let pairs: [DiffPair]
    let side: DiffSide
    let showLineNumbers: Bool

    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: []) {
            ForEach(pairs) { pair in
                if let header = pair.hunkHeader {
                    // Hunk header - same on both sides
                    FastHunkHeader(header: header)
                } else {
                    // Render line for this side
                    if let line = lineForSide(pair, side) {
                        FastDiffLine(
                            line: line,
                            side: side,
                            showLineNumber: showLineNumbers,
                            paired: pairedLine(pair, side)
                        )
                    } else {
                        // Empty line on this side
                        FastEmptyLine(
                            showLineNumber: showLineNumbers,
                            isDeleted: side == .left && pair.right?.type == .addition,
                            isAdded: side == .right && pair.left?.type == .deletion
                        )
                    }
                }
            }
        }
    }

    private func lineForSide(_ pair: DiffPair, _ side: DiffSide) -> DiffLine? {
        side == .left ? pair.left : pair.right
    }

    private func pairedLine(_ pair: DiffPair, _ side: DiffSide) -> DiffLine? {
        side == .left ? pair.right : pair.left
    }
}

// MARK: - Optimized Inline Diff View

struct OptimizedInlineDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat

    private var allLines: [IdentifiedDiffLine] {
        var result: [IdentifiedDiffLine] = []
        var lineId = 0
        for hunk in hunks {
            lineId += 1
            result.append(IdentifiedDiffLine(id: lineId, line: nil, hunkHeader: hunk.header))
            for line in hunk.lines {
                lineId += 1
                result.append(IdentifiedDiffLine(id: lineId, line: line, hunkHeader: nil))
            }
        }
        return result
    }

    var body: some View {
        UnifiedDiffScrollView(scrollOffset: $scrollOffset, viewportHeight: $viewportHeight) {
            VStack(spacing: 0) {
                LazyVStack(spacing: 0) {
                    ForEach(allLines) { item in
                        if let header = item.hunkHeader {
                            FastHunkHeader(header: header)
                        } else if let line = item.line {
                            FastInlineLine(line: line, showLineNumber: showLineNumbers)
                        }
                    }
                }
            }
        }
    }
}



// FastHunkHeader, FastEmptyLine, FastDiffLine, FastInlineLine are now in UI/Components/Diff/DiffLineView.swift
// DiffViewMode, DiffToolbar, ToolbarButton, DiffModeButton are now in UI/Components/Diff/DiffToolbar.swift
// DiffSide enum is now in UI/Components/Diff/DiffLineView.swift

// MARK: - Diff Toolbar components moved to UI/Components/Diff/DiffToolbar.swift

// MARK: - Split Diff View (Side by Side) with Synchronized Scrolling

struct SplitDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    let filename: String
    @StateObject private var themeManager = ThemeManager.shared

    // Build paired lines for proper alignment
    private var pairedLines: [(left: DiffLine?, right: DiffLine?, hunkHeader: String?)] {
        var pairs: [(left: DiffLine?, right: DiffLine?, hunkHeader: String?)] = []

        for hunk in hunks {
            // Add hunk header as a special row
            pairs.append((left: nil, right: nil, hunkHeader: hunk.header))

            // Group consecutive deletions and additions for better pairing
            var i = 0
            let lines = hunk.lines

            while i < lines.count {
                let line = lines[i]

                if line.type == .context {
                    pairs.append((left: line, right: line, hunkHeader: nil))
                    i += 1
                } else if line.type == .deletion {
                    // Collect consecutive deletions
                    var deletions: [DiffLine] = []
                    while i < lines.count && lines[i].type == .deletion {
                        deletions.append(lines[i])
                        i += 1
                    }

                    // Collect consecutive additions
                    var additions: [DiffLine] = []
                    while i < lines.count && lines[i].type == .addition {
                        additions.append(lines[i])
                        i += 1
                    }

                    // Pair them up
                    let maxCount = max(deletions.count, additions.count)
                    for j in 0..<maxCount {
                        let del = j < deletions.count ? deletions[j] : nil
                        let add = j < additions.count ? additions[j] : nil
                        pairs.append((left: del, right: add, hunkHeader: nil))
                    }
                } else if line.type == .addition {
                    // Standalone addition (no preceding deletion)
                    pairs.append((left: nil, right: line, hunkHeader: nil))
                    i += 1
                } else {
                    i += 1
                }
            }
        }

        return pairs
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        GeometryReader { geometry in
            let halfWidth = geometry.size.width / 2 - 1

            ScrollView([.vertical, .horizontal]) {
                HStack(spacing: 0) {
                    // Left side (old)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(pairedLines.enumerated()), id: \.offset) { index, pair in
                            if let header = pair.hunkHeader {
                                SplitHunkHeaderRow(header: header)
                                    .frame(width: halfWidth)
                            } else if let line = pair.left {
                                SplitDiffLineRow(
                                    line: line,
                                    side: .left,
                                    showLineNumber: showLineNumbers,
                                    pairedLine: pair.right
                                )
                                .frame(width: halfWidth)
                            } else {
                                EmptyLineRow(showLineNumber: showLineNumbers)
                                    .frame(width: halfWidth)
                            }
                        }
                    }
                    .frame(width: halfWidth)

                    // Divider
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 2)

                    // Right side (new)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(pairedLines.enumerated()), id: \.offset) { index, pair in
                            if let header = pair.hunkHeader {
                                SplitHunkHeaderRow(header: header)
                                    .frame(width: halfWidth)
                            } else if let line = pair.right {
                                SplitDiffLineRow(
                                    line: line,
                                    side: .right,
                                    showLineNumber: showLineNumbers,
                                    pairedLine: pair.left
                                )
                                .frame(width: halfWidth)
                            } else {
                                EmptyLineRow(showLineNumber: showLineNumbers)
                                    .frame(width: halfWidth)
                            }
                        }
                    }
                    .frame(width: halfWidth)
                }
            }
        }
    }
}

// MARK: - Split View Components

struct SplitHunkHeaderRow: View {
    let header: String
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "text.alignleft")
                .font(DesignTokens.Typography.caption2)
            Text(header)
                .font(DesignTokens.Typography.commitHash)
        }
        .foregroundColor(theme.accent)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.08))
    }
}

struct SplitDiffLineRow: View {
    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let pairedLine: DiffLine?
    @StateObject private var themeManager = ThemeManager.shared

    var lineNumber: Int? {
        switch side {
        case .left: return line.oldLineNumber
        case .right: return line.newLineNumber
        }
    }

    // Compute character-level diff (Kaleidoscope-style)
    private var highlightedContent: AttributedString {
        guard let paired = pairedLine,
              line.type != .context,
              paired.type != .context else {
            return AttributedString(line.content)
        }

        // Determine old and new content based on line types
        let oldContent = line.type == .deletion ? line.content : paired.content
        let newContent = line.type == .addition ? line.content : paired.content

        // Get character-level diff
        let diffResult = WordLevelDiff.compare(oldLine: oldContent, newLine: newContent)

        // Use appropriate segments based on which side we're rendering
        let segments = line.type == .deletion ? diffResult.oldSegments : diffResult.newSegments

        var result = AttributedString()

        for segment in segments {
            var segmentAttr = AttributedString(segment.text)

            switch segment.type {
            case .unchanged:
                // No special highlighting
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
                    .foregroundColor(theme.text)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
                    .background(lineNumberBackground(theme: theme))
            }

            // Change indicator
            Text(changeIndicator)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(indicatorColor(theme: theme))
                .frame(width: 16)

            // Content with word-level highlighting
            Text(highlightedContent)
                .font(DesignTokens.Typography.diffLine)
                .foregroundColor(textColor(theme: theme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .padding(.trailing, DesignTokens.Spacing.sm)
        .background(backgroundColor(theme: theme))
        .diffLineContextMenu(line: line)
    }

    var changeIndicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@@"
        }
    }

    func indicatorColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        default: return theme.text
        }
    }

    func backgroundColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAdditionBg
        case .deletion: return AppTheme.diffDeletionBg
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    func lineNumberBackground(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffLineNumberBg
        case .deletion: return AppTheme.diffLineNumberBg
        case .context, .hunkHeader: return theme.backgroundSecondary
        }
    }

    func textColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return AppTheme.diffAddition
        case .deletion: return AppTheme.diffDeletion
        case .context, .hunkHeader: return theme.text
        }
    }
}

// MARK: - Inline Diff View

struct InlineDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    let filename: String

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
                    HunkHeaderRow(header: hunk.header, hunkIndex: index)

                    ForEach(hunk.lines) { line in
                        InlineDiffLineRow(
                            line: line,
                            showLineNumbers: showLineNumbers,
                            filename: filename
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Hunk Diff View

struct HunkDiffView: View {
    let hunks: [DiffHunk]
    let showLineNumbers: Bool
    var filePath: String? = nil
    var isStaged: Bool = false
    var onStageHunk: ((Int) -> Void)? = nil
    var onUnstageHunk: ((Int) -> Void)? = nil
    var onDiscardHunk: ((Int) -> Void)? = nil

    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    var contentHeight: Binding<CGFloat>? = nil
    var viewId: String = "DiffScrollView"
    @State private var collapsedHunks: Set<Int> = []
    @State private var selectedHunks: Set<Int> = []
    @State private var isSelectionMode: Bool = false

    private var hasActions: Bool {
        onStageHunk != nil || onUnstageHunk != nil || onDiscardHunk != nil
    }

    private var totalAdditions: Int {
        hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.type == .addition }.count
        }
    }

    private var totalDeletions: Int {
        hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.type == .deletion }.count
        }
    }

    var body: some View {
        UnifiedDiffScrollView(
            scrollOffset: $scrollOffset,
            viewportHeight: $viewportHeight,
            contentHeight: contentHeight,
            id: viewId
        ) {
            contentView
        }
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                headerView
                hunksList
            }
            .padding()
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HunkSummaryHeader(
                hunkCount: hunks.count,
                totalAdditions: totalAdditions,
                totalDeletions: totalDeletions
            )

            Spacer()

            if hasActions && hunks.count > 1 {
                selectionToolbar
            }
        }
    }

    @ViewBuilder
    private var selectionToolbar: some View {
        HunkSelectionToolbar(
            isSelectionMode: $isSelectionMode,
            selectedCount: selectedHunks.count,
            totalCount: hunks.count,
            isStaged: isStaged,
            onSelectAll: selectAllHunks,
            onDeselectAll: deselectAllHunks,
            onStageSelected: stageSelectionAction,
            onUnstageSelected: unstageSelectionAction,
            onDiscardSelected: discardSelectionAction
        )
    }

    private var stageSelectionAction: (() -> Void)? {
        if onStageHunk != nil {
            return stageSelectedHunks
        }
        return nil
    }

    private var unstageSelectionAction: (() -> Void)? {
        if onUnstageHunk != nil {
            return unstageSelectedHunks
        }
        return nil
    }

    private var discardSelectionAction: (() -> Void)? {
        if onDiscardHunk != nil {
            return discardSelectedHunks
        }
        return nil
    }

    private func selectAllHunks() {
        selectedHunks = Set(0..<hunks.count)
    }

    private func deselectAllHunks() {
        selectedHunks.removeAll()
    }

    @ViewBuilder
    private var hunksList: some View {
        ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
            CollapsibleHunkCard(
                hunk: hunk,
                hunkIndex: index,
                totalHunks: hunks.count,
                showLineNumbers: showLineNumbers,
                showActions: onStageHunk != nil || onUnstageHunk != nil,
                isStaged: isStaged,
                isCollapsed: collapsedHunks.contains(index),
                isSelectionMode: isSelectionMode,
                isSelected: selectedHunks.contains(index),
                onToggleCollapse: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if collapsedHunks.contains(index) {
                            collapsedHunks.remove(index)
                        } else {
                            collapsedHunks.insert(index)
                        }
                    }
                },
                onToggleSelection: {
                    if selectedHunks.contains(index) {
                        selectedHunks.remove(index)
                    } else {
                        selectedHunks.insert(index)
                    }
                },
                onStage: { onStageHunk?(index) },
                onUnstage: { onUnstageHunk?(index) },
                onDiscard: { onDiscardHunk?(index) }
            )
        }
    }

    private func stageSelectedHunks() {
        for index in selectedHunks.sorted() {
            onStageHunk?(index)
        }
        selectedHunks.removeAll()
        isSelectionMode = false
    }

    private func unstageSelectedHunks() {
        for index in selectedHunks.sorted() {
            onUnstageHunk?(index)
        }
        selectedHunks.removeAll()
        isSelectionMode = false
    }

    private func discardSelectedHunks() {
        // Discard in reverse order to avoid index shifting issues
        for index in selectedHunks.sorted().reversed() {
            onDiscardHunk?(index)
        }
        selectedHunks.removeAll()
        isSelectionMode = false
    }
}

// MARK: - Hunk Summary Header

struct HunkSummaryHeader: View {
    let hunkCount: Int
    let totalAdditions: Int
    let totalDeletions: Int
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "text.alignleft")
                    .font(DesignTokens.Typography.callout)
                Text("\(hunkCount) hunk\(hunkCount == 1 ? "" : "s")")
                    .font(DesignTokens.Typography.callout.weight(.medium))
            }
            .foregroundColor(theme.text)

            Spacer()

            HStack(spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                    Text("\(totalAdditions)")
                }
                .foregroundColor(AppTheme.diffAddition)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "minus")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                    Text("\(totalDeletions)")
                }
                .foregroundColor(AppTheme.diffDeletion)
            }
            .font(DesignTokens.Typography.callout.weight(.semibold).monospaced())
        }
        .padding(.horizontal, DesignTokens.Spacing.md + DesignTokens.Spacing.xxs)
        .padding(.vertical, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
        .background(theme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Hunk Selection Toolbar

struct HunkSelectionToolbar: View {
    @Binding var isSelectionMode: Bool
    let selectedCount: Int
    let totalCount: Int
    var isStaged: Bool = false
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?
    var onStageSelected: (() -> Void)?
    var onUnstageSelected: (() -> Void)?
    var onDiscardSelected: (() -> Void)?
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.sm) {
            // Toggle selection mode
            Button {
                withAnimation(DesignTokens.Animation.fastEasing) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        onDeselectAll?()
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: isSelectionMode ? "checkmark.square.fill" : "square.dashed")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.textSecondary)
                    Text("Select")
                        .font(DesignTokens.Typography.caption.weight(.medium))
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelectionMode ? theme.accent.opacity(0.2) : Color.clear)
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .buttonStyle(.plain)
            .foregroundColor(isSelectionMode ? theme.accent : theme.text)

            if isSelectionMode {
                Divider()
                    .frame(height: 16)

                // Selection counter
                Text("\(selectedCount)/\(totalCount)")
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundColor(theme.text)

                // Select/Deselect all buttons
                Button("All") { onSelectAll?() }
                    .font(DesignTokens.Typography.caption2.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundColor(theme.accent)

                Button("None") { onDeselectAll?() }
                    .font(DesignTokens.Typography.caption2.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundColor(theme.text)

                if selectedCount > 0 {
                    Divider()
                        .frame(height: 16)

                    // Bulk actions
                    if !isStaged, let stageSelected = onStageSelected {
                        Button {
                            stageSelected()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxs + 1) {
                                Image(systemName: "plus.circle.fill")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(theme.success)
                                Text("Stage")
                                    .font(DesignTokens.Typography.caption2.weight(.medium))
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs + 1)
                            .background(AppTheme.diffAddition)
                            .foregroundColor(AppTheme.textPrimary)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    if isStaged, let unstageSelected = onUnstageSelected {
                        Button {
                            unstageSelected()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxs + 1) {
                                Image(systemName: "minus.circle.fill")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(theme.error)
                                Text("Unstage")
                                    .font(DesignTokens.Typography.caption2.weight(.medium))
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs + 1)
                            .background(AppTheme.warning)
                            .foregroundColor(AppTheme.textPrimary)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    if !isStaged, let discardSelected = onDiscardSelected {
                        Button {
                            discardSelected()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.xxs + 1) {
                                Image(systemName: "trash")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(theme.error)
                                Text("Discard")
                                    .font(DesignTokens.Typography.caption2.weight(.medium))
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                            .padding(.vertical, DesignTokens.Spacing.xxs + 1)
                            .background(AppTheme.diffDeletion)
                            .foregroundColor(AppTheme.textPrimary)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Collapsible Hunk Card

struct CollapsibleHunkCard: View {
    let hunk: DiffHunk
    let hunkIndex: Int
    let totalHunks: Int
    let showLineNumbers: Bool
    let showActions: Bool
    let isStaged: Bool
    let isCollapsed: Bool
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleCollapse: (() -> Void)?
    var onToggleSelection: (() -> Void)?
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?

    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

    private var additions: Int {
        hunk.lines.filter { $0.type == .addition }.count
    }

    private var deletions: Int {
        hunk.lines.filter { $0.type == .deletion }.count
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(alignment: .leading, spacing: 0) {
            // Hunk header (always visible)
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Selection checkbox (visible in selection mode)
                if isSelectionMode {
                    Button {
                        onToggleSelection?()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(isSelected ? theme.accent : theme.text)
                    }
                    .buttonStyle(.plain)
                }

                // Collapse toggle
                Button(action: { onToggleCollapse?() }) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(DesignTokens.Typography.caption2.weight(.bold))
                        .foregroundColor(theme.text)
                        .frame(width: DesignTokens.Size.iconMD, height: DesignTokens.Size.iconMD)
                }
                .buttonStyle(.plain)

                // Hunk number badge
                Text("Hunk \(hunkIndex + 1)/\(totalHunks)")
                    .font(DesignTokens.Typography.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(theme.accent)
                    .cornerRadius(DesignTokens.CornerRadius.sm)

                // Line range
                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines) → \(hunk.newStart)-\(hunk.newStart + hunk.newLines)")
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundColor(theme.text)

                // Change stats
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if additions > 0 {
                        Text("+\(additions)")
                            .foregroundColor(AppTheme.diffAddition)
                    }
                    if deletions > 0 {
                        Text("-\(deletions)")
                            .foregroundColor(AppTheme.diffDeletion)
                    }
                }
                .font(DesignTokens.Typography.caption.weight(.medium).monospaced())

                Spacer()

                // Actions (visible on hover)
                if showActions && isHovered && !isCollapsed {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if !isStaged {
                            Button {
                                onStage?()
                            } label: {
                                Label("Stage", systemImage: "plus.circle.fill")
                                    .font(DesignTokens.Typography.caption.weight(.medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(AppTheme.diffAddition)
                                    .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDiscard?()
                            } label: {
                                Label("Discard", systemImage: "trash")
                                    .font(DesignTokens.Typography.caption.weight(.medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(AppTheme.diffDeletion)
                                    .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                onUnstage?()
                            } label: {
                                Label("Unstage", systemImage: "minus.circle.fill")
                                    .font(DesignTokens.Typography.caption.weight(.medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(AppTheme.warning)
                                    .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(theme.accent.opacity(0.08))

            // Lines (collapsible)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(hunk.lines) { line in
                        HunkLineRow(line: line, showLineNumber: showLineNumbers)
                    }
                }
            } else {
                // Collapsed preview
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("...")
                        .foregroundColor(theme.text)
                    Text("\(hunk.lines.count) lines")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(theme.text)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.backgroundTertiary)
            }
        }
        .background(isSelected ? theme.accent.opacity(0.1) : theme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(
                    isSelected ? theme.accent : (isHovered ? theme.accent.opacity(0.6) : theme.border),
                    lineWidth: isSelected || isHovered ? 2 : 1
                )
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection?()
            }
        }
    }
}

// MARK: - Hunk Card with Actions
struct HunkCard: View {
    let hunk: DiffHunk
    let hunkIndex: Int
    let showLineNumbers: Bool
    let showActions: Bool
    let isStaged: Bool
    var onStage: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onDiscard: (() -> Void)?
    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with actions
            HStack {
                Text(hunk.header)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(theme.text)

                Spacer()

                if showActions && isHovered {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if !isStaged {
                            // Stage this hunk
                            Button {
                                onStage?()
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Stage Hunk")
                                }
                                .font(DesignTokens.Typography.caption.weight(.medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(AppTheme.diffAddition)
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)

                            // Discard this hunk
                            Button {
                                onDiscard?()
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    Image(systemName: "trash")
                                    Text("Discard")
                                }
                                .font(DesignTokens.Typography.caption.weight(.medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(AppTheme.diffDeletion)
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Unstage this hunk
                            Button {
                                onUnstage?()
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    Image(systemName: "minus.circle.fill")
                                    Text("Unstage Hunk")
                                }
                                .font(DesignTokens.Typography.caption.weight(.medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                                .background(AppTheme.warning)
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(theme.text)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(theme.info.opacity(0.1))

            // Lines
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hunk.lines) { line in
                    HunkLineRow(line: line, showLineNumber: showLineNumbers)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(isHovered ? theme.accent.opacity(0.5) : theme.border, lineWidth: isHovered ? 2 : 1)
        )
        .onHover { isHovered = $0 }
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
    let line: LargeDiffLine
    let showLineNumbers: Bool
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: 0) {
            if line.type == .hunkHeader {
                // Hunk header
                Text(line.content)
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(AppTheme.info)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(SwiftUI.Color.cyan.opacity(0.1))
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
                    .foregroundColor(theme.text.opacity(0.7))
                    .padding(.trailing, DesignTokens.Spacing.xs)
                }

                Text(prefix)
                    .font(DesignTokens.Typography.diffLine)
                    .foregroundColor(prefixColor(theme: theme))
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

    private func prefixColor(theme: SwiftUI.Color.Theme) -> SwiftUI.Color {
        switch line.type {
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        default: return theme.text
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

// #Preview {
//     let sampleDiff = FileDiff(
//         oldPath: "test.swift",
//         newPath: "test.swift",
//         status: .modified,
//         hunks: [
//             DiffHunk(
//                 header: "@@ -1,5 +1,7 @@",
//                 oldStart: 1,
//                 oldLines: 5,
//                 newStart: 1,
//                 newLines: 7,
//                 lines: [
//                     DiffLine(type: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
//                     DiffLine(type: .addition, content: "import SwiftUI", oldLineNumber: nil, newLineNumber: 2),
//                     DiffLine(type: .context, content: "", oldLineNumber: 2, newLineNumber: 3),
//                     DiffLine(type: .deletion, content: "class OldClass {", oldLineNumber: 3, newLineNumber: nil),
//                     DiffLine(type: .addition, content: "struct NewStruct {", oldLineNumber: nil, newLineNumber: 4),
//                     DiffLine(type: .context, content: "    let value: Int", oldLineNumber: 4, newLineNumber: 5),
//                     DiffLine(type: .context, content: "}", oldLineNumber: 5, newLineNumber: 6),
//                 ]
//             )
//         ],
//         additions: 2,
//         deletions: 1
//     )
// 
//     DiffView(fileDiff: sampleDiff)
//         .frame(width: 800, height: 500)
// }
