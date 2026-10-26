import SwiftUI
import AppKit

// MARK: - Graph Row
struct GraphRow: View {
    let node: GraphNode
    let isSelected: Bool
    let isHovered: Bool
    let settings: GraphSettings
    var hasWorkingCopyChild = false
    let onHoverBranch: ((String?) -> Void)?
    var onDropBranch: ((String, BranchTransferable) -> Void)? = nil

    private var H: CGFloat { settings.rowHeight }
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
                            isHead: Branch.mainBranchNames.contains(label),
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
                GraphCanvas { ctx, size in
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
                    if (node.lineFromTop || hasWorkingCopyChild) && node.lineToBottom {
                        drawLine(ctx, from: CGPoint(x: myX, y: 0), to: CGPoint(x: myX, y: size.height), color: c)
                    } else if node.lineFromTop || hasWorkingCopyChild {
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
                        .foregroundStyle(AppTheme.textPrimary)
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
                        .foregroundStyle(AppTheme.textSecondary)
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
            .frame(width: settings.responsiveChangesColumnWidth, alignment: .leading)

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
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                .frame(width: settings.authorColumnWidth, alignment: .leading)
            }

            // Date column (optional, responsive)
            if settings.shouldShowDateColumn {
                Text(node.commit.relativeDate)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: settings.dateColumnWidth, alignment: .trailing)
            }

            // SHA column (optional, responsive)
            if settings.shouldShowSHAColumn {
                Text(node.commit.shortSha)
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundStyle(AppTheme.textSecondary)
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
        GraphGeometry.laneX(lane, laneWidth: settings.effectiveLaneWidth, zoom: settings.zoomLevel)
    }
    func color(_ lane: Int) -> Color { Color.branchColor(lane) }

    func drawLine(_ ctx: GraphDrawingContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        // Draw with slight shadow for depth
        ctx.stroke(p, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: LW + 2, lineCap: .round))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: LW, lineCap: .round))
    }

    func drawBezierCurve(_ ctx: GraphDrawingContext, from: CGPoint, to: CGPoint, color: Color) {
        var p = Path()
        p.move(to: from)

        // Professional smooth curve like GitKraken - railroad track style
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

// MARK: - Shared graph drawing

struct GraphPaint {
    let value: Color
    static func color(_ value: Color) -> GraphPaint { GraphPaint(value: value) }
}

enum GraphDrawingRole: String { case commit, stash, wip, minimap }

/// The same paths/styles can be drawn by either backend for a controlled comparison.
@MainActor
enum GraphDrawingContext {
    case canvas(GraphicsContext)
    case native(CGContext)

    func fill(_ path: Path, with paint: GraphPaint) {
        switch self {
        case .canvas(let context): context.fill(path, with: .color(paint.value))
        case .native(let context):
            context.saveGState()
            defer { context.restoreGState() }
            context.setFillColor(NSColor(paint.value).cgColor)
            context.beginPath()
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    func stroke(_ path: Path, with paint: GraphPaint, lineWidth: CGFloat) {
        stroke(path, with: paint, style: StrokeStyle(lineWidth: lineWidth))
    }

    func stroke(_ path: Path, with paint: GraphPaint, style: StrokeStyle) {
        switch self {
        case .canvas(let context): context.stroke(path, with: .color(paint.value), style: style)
        case .native(let context):
            context.saveGState()
            defer { context.restoreGState() }
            context.setStrokeColor(NSColor(paint.value).cgColor)
            context.setLineWidth(style.lineWidth)
            context.setLineCap(style.lineCap)
            context.setLineJoin(style.lineJoin)
            context.setMiterLimit(style.miterLimit)
            context.setLineDash(phase: style.dashPhase, lengths: style.dash)
            context.beginPath()
            context.addPath(path.cgPath)
            context.strokePath()
        }
    }
}

/// Decorative vector surface. Interaction remains in the surrounding SwiftUI row/minimap.
@MainActor
struct GraphCanvas: View {
    var role: GraphDrawingRole = .commit
    let renderer: (GraphDrawingContext, CGSize) -> Void
    private static var recordedBackends: Set<String> = []

    static func recordDrawing(_ backend: String, role: GraphDrawingRole, size: CGSize) {
        guard PerformanceProbe.isEnabled, size.width.isFinite, size.height.isFinite,
              size.width >= 1, size.height >= 1, size.width < 1_000_000, size.height < 1_000_000 else { return }
        let stage = "graph-\(backend)-\(role.rawValue)-drawn"
        guard recordedBackends.insert(stage).inserted else { return }
        PerformanceProbe.record(stage, counts: ["width": Int(size.width), "height": Int(size.height)])
    }

    var body: some View {
        if CommandLine.arguments.contains("--performance-fixture") && CommandLine.arguments.contains("--canvas-graph-control") {
            Canvas { context, size in
                renderer(.canvas(context), size)
                Self.recordDrawing("canvas", role: role, size: size)
            }
        } else {
            NativeGraphCanvas(role: role, renderer: renderer)
                .allowsHitTesting(false)
        }
    }
}

@MainActor
private struct NativeGraphCanvas: NSViewRepresentable {
    let role: GraphDrawingRole
    let renderer: (GraphDrawingContext, CGSize) -> Void

    func makeNSView(context: Context) -> NativeGraphDrawingView {
        let view = NativeGraphDrawingView(frame: .zero)
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: NativeGraphDrawingView, context: Context) {
        view.role = role
        view.renderer = renderer
        view.needsDisplay = true
    }

    static func dismantleNSView(_ view: NativeGraphDrawingView, coordinator: ()) {
        view.renderer = nil
    }
}

@MainActor
final class NativeGraphDrawingView: NSView {
    var role: GraphDrawingRole = .commit
    var renderer: ((GraphDrawingContext, CGSize) -> Void)?
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let renderer, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: bounds)
        renderer(.native(context), bounds.size)
        GraphCanvas.recordDrawing("native", role: role, size: bounds.size)
    }
}
