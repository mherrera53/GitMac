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
            let lineHeight = max(0.5, geo.size.height / CGFloat(max(totalLines, 1)))
            let vpHeight = max(20, geo.size.height * viewportRatio)
            let vpTop = scrollPosition * (geo.size.height - vpHeight)

            ZStack(alignment: .topLeading) {
                // Dimmed background for non-viewport area (optional, for focus)
                Color.black.opacity(0.05)

                // Fast canvas-style rendering
                Canvas { context, size in
                    var y: CGFloat = 0
                    let spacing: CGFloat = 0.2 // Tiny vertical gap
                    
                    for row in rows {
                        if row.color != .clear {
                            context.fill(
                                Path(CGRect(x: 0, y: y + spacing, width: size.width, height: max(lineHeight - spacing * 2, 0.5))),
                                with: .color(row.color.opacity(0.8))
                            )
                        }
                        y += lineHeight
                    }
                }

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
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        // Calculate position relative to the center of the lens or just follow touch
                        let normalizedY = min(1, max(0, value.location.y / geo.size.height))
                        
                        // We want the lens center to be at the touch point if possible
                        onScrollToPosition?(normalizedY)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
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
