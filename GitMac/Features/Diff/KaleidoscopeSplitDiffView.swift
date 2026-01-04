import SwiftUI
import AppKit

// MARK: - Kaleidoscope-style Split Diff View

/// Enhanced split diff view with connected change visualization
struct KaleidoscopeSplitDiffView: View {
    // Receive pre-calculated lines from parent to ensure 1:1 sync with Minimap
    let pairedLines: [DiffPairWithConnection]
    let filePath: String
    let hunksById: [UUID: DiffHunk]
    let repoPath: String?
    var allowPatchActions: Bool = true
    var contentVersion: Int = 0
    let showLineNumbers: Bool
    var showConnectionLines: Bool = true
    var isFluidMode: Bool = false
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    
    // Content Height is now derived from pairedLines, but we bind it to report back to parent/minimap
    @Binding var contentHeight: CGFloat
    @Binding var minimapScrollTrigger: UUID

    @StateObject private var themeManager = ThemeManager.shared
    
    // Virtualization state
    @State private var visibleRange: Range<Int> = 0..<50 // Initialize with first 50 items visible
    
    // Scroll state management
    @State private var lastExternalScrollOffset: CGFloat = -1
    @State private var isHandlingMinimapClick = false

    // Layout Constants
    private let rowHeight: CGFloat = 24
    private let gutterWidth: CGFloat = 60



    var body: some View {
        GeometryReader { geometry in
            let theme = Color.Theme(themeManager.colors)
            // Dynamic Layout Metrics
            let panelWidth = max(0, (geometry.size.width - gutterWidth) / 2)
            let overlap = min(240, max(18, panelWidth * 0.24))
            
            let safeLower = max(0, min(visibleRange.lowerBound, pairedLines.count))
            let safeUpper = max(safeLower, min(visibleRange.upperBound, pairedLines.count))
            let safeRange = safeLower..<safeUpper

            let topSpacerHeight = CGFloat(safeLower) * rowHeight
            let bottomSpacerHeight = CGFloat(max(0, pairedLines.count - safeUpper)) * rowHeight

            if geometry.size.width > 0 {
                KaleidoscopeScrollContainer(
                    scrollOffset: $scrollOffset,
                    viewportHeight: $viewportHeight,
                    contentHeight: $contentHeight,
                    minimapScrollTrigger: $minimapScrollTrigger,
                    desiredWidth: geometry.size.width,
                    contentVersion: contentVersion
                        &+ safeLower &* 31
                        &+ safeUpper &* 131
                        &+ Int(geometry.size.width)
                ) {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            SwiftUI.Color.clear
                                .frame(height: topSpacerHeight)

                            ForEach(safeRange, id: \.self) { index in
                                let pair = pairedLines[index]
                                HStack(spacing: 0) {
                                    Group {
                                        if let header = pair.hunkHeader {
                                            KaleidoscopeHunkHeader(
                                                header: header,
                                                onStageHunk: stageHunkAction(for: pair),
                                                onDiscardHunk: discardHunkAction(for: pair)
                                            )
                                        } else if let line = pair.left {
                                            KaleidoscopeDiffLine(
                                                line: line,
                                                side: .left,
                                                showLineNumber: showLineNumbers,
                                                pairedLine: pair.right
                                            )
                                            .diffLineContextMenuWithActions(
                                                line: line,
                                                onStageLine: stageLineAction(for: pair, side: .left),
                                                onDiscardLine: discardLineAction(for: pair, side: .left)
                                            )
                                        } else {
                                            EmptyDiffLine(showLineNumber: showLineNumbers)
                                        }
                                    }
                                    .frame(width: panelWidth)

                                    KaleidoscopeGutterView()
                                        .frame(width: gutterWidth)

                                    Group {
                                        if let header = pair.hunkHeader {
                                            KaleidoscopeHunkHeader(
                                                header: header,
                                                onStageHunk: stageHunkAction(for: pair),
                                                onDiscardHunk: discardHunkAction(for: pair)
                                            )
                                        } else if let line = pair.right {
                                            KaleidoscopeDiffLine(
                                                line: line,
                                                side: .right,
                                                showLineNumber: showLineNumbers,
                                                pairedLine: pair.left
                                            )
                                            .diffLineContextMenuWithActions(
                                                line: line,
                                                onStageLine: stageLineAction(for: pair, side: .right),
                                                onDiscardLine: discardLineAction(for: pair, side: .right)
                                            )
                                        } else {
                                            EmptyDiffLine(showLineNumber: showLineNumbers)
                                        }
                                    }
                                    .frame(width: panelWidth)
                                }
                                .frame(height: rowHeight)
                            }

                            SwiftUI.Color.clear
                                .frame(height: bottomSpacerHeight)
                        }
                        .frame(width: geometry.size.width, alignment: .topLeading)
                        .background(theme.background)

                        if showConnectionLines, !pairedLines.isEmpty {
                            ConnectionRibbonsView(
                                pairs: pairedLines,
                                lineHeight: rowHeight,
                                isFluidMode: isFluidMode,
                                viewWidth: geometry.size.width,
                                gutterWidth: gutterWidth,
                                panelOverlap: overlap,
                                visibleRange: visibleRange
                            )
                            .frame(width: geometry.size.width, height: CGFloat(pairedLines.count) * rowHeight, alignment: .topLeading)
                            .allowsHitTesting(false)
                        }
                    }
                }
                .onAppear {
                    updateContentHeight()
                    updateVisibleRange(offset: scrollOffset, viewport: viewportHeight)
                }
                .onChange(of: pairedLines.count) { _, _ in
                    updateContentHeight()
                }
                .onChange(of: scrollOffset) { _, newValue in
                    updateVisibleRange(offset: newValue, viewport: viewportHeight)
                }
            } else {
                Color.clear
            }
        }
    }
    
    // MARK: - Helpers
    
    private func updateContentHeight() {
        let calculatedHeight = CGFloat(pairedLines.count) * rowHeight
        if contentHeight != calculatedHeight {
            // Update binding so parent knows accurate height for minimap
            contentHeight = calculatedHeight
        }
        // Also update visible range
        updateVisibleRange(offset: scrollOffset, viewport: viewportHeight)
    }

    private func updateVisibleRange(offset: CGFloat, viewport: CGFloat) {
        guard !pairedLines.isEmpty else { return }

        let buffer = max(10, Int(viewport / rowHeight)) // Dynamic buffer based on viewport height
        let startRow = max(0, Int(offset / rowHeight) - buffer)
        let endRow = min(pairedLines.count, Int((offset + viewport) / rowHeight) + buffer)
        
        if visibleRange.lowerBound != startRow || visibleRange.upperBound != endRow {
            visibleRange = startRow..<endRow
        }
    }

    private func drawConnectionLines(
        context: GraphicsContext,
        size: CGSize,
        pairs: [DiffPairWithConnection],
        lineHeight: CGFloat
    ) {
        let theme = Color.Theme(themeManager.colors)
        var yOffset: CGFloat = 0

        for pair in pairs {
            if pair.hunkHeader != nil {
                yOffset += lineHeight
                continue
            }

            let centerY = yOffset + lineHeight / 2

            switch pair.connectionType {
            case .change:
                // Kaleidoscope-style curved connection line spanning both panes
                var path = Path()
                let paneWidth = size.width / 2
                
                // Start from the right edge of left pane
                path.move(to: CGPoint(x: paneWidth - 2, y: centerY))
                
                // Smooth bezier curve spanning the gap between panes
                let controlPoint1 = CGPoint(x: paneWidth + 10, y: centerY - 3)
                let controlPoint2 = CGPoint(x: paneWidth + 10, y: centerY + 3)
                
                // End at the left edge of right pane
                path.addCurve(
                    to: CGPoint(x: paneWidth + 2, y: centerY),
                    control1: controlPoint1,
                    control2: controlPoint2
                )
                
                context.stroke(
                    path,
                    with: .color(theme.info.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )

            case .deletion:
                // Deletion indicator - short line from left
                var path = Path()
                path.move(to: CGPoint(x: 5, y: centerY))
                path.addLine(to: CGPoint(x: 20, y: centerY))

                context.stroke(
                    path,
                    with: .color(theme.diffDeletion.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

            case .addition:
                // Addition indicator - short line from right
                var path = Path()
                path.move(to: CGPoint(x: size.width - 20, y: centerY))
                path.addLine(to: CGPoint(x: size.width - 5, y: centerY))

                context.stroke(
                    path,
                    with: .color(theme.diffAddition.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

            case .none:
                break
            }

            yOffset += lineHeight
        }
    }

    private func stageLineAction(for pair: DiffPairWithConnection, side: DiffSide) -> (() -> Void)? {
        guard allowPatchActions else { return nil }
        guard let repoPath else { return nil }
        guard let hunkId = pair.hunkId, let hunk = hunksById[hunkId] else { return nil }

        let lineIndex: Int?
        switch side {
        case .left:
            lineIndex = pair.leftLineIndexInHunk
        case .right:
            lineIndex = pair.rightLineIndexInHunk
        }
        guard let lineIndex else { return nil }
        return {
            Task {
                do {
                    let service = GitService()
                    service.currentRepository = Repository(path: repoPath)
                    try await service.stageLine(filePath: filePath, hunk: hunk, lineIndex: lineIndex)
                    NotificationManager.shared.success("Staged line")
                } catch {
                    NotificationManager.shared.error("Failed to stage line", detail: String(describing: error))
                }
            }
        }
    }

    private func discardLineAction(for pair: DiffPairWithConnection, side: DiffSide) -> (() -> Void)? {
        guard allowPatchActions else { return nil }
        guard let repoPath else { return nil }
        guard let hunkId = pair.hunkId, let hunk = hunksById[hunkId] else { return nil }

        let lineIndex: Int?
        switch side {
        case .left:
            lineIndex = pair.leftLineIndexInHunk
        case .right:
            lineIndex = pair.rightLineIndexInHunk
        }
        guard let lineIndex else { return nil }
        return {
            Task {
                do {
                    let service = GitService()
                    service.currentRepository = Repository(path: repoPath)
                    try await service.discardLine(filePath: filePath, hunk: hunk, lineIndex: lineIndex)
                    NotificationManager.shared.success("Discarded line")
                } catch {
                    NotificationManager.shared.error("Failed to discard line", detail: String(describing: error))
                }
            }
        }
    }

    private func stageHunkAction(for pair: DiffPairWithConnection) -> (() -> Void)? {
        guard allowPatchActions else { return nil }
        guard pair.hunkHeader != nil else { return nil }
        guard let repoPath else { return nil }
        guard let hunkId = pair.hunkId, let hunk = hunksById[hunkId] else { return nil }
        return {
            Task {
                do {
                    let service = GitService()
                    service.currentRepository = Repository(path: repoPath)
                    try await service.stageHunk(filePath: filePath, hunk: hunk)
                    NotificationManager.shared.success("Staged hunk")
                } catch {
                    NotificationManager.shared.error("Failed to stage hunk", detail: String(describing: error))
                }
            }
        }
    }

    private func discardHunkAction(for pair: DiffPairWithConnection) -> (() -> Void)? {
        guard allowPatchActions else { return nil }
        guard pair.hunkHeader != nil else { return nil }
        guard let repoPath else { return nil }
        guard let hunkId = pair.hunkId, let hunk = hunksById[hunkId] else { return nil }
        return {
            Task {
                do {
                    let service = GitService()
                    service.currentRepository = Repository(path: repoPath)
                    try await service.discardHunk(filePath: filePath, hunk: hunk)
                    NotificationManager.shared.success("Discarded hunk")
                } catch {
                    NotificationManager.shared.error("Failed to discard hunk", detail: String(describing: error))
                }
            }
        }
    }
}

// MARK: - NSScrollView-backed container (minimap accurate scrolling)

private struct KaleidoscopeScrollContainer<Content: View>: NSViewRepresentable {
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var minimapScrollTrigger: UUID
    let desiredWidth: CGFloat
    let contentVersion: Int
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.postsBoundsChangedNotifications = true

        let hostingView = NSHostingView(rootView: content())
        scrollView.documentView = hostingView

        context.coordinator.scrollView = scrollView
        context.coordinator.hostingView = hostingView
        context.coordinator.lastContentVersion = contentVersion

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let hostingView = context.coordinator.hostingView else { return }

        if context.coordinator.lastContentVersion != contentVersion {
            hostingView.rootView = content()
            context.coordinator.lastContentVersion = contentVersion
        }

        let viewport = scrollView.contentView.bounds.height
        if viewport > 0, context.coordinator.lastViewportHeight != viewport {
            context.coordinator.lastViewportHeight = viewport
            DispatchQueue.main.async {
                viewportHeight = viewport
            }
        }

        // Ensure the document view has a real frame so the scroll view can scroll.
        // Avoid calling `fittingSize` on every scroll tick (expensive layout).
        let viewportWidth = scrollView.contentView.bounds.width
        if viewportWidth > 0, context.coordinator.cachedDocumentWidth != viewportWidth {
            context.coordinator.cachedDocumentWidth = viewportWidth
        }
        
        // Use desired width if explicitly provided and scroll view is still waking up
        let effectiveWidth = desiredWidth > 0 ? desiredWidth : context.coordinator.cachedDocumentWidth
        let docWidth = max(1, effectiveWidth)
        let docHeight = max(contentHeight, viewport)
        if hostingView.frame.size.width != docWidth || hostingView.frame.size.height != docHeight {
            hostingView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)
        }

        // Programmatic scroll: react to minimap trigger and clamp
        let maxScroll = max(0, contentHeight - viewport)
        let clampedOffset = max(0, min(scrollOffset, maxScroll))
        if context.coordinator.lastAppliedMinimapTrigger != minimapScrollTrigger {
            context.coordinator.lastAppliedMinimapTrigger = minimapScrollTrigger
            Task { @MainActor in
                context.coordinator.scrollTo(y: clampedOffset)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: KaleidoscopeScrollContainer
        weak var scrollView: NSScrollView?
        weak var hostingView: NSHostingView<Content>?

        var isSyncing = false
        var lastAppliedMinimapTrigger: UUID = UUID()
        var lastContentVersion: Int = -1
        var cachedDocumentWidth: CGFloat = 0 // Initialized dynamically in init
        var lastViewportHeight: CGFloat = 0

        init(parent: KaleidoscopeScrollContainer) {
            self.parent = parent
            self.cachedDocumentWidth = parent.desiredWidth
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @MainActor @objc func scrollViewDidScroll(_ notification: Notification) {
            guard !isSyncing else { return }
            guard let clipView = notification.object as? NSClipView else { return }
            let y = max(0, clipView.bounds.origin.y)
            let viewport = clipView.bounds.height
            let maxScroll = max(0, parent.contentHeight - viewport)
            let newOffset = min(y, maxScroll)
            if parent.scrollOffset != newOffset {
                DispatchQueue.main.async {
                    self.parent.scrollOffset = newOffset
                }
            }
        }

        @MainActor func scrollTo(y: CGFloat) {
            guard let scrollView else { return }
            isSyncing = true
            scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.origin.x, y: y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
    }
}

private struct KaleidoscopeGutterView: View {
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)
        ZStack {
            Rectangle()
                .fill(theme.backgroundSecondary)
            Rectangle()
                .fill(theme.border.opacity(0.7))
                .frame(width: 1)
        }
    }
}

// MARK: - Diff Pair with Connection



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
        let theme = Color.Theme(themeManager.colors)
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
                segmentAttr.backgroundColor = theme.diffAddition.opacity(0.4)
                segmentAttr.foregroundColor = theme.diffAddition
            case .removed:
                segmentAttr.backgroundColor = theme.diffDeletion.opacity(0.4)
                segmentAttr.foregroundColor = theme.diffDeletion
            case .changed:
                let color = line.type == .addition ? theme.diffAddition : theme.diffDeletion
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
        .frame(height: 24)
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
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        default: return theme.textMuted
        }
    }

    private func backgroundColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return theme.diffAdditionBg
        case .deletion: return theme.diffDeletionBg
        case .context, .hunkHeader: return SwiftUI.Color.clear
        }
    }

    private func lineNumberBackground(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return theme.diffLineNumberBg
        case .deletion: return theme.diffLineNumberBg
        case .context, .hunkHeader: return theme.backgroundSecondary
        }
    }

    private func textColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        case .context, .hunkHeader: return theme.text
        }
    }
}

// MARK: - Kaleidoscope Hunk Header

struct KaleidoscopeHunkHeader: View {
    let header: String
    var onStageHunk: (() -> Void)? = nil
    var onDiscardHunk: (() -> Void)? = nil
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "text.alignleft")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(theme.accent)

            Text(header)
                .font(DesignTokens.Typography.commitHash)
                .foregroundColor(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 24)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(theme.accent.opacity(0.08))
        .contextMenu {
            if let onStageHunk {
                Button {
                    onStageHunk()
                } label: {
                    Label("Stage Hunk", systemImage: "plus.circle")
                }
            }

            if let onDiscardHunk {
                Button(role: .destructive) {
                    onDiscardHunk()
                } label: {
                    Label("Discard Hunk", systemImage: "trash")
                }
            }
        }
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
        .frame(height: 24)
    }
}

// MARK: - Connection Lines View (Professional Quality)

// MARK: - Row Connection Line

struct RowConnectionLine: View {
    var isFluidMode: Bool
    let width: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let centerY = size.height / 2
            
            if isFluidMode {
                // Fluid: Flowing S-curve
                var path = Path()
                path.move(to: CGPoint(x: 0, y: centerY))
                
                let cp1X = width * 0.4
                let cp2X = width * 0.6
                path.addCurve(
                    to: CGPoint(x: width, y: centerY),
                    control1: CGPoint(x: cp1X, y: centerY - 4),
                    control2: CGPoint(x: cp2X, y: centerY + 4)
                )
                
                var ctx = context
                ctx.opacity = 0.9
                ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.6, blue: 1.0)), 
                          style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                // Glow
                ctx.opacity = 0.4
                ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.6, blue: 1.0)),
                          style: StrokeStyle(lineWidth: 4, lineCap: .round))
            } else {
                // Blocks: Structured curve
                var path = Path()
                path.move(to: CGPoint(x: 0, y: centerY))
                
                let cp1X = width * 0.35
                let cp2X = width * 0.65
                path.addCurve(
                    to: CGPoint(x: width, y: centerY),
                    control1: CGPoint(x: cp1X, y: centerY - 2),
                    control2: CGPoint(x: cp2X, y: centerY + 2)
                )
                
                var ctx = context
                ctx.opacity = 0.85
                ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.6, blue: 1.0)),
                          style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                
                // Subtle glow
                ctx.opacity = 0.3
                ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.6, blue: 1.0)),
                          style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .frame(height: 24)
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
        let hunks = [
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
        ]
        let pairedLines = KaleidoscopePairingEngine.calculatePairs(from: hunks)
        let hunksById = Dictionary(uniqueKeysWithValues: hunks.map { ($0.id, $0) })
        
        KaleidoscopeSplitDiffView(
            pairedLines: pairedLines,
            filePath: "preview.txt",
            hunksById: hunksById,
            repoPath: nil,
            showLineNumbers: true,
            scrollOffset: .constant(0),
            viewportHeight: .constant(400),
            contentHeight: .constant(800),
            minimapScrollTrigger: .constant(UUID())
        )

    }
}
#endif
