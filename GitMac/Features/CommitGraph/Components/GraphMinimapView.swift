import SwiftUI

struct GraphMinimapView: View {
    let minimapNodes: [MinimapCommitNode]
    let loadedCount: Int
    let visibleRange: ClosedRange<Int>
    let onSeek: (Int) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isDragging = false

    private let minimapWidth: CGFloat = 50

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 3) {
                Image(systemName: "map.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textMuted)
                Text("\(minimapNodes.count)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(theme.backgroundSecondary)

            Divider()

            // Minimap canvas
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Background
                    theme.background

                    // Compact minimap: collapse lanes to max 5 columns, tiny dots
                    Canvas { ctx, size in
                        let totalCount = max(minimapNodes.count, 1)
                        let rowHeight = size.height / CGFloat(totalCount)
                        let maxVisualLanes = 5
                        let padding: CGFloat = 3
                        let usableWidth = size.width - padding * 2
                        let laneWidth = usableWidth / CGFloat(maxVisualLanes)

                        // Draw commit dots (collapsed to max 5 lanes)
                        for node in minimapNodes {
                            let y = CGFloat(node.index) * rowHeight + rowHeight / 2
                            let visualLane = node.lane % maxVisualLanes
                            let x = padding + CGFloat(visualLane) * laneWidth + laneWidth / 2

                            let dotSize: CGFloat = node.isMerge ? 1.5 : 1.0
                            let dotRect = CGRect(
                                x: x - dotSize / 2,
                                y: y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )

                            let color = Color.branchColor(node.lane)
                            ctx.fill(Circle().path(in: dotRect), with: .color(color.opacity(0.7)))
                        }
                    }

                    // Visible viewport indicator -- prominent
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(isDragging ? 0.12 : 0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(isDragging ? 0.6 : 0.35), lineWidth: 1)
                        )
                        .frame(
                            width: geo.size.width - 2,
                            height: max(viewportHeight(in: geo.size), 8)
                        )
                        .offset(x: 1, y: viewportOffset(in: geo.size))
                        .animation(.easeOut(duration: 0.08), value: visibleRange.lowerBound)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newIndex = indexFromY(value.location.y, in: geo.size)
                            onSeek(newIndex)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onTapGesture { location in
                    let newIndex = indexFromY(location.y, in: geo.size)
                    onSeek(newIndex)
                }
            }
            .frame(width: minimapWidth)
        }
        .frame(width: minimapWidth)
        .background(theme.background)
    }

    private func viewportHeight(in size: CGSize) -> CGFloat {
        let visibleCount = visibleRange.upperBound - visibleRange.lowerBound + 1
        let totalCount = max(minimapNodes.count, 1)
        return size.height * CGFloat(visibleCount) / CGFloat(totalCount)
    }

    private func viewportOffset(in size: CGSize) -> CGFloat {
        let totalCount = max(minimapNodes.count, 1)
        return size.height * CGFloat(visibleRange.lowerBound) / CGFloat(totalCount)
    }

    private func indexFromY(_ y: CGFloat, in size: CGSize) -> Int {
        let totalCount = minimapNodes.count
        let ratio = y / size.height
        let index = Int(ratio * CGFloat(totalCount))
        return max(0, min(index, totalCount - 1))
    }
}
