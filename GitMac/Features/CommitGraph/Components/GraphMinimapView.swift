import SwiftUI

struct GraphMinimapView: View {
    /// Bounded drawing sample; indices still address the complete local history.
    let minimapNodes: [MinimapCommitNode]
    let totalCount: Int
    let maxLane: Int
    let loadedCount: Int
    let visibleRange: ClosedRange<Int>?
    let selectedIndex: Int?
    let isLoading: Bool
    let errorMessage: String?
    let onSeek: (Int) -> Void
    let onRetry: () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @State private var previewIndex: Int?
    private let minimapWidth: CGFloat = 80

    var body: some View {
        let theme = Color.Theme(themeManager.colors)
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "map")
                Text(totalCount, format: .number.notation(.compactName)).monospacedDigit()
                if isLoading { ProgressView().controlSize(.mini) }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(theme.text)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(theme.backgroundSecondary)
            Divider()

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    theme.background
                    GraphCanvas(role: .minimap) { context, size in
                        let rowHeight = size.height / CGFloat(max(1, totalCount))
                        let laneWidth = max(0, size.width - 10) / CGFloat(max(1, maxLane + 1))
                        func point(_ index: Int, _ lane: Int) -> CGPoint {
                            CGPoint(x: 5 + (CGFloat(lane) + 0.5) * laneWidth,
                                    y: (CGFloat(index) + 0.5) * rowHeight)
                        }
                        for node in minimapNodes {
                            let origin = point(node.index, node.lane)
                            let color = Color.branchColor(node.lane)
                            for (index, parent) in node.parentIndexValues.enumerated() {
                                guard index < node.parentLanes.count else { continue }
                                let end = point(parent, node.parentLanes[index])
                                var path = Path()
                                path.move(to: origin)
                                path.addCurve(to: end,
                                    control1: CGPoint(x: origin.x, y: origin.y + (end.y - origin.y) * 0.4),
                                    control2: CGPoint(x: end.x, y: origin.y + (end.y - origin.y) * 0.6))
                                context.stroke(path, with: .color(color.opacity(0.45)), lineWidth: 0.8)
                            }
                            let diameter: CGFloat = node.isMerge ? 2.4 : 1.4
                            context.fill(Circle().path(in: CGRect(x: origin.x - diameter / 2,
                                y: origin.y - diameter / 2, width: diameter, height: diameter)), with: .color(color))
                        }
                    }
                    .accessibilityHidden(true)

                    if let viewport = MinimapLayout.viewport(range: visibleRange, height: geometry.size.height, count: totalCount) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.accent.opacity(0.16))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppTheme.accent, lineWidth: 1))
                            .frame(width: max(0, geometry.size.width - 2), height: viewport.height)
                            .offset(x: 1, y: viewport.minY)
                            .allowsHitTesting(false)
                    }
                    if let index = previewIndex ?? selectedIndex, totalCount > 0 {
                        Rectangle().fill(theme.text.opacity(0.8)).frame(height: 1)
                            .offset(y: min(max(0, geometry.size.height - 1),
                                geometry.size.height * CGFloat(index) / CGFloat(max(1, totalCount - 1))))
                            .allowsHitTesting(false)
                    }
                    if totalCount == 0 && !isLoading {
                        Text(errorMessage == nil ? "No history" : "Unavailable")
                            .font(.system(size: 10)).foregroundStyle(theme.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        previewIndex = MinimapLayout.index(at: value.location.y, height: geometry.size.height, count: totalCount)
                    }
                    .onEnded { value in
                        if let index = MinimapLayout.index(at: value.location.y, height: geometry.size.height, count: totalCount) {
                            onSeek(index)
                        }
                        previewIndex = nil
                    })
                .accessibilityRepresentation {
                    Slider(value: Binding(
                        get: { Double((selectedIndex ?? visibleRange?.lowerBound ?? 0) + 1) },
                        set: { value in
                            guard totalCount > 0, value.isFinite else { return }
                            onSeek(min(totalCount - 1, max(0, Int(value.rounded()) - 1)))
                        }), in: 1...Double(max(2, totalCount)), step: 1)
                        .accessibilityIdentifier("history-minimap")
                        .accessibilityLabel("Commit history minimap, \(totalCount) commits")
                        .accessibilityValue("\(totalCount) commits, position \(totalCount == 0 ? 0 : (selectedIndex ?? visibleRange?.lowerBound ?? 0) + 1)")
                        .disabled(totalCount == 0)
                }
            }

            Divider()
            HStack(spacing: 0) {
                Button { onSeek(0) } label: { Image(systemName: "arrow.up.to.line").frame(width: 28, height: 28) }
                    .help("Newest commit").accessibilityLabel("Go to newest commit")
                Button { onSeek(totalCount - 1) } label: { Image(systemName: "arrow.down.to.line").frame(width: 28, height: 28) }
                    .help("Oldest local commit").accessibilityLabel("Go to oldest local commit")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.text)
            .disabled(totalCount == 0)
            Text("\(loadedCount) loaded")
                .font(.system(size: 9)).monospacedDigit().foregroundStyle(theme.textMuted)
                .lineLimit(1).padding(.bottom, 4)
            if let errorMessage {
                Button("Retry", action: onRetry).buttonStyle(.borderless).help(errorMessage)
            }
        }
        .frame(width: minimapWidth)
        .background(theme.background)
        .help("Local history of the current revision. Click or drag to navigate; seeking clears search and author filters. Dense histories use a simplified overview.")
    }
}
