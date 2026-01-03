import SwiftUI

// MARK: - Diff Scroll Preference Keys

struct DiffScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Optimized Minimap (Interactive with click navigation)

struct MinimapRow: Identifiable {
    let id: Int
    let color: Color
    let isHeader: Bool
}

struct OptimizedMinimapView: View {
    let rows: [MinimapRow]
    let scrollPosition: CGFloat
    let viewportRatio: CGFloat
    var onScrollToPosition: ((CGFloat) -> Void)? = nil

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let totalLines = rows.count
            // Strictly scale content to fit the available height
            let stepHeight = geo.size.height / CGFloat(max(totalLines, 1))
            // Ensure visible blocks are at least somewhat visible, even if they overlap
            let drawHeight = max(stepHeight, 1.0) 
            
            let vpHeight = max(20, geo.size.height * viewportRatio)
            let vpTop = scrollPosition * (geo.size.height - vpHeight)

            ZStack(alignment: .topLeading) {
                // Dimmed background for non-viewport area (optional, for focus)
                Color.black.opacity(0.05)

                // Fast canvas-style rendering - disable hit testing
                Canvas { context, size in
                    var y: CGFloat = 0
                    // No artificial spacing that accumulates error
                    
                    for row in rows {
                        if row.color != .clear {
                            context.fill(
                                Path(CGRect(x: 0, y: y, width: size.width, height: drawHeight)),
                                with: .color(row.color.opacity(0.8))
                            )
                        }
                        y += stepHeight
                    }
                }
                .allowsHitTesting(false) // CRITICAL: Don't let Canvas block gestures

                // Viewport indicator (Kaleidoscope-style lens)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(isDragging ? 0.3 : 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.textPrimary.opacity(isDragging ? 0.8 : 0.4), lineWidth: 1.5)
                    )
                    .frame(width: geo.size.width - 2, height: vpHeight)
                    .offset(x: 1, y: vpTop)
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .allowsHitTesting(false) // Don't block gestures
            }
            // Invisible overlay to capture ALL gestures
            .overlay(
                Color.white.opacity(0.001) // Ensure it's hit-testable but invisible
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let h = geo.size.height
                                // Center the lens under the cursor if possible
                                // If we just use value.location.y, that's the top of the lens? 
                                // Actually, standard minimap behavior is usually "absolute jump to this point".
                                // Let's ensure the calculation is robust.
                                let normalizedY = min(1, max(0, value.location.y / h))
                                onScrollToPosition?(normalizedY)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            )
        }
        .background(AppTheme.backgroundSecondary.opacity(0.5))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Kaleidoscope Minimap Wrapper (reactive to scroll changes)

struct KaleidoscopeMinimapWrapper: View {
    let rows: [MinimapRow]
    @Binding var scrollOffset: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var contentHeight: CGFloat
    var minimapScrollTriggerAction: () -> Void
    
    var body: some View {
        let maxScroll = max(1, contentHeight - viewportHeight)
        let scrollRatio = contentHeight > viewportHeight && contentHeight > 0
            ? max(0, min(1, scrollOffset / maxScroll))
            : CGFloat(0)
        let vpRatio = contentHeight > 0 ? min(1, viewportHeight / contentHeight) : CGFloat(1)
        
        OptimizedMinimapView(
            rows: rows,
            scrollPosition: scrollRatio,
            viewportRatio: vpRatio
        ) { ratio in
            NSLog("🔵 [MinimapWrapper] Callback! ratio=%.2f, maxScroll=%.1f, newOffset=%.1f", ratio, maxScroll, ratio * maxScroll)
            scrollOffset = ratio * maxScroll
            minimapScrollTriggerAction()
        }
    }
}
