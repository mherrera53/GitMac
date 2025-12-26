import SwiftUI
import Splash

// MARK: - Word-Level Diff Algorithm (Kaleidoscope-style)

/// Represents a segment of text with its diff status
struct DiffSegment: Identifiable {
    let id = UUID()
    let text: String
    let type: SegmentType

    enum SegmentType {
        case unchanged  // Same in both versions
        case added      // Only in new version
        case removed    // Only in old version
        case changed    // Modified
    }
}

/// Word-level diff result for a pair of lines
struct WordLevelDiffResult {
    let oldSegments: [DiffSegment]
    let newSegments: [DiffSegment]
    let hasInlineChanges: Bool
}

/// Computes character-level diffs between two strings
enum WordLevelDiff {

    /// Compare two lines and return highlighted segments
    static func compare(oldLine: String, newLine: String) -> WordLevelDiffResult {
        if oldLine == newLine {
            return WordLevelDiffResult(
                oldSegments: [DiffSegment(text: oldLine, type: .unchanged)],
                newSegments: [DiffSegment(text: newLine, type: .unchanged)],
                hasInlineChanges: false
            )
        }

        if oldLine.isEmpty {
            return WordLevelDiffResult(
                oldSegments: [],
                newSegments: [DiffSegment(text: newLine, type: .added)],
                hasInlineChanges: true
            )
        }

        if newLine.isEmpty {
            return WordLevelDiffResult(
                oldSegments: [DiffSegment(text: oldLine, type: .removed)],
                newSegments: [],
                hasInlineChanges: true
            )
        }

        // Find common prefix and suffix for character-level precision
        let (prefix, oldMiddle, newMiddle, suffix) = findCommonPrefixSuffix(oldLine, newLine)

        var oldSegments: [DiffSegment] = []
        var newSegments: [DiffSegment] = []

        if !prefix.isEmpty {
            oldSegments.append(DiffSegment(text: prefix, type: .unchanged))
            newSegments.append(DiffSegment(text: prefix, type: .unchanged))
        }

        if !oldMiddle.isEmpty {
            oldSegments.append(DiffSegment(text: oldMiddle, type: .removed))
        }
        if !newMiddle.isEmpty {
            newSegments.append(DiffSegment(text: newMiddle, type: .added))
        }

        if !suffix.isEmpty {
            oldSegments.append(DiffSegment(text: suffix, type: .unchanged))
            newSegments.append(DiffSegment(text: suffix, type: .unchanged))
        }

        return WordLevelDiffResult(
            oldSegments: oldSegments,
            newSegments: newSegments,
            hasInlineChanges: !oldMiddle.isEmpty || !newMiddle.isEmpty
        )
    }

    private static func findCommonPrefixSuffix(_ old: String, _ new: String) -> (prefix: String, oldMiddle: String, newMiddle: String, suffix: String) {
        let oldChars = Array(old)
        let newChars = Array(new)

        var prefixLen = 0
        while prefixLen < oldChars.count && prefixLen < newChars.count && oldChars[prefixLen] == newChars[prefixLen] {
            prefixLen += 1
        }

        var suffixLen = 0
        while suffixLen < (oldChars.count - prefixLen) &&
              suffixLen < (newChars.count - prefixLen) &&
              oldChars[oldChars.count - 1 - suffixLen] == newChars[newChars.count - 1 - suffixLen] {
            suffixLen += 1
        }

        let prefix = String(oldChars[0..<prefixLen])
        let suffix = suffixLen > 0 ? String(oldChars[(oldChars.count - suffixLen)...]) : ""
        let oldMiddle = String(oldChars[prefixLen..<(oldChars.count - suffixLen)])
        let newMiddle = String(newChars[prefixLen..<(newChars.count - suffixLen)])

        return (prefix, oldMiddle, newMiddle, suffix)
    }
}

// MARK: - Diff Line Context Menu Extension

extension View {
    /// Adds a context menu with copy actions to a diff line view
    func diffLineContextMenu(line: DiffLine) -> some View {
        self.contextMenu {
            Button {
                ContextMenuHelper.copyToClipboard(line.content)
                ToastManager.shared.show("Line content copied")
            } label: {
                Label("Copy Line Content", systemImage: "doc.on.doc")
            }

            Button {
                let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 0
                let prefix: String
                switch line.type {
                case .addition: prefix = "+"
                case .deletion: prefix = "-"
                default: prefix = " "
                }
                let text = "\(lineNum): \(prefix)\(line.content)"
                ContextMenuHelper.copyToClipboard(text)
                ToastManager.shared.show("Line copied with number")
            } label: {
                Label("Copy with Line Number", systemImage: "list.number")
            }

            if line.type != .context && line.type != .hunkHeader {
                Divider()

                // Hint for hunk-level actions
                Label("Hover over hunk header for Stage/Discard", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Extended context menu with stage/discard actions for diff lines
    func diffLineContextMenuWithActions(
        line: DiffLine,
        onStageLine: (() -> Void)? = nil,
        onDiscardLine: (() -> Void)? = nil
    ) -> some View {
        self.contextMenu {
            Button {
                ContextMenuHelper.copyToClipboard(line.content)
                ToastManager.shared.show("Line content copied")
            } label: {
                Label("Copy Line Content", systemImage: "doc.on.doc")
            }

            Button {
                let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 0
                let prefix: String
                switch line.type {
                case .addition: prefix = "+"
                case .deletion: prefix = "-"
                default: prefix = " "
                }
                let text = "\(lineNum): \(prefix)\(line.content)"
                ContextMenuHelper.copyToClipboard(text)
                ToastManager.shared.show("Line copied with number")
            } label: {
                Label("Copy with Line Number", systemImage: "list.number")
            }

            if line.type != .context && line.type != .hunkHeader {
                Divider()

                if let stageLine = onStageLine {
                    Button {
                        stageLine()
                    } label: {
                        Label("Stage This Line", systemImage: "plus.circle")
                    }
                }

                if let discardLine = onDiscardLine {
                    Button(role: .destructive) {
                        discardLine()
                    } label: {
                        Label("Discard This Line", systemImage: "trash")
                    }
                }

                if onStageLine == nil && onDiscardLine == nil {
                    Label("Hover over hunk header for Stage/Discard", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

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
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("LFM")
                            .font(.system(size: 10, weight: .semibold))
                        Text("(\(totalLineCount) lines)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SwiftUI.Color.orange.opacity(0.15))
                    .cornerRadius(4)
                    .padding(.trailing, 8)
                }
            }

            Rectangle()
                .fill(GitKrakenTheme.border)
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
                    }
                }

                if showMinimap && !fileDiff.isBinary && viewMode != .preview && !isLargeFile {
                    Rectangle()
                        .fill(GitKrakenTheme.border)
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

        .background(GitKrakenTheme.background)
    }
}

// MARK: - Optimized Minimap (Interactive with click navigation)

struct OptimizedMinimapView: View {
    let hunks: [DiffHunk]
    let scrollPosition: CGFloat
    let viewportRatio: CGFloat
    var onScrollToPosition: ((CGFloat) -> Void)? = nil

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let totalLines = hunks.reduce(0) { $0 + $1.lines.count }
            let lineHeight = max(0.5, geo.size.height / CGFloat(max(totalLines, 1)))
            let vpHeight = max(20, geo.size.height * viewportRatio)
            let vpTop = scrollPosition * (geo.size.height - vpHeight)

            ZStack(alignment: .topLeading) {
                // Fast canvas-style rendering
                Canvas { context, size in
                    var y: CGFloat = 0
                    for hunk in hunks {
                        for line in hunk.lines {
                            let nsColor: NSColor = switch line.type {
                            case .addition: NSColor.systemGreen
                            case .deletion: NSColor.systemRed
                            case .hunkHeader: NSColor.systemBlue.withAlphaComponent(0.5)
                            case .context: NSColor.clear
                            }
                            if nsColor != .clear {
                                context.fill(
                                    Path(CGRect(x: 0, y: y, width: size.width, height: max(lineHeight, 1))),
                                    with: .color(SwiftUI.Color(nsColor).opacity(0.7))
                                )
                            }
                            y += lineHeight
                        }
                    }
                }

                // Viewport indicator (draggable)
                RoundedRectangle(cornerRadius: 2)
                    .fill(SwiftUI.Color.white.opacity(isDragging ? 0.35 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(SwiftUI.Color.white.opacity(isDragging ? 0.7 : 0.5), lineWidth: 1)
                    )
                    .frame(width: geo.size.width - 4, height: vpHeight)
                    .offset(x: 2, y: vpTop)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let normalizedY = min(1, max(0, value.location.y / geo.size.height))
                                onScrollToPosition?(normalizedY)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                // Click anywhere on minimap to navigate
                let normalizedY = min(1, max(0, location.y / geo.size.height))
                onScrollToPosition?(normalizedY)
            }
        }
        .background(SwiftUI.Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}

// MARK: - Diff Scroll Preference Keys

struct DiffScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Unified Scroll Container (The Source of Truth)
struct UnifiedDiffScrollView<Content: View>: View {
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    var viewportWidth: Binding<CGFloat>? = nil
    var contentHeight: Binding<CGFloat>? = nil
    var id: String = "DiffScrollView"
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .top) {
                // Reliable Scroll Tracker
                GeometryReader { geo in
                    SwiftUI.Color.clear
                        .preference(key: DiffScrollOffsetKey.self, value: -geo.frame(in: .named(id)).minY)
                }
                .frame(height: 1)

                // Content
                content()
            }
            .background(
                GeometryReader { geo in
                    SwiftUI.Color.clear
                        .onAppear { contentHeight?.wrappedValue = geo.size.height }
                        .onChange(of: geo.size.height) { _, new in contentHeight?.wrappedValue = new }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: id)
        .background(
            GeometryReader { geo in
                SwiftUI.Color.clear
                    .onAppear { 
                        viewportHeight = geo.size.height
                        viewportWidth?.wrappedValue = geo.size.width
                    }
                    .onChange(of: geo.size.height) { _, new in viewportHeight = new }
                    .onChange(of: geo.size.width) { _, new in viewportWidth?.wrappedValue = new }
            }
        )
        .onPreferenceChange(DiffScrollOffsetKey.self) { val in
            scrollOffset = max(0, val)
        }
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

        // Update content if needed
        if let leftDoc = leftScrollView.documentView as? NSHostingView<LeftContent> {
            leftDoc.rootView = leftContent()
        }
        if let rightDoc = rightScrollView.documentView as? NSHostingView<RightContent> {
            rightDoc.rootView = rightContent()
        }

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
        private let scrollDebounceInterval: TimeInterval = 0.01 // 10ms

        init(_ parent: SynchronizedSplitDiffScrollView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
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

            // Update SwiftUI binding for minimap integration
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.scrollOffset = max(0, scrollPosition.y)

                // Update viewport height if container is available
                if let container = self.containerView {
                    self.parent.viewportHeight = container.bounds.height
                }
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

// MARK: - Fast Rendering Components

struct DiffPair: Identifiable {
    let id: Int
    let left: DiffLine?
    let right: DiffLine?
    let hunkHeader: String?
}

struct IdentifiedDiffLine: Identifiable {
    let id: Int
    let line: DiffLine?
    let hunkHeader: String?
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
                        .fill(Color.secondary.opacity(0.3))
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 10))
            Text(header)
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundColor(GitKrakenTheme.accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GitKrakenTheme.accent.opacity(0.08))
    }
}

struct SplitDiffLineRow: View {
    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let pairedLine: DiffLine?

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
                segmentAttr.backgroundColor = GitKrakenTheme.accentGreen.opacity(0.4)
                segmentAttr.foregroundColor = SwiftUI.Color.green
            case .removed:
                segmentAttr.backgroundColor = GitKrakenTheme.accentRed.opacity(0.4)
                segmentAttr.foregroundColor = SwiftUI.Color.red
            case .changed:
                let color = line.type == .addition ? GitKrakenTheme.accentGreen : GitKrakenTheme.accentRed
                segmentAttr.backgroundColor = color.opacity(0.4)
            }

            result.append(segmentAttr)
        }

        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text(lineNumber.map { String($0) } ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, 8)
                    .background(lineNumberBackground)
            }

            // Change indicator
            Text(changeIndicator)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 16)

            // Content with word-level highlighting
            Text(highlightedContent)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.trailing, 8)
        .background(backgroundColor)
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

    var indicatorColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        default: return GitKrakenTheme.textMuted
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.12)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.12)
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var lineNumberBackground: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.06)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.06)
        case .context, .hunkHeader: return GitKrakenTheme.backgroundSecondary
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        case .context, .hunkHeader: return GitKrakenTheme.textPrimary
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
                ForEach(hunks) { hunk in
                    HunkHeaderRow(header: hunk.header)

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

    var body: some View {
        UnifiedDiffScrollView(scrollOffset: $scrollOffset, viewportHeight: $viewportHeight, contentHeight: contentHeight, id: viewId) {
            VStack(spacing: 0) {
                LazyVStack(spacing: 12) {
                    // Summary header with selection toolbar
                    HStack(spacing: 12) {
                        HunkSummaryHeader(
                            hunkCount: hunks.count,
                            totalAdditions: hunks.reduce(0) { $0 + $1.lines.filter { $0.type == .addition }.count },
                            totalDeletions: hunks.reduce(0) { $0 + $1.lines.filter { $0.type == .deletion }.count }
                        )

                        Spacer()

                        // Selection mode toggle and actions
                        if hasActions && hunks.count > 1 {
                            HunkSelectionToolbar(
                                isSelectionMode: $isSelectionMode,
                                selectedCount: selectedHunks.count,
                                totalCount: hunks.count,
                                isStaged: isStaged,
                                onSelectAll: { selectedHunks = Set(0..<hunks.count) },
                                onDeselectAll: { selectedHunks.removeAll() },
                                onStageSelected: onStageHunk != nil ? stageSelectedHunks : nil,
                                onUnstageSelected: onUnstageHunk != nil ? unstageSelectedHunks : nil,
                                onDiscardSelected: onDiscardHunk != nil ? discardSelectedHunks : nil
                            )
                        }
                    }

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
                .padding()
            }
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

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                Text("\(hunkCount) hunk\(hunkCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(GitKrakenTheme.textSecondary)

            Spacer()

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(totalAdditions)")
                }
                .foregroundColor(GitKrakenTheme.accentGreen)

                HStack(spacing: 4) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(totalDeletions)")
                }
                .foregroundColor(GitKrakenTheme.accentRed)
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GitKrakenTheme.backgroundSecondary)
        .cornerRadius(8)
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

    var body: some View {
        HStack(spacing: 8) {
            // Toggle selection mode
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        onDeselectAll?()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSelectionMode ? "checkmark.square.fill" : "square.dashed")
                        .font(.system(size: 11))
                    Text("Select")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelectionMode ? GitKrakenTheme.accent.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .foregroundColor(isSelectionMode ? GitKrakenTheme.accent : GitKrakenTheme.textSecondary)

            if isSelectionMode {
                Divider()
                    .frame(height: 16)

                // Selection counter
                Text("\(selectedCount)/\(totalCount)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.textSecondary)

                // Select/Deselect all buttons
                Button("All") { onSelectAll?() }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(GitKrakenTheme.accent)

                Button("None") { onDeselectAll?() }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(GitKrakenTheme.textSecondary)

                if selectedCount > 0 {
                    Divider()
                        .frame(height: 16)

                    // Bulk actions
                    if !isStaged, let stageSelected = onStageSelected {
                        Button {
                            stageSelected()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 10))
                                Text("Stage")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(GitKrakenTheme.accentGreen)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    if isStaged, let unstageSelected = onUnstageSelected {
                        Button {
                            unstageSelected()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 10))
                                Text("Unstage")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(GitKrakenTheme.accentOrange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    if !isStaged, let discardSelected = onDiscardSelected {
                        Button {
                            discardSelected()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                Text("Discard")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(GitKrakenTheme.accentRed)
                            .foregroundColor(.white)
                            .cornerRadius(4)
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

    private var additions: Int {
        hunk.lines.filter { $0.type == .addition }.count
    }

    private var deletions: Int {
        hunk.lines.filter { $0.type == .deletion }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header (always visible)
            HStack(spacing: 8) {
                // Selection checkbox (visible in selection mode)
                if isSelectionMode {
                    Button {
                        onToggleSelection?()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 14))
                            .foregroundColor(isSelected ? GitKrakenTheme.accent : GitKrakenTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Collapse toggle
                Button(action: { onToggleCollapse?() }) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(GitKrakenTheme.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                // Hunk number badge
                Text("Hunk \(hunkIndex + 1)/\(totalHunks)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(GitKrakenTheme.accent)
                    .cornerRadius(4)

                // Line range
                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines) → \(hunk.newStart)-\(hunk.newStart + hunk.newLines)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.textMuted)

                // Change stats
                HStack(spacing: 6) {
                    if additions > 0 {
                        Text("+\(additions)")
                            .foregroundColor(GitKrakenTheme.accentGreen)
                    }
                    if deletions > 0 {
                        Text("-\(deletions)")
                            .foregroundColor(GitKrakenTheme.accentRed)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))

                Spacer()

                // Actions (visible on hover)
                if showActions && isHovered && !isCollapsed {
                    HStack(spacing: 6) {
                        if !isStaged {
                            Button {
                                onStage?()
                            } label: {
                                Label("Stage", systemImage: "plus.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(GitKrakenTheme.accentGreen)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDiscard?()
                            } label: {
                                Label("Discard", systemImage: "trash")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(GitKrakenTheme.accentRed)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                onUnstage?()
                            } label: {
                                Label("Unstage", systemImage: "minus.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(GitKrakenTheme.accentOrange)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(GitKrakenTheme.accent.opacity(0.08))

            // Lines (collapsible)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(hunk.lines) { line in
                        HunkLineRow(line: line, showLineNumber: showLineNumbers)
                    }
                }
            } else {
                // Collapsed preview
                HStack(spacing: 8) {
                    Text("...")
                        .foregroundColor(GitKrakenTheme.textMuted)
                    Text("\(hunk.lines.count) lines")
                        .font(.system(size: 11))
                        .foregroundColor(GitKrakenTheme.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GitKrakenTheme.backgroundTertiary)
            }
        }
        .background(isSelected ? GitKrakenTheme.accent.opacity(0.1) : GitKrakenTheme.backgroundSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? GitKrakenTheme.accent : (isHovered ? GitKrakenTheme.accent.opacity(0.6) : GitKrakenTheme.border),
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header with actions
            HStack {
                Text(hunk.header)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                if showActions && isHovered {
                    HStack(spacing: 8) {
                        if !isStaged {
                            // Stage this hunk
                            Button {
                                onStage?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Stage Hunk")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GitKrakenTheme.accentGreen)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            // Discard this hunk
                            Button {
                                onDiscard?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Discard")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GitKrakenTheme.accentRed)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Unstage this hunk
                            Button {
                                onUnstage?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "minus.circle.fill")
                                    Text("Unstage Hunk")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GitKrakenTheme.accentOrange)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Lines \(hunk.oldStart)-\(hunk.oldStart + hunk.oldLines)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))

            // Lines
            VStack(alignment: .leading, spacing: 0) {
                ForEach(hunk.lines) { line in
                    HunkLineRow(line: line, showLineNumber: showLineNumbers)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? GitKrakenTheme.accent.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: isHovered ? 2 : 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - DiffSide moved to UI/Components/Diff/DiffLineView.swift

// MARK: - Line Components

struct DiffLineRow: View {
    let line: DiffLine
    let side: DiffSide
    let showLineNumber: Bool
    let filename: String

    var lineNumber: Int? {
        switch side {
        case .left: return line.oldLineNumber
        case .right: return line.newLineNumber
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text(lineNumber.map { String($0) } ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(backgroundColor)
        .diffLineContextMenu(line: line)
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green.opacity(0.15)
        case .deletion: return SwiftUI.Color.red.opacity(0.15)
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green
        case .deletion: return SwiftUI.Color.red
        case .context, .hunkHeader: return SwiftUI.Color.primary
        }
    }
}

struct InlineDiffLineRow: View {
    let line: DiffLine
    let showLineNumbers: Bool
    let filename: String

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            if showLineNumbers {
                HStack(spacing: 0) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 40, alignment: .trailing)

                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .frame(width: 40, alignment: .trailing)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
            }

            // Indicator
            Text(lineIndicator)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 16)

            // Content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(backgroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .diffLineContextMenu(line: line)
    }

    var lineIndicator: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    var indicatorColor: SwiftUI.Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .secondary
        case .hunkHeader: return .blue
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green.opacity(0.15)
        case .deletion: return SwiftUI.Color.red.opacity(0.15)
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return SwiftUI.Color.green
        case .deletion: return SwiftUI.Color.red
        case .context, .hunkHeader: return SwiftUI.Color.primary
        }
    }
}

struct HunkLineRow: View {
    let line: DiffLine
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                HStack(spacing: 4) {
                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                    Text(line.newLineNumber.map { String($0) } ?? "")
                        .frame(width: 35, alignment: .trailing)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(GitKrakenTheme.textMuted)
                .padding(.trailing, 8)
                .background(lineNumberBackground)
            }

            Text(linePrefix)
                .foregroundColor(prefixColor)
                .frame(width: 16)

            Text(line.content)
                .foregroundColor(textColor)
                .textSelection(.enabled)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(backgroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .diffLineContextMenu(line: line)
    }

    var linePrefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }

    var prefixColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        default: return GitKrakenTheme.textMuted
        }
    }

    var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.1)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.1)
        default: return SwiftUI.Color.clear
        }
    }

    var lineNumberBackground: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen.opacity(0.06)
        case .deletion: return GitKrakenTheme.accentRed.opacity(0.06)
        default: return GitKrakenTheme.backgroundSecondary
        }
    }

    var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return GitKrakenTheme.accentGreen
        case .deletion: return GitKrakenTheme.accentRed
        default: return GitKrakenTheme.textPrimary
        }
    }
}

struct HunkHeaderRow: View {
    let header: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 10))
            Text(header)
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundColor(GitKrakenTheme.accent)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GitKrakenTheme.accent.opacity(0.08))
    }
}

struct EmptyLineRow: View {
    let showLineNumber: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumber {
                Text("")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, 8)
                    .background(GitKrakenTheme.backgroundSecondary)
            }
            Text(" ")
                .frame(width: 16)
            Spacer()
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 2)
        .background(GitKrakenTheme.backgroundTertiary.opacity(0.3))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BinaryFileView: View {
    let filename: String
    var repoPath: String? = nil

    private var isImage: Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "ico", "svg"].contains(ext)
    }

    private var isPDF: Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ext == "pdf"
    }

    private var fullPath: URL? {
        guard let repoPath = repoPath else { return nil }
        return URL(fileURLWithPath: repoPath).appendingPathComponent(filename)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isImage, let path = fullPath {
                    // Image preview
                    ImagePreviewView(imageURL: path, filename: filename)
                } else if isPDF, let path = fullPath {
                    // PDF preview
                    PDFPreviewView(pdfURL: path, filename: filename)
                } else {
                    // Generic binary file
                    GenericBinaryView(filename: filename)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Image Preview
struct ImagePreviewView: View {
    let imageURL: URL
    let filename: String
    @State private var imageSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
                Text(filename)
                    .font(.headline)
                Spacer()
                if imageSize != .zero {
                    Text("\(Int(imageSize.width)) × \(Int(imageSize.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Image preview with max size
            if let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 800, maxHeight: 600)
                    .background(
                        // Checkerboard pattern for transparent images
                        CheckerboardPattern()
                    )
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .onAppear {
                        imageSize = nsImage.size
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("Could not load image")
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }

            // File info
            if let attrs = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
               let fileSize = attrs[.size] as? Int64 {
                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Checkerboard Pattern (for transparent images)
struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 10
            let light = Color.gray.opacity(0.2)
            let dark = Color.gray.opacity(0.3)

            for row in 0..<Int(size.height / squareSize) + 1 {
                for col in 0..<Int(size.width / squareSize) + 1 {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Rectangle().path(in: rect), with: .color(isLight ? light : dark))
                }
            }
        }
    }
}

// MARK: - PDF Preview
struct PDFPreviewView: View {
    let pdfURL: URL
    let filename: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundColor(.red)
                Text(filename)
                    .font(.headline)
                Spacer()
            }

            // Quick Look preview or fallback
            if let pdfData = try? Data(contentsOf: pdfURL),
               let pdfDoc = NSPDFImageRep(data: pdfData) {
                VStack {
                    Image(nsImage: pdfDoc.pdfImage ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 800)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Text("\(pdfDoc.pageCount) page(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("PDF Document")
                        .font(.headline)
                    Button("Open in Preview") {
                        NSWorkspace.shared.open(pdfURL)
                    }
                }
                .frame(height: 200)
            }
        }
    }
}

extension NSPDFImageRep {
    var pdfImage: NSImage? {
        let image = NSImage(size: bounds.size)
        image.addRepresentation(self)
        return image
    }
}

// MARK: - Generic Binary View
struct GenericBinaryView: View {
    let filename: String

    private var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    private var fileIcon: String {
        switch fileExtension {
        case "zip", "tar", "gz", "7z", "rar": return "doc.zipper"
        case "dmg", "iso": return "externaldrive"
        case "app": return "app.badge.checkmark"
        case "ttf", "otf", "woff", "woff2": return "textformat"
        case "mp3", "wav", "aac", "flac", "m4a": return "waveform"
        case "mp4", "mov", "avi", "mkv", "webm": return "film"
        case "sqlite", "db": return "cylinder"
        default: return "doc.fill"
        }
    }

    private var fileTypeName: String {
        switch fileExtension {
        case "zip": return "ZIP Archive"
        case "tar": return "TAR Archive"
        case "gz": return "GZIP Archive"
        case "7z": return "7-Zip Archive"
        case "rar": return "RAR Archive"
        case "dmg": return "Disk Image"
        case "iso": return "ISO Image"
        case "app": return "Application"
        case "ttf", "otf": return "Font File"
        case "woff", "woff2": return "Web Font"
        case "mp3": return "MP3 Audio"
        case "wav": return "WAV Audio"
        case "aac": return "AAC Audio"
        case "flac": return "FLAC Audio"
        case "m4a": return "M4A Audio"
        case "mp4": return "MP4 Video"
        case "mov": return "QuickTime Video"
        case "avi": return "AVI Video"
        case "mkv": return "MKV Video"
        case "webm": return "WebM Video"
        case "sqlite", "db": return "Database"
        default: return "Binary File"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: fileIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(fileTypeName)
                .font(.headline)

            Text(filename)
                .foregroundColor(.secondary)

            Text("Cannot display diff for binary files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - Syntax Highlighter

struct SyntaxHighlightedText: View {
    let code: String
    let language: String

    private var highlightedCode: AttributedString {
        guard grammar(for: language) != nil else {
            return AttributedString(code)
        }

        let highlighter = Splash.SyntaxHighlighter(
            format: AttributedStringOutputFormat(theme: .sundellsColors(withFont: .init(size: 12)))
        )

        let highlighted = highlighter.highlight(code)
        return AttributedString(highlighted)
    }

    var body: some View {
        Text(highlightedCode)
            .font(.system(.body, design: .monospaced))
    }

    private func grammar(for language: String) -> Grammar? {
        switch language.lowercased() {
        case "swift": return SwiftGrammar()
        default: return nil
        }
    }
}

// MARK: - Diff Parser

struct DiffParser {
    /// Maximum lines to parse (prevents freezing on huge files)
    private static let maxLinesToParse = 100000

    /// Parse a unified diff string into FileDiff objects (ASYNC - runs on background thread)
    static func parseAsync(_ diffString: String) async -> [FileDiff] {
        // Run parsing on background thread to avoid UI freeze
        return await Task.detached(priority: .userInitiated) {
            parse(diffString)
        }.value
    }

    /// Parse a unified diff string into FileDiff objects
    /// Limits parsing to maxLinesToParse for performance
    static func parse(_ diffString: String) -> [FileDiff] {
        var files: [FileDiff] = []
        var currentFile: (oldPath: String?, newPath: String, hunks: [DiffHunk], additions: Int, deletions: Int)?
        var currentHunk: (header: String, oldStart: Int, oldLines: Int, newStart: Int, newLines: Int, lines: [DiffLine])?

        // For very large diffs, truncate the string first to avoid memory issues
        // Use utf8.count which is O(1) for native strings
        let maxBytes = 50_000_000 // ~50MB max
        let truncatedString: String
        var wasTruncated = false

        if diffString.utf8.count > maxBytes {
            // Truncate by taking prefix of utf8 bytes
            truncatedString = String(diffString.utf8.prefix(maxBytes)) ?? String(diffString.prefix(maxBytes / 4))
            wasTruncated = true
        } else {
            truncatedString = diffString
        }

        let lines = truncatedString.components(separatedBy: .newlines)
        var oldLineNum = 0
        var newLineNum = 0
        var linesParsed = 0

        for line in lines {
            // Limit lines parsed
            linesParsed += 1
            if linesParsed > maxLinesToParse {
                wasTruncated = true
                break
            }
            if line.hasPrefix("diff --git") {
                // Save previous file
                if var file = currentFile {
                    if let hunk = currentHunk {
                        file.hunks.append(DiffHunk(
                            header: hunk.header,
                            oldStart: hunk.oldStart,
                            oldLines: hunk.oldLines,
                            newStart: hunk.newStart,
                            newLines: hunk.newLines,
                            lines: hunk.lines
                        ))
                    }
                    files.append(FileDiff(
                        oldPath: file.oldPath,
                        newPath: file.newPath,
                        status: determineStatus(file.oldPath, file.newPath),
                        hunks: file.hunks,
                        additions: file.additions,
                        deletions: file.deletions
                    ))
                }
                currentFile = nil
                currentHunk = nil
            } else if line.hasPrefix("--- ") {
                let path = String(line.dropFirst(4))
                if currentFile == nil {
                    currentFile = (oldPath: path == "/dev/null" ? nil : path, newPath: "", hunks: [], additions: 0, deletions: 0)
                } else {
                    currentFile?.oldPath = path == "/dev/null" ? nil : path
                }
            } else if line.hasPrefix("+++ ") {
                let path = String(line.dropFirst(4)).replacingOccurrences(of: "b/", with: "")
                if currentFile == nil {
                    currentFile = (oldPath: nil, newPath: path, hunks: [], additions: 0, deletions: 0)
                } else {
                    currentFile?.newPath = path
                }
            } else if line.hasPrefix("@@") {
                // Save previous hunk
                if let hunk = currentHunk {
                    currentFile?.hunks.append(DiffHunk(
                        header: hunk.header,
                        oldStart: hunk.oldStart,
                        oldLines: hunk.oldLines,
                        newStart: hunk.newStart,
                        newLines: hunk.newLines,
                        lines: hunk.lines
                    ))
                }

                // Parse hunk header: @@ -oldStart,oldLines +newStart,newLines @@
                let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@.*"#
                print("DEBUG: Parsing hunk header: \(line)")
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                    let oldStart = Int(line[Range(match.range(at: 1), in: line)!]) ?? 0
                    let oldLines = match.range(at: 2).location != NSNotFound ?
                        Int(line[Range(match.range(at: 2), in: line)!]) ?? 1 : 1
                    let newStart = Int(line[Range(match.range(at: 3), in: line)!]) ?? 0
                    let newLines = match.range(at: 4).location != NSNotFound ?
                        Int(line[Range(match.range(at: 4), in: line)!]) ?? 1 : 1

                    oldLineNum = oldStart
                    newLineNum = newStart
                    print("DEBUG: Hunk parsed successfully. Start: \(newStart)")

                    currentHunk = (header: line, oldStart: oldStart, oldLines: oldLines, newStart: newStart, newLines: newLines, lines: [])
                } else {
                    print("DEBUG: Failed to parse hunk header regex for: \(line)")
                }
            } else if currentHunk != nil {
                let type: DiffLineType
                var content = line
                var oldNum: Int? = nil
                var newNum: Int? = nil

                if line.hasPrefix("+") {
                    type = .addition
                    content = String(line.dropFirst())
                    newNum = newLineNum
                    newLineNum += 1
                    currentFile?.additions += 1
                } else if line.hasPrefix("-") {
                    type = .deletion
                    content = String(line.dropFirst())
                    oldNum = oldLineNum
                    oldLineNum += 1
                    currentFile?.deletions += 1
                } else if line.hasPrefix(" ") {
                    type = .context
                    content = String(line.dropFirst())
                    oldNum = oldLineNum
                    newNum = newLineNum
                    oldLineNum += 1
                    newLineNum += 1
                } else {
                    type = .context
                    oldNum = oldLineNum
                    newNum = newLineNum
                    oldLineNum += 1
                    newLineNum += 1
                }

                currentHunk?.lines.append(DiffLine(
                    type: type,
                    content: content,
                    oldLineNumber: oldNum,
                    newLineNumber: newNum
                ))
            }
        }

        // Save last file
        if var file = currentFile {
            if var hunk = currentHunk {
                // Add truncation indicator if needed
                if wasTruncated {
                    hunk.lines.append(DiffLine(
                        type: .context,
                        content: "... [Diff truncated - file too large to display fully] ...",
                        oldLineNumber: nil,
                        newLineNumber: nil
                    ))
                }
                file.hunks.append(DiffHunk(
                    header: hunk.header,
                    oldStart: hunk.oldStart,
                    oldLines: hunk.oldLines,
                    newStart: hunk.newStart,
                    newLines: hunk.newLines,
                    lines: hunk.lines
                ))
            }
            files.append(FileDiff(
                oldPath: file.oldPath,
                newPath: file.newPath,
                status: determineStatus(file.oldPath, file.newPath),
                hunks: file.hunks,
                additions: file.additions,
                deletions: file.deletions
            ))
        }

        return files
    }

    private static func determineStatus(_ oldPath: String?, _ newPath: String) -> FileStatusType {
        if oldPath == nil || oldPath == "/dev/null" {
            return .added
        } else if newPath.isEmpty || newPath == "/dev/null" {
            return .deleted
        } else if oldPath != newPath {
            return .renamed
        }
        return .modified
    }
}

// MARK: - Large File Diff View (Paginated for performance)

/// High-performance diff view for large files with pagination
struct LargeFileDiffViewWrapper: View {
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
                                    .frame(width: 16, height: 16)
                            }
                            Text("Load \(min(remainingLines, Self.loadMoreIncrement)) more lines (\(remainingLines) remaining)")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(GitKrakenTheme.backgroundSecondary)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(GitKrakenTheme.accent)
                }
            }
        }

        .background(GitKrakenTheme.background)
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
    let line: LargeDiffLine
    let showLineNumbers: Bool

    var body: some View {
        HStack(spacing: 0) {
            if line.type == .hunkHeader {
                // Hunk header
                Text(line.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SwiftUI.Color.cyan.opacity(0.1))
            } else {
                // Regular line
                if showLineNumbers {
                    HStack(spacing: 2) {
                        Text(line.oldLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 35, alignment: .trailing)
                        Text(line.newLineNumber.map { "\($0)" } ?? "")
                            .frame(width: 35, alignment: .trailing)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.trailing, 4)
                }

                Text(prefix)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(prefixColor)
                    .frame(width: 14)

                Text(line.content)
                    .font(.system(size: 12, design: .monospaced))
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
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        default: return .secondary
        }
    }

    private var textColor: SwiftUI.Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        default: return SwiftUI.Color(NSColor.textColor)
        }
    }

    private var backgroundColor: SwiftUI.Color {
        switch line.type {
        case .addition: return .green.opacity(0.1)
        case .deletion: return .red.opacity(0.1)
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
        context.setFillColor(NSColor(GitKrakenTheme.background).cgColor)
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
