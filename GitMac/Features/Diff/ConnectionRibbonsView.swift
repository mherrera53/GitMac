import SwiftUI

/// Visual connection ribbons that link related lines between left and right diff panels
struct ConnectionRibbonsView: View {
    let pairs: [DiffPairWithConnection]
    let lineHeight: CGFloat
    let isFluidMode: Bool
    let viewWidth: CGFloat
    let gutterWidth: CGFloat
    let panelOverlap: CGFloat
    let visibleRange: Range<Int>
    let themeColors: ColorScheme

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            drawRibbons(context: context, size: size)
        }
        .frame(width: viewWidth, alignment: .topLeading)
        .drawingGroup()
    }

    private func drawRibbons(context: GraphicsContext, size: CGSize) {
        let theme = Color.Theme(themeColors)
        let layoutWidth = viewWidth
        let lower = max(0, min(visibleRange.lowerBound, pairs.count))
        let upper = max(lower, min(visibleRange.upperBound, pairs.count))

        var i = lower
        while i < upper {
            let pair = pairs[i]
            guard pair.connectionType != .none, (pair.left != nil || pair.right != nil) else {
                i += 1
                continue
            }

            var j = i + 1
            while j < upper {
                let next = pairs[j]
                guard next.connectionType != .none, (next.left != nil || next.right != nil) else { break }
                j += 1
            }

            var hasLeft = false
            var hasRight = false

            var leftFirst = Int.max
            var leftLast = Int.min
            var rightFirst = Int.max
            var rightLast = Int.min

            for idx in i..<j {
                let p = pairs[idx]
                if p.left != nil {
                    hasLeft = true
                    leftFirst = min(leftFirst, idx)
                    leftLast = max(leftLast, idx + 1)
                }
                if p.right != nil {
                    hasRight = true
                    rightFirst = min(rightFirst, idx)
                    rightLast = max(rightLast, idx + 1)
                }
            }

            let color: Color
            if hasLeft, hasRight {
                color = theme.info
            } else if hasLeft {
                color = theme.diffDeletion
            } else {
                color = theme.diffAddition
            }

            if hasLeft, hasRight {
                let lt = CGFloat(leftFirst) * lineHeight
                let lb = CGFloat(leftLast) * lineHeight
                let rt = CGFloat(rightFirst) * lineHeight
                let rb = CGFloat(rightLast) * lineHeight
                drawTrapezoidRibbonBlock(
                    context: context,
                    leftTop: lt,
                    leftBottom: lb,
                    rightTop: rt,
                    rightBottom: rb,
                    color: color,
                    isFluid: isFluidMode,
                    layoutWidth: layoutWidth
                )
            } else if hasLeft {
                let lt = CGFloat(leftFirst) * lineHeight
                let lb = CGFloat(leftLast) * lineHeight
                drawTeardropBlock(
                    context: context,
                    side: .left,
                    topY: lt,
                    bottomY: lb,
                    color: color,
                    layoutWidth: layoutWidth
                )
            } else if hasRight {
                let rt = CGFloat(rightFirst) * lineHeight
                let rb = CGFloat(rightLast) * lineHeight
                drawTeardropBlock(
                    context: context,
                    side: .right,
                    topY: rt,
                    bottomY: rb,
                    color: color,
                    layoutWidth: layoutWidth
                )
            }

            i = j
        }
    }

    private enum RibbonSide {
        case left
        case right
    }

    private func drawTeardropBlock(
        context: GraphicsContext,
        side: RibbonSide,
        topY: CGFloat,
        bottomY: CGFloat,
        color: Color,
        layoutWidth: CGFloat
    ) {
        let panelWidth = max(0, (layoutWidth - gutterWidth) / 2)
        let gutterLeft = panelWidth
        let gutterRight = panelWidth + gutterWidth
        let gutterMidX = (gutterLeft + gutterRight) / 2

        let height = max(lineHeight, bottomY - topY)
        let top = topY
        let bottom = topY + height

        // Convergence point: top of the block (where insertion/deletion happens in the other panel)
        // This creates a proper funnel: wide at block, narrowing to a thin line at the insertion point
        let pointY = top
        let fadeWidth: CGFloat = min(14, max(8, panelWidth * 0.05))

        context.drawLayer { layer in
            switch side {
            case .right:
                // Addition-only: smooth teardrop -- wide at right, rounded point at left
                let tipY = pointY + lineHeight * 0.5
                var funnel = Path()
                funnel.move(to: CGPoint(x: gutterRight, y: top))
                funnel.addCurve(
                    to: CGPoint(x: gutterLeft, y: tipY),
                    control1: CGPoint(x: gutterMidX, y: top),
                    control2: CGPoint(x: gutterLeft, y: tipY - lineHeight * 0.3)
                )
                funnel.addCurve(
                    to: CGPoint(x: gutterRight, y: bottom),
                    control1: CGPoint(x: gutterLeft, y: tipY + lineHeight * 0.3),
                    control2: CGPoint(x: gutterMidX, y: bottom)
                )
                funnel.closeSubpath()

                layer.fill(funnel, with: .color(color.opacity(0.10)))
                layer.stroke(funnel, with: .color(color.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round))

                // Insertion reference line into left panel
                var refLine = Path()
                refLine.move(to: CGPoint(x: gutterLeft - fadeWidth * 2, y: tipY))
                refLine.addLine(to: CGPoint(x: gutterLeft, y: tipY))
                layer.stroke(refLine, with: .color(color.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .butt))

                // Right panel edge marker
                let markerRect = CGRect(x: gutterRight + 1, y: top, width: 2, height: height)
                layer.fill(Path(markerRect), with: .color(color.opacity(0.18)))

            case .left:
                // Deletion-only: smooth teardrop -- wide at left, rounded point at right
                let tipY = pointY + lineHeight * 0.5
                var funnel = Path()
                funnel.move(to: CGPoint(x: gutterLeft, y: top))
                funnel.addCurve(
                    to: CGPoint(x: gutterRight, y: tipY),
                    control1: CGPoint(x: gutterMidX, y: top),
                    control2: CGPoint(x: gutterRight, y: tipY - lineHeight * 0.3)
                )
                funnel.addCurve(
                    to: CGPoint(x: gutterLeft, y: bottom),
                    control1: CGPoint(x: gutterRight, y: tipY + lineHeight * 0.3),
                    control2: CGPoint(x: gutterMidX, y: bottom)
                )
                funnel.closeSubpath()

                layer.fill(funnel, with: .color(color.opacity(0.10)))
                layer.stroke(funnel, with: .color(color.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round))

                // Removal reference line into right panel
                var refLine = Path()
                refLine.move(to: CGPoint(x: gutterRight, y: tipY))
                refLine.addLine(to: CGPoint(x: gutterRight + fadeWidth * 2, y: tipY))
                layer.stroke(refLine, with: .color(color.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .butt))

                // Left panel edge marker
                let markerRect = CGRect(x: gutterLeft - 3, y: top, width: 2, height: height)
                layer.fill(Path(markerRect), with: .color(color.opacity(0.18)))
            }
        }
    }

    private func drawTrapezoidRibbonBlock(
        context: GraphicsContext,
        leftTop: CGFloat,
        leftBottom: CGFloat,
        rightTop: CGFloat,
        rightBottom: CGFloat,
        color: Color,
        isFluid: Bool,
        layoutWidth: CGFloat
    ) {
        let panelWidth = max(0, (layoutWidth - gutterWidth) / 2)
        let gutterLeft = panelWidth
        let gutterRight = panelWidth + gutterWidth

        let effectiveOverlap = min(panelOverlap, panelWidth)
        let leftX = max(0, gutterLeft - effectiveOverlap)
        let rightX = min(layoutWidth, gutterRight + effectiveOverlap)

        let lt = leftTop
        let lb = max(lt + lineHeight, leftBottom)
        let rt = rightTop
        let rb = max(rt + lineHeight, rightBottom)

        let gutterMidX = (gutterLeft + gutterRight) / 2

        let topLeft = CGPoint(x: leftX, y: lt)
        let topRight = CGPoint(x: rightX, y: rt)
        let bottomRight = CGPoint(x: rightX, y: rb)
        let bottomLeft = CGPoint(x: leftX, y: lb)

        // Smooth S-curve: control points pull horizontally through the gutter center
        // This prevents crossing artifacts when left/right heights differ greatly
        var band = Path()
        band.move(to: topLeft)
        band.addCurve(
            to: topRight,
            control1: CGPoint(x: gutterMidX, y: lt),
            control2: CGPoint(x: gutterMidX, y: rt)
        )
        band.addLine(to: bottomRight)
        band.addCurve(
            to: bottomLeft,
            control1: CGPoint(x: gutterMidX, y: rb),
            control2: CGPoint(x: gutterMidX, y: lb)
        )
        band.closeSubpath()

        // Transition gradient: deletion color (left) -> addition color (right)

        // Transition gradient: deletion color (left) -> addition color (right)
        let leftColor = AppTheme.diffDeletion
        let rightColor = AppTheme.diffAddition

        let fillGradient = Gradient(stops: [
            .init(color: leftColor.opacity(0.0), location: 0.0),
            .init(color: leftColor.opacity(0.20), location: 0.12),
            .init(color: leftColor.opacity(0.22), location: 0.30),
            .init(color: color.opacity(0.12), location: 0.50),
            .init(color: rightColor.opacity(0.22), location: 0.70),
            .init(color: rightColor.opacity(0.20), location: 0.88),
            .init(color: rightColor.opacity(0.0), location: 1.0)
        ])

        let strokeWidth: CGFloat = 1.0
        let markerWidth: CGFloat = 3
        let fadeWidth: CGFloat = min(14, max(8, panelWidth * 0.05))

        let top = min(lt, rt)
        let bottom = max(lb, rb)
        let height = max(lineHeight, bottom - top)
        let midY = (top + bottom) / 2

        let x0 = max(0, min(leftX, gutterLeft - markerWidth - 1 - fadeWidth) - strokeWidth)
        let x1 = min(layoutWidth, max(rightX, gutterRight + 1 + markerWidth + fadeWidth) + strokeWidth)
        let y0 = top - strokeWidth
        let y1 = bottom + strokeWidth
        let clipRect = CGRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(lineHeight, y1 - y0))

        context.drawLayer { layer in
            layer.clip(to: Path(clipRect))

            layer.fill(
                band,
                with: .linearGradient(
                    fillGradient,
                    startPoint: CGPoint(x: leftX, y: midY),
                    endPoint: CGPoint(x: rightX, y: midY)
                )
            )

            // Border gradient: red edge -> green edge
            let borderGradient = Gradient(stops: [
                .init(color: leftColor.opacity(0.0), location: 0.0),
                .init(color: leftColor.opacity(0.50), location: 0.15),
                .init(color: color.opacity(0.30), location: 0.50),
                .init(color: rightColor.opacity(0.50), location: 0.85),
                .init(color: rightColor.opacity(0.0), location: 1.0)
            ])

            var topEdge = Path()
            topEdge.move(to: topLeft)
            topEdge.addCurve(
                to: topRight,
                control1: CGPoint(x: gutterMidX, y: lt),
                control2: CGPoint(x: gutterMidX, y: rt)
            )
            layer.stroke(
                topEdge,
                with: .linearGradient(borderGradient, startPoint: CGPoint(x: leftX, y: midY), endPoint: CGPoint(x: rightX, y: midY)),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )

            var bottomEdge = Path()
            bottomEdge.move(to: bottomLeft)
            bottomEdge.addCurve(
                to: bottomRight,
                control1: CGPoint(x: gutterMidX, y: lb),
                control2: CGPoint(x: gutterMidX, y: rb)
            )
            layer.stroke(
                bottomEdge,
                with: .linearGradient(borderGradient, startPoint: CGPoint(x: leftX, y: midY), endPoint: CGPoint(x: rightX, y: midY)),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )

            // Left panel marker (deletion side -- red tint)
            let leftMarkerRect = CGRect(x: max(0, gutterLeft - markerWidth - 1), y: top, width: markerWidth, height: height)
            layer.fill(Path(leftMarkerRect), with: .color(leftColor.opacity(0.28)))
            let leftFadeRect = CGRect(x: max(0, gutterLeft - markerWidth - 1 - fadeWidth), y: top, width: fadeWidth, height: height)
            layer.fill(
                Path(leftFadeRect),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: leftColor.opacity(0.14), location: 0.0),
                        .init(color: leftColor.opacity(0.0), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: gutterLeft, y: midY),
                    endPoint: CGPoint(x: gutterLeft - fadeWidth, y: midY)
                )
            )

            // Right panel marker (addition side -- green tint)
            let rightMarkerRect = CGRect(x: min(layoutWidth - markerWidth, gutterRight + 1), y: top, width: markerWidth, height: height)
            layer.fill(Path(rightMarkerRect), with: .color(rightColor.opacity(0.28)))
            let rightFadeRect = CGRect(x: min(layoutWidth, gutterRight + 1 + markerWidth), y: top, width: fadeWidth, height: height)
            layer.fill(
                Path(rightFadeRect),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: rightColor.opacity(0.14), location: 0.0),
                        .init(color: rightColor.opacity(0.0), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: gutterRight, y: midY),
                    endPoint: CGPoint(x: gutterRight + fadeWidth, y: midY)
                )
            )

            // Center flow line -- connects midpoints of left and right blocks
            let leftMidY = (lt + lb) / 2
            let rightMidY = (rt + rb) / 2
            var center = Path()
            center.move(to: CGPoint(x: leftX + 2, y: leftMidY))
            center.addCurve(
                to: CGPoint(x: rightX - 2, y: rightMidY),
                control1: CGPoint(x: gutterMidX, y: leftMidY),
                control2: CGPoint(x: gutterMidX, y: rightMidY)
            )
            layer.stroke(
                center,
                with: .linearGradient(borderGradient, startPoint: CGPoint(x: leftX, y: midY), endPoint: CGPoint(x: rightX, y: midY)),
                style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round, dash: [3, 2])
            )
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ConnectionRibbonsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionRibbonsView(
            pairs: [
                DiffPairWithConnection(
                    id: 0,
                    left: DiffLine(type: .deletion, content: "old", oldLineNumber: 1, newLineNumber: nil),
                    right: DiffLine(type: .addition, content: "new", oldLineNumber: nil, newLineNumber: 1),
                    hunkHeader: nil,
                    connectionType: .change
                )
            ],
            lineHeight: 22,
            isFluidMode: true,
            viewWidth: 800,
            gutterWidth: 60,
            panelOverlap: 18,
            visibleRange: 0..<1,
            themeColors: ColorScheme.default(for: .dark)
        )
        .frame(width: 800, height: 400)
        .background(Color.black.opacity(0.8))
    }
}
#endif
