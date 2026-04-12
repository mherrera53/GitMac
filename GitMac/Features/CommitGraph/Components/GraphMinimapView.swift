import SwiftUI

struct GraphMinimapView: View {
    let minimapNodes: [MinimapCommitNode]
    let loadedCount: Int
    let visibleRange: ClosedRange<Int>
    let onSeek: (Int) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isDragging = false

    private let minimapWidth: CGFloat = 80

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

                    // Branch lines + commit dots (uses lightweight minimapNodes)
                    Canvas { ctx, size in
                        let totalCount = max(minimapNodes.count, 1)
                        let rowHeight = size.height / CGFloat(totalCount)
                        let maxLane = (minimapNodes.map(\.lane).max() ?? 0) + 1
                        let laneWidth = min(size.width / CGFloat(max(maxLane, 1)), 12.0)

                        // Draw vertical lane lines (faint)
                        for lane in 0..<maxLane {
                            let x = CGFloat(lane) * laneWidth + laneWidth / 2
                            let color = Color.branchColor(lane).opacity(0.15)
                            let linePath = Path { p in
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: size.height))
                            }
                            ctx.stroke(linePath, with: .color(color), lineWidth: 0.5)
                        }

                        // Draw loaded region indicator
                        if loadedCount < totalCount {
                            let loadedHeight = CGFloat(loadedCount) * rowHeight
                            let unloadedRect = CGRect(x: 0, y: loadedHeight, width: size.width, height: size.height - loadedHeight)
                            ctx.fill(Rectangle().path(in: unloadedRect), with: .color(Color.gray.opacity(0.05)))
                        }

                        // Draw commit dots
                        for node in minimapNodes {
                            let y = CGFloat(node.index) * rowHeight + rowHeight / 2
                            let x = CGFloat(node.lane) * laneWidth + laneWidth / 2

                            let dotSize: CGFloat = node.isMerge ? 3 : 2
                            let dotRect = CGRect(
                                x: x - dotSize / 2,
                                y: y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )

                            let color = Color.branchColor(node.lane)
                            ctx.fill(Circle().path(in: dotRect), with: .color(color))
                        }
                    }

                    // Visible viewport indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.accent.opacity(isDragging ? 0.2 : 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(AppTheme.accent.opacity(isDragging ? 0.8 : 0.5), lineWidth: 1.5)
                        )
                        .frame(
                            width: geo.size.width - 4,
                            height: max(viewportHeight(in: geo.size), 12)
                        )
                        .offset(x: 2, y: viewportOffset(in: geo.size))
                        .animation(.easeOut(duration: 0.1), value: visibleRange.lowerBound)
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
