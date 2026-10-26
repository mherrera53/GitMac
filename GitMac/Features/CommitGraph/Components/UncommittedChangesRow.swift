import SwiftUI

// MARK: - Uncommitted Changes Row
struct UncommittedChangesRow: View {
    let stagedCount: Int
    let unstagedCount: Int
    let isSelected: Bool
    let isHovered: Bool
    var settings: GraphSettings? = nil
    var connectToHistory = true
    var conflictedCount = 0

    private var statusColor: Color { conflictedCount > 0 ? AppTheme.error : AppTheme.warning }
    private var statusSummary: String {
        let changes = "\(stagedCount) staged, \(unstagedCount) unstaged"
        return conflictedCount > 0 ? changes + ", \(conflictedCount) \(conflictedCount == 1 ? "conflict" : "conflicts")" : changes
    }

    private var H: CGFloat { settings?.rowHeight ?? 44 }
    private var R: CGFloat { settings?.nodeRadius ?? 14 }
    private var zoom: CGFloat { settings?.zoomLevel ?? 1 }
    private var nodeX: CGFloat {
        GraphGeometry.laneX(0, laneWidth: settings?.effectiveLaneWidth ?? GraphSettings.baseLaneWidth, zoom: zoom)
    }

    private var branchColumnWidth: CGFloat {
        settings?.responsiveBranchColumnWidth ?? 140
    }

    private var graphColumnWidth: CGFloat {
        settings?.graphColumnWidth ?? 110
    }

    var body: some View {
        return HStack(spacing: 0) {
            // Label
            if settings?.shouldShowBranchColumn ?? true {
                HStack {
                    BranchBadge(
                        name: "// WIP",
                        color: statusColor,
                        isHead: false,
                        isTag: false
                    )
                    Spacer()
                }
                .frame(width: branchColumnWidth)
                .padding(.leading, DesignTokens.Spacing.sm)
            }

            // Graph - dotted node
            ZStack {
                GraphCanvas(role: .wip) { ctx, size in
                    let cy = size.height / 2
                    let myX = nodeX

                    // Dotted line to bottom
                    if connectToHistory {
                        drawDottedLine(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: myX, y: size.height), color: statusColor)
                    }

                    // Dotted circle
                    let nodeRect = CGRect(x: myX - R, y: cy - R, width: R * 2, height: R * 2)
                    // Fill with background to hide line passing through
                    ctx.fill(Circle().path(in: nodeRect), with: .color(AppTheme.background))
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(statusColor), style: StrokeStyle(lineWidth: 2 * zoom, dash: [4 * zoom, 3 * zoom]))
                }
                .frame(width: graphColumnWidth, height: H)

                // Pencil icon inside node
                Image(systemName: conflictedCount > 0 ? "exclamationmark" : "pencil")
                    .font(.system(size: 13 * zoom, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .offset(x: nodeX - graphColumnWidth / 2)
            }

            // Info
            HStack(spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Uncommitted changes")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                    Text(statusSummary)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
        .frame(height: H)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("graph-working-copy")
    }

    func drawDottedLine(_ ctx: GraphDrawingContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2 * zoom, lineCap: .round, dash: [4 * zoom, 3 * zoom]))
    }
}
