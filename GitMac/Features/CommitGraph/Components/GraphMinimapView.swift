import SwiftUI

struct GraphMinimapView: View {
    let minimapNodes: [MinimapCommitNode]
    let loadedCount: Int
    let visibleRange: ClosedRange<Int>
    let onSeek: (Int) -> Void

    @Environment(ThemeManager.self) private var themeManager
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

                    // Graph minimap: lines + dots showing real merge topology
                    Canvas { ctx, size in
                        let totalCount = max(minimapNodes.count, 1)
                        let rowHeight = size.height / CGFloat(totalCount)
                        let maxVisualLanes = 5
                        let padding: CGFloat = 4
                        let usableWidth = size.width - padding * 2
                        let laneWidth = usableWidth / CGFloat(maxVisualLanes)

                        func xFor(lane: Int) -> CGFloat {
                            padding + CGFloat(lane % maxVisualLanes) * laneWidth + laneWidth / 2
                        }
                        func yFor(index: Int) -> CGFloat {
                            CGFloat(index) * rowHeight + rowHeight / 2
                        }

                        // Draw connection lines (parent edges) -- the graph structure
                        for node in minimapNodes {
                            let childY = yFor(index: node.index)
                            let childX = xFor(lane: node.lane)

                            for i in 0..<node.parentIndices.count {
                                let parentIdx = node.parentIndices[i]
                                let parentLane = i < node.parentLanes.count ? node.parentLanes[i] : node.lane
                                let parentY = yFor(index: parentIdx)
                                let parentX = xFor(lane: parentLane)

                                let color = Color.branchColor(node.lane)
                                let isMergeLine = i > 0 // secondary parent = merge line

                                var linePath = Path()
                                if childX == parentX {
                                    // Straight vertical line (same lane)
                                    linePath.move(to: CGPoint(x: childX, y: childY))
                                    linePath.addLine(to: CGPoint(x: parentX, y: parentY))
                                } else {
                                    // Curved merge/branch line
                                    linePath.move(to: CGPoint(x: childX, y: childY))
                                    linePath.addCurve(
                                        to: CGPoint(x: parentX, y: parentY),
                                        control1: CGPoint(x: childX, y: childY + (parentY - childY) * 0.4),
                                        control2: CGPoint(x: parentX, y: childY + (parentY - childY) * 0.6)
                                    )
                                }

                                ctx.stroke(
                                    linePath,
                                    with: .color(color.opacity(isMergeLine ? 0.25 : 0.35)),
                                    lineWidth: isMergeLine ? 0.5 : 0.7
                                )
                            }
                        }

                        // Draw commit dots on top
                        for node in minimapNodes {
                            let y = yFor(index: node.index)
                            let x = xFor(lane: node.lane)

                            let dotSize: CGFloat = node.isMerge ? 1.8 : 1.0
                            let dotRect = CGRect(
                                x: x - dotSize / 2,
                                y: y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )

                            let color = Color.branchColor(node.lane)
                            ctx.fill(Circle().path(in: dotRect), with: .color(color.opacity(0.8)))
                        }
                    }

                    // Visible viewport indicator
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
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            // Calculate the center of where the viewport should be
                            let vpHeight = viewportHeight(in: geo.size)
                            let centerY = value.location.y - vpHeight / 2
                            let ratio = centerY / (geo.size.height - vpHeight)
                            let clampedRatio = max(0, min(1, ratio))
                            let targetIndex = Int(clampedRatio * CGFloat(minimapNodes.count))
                            onSeek(max(0, min(targetIndex, minimapNodes.count - 1)))
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
