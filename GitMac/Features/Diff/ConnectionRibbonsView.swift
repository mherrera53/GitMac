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

        let effectiveOverlap = min(panelOverlap, panelWidth)
        let leftX: CGFloat
        let rightX: CGFloat
        
        switch side {
        case .left:
            leftX = max(0, gutterLeft - effectiveOverlap)
            rightX = gutterLeft
        case .right:
            leftX = gutterRight
            rightX = min(layoutWidth, gutterRight + effectiveOverlap)
        }

        let height = max(lineHeight, bottomY - topY)
        let midY = topY + height / 2
        let top = topY
        let bottom = topY + height

        // EXACTLY the same gradient as change ribbons
        let gradient = Gradient(stops: [
            .init(color: color.opacity(0.0), location: 0.0),
            .init(color: color.opacity(0.16), location: 0.10),
            .init(color: color.opacity(0.28), location: 0.30),
            .init(color: color.opacity(0.34), location: 0.50),
            .init(color: color.opacity(0.28), location: 0.70),
            .init(color: color.opacity(0.16), location: 0.90),
            .init(color: color.opacity(0.0), location: 1.0)
        ])

        let borderGradient = Gradient(stops: [
            .init(color: color.opacity(0.0), location: 0.0),
            .init(color: color.opacity(0.60), location: 0.12),
            .init(color: color.opacity(0.60), location: 0.50),
            .init(color: color.opacity(0.60), location: 0.88),
            .init(color: color.opacity(0.0), location: 1.0)
        ])

        let markerWidth: CGFloat = 4
        let fadeWidth: CGFloat = min(18, max(10, panelWidth * 0.06))

        // Create main ribbon shape
        let topLeft = CGPoint(x: leftX, y: top)
        let topRight = CGPoint(x: rightX, y: top)
        let bottomRight = CGPoint(x: rightX, y: bottom)
        let bottomLeft = CGPoint(x: leftX, y: bottom)

        var band = Path()
        band.move(to: topLeft)
        band.addLine(to: topRight)
        band.addLine(to: bottomRight)
        band.addLine(to: bottomLeft)
        band.closeSubpath()

        context.drawLayer { layer in
            // Main ribbon fill with gradient (SAME as change ribbons)
            layer.fill(
                band,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: leftX, y: midY),
                    endPoint: CGPoint(x: rightX, y: midY)
                )
            )

            // Top edge border (SAME as change ribbons)
            var topEdge = Path()
            topEdge.move(to: topLeft)
            topEdge.addLine(to: topRight)
            layer.stroke(
                topEdge,
                with: .linearGradient(borderGradient, startPoint: CGPoint(x: leftX, y: midY), endPoint: CGPoint(x: rightX, y: midY)),
                style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
            )

            // Bottom edge border (SAME as change ribbons)
            var bottomEdge = Path()
            bottomEdge.move(to: bottomLeft)
            bottomEdge.addLine(to: bottomRight)
            layer.stroke(
                bottomEdge,
                with: .linearGradient(borderGradient, startPoint: CGPoint(x: leftX, y: midY), endPoint: CGPoint(x: rightX, y: midY)),
                style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
            )

            // Panel inner edge marker and fade (EXACTLY like change ribbons)
            if side == .left {
                // Left panel marker (at gutter edge)
                let markerRect = CGRect(x: max(0, gutterLeft - markerWidth - 1), y: top, width: markerWidth, height: height)
                layer.fill(Path(markerRect), with: .color(color.opacity(0.32)))
                
                // Left fade
                let leftFadeRect = CGRect(x: max(0, gutterLeft - markerWidth - 1 - fadeWidth), y: top, width: fadeWidth, height: height)
                layer.fill(
                    Path(leftFadeRect),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: color.opacity(0.18), location: 0.0),
                            .init(color: color.opacity(0.0), location: 1.0)
                        ]),
                        startPoint: CGPoint(x: gutterLeft, y: midY),
                        endPoint: CGPoint(x: gutterLeft - fadeWidth, y: midY)
                    )
                )
            } else {
                // Right panel marker (at gutter edge)
                let markerRect = CGRect(x: min(layoutWidth - markerWidth, gutterRight + 1), y: top, width: markerWidth, height: height)
                layer.fill(Path(markerRect), with: .color(color.opacity(0.32)))
                
                // Right fade
                let rightFadeRect = CGRect(x: min(layoutWidth, gutterRight + 1 + markerWidth), y: top, width: fadeWidth, height: height)
                layer.fill(
                    Path(rightFadeRect),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: color.opacity(0.18), location: 0.0),
                            .init(color: color.opacity(0.0), location: 1.0)
                        ]),
                        startPoint: CGPoint(x: gutterRight, y: midY),
                        endPoint: CGPoint(x: gutterRight + fadeWidth, y: midY)
                    )
                )
            }

            // Center line for continuity (SAME as change ribbons)
            var center = Path()
            center.move(to: CGPoint(x: leftX + 2, y: midY))
            center.addLine(to: CGPoint(x: rightX - 2, y: midY))
            layer.stroke(
                center,
                with: .linearGradient(borderGradient, startPoint: CGPoint(x: leftX, y: midY), endPoint: CGPoint(x: rightX, y: midY)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            )
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

        let topMidY = (lt + rt) / 2
        let bottomMidY = (lb + rb) / 2

        let ribbonWidth = rightX - leftX
        let curvatureX = ribbonWidth * (isFluid ? 0.46 : 0.38)
        let curvatureY = max(6, lineHeight * (isFluid ? 0.55 : 0.35))

        let topLeft = CGPoint(x: leftX, y: lt)
        let topRight = CGPoint(x: rightX, y: rt)
        let bottomRight = CGPoint(x: rightX, y: rb)
        let bottomLeft = CGPoint(x: leftX, y: lb)

        var band = Path()
        band.move(to: topLeft)
        band.addCurve(
            to: topRight,
            control1: CGPoint(x: leftX + curvatureX, y: topMidY + curvatureY),
            control2: CGPoint(x: rightX - curvatureX, y: topMidY - curvatureY)
        )
        band.addLine(to: bottomRight)
        band.addCurve(
            to: bottomLeft,
            control1: CGPoint(x: rightX - curvatureX, y: bottomMidY - curvatureY),
            control2: CGPoint(x: leftX + curvatureX, y: bottomMidY + curvatureY)
        )
        band.closeSubpath()

        let gradient = Gradient(stops: [
            .init(color: color.opacity(0.0), location: 0.0),
            .init(color: color.opacity(0.16), location: 0.10),
            .init(color: color.opacity(0.28), location: 0.30),
            .init(color: color.opacity(0.34), location: 0.50),
            .init(color: color.opacity(0.28), location: 0.70),
            .init(color: color.opacity(0.16), location: 0.90),
            .init(color: color.opacity(0.0), location: 1.0)
        ])

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
                    startPoint: CGPoint(x: leftX, y: (topMidY + bottomMidY) / 2),
                    endPoint: CGPoint(x: rightX, y: (topMidY + bottomMidY) / 2)
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
                control1: CGPoint(x: leftX + curvatureX, y: topMidY + curvatureY),
                control2: CGPoint(x: rightX - curvatureX, y: topMidY - curvatureY)
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
                control1: CGPoint(x: leftX + curvatureX, y: bottomMidY + curvatureY),
                control2: CGPoint(x: rightX - curvatureX, y: bottomMidY - curvatureY)
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

            var center = Path()
            center.move(to: CGPoint(x: leftX + 2, y: (lt + lb) / 2))
            center.addCurve(
                to: CGPoint(x: rightX - 2, y: (rt + rb) / 2),
                control1: CGPoint(x: leftX + curvatureX, y: (topMidY + bottomMidY) / 2 + curvatureY * 0.35),
                control2: CGPoint(x: rightX - curvatureX, y: (topMidY + bottomMidY) / 2 - curvatureY * 0.35)
            )
            layer.stroke(
                center,
                with: .linearGradient(borderGradient, startPoint: CGPoint(x: leftX, y: midY), endPoint: CGPoint(x: rightX, y: midY)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
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
