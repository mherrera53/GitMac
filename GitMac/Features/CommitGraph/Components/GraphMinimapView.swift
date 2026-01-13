import SwiftUI

struct GraphMinimapView: View {
    let nodes: [GraphNode]
    let visibleRange: ClosedRange<Int>
    let totalHeight: CGFloat
    let onSeek: (Int) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isDragging = false

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return VStack(spacing: 0) {
            // Header
            Text("MAP")
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(theme.backgroundSecondary)

            Divider()

            // Minimap canvas
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Background
                    theme.background

                    // Commit dots
                    Canvas { ctx, size in
                        let nodeCount = max(nodes.count, 1)
                        let rowHeight = size.height / CGFloat(nodeCount)

                        for (index, node) in nodes.enumerated() {
                            let y = CGFloat(index) * rowHeight + rowHeight / 2
                            let x = CGFloat(node.lane) * 6 + 8

                            let dotSize: CGFloat = max(2, min(rowHeight * 0.6, 4))
                            let dotRect = CGRect(
                                x: x - dotSize/2,
                                y: y - dotSize/2,
                                width: dotSize,
                                height: dotSize
                            )

                            let color = Color.branchColor(node.lane)
                            ctx.fill(Circle().path(in: dotRect), with: .color(color))
                        }
                    }

                    // Visible viewport indicator
                    Rectangle()
                        .fill(theme.selection.opacity(0.3))
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.accent, lineWidth: 1)
                        )
                        .frame(
                            width: geo.size.width,
                            height: viewportHeight(in: geo.size)
                        )
                        .offset(y: viewportOffset(in: geo.size))
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
            .frame(width: 60)
        }
        .frame(width: 60)
        .background(theme.background)
    }

    private func viewportHeight(in size: CGSize) -> CGFloat {
        let visibleCount = visibleRange.upperBound - visibleRange.lowerBound + 1
        let totalCount = max(nodes.count, 1)
        return size.height * CGFloat(visibleCount) / CGFloat(totalCount)
    }

    private func viewportOffset(in size: CGSize) -> CGFloat {
        let totalCount = max(nodes.count, 1)
        return size.height * CGFloat(visibleRange.lowerBound) / CGFloat(totalCount)
    }

    private func indexFromY(_ y: CGFloat, in size: CGSize) -> Int {
        let totalCount = nodes.count
        let ratio = y / size.height
        let index = Int(ratio * CGFloat(totalCount))
        return max(0, min(index, totalCount - 1))
    }
}
