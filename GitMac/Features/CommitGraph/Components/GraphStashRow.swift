import SwiftUI

// MARK: - Graph Stash Row (Modern)
struct GraphStashRow: View {
    let stash: StashNode
    let isSelected: Bool
    let isHovered: Bool
    var settings: GraphSettings? = nil

    private var H: CGFloat { settings?.rowHeight ?? 44 }
    private var W: CGFloat { (settings?.effectiveLaneWidth ?? 28) * zoomLevel }  // Match GraphRow's dynamic lane width
    private var boxSize: CGFloat { 16 * zoomLevel }
    private var LW: CGFloat { GraphSettings.lineWidth * zoomLevel }
    private var zoomLevel: CGFloat { settings?.zoomLevel ?? 1.0 }
    private var stashColor: Color { AppTheme.info }

    private var branchColumnWidth: CGFloat {
        settings?.responsiveBranchColumnWidth ?? 140
    }

    private var graphColumnWidth: CGFloat {
        settings?.graphColumnWidth ?? 110
    }

    // Use same coordinate system as GraphRow
    private func x(_ lane: Int) -> CGFloat {
        let padding: CGFloat = 12 * zoomLevel
        return CGFloat(lane) * W + W / 2 + padding
    }

    // Human-friendly stash description
    private var humanFriendlyName: String {
        let date = stash.stash.relativeDate
        if let branch = stash.stash.branchName {
            return "On \(branch)"
        }
        return date
    }

    var body: some View {
        return HStack(spacing: 0) {
            // Label - stash badge with human-friendly name
            if settings?.shouldShowBranchColumn ?? true {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    StashBadge(name: humanFriendlyName)
                    Spacer()
                }
                .frame(width: branchColumnWidth)
                .padding(.leading, DesignTokens.Spacing.sm)
            }

            // Graph area - aligned with main graph
            ZStack {
                Canvas { ctx, size in
                    let cy = size.height / 2
                    let mainLaneX = x(0)  // Main branch is always lane 0
                    let stashLaneX = x(1)  // Stash appears at lane 1

                    // 1) Main branch line (continues through) - full height for seamless connection
                    var mainLine = Path()
                    mainLine.move(to: CGPoint(x: mainLaneX, y: 0))
                    mainLine.addLine(to: CGPoint(x: mainLaneX, y: size.height))
                    // Draw with shadow like GraphRow
                    ctx.stroke(mainLine, with: .color(Color.branchColor(0).opacity(0.3)), style: StrokeStyle(lineWidth: LW + 2, lineCap: .round))
                    ctx.stroke(mainLine, with: .color(Color.branchColor(0)), style: StrokeStyle(lineWidth: LW, lineCap: .round))

                    // 2) Stash connection line (dashed, from stash node down to main line)
                    var connLine = Path()
                    connLine.move(to: CGPoint(x: stashLaneX, y: cy))
                    connLine.addLine(to: CGPoint(x: mainLaneX, y: size.height))
                    ctx.stroke(connLine, with: .color(stashColor),
                              style: StrokeStyle(lineWidth: LW, lineCap: .round, dash: [5, 4]))

                    // 3) Stash node (rounded box)
                    let boxRect = CGRect(x: stashLaneX - boxSize/2, y: cy - boxSize/2,
                                        width: boxSize, height: boxSize)
                    let roundedBox = RoundedRectangle(cornerRadius: 4).path(in: boxRect)

                    // Glow effect
                    let glowRect = boxRect.insetBy(dx: -1.5, dy: -1.5)
                    ctx.fill(RoundedRectangle(cornerRadius: 5).path(in: glowRect), with: .color(stashColor.opacity(0.3)))

                    // Fill and stroke
                    ctx.fill(roundedBox, with: .color(stashColor))
                    ctx.stroke(roundedBox, with: .color(AppTheme.background), lineWidth: LW * 0.6 + 1)
                    ctx.stroke(roundedBox, with: .color(stashColor.opacity(0.8)), lineWidth: LW * 0.6)
                }
                .frame(width: graphColumnWidth, height: H)
                .clipped()

                // Box icon - positioned at lane 1
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 8 * zoomLevel, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: x(1) - (graphColumnWidth / 2))
            }

            // Info - human friendly display
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: 4) {
                    Text(stash.stash.displayMessage.isEmpty ? "Stashed changes" : stash.stash.displayMessage)
                        .font(settings?.compactMode == true ? DesignTokens.Typography.caption : DesignTokens.Typography.callout)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Image(systemName: "shippingbox")
                        .font(.system(size: 10))
                        .foregroundStyle(stashColor)
                        .help("Stash entry")
                }

                if !(settings?.compactMode ?? false) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if let branch = stash.stash.branchName {
                            Text("on \(branch)")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Text("•")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(AppTheme.textMuted)

                        Text(stash.stash.relativeDate)
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.sm)

            Spacer()

            // SHA (abbreviated)
            if settings?.shouldShowSHAColumn ?? false {
                Text(stash.stash.shortSHA)
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: settings?.shaColumnWidth ?? 80, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
            }
        }
        .frame(height: H)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .contextMenu {
            Button {
                NotificationCenter.default.post(name: .applyStash, object: stash.stash.index)
            } label: {
                Label("Apply Stash", systemImage: "arrow.down.doc")
            }
            Button {
                NotificationCenter.default.post(name: .popStashAtIndex, object: stash.stash.index)
            } label: {
                Label("Pop Stash", systemImage: "arrow.up.doc")
            }
            Divider()
            Button(role: .destructive) {
                NotificationCenter.default.post(name: .dropStash, object: stash.stash.index)
            } label: {
                Label("Drop Stash", systemImage: "trash")
            }
        }
    }
}
