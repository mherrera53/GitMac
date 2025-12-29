import SwiftUI

// MARK: - Diff Scroll Preference Keys

struct DiffScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(AppTheme.textPrimary.opacity(isDragging ? 0.35 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(AppTheme.textPrimary.opacity(isDragging ? 0.7 : 0.5), lineWidth: 1)
                    )
                    .frame(width: geo.size.width - 4, height: vpHeight)
                    .offset(x: DesignTokens.Spacing.xxs, y: vpTop)
                    .highPriorityGesture(
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
