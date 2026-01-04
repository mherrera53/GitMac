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
    @State private var dragStartLocation: CGFloat?
    @State private var isLensInteraction = false
    @State private var initialScrollPosition: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let totalLines = rows.count
            let stepHeight = geo.size.height / CGFloat(max(totalLines, 1))
            let drawHeight = max(stepHeight, 1.0)
            
            let vpHeight = max(20, geo.size.height * viewportRatio)
            let vpTop = scrollPosition * (geo.size.height - vpHeight)

            ZStack(alignment: .topLeading) {
                // Dimmed background
                Color.black.opacity(0.05)
                
                // Content Canvas
                Canvas { context, size in
                    var y: CGFloat = 0
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
                .allowsHitTesting(false)

                // Lens
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(isDragging && isLensInteraction ? 0.3 : 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.textPrimary.opacity(isDragging && isLensInteraction ? 0.8 : 0.4), lineWidth: 1.5)
                    )
                    .frame(width: geo.size.width - 2, height: vpHeight)
                    .offset(x: 1, y: vpTop)
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .contentShape(Rectangle()) // Capture all touches
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let locationY = value.location.y
                        let trackHeight = geo.size.height - vpHeight
                        guard trackHeight > 0 else { return }

                        if !isDragging {
                            // Start of gesture
                            isDragging = true
                            
                            // Hit test: Did we click the lens?
                            if locationY >= vpTop && locationY <= (vpTop + vpHeight) {
                                isLensInteraction = true
                                dragStartLocation = locationY
                                initialScrollPosition = scrollPosition
                            } else {
                                isLensInteraction = false // Jump mode
                            }
                        }
                        
                        var newRatio: CGFloat = scrollPosition
                        
                        if isLensInteraction {
                            // Dragging the lens relative to start
                            if let startY = dragStartLocation {
                                let deltaY = locationY - startY
                                let deltaRatio = deltaY / trackHeight
                                newRatio = initialScrollPosition + deltaRatio
                            }
                        } else {
                            // Jump to specific point (center lens on mouse)
                            // We want the mouse Y to be the center of the lens
                            let targetTop = locationY - (vpHeight / 2)
                            newRatio = targetTop / trackHeight
                        }
                        
                        // Clamp
                        newRatio = max(0, min(1, newRatio))
                        
                        // Notify
                        if abs(newRatio - scrollPosition) > 0.001 {
                            onScrollToPosition?(newRatio)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragStartLocation = nil
                        isLensInteraction = false
                    }
            )
        }
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
        let maxScroll = max(0, contentHeight - viewportHeight)
        let scrollRatio = maxScroll > 0 && contentHeight > 0
            ? max(0, min(1, scrollOffset / maxScroll))
            : CGFloat(0)
        let vpRatio = contentHeight > 0 ? min(1, viewportHeight / contentHeight) : CGFloat(1)
        
        OptimizedMinimapView(
            rows: rows,
            scrollPosition: scrollRatio,
            viewportRatio: vpRatio,
            onScrollToPosition: { ratio in
                NSLog("🔵 [MinimapWrapper] Callback! ratio=%.2f, maxScroll=%.1f, newOffset=%.1f", ratio, maxScroll, ratio * maxScroll)
                let newOffset = ratio * maxScroll
                if abs(newOffset - scrollOffset) > 0.5 {
                    DispatchQueue.main.async {
                        scrollOffset = newOffset
                        minimapScrollTriggerAction()
                    }
                }
            }
        )
        .onAppear {
            NSLog("🔍 [KaleidoscopeMinimapWrapper] contentHeight: %.1f, viewportHeight: %.1f, scrollOffset: %.1f", contentHeight, viewportHeight, scrollOffset)
            NSLog("🔍 [KaleidoscopeMinimapWrapper] maxScroll: %.1f, scrollRatio: %.3f, vpRatio: %.3f", maxScroll, scrollRatio, vpRatio)
        }
        .onChange(of: contentHeight) { _, newHeight in
            NSLog("🔍 [KaleidoscopeMinimapWrapper] contentHeight changed to: %.1f", newHeight)
        }
        .onChange(of: scrollOffset) { _, newOffset in
            NSLog("🔍 [KaleidoscopeMinimapWrapper] scrollOffset changed to: %.1f", newOffset)
        }
    }
}
