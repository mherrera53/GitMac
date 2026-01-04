import SwiftUI
import AppKit

// MARK: - Kaleidoscope Unified View

/// True Unified view with A/B labels in the left margin (Kaleidoscope-style)
struct KaleidoscopeUnifiedView: View {
    let unifiedLines: [UnifiedLine]
    let showLineNumbers: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var minimapScrollTrigger: UUID
    var contentVersion: Int = 0

    @StateObject private var themeManager = ThemeManager.shared

    @State private var visibleRange: Range<Int> = 0..<50

private struct KaleidoscopeUnifiedScrollContainer<Content: View>: NSViewRepresentable {
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var minimapScrollTrigger: UUID
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
        let docWidth = max(1, context.coordinator.cachedDocumentWidth)
        let docHeight = max(contentHeight, viewport)
        if hostingView.frame.size.width != docWidth || hostingView.frame.size.height != docHeight {
            hostingView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)
        }

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
        var parent: KaleidoscopeUnifiedScrollContainer
        weak var scrollView: NSScrollView?
        weak var hostingView: NSHostingView<Content>?

        var isSyncing = false
        var lastAppliedMinimapTrigger: UUID = UUID()
        var lastContentVersion: Int = -1
        var cachedDocumentWidth: CGFloat = 0
        var lastViewportHeight: CGFloat = 0

        init(parent: KaleidoscopeUnifiedScrollContainer) {
            self.parent = parent
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

    var body: some View {
        let rowHeight: CGFloat = 24
        let safeLower = max(0, min(visibleRange.lowerBound, unifiedLines.count))
        let safeUpper = max(safeLower, min(visibleRange.upperBound, unifiedLines.count))
        let safeRange = safeLower..<safeUpper

        let topSpacerHeight = CGFloat(safeLower) * rowHeight
        let bottomSpacerHeight = CGFloat(max(0, unifiedLines.count - safeUpper)) * rowHeight

        KaleidoscopeUnifiedScrollContainer(
            scrollOffset: $scrollOffset,
            viewportHeight: $viewportHeight,
            contentHeight: $contentHeight,
            minimapScrollTrigger: $minimapScrollTrigger,
            contentVersion: contentVersion
                &+ safeLower &* 31
                &+ safeUpper &* 131
        ) {
            VStack(alignment: .leading, spacing: 0) {
                SwiftUI.Color.clear
                    .frame(height: topSpacerHeight)

                ForEach(safeRange, id: \.self) { index in
                    let line = unifiedLines[index]
                    UnifiedLineRow(
                        line: line,
                        showLineNumber: showLineNumbers
                    )
                }

                SwiftUI.Color.clear
                    .frame(height: bottomSpacerHeight)
            }
        }
        .onAppear {
            updateContentHeight()
            updateVisibleRange(offset: scrollOffset, viewport: viewportHeight)
        }
        .onChange(of: scrollOffset) { _, newValue in
            updateVisibleRange(offset: newValue, viewport: viewportHeight)
        }
    }

    private func updateContentHeight() {
        let height = CGFloat(unifiedLines.count) * 24
        if contentHeight != height {
            contentHeight = height
        }
    }

    private func updateVisibleRange(offset: CGFloat, viewport: CGFloat) {
        guard !unifiedLines.isEmpty else { return }
        let rowHeight: CGFloat = 24
        let buffer = 24
        let startRow = max(0, Int(offset / rowHeight) - buffer)
        let endRow = min(unifiedLines.count, Int((offset + viewport) / rowHeight) + buffer)
        if visibleRange.lowerBound != startRow || visibleRange.upperBound != endRow {
            visibleRange = startRow..<endRow
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
        let theme = Color.Theme(themeManager.colors)
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
        let theme = Color.Theme(themeManager.colors)
        switch line.side {
        case .a:
            Text("A")
                .font(DesignTokens.Typography.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 14, height: 14)
                .background(theme.accent)
                .cornerRadius(2)

        case .b:
            Text("B")
                .font(DesignTokens.Typography.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 14, height: 14)
                .background(theme.info)
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
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        case .hunkHeader: return theme.accent
        default: return theme.textMuted
        }
    }

    private func backgroundColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return theme.diffAdditionBg
        case .deletion: return theme.diffDeletionBg
        case .hunkHeader: return theme.accent.opacity(0.08)
        case .context: return Color.clear
        }
    }

    private func lineNumberBackground(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition, .deletion: return theme.diffLineNumberBg
        case .context, .hunkHeader: return theme.backgroundSecondary
        }
    }

    private func textColor(theme: SwiftUI.Color.Theme) -> Color {
        switch line.type {
        case .addition: return theme.diffAddition
        case .deletion: return theme.diffDeletion
        case .hunkHeader: return theme.accent
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
        let hunks: [DiffHunk] = [
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
            )
        ]
        let unifiedLines = KaleidoscopePairingEngine.calculateUnifiedLines(from: hunks)

        KaleidoscopeUnifiedView(
            unifiedLines: unifiedLines,
            showLineNumbers: true,
            scrollOffset: .constant(0),
            viewportHeight: .constant(400),
            contentHeight: .constant(800),
            minimapScrollTrigger: .constant(UUID())
        )
        .frame(width: 1000, height: 600)
    }
}
#endif
