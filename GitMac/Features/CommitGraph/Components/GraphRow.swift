import SwiftUI

// MARK: - Graph Row
struct GraphRow: View {
    let node: GraphNode
    let isSelected: Bool
    let isHovered: Bool
    let settings: GraphSettings
    let onHoverBranch: ((String?) -> Void)?
    var onDropBranch: ((String, BranchTransferable) -> Void)? = nil

    private var H: CGFloat { settings.rowHeight }
    private var W: CGFloat { settings.effectiveLaneWidth * settings.zoomLevel }  // Dynamic lane spacing (compressed when many branches)
    private var R: CGFloat { settings.nodeRadius }
    private var LW: CGFloat { GraphSettings.lineWidth * settings.zoomLevel }  // Scaled line width

    var body: some View {
        return HStack(spacing: 0) {
            // Branch label with badge
            if settings.shouldShowBranchColumn {
                HStack {
                    if let label = node.branchLabel {
                        BranchBadge(
                            name: label,
                            color: color(node.lane),
                            isHead: label == "main" || label == "master",
                            isTag: label.hasPrefix("v") || label.contains("."),
                            onDropBranch: { dropped in
                                onDropBranch?(label, dropped)
                            }
                        )
                    }
                    Spacer()
                }
                .frame(width: settings.responsiveBranchColumnWidth)
                .padding(.leading, DesignTokens.Spacing.sm)
            }

            // Graph - Canvas for lines, overlay for avatar
            ZStack {
                Canvas { ctx, size in
                    let cy = size.height / 2
                    let myX = x(node.lane)
                    let c = color(node.lane)

                    // 1) Pass-through vertical lines (other branches) - draw first (behind)
                    for lane in node.passThroughLanes.sorted() {
                        let lx = x(lane)
                        drawLine(ctx, from: CGPoint(x: lx, y: 0), to: CGPoint(x: lx, y: size.height), color: color(lane))
                    }

                    // 2) Curves going to bottom (to other columns) - draw before my line
                    for toLane in node.curvesToBottom.sorted() {
                        let toX = x(toLane)
                        drawBezierCurve(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: toX, y: size.height), color: color(toLane))
                    }

                    // 3) My vertical line (draw on top of curves)
                    if node.lineFromTop && node.lineToBottom {
                        drawLine(ctx, from: CGPoint(x: myX, y: 0), to: CGPoint(x: myX, y: size.height), color: c)
                    } else if node.lineFromTop {
                        drawLine(ctx, from: CGPoint(x: myX, y: 0), to: CGPoint(x: myX, y: cy), color: c)
                    } else if node.lineToBottom {
                        drawLine(ctx, from: CGPoint(x: myX, y: cy), to: CGPoint(x: myX, y: size.height), color: c)
                    }

                    // 4) Node circle with professional styling
                    let nodeSize = R * 2
                    let nodeRect = CGRect(x: myX - R, y: cy - R, width: nodeSize, height: nodeSize)

                    // Outer glow/shadow effect for depth
                    let glowRect = nodeRect.insetBy(dx: -1.5, dy: -1.5)
                    ctx.fill(Circle().path(in: glowRect), with: .color(c.opacity(0.3)))

                    // Main node fill
                    ctx.fill(Circle().path(in: nodeRect), with: .color(c))

                    // Inner highlight for 3D effect
                    let highlightRect = CGRect(x: myX - R * 0.6, y: cy - R * 0.8, width: R * 0.8, height: R * 0.6)
                    ctx.fill(Ellipse().path(in: highlightRect), with: .color(Color.white.opacity(0.25)))

                    // Border stroke
                    let borderWidth = LW * 0.6
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(AppTheme.background), lineWidth: borderWidth + 1)
                    ctx.stroke(Circle().path(in: nodeRect), with: .color(c.opacity(0.8)), lineWidth: borderWidth)
                }
                .frame(width: settings.graphColumnWidth, height: H)
                .clipped()  // Keep graph contained but allow full drawing within bounds

                // Avatar overlay INSIDE the node - FIXED positioning and size
                if settings.showAvatars {
                    avatarView
                        .frame(width: settings.avatarSize, height: settings.avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(color(node.lane), lineWidth: 2)
                        )
                        .background(
                            Circle()
                                .fill(AppTheme.background)
                        )
                        .offset(x: x(node.lane) - (settings.graphColumnWidth / 2))
                        .scaleEffect(isHovered ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                }
            }

            // Commit message
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: 4) {
                    Text(node.commit.summary)
                        .font(settings.compactMode ? DesignTokens.Typography.caption : DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    if node.commit.isVerified {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.success)
                            .help("Verified signature")
                    }
                }
                if !settings.compactMode && !settings.showAuthorColumn {
                    Text(node.commit.author)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.sm)

            // Changes indicator
            FileChangesIndicator(
                additions: node.commit.additions ?? 0,
                deletions: node.commit.deletions ?? 0,
                filesChanged: node.commit.filesChanged ?? 0,
                compact: settings.compactMode
            )
            .frame(width: settings.changesColumnWidth, alignment: .leading)

            // Author column (optional, responsive)
            if settings.shouldShowAuthorColumn {
                HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                    if settings.showAvatars && !settings.compactMode {
                        AvatarImageView(
                            email: node.commit.authorEmail,
                            size: 20,
                            fallbackInitial: String(node.commit.author.prefix(1))
                        )
                    }
                    Text(node.commit.author)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                .frame(width: settings.authorColumnWidth, alignment: .leading)
            }

            // Date column (optional, responsive)
            if settings.shouldShowDateColumn {
                Text(node.commit.relativeDate)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: settings.dateColumnWidth, alignment: .trailing)
            }

            // SHA column (optional, responsive)
            if settings.shouldShowSHAColumn {
                Text(node.commit.shortSha)
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: settings.shaColumnWidth, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
            }
        }
        .frame(height: H)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .opacity(settings.dimMergeCommits && node.isMerge ? 0.5 : 1.0)
        .onHover { hovering in
            if let label = node.branchLabel, hovering {
                onHoverBranch?(label)
            } else if !hovering {
                onHoverBranch?(nil)
            }
        }
        .contextMenu {
            CommitContextMenu(commits: [node.commit])
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        AvatarImageView(
            email: node.commit.authorEmail,
            size: settings.avatarSize,
            fallbackInitial: String(node.commit.author.prefix(1))
        )
    }

    func x(_ lane: Int) -> CGFloat {
        let padding: CGFloat = 12 * settings.zoomLevel  // Left padding scaled with zoom
        return CGFloat(lane) * W + W / 2 + padding
    }
    func color(_ lane: Int) -> Color { Color.branchColor(lane) }

    func drawLine(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        // Draw with slight shadow for depth
        ctx.stroke(p, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: LW + 2, lineCap: .round))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: LW, lineCap: .round))
    }

    func drawBezierCurve(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)

        // Professional smooth curve like GitKraken - railroad track style
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y

        // Use quadratic control points for smoother curves
        let control1 = CGPoint(x: from.x, y: from.y + deltaY * 0.5)
        let control2 = CGPoint(x: to.x, y: from.y + deltaY * 0.5)

        p.addCurve(to: to, control1: control1, control2: control2)

        // Draw with shadow for depth
        ctx.stroke(p, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: LW + 2, lineCap: .round, lineJoin: .round))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: LW, lineCap: .round, lineJoin: .round))
    }
}
