import SwiftUI

// MARK: - Uncommitted Changes Row
struct UncommittedChangesRow: View {
    let stagedCount: Int
    let unstagedCount: Int
    let isSelected: Bool
    let isHovered: Bool
    var settings: GraphSettings? = nil

    private var H: CGFloat { settings?.rowHeight ?? 44 }
    private let W: CGFloat = 26
    private var R: CGFloat { settings?.nodeRadius ?? 14 }

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
                        color: .orange,
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
                Canvas { ctx, size in
                    let cy = size.height / 2
                    let myX: CGFloat = W / 2 + DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs

                    // Dotted line to bottom
                    drawDottedLine(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: myX, y: size.height), color: .orange)

                    // Dotted circle
                    let nodeRect = CGRect(x: myX - R, y: cy - R, width: R * 2, height: R * 2)
                    // Fill with background to hide line passing through
                    ctx.fill(Circle().path(in: nodeRect), with: .color(AppTheme.background))
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(.orange), style: StrokeStyle(lineWidth: 2, dash: [5, 6]))
                }
                .frame(width: graphColumnWidth, height: H)

                // Pencil icon inside node
                Image(systemName: "pencil")
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.warning)
                    .offset(x: -(graphColumnWidth / 2) + W / 2 + 8)
            }

            // Info
            HStack(spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Uncommitted changes")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.warning)
                    Text("\(stagedCount) staged, \(unstagedCount) unstaged")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
        .frame(height: H)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
    }

    func drawDottedLine(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 6]))
    }
}
