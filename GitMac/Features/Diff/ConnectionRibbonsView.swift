import SwiftUI

/// Visual connection ribbons that link related lines between left and right diff panels
struct ConnectionRibbonsView: View {
    let pairs: [DiffPairWithConnection]
    let lineHeight: CGFloat
    let isFluidMode: Bool
    let viewWidth: CGFloat

    private let leftPanelWidth: CGFloat
    private let rightPanelWidth: CGFloat
    
    // Kaleidoscope Style: Balanced opacity for fill, strong opacity for strokes
    private let ribbonOpacity: Double = 0.15
    private let strokeOpacity: Double = 0.6

    init(pairs: [DiffPairWithConnection], lineHeight: CGFloat, isFluidMode: Bool, viewWidth: CGFloat) {
        self.pairs = pairs
        self.lineHeight = lineHeight
        self.isFluidMode = isFluidMode
        self.viewWidth = viewWidth

        // Calculate panel widths (assuming equal split)
        self.leftPanelWidth = viewWidth / 2
        self.rightPanelWidth = viewWidth / 2
    }

    var body: some View {
        Canvas { context, size in
            drawRibbons(context: context, size: size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func drawRibbons(context: GraphicsContext, size: CGSize) {
        var yOffset: CGFloat = 0

        for pair in pairs {
            // Draw ribbons for any non-none connection
            guard pair.connectionType != .none else {
                yOffset += lineHeight
                continue
            }

            // Skip if both sides are nil
            guard pair.left != nil || pair.right != nil else {
                yOffset += lineHeight
                continue
            }

            let ribbonColor = getRibbonColor(for: pair)

            // Draw ribbon connecting left and right panels
            drawRibbon(
                context: context,
                yPosition: yOffset,
                color: ribbonColor,
                isFluid: isFluidMode
            )

            yOffset += lineHeight
        }
    }

    private func drawRibbon(
        context: GraphicsContext,
        yPosition: CGFloat,
        color: Color,
        isFluid: Bool
    ) {
        let centerX = viewWidth / 2
        let ribbonGap: CGFloat = 60
        
        let leftEnd = centerX - (ribbonGap / 2)
        let rightStart = centerX + (ribbonGap / 2)

        let topY = yPosition
        let bottomY = yPosition + lineHeight
        
        // --- Path Construction ---
        var path = Path()
        path.move(to: CGPoint(x: leftEnd, y: topY))
        
        // Horizontal distance for control points
        let cpX = ribbonGap * 0.5
        
        if isFluid {
            // Fluid Mode: Elegant S-Curve
            path.addCurve(
                to: CGPoint(x: rightStart, y: topY),
                control1: CGPoint(x: leftEnd + cpX, y: topY),
                control2: CGPoint(x: rightStart - cpX, y: topY)
            )
            path.addLine(to: CGPoint(x: rightStart, y: bottomY))
            path.addCurve(
                to: CGPoint(x: leftEnd, y: bottomY),
                control1: CGPoint(x: rightStart - cpX, y: bottomY),
                control2: CGPoint(x: leftEnd + cpX, y: bottomY)
            )
        } else {
            // Blocks Mode: Straight but with slightly softer entry
            path.addLine(to: CGPoint(x: rightStart, y: topY))
            path.addLine(to: CGPoint(x: rightStart, y: bottomY))
            path.addLine(to: CGPoint(x: leftEnd, y: bottomY))
        }
        path.closeSubpath()

        // --- Fill logic (Subtle Gradient) ---
        let fillGradient = Gradient(stops: [
            .init(color: color.opacity(0.1), location: 0),
            .init(color: color.opacity(0.2), location: 0.5),
            .init(color: color.opacity(0.1), location: 1)
        ])
        
        context.fill(
            path,
            with: .linearGradient(
                fillGradient,
                startPoint: CGPoint(x: leftEnd, y: topY),
                endPoint: CGPoint(x: rightStart, y: topY)
            )
        )

        // --- Border Lines (Distinct Strokes) ---
        // This is the key "Kaleidoscope" visual trait: distinct lines connecting the blocks
        var topBorder = Path()
        topBorder.move(to: CGPoint(x: leftEnd, y: topY))
        
        var bottomBorder = Path()
        bottomBorder.move(to: CGPoint(x: leftEnd, y: bottomY))

        if isFluid {
            // Fluid: Smooth S-Curve
            topBorder.addCurve(
                to: CGPoint(x: rightStart, y: topY),
                control1: CGPoint(x: leftEnd + cpX, y: topY),
                control2: CGPoint(x: rightStart - cpX, y: topY)
            )
            bottomBorder.addCurve(
                to: CGPoint(x: rightStart, y: bottomY),
                control1: CGPoint(x: leftEnd + cpX, y: bottomY),
                control2: CGPoint(x: rightStart - cpX, y: bottomY)
            )
        } else {
            // Blocks: Straight lines with slight easing
            topBorder.addLine(to: CGPoint(x: rightStart, y: topY))
            bottomBorder.addLine(to: CGPoint(x: rightStart, y: bottomY))
        }

        // Draw Strokes
        context.stroke(
            topBorder,
            with: .color(color.opacity(strokeOpacity)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
        
        context.stroke(
            bottomBorder,
            with: .color(color.opacity(strokeOpacity)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
        
        // --- Side definition (where it hits the panels) ---
        var leftEdge = Path()
        leftEdge.move(to: CGPoint(x: leftEnd, y: topY))
        leftEdge.addLine(to: CGPoint(x: leftEnd, y: bottomY))
        context.stroke(leftEdge, with: .color(color.opacity(0.3)), lineWidth: 0.5)

        var rightEdge = Path()
        rightEdge.move(to: CGPoint(x: rightStart, y: topY))
        rightEdge.addLine(to: CGPoint(x: rightStart, y: bottomY))
        context.stroke(rightEdge, with: .color(color.opacity(0.3)), lineWidth: 0.5)
    }

    private func getRibbonColor(for pair: DiffPairWithConnection) -> Color {
        // Use AppTheme colors for consistency
        if pair.left != nil && pair.right != nil {
            // Modified
            return AppTheme.diffChange
        } else if pair.left != nil {
            // Deleted
            return AppTheme.diffDeletion
        } else {
            // Added
            return AppTheme.diffAddition
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
            viewWidth: 800
        )
        .frame(width: 800, height: 400)
        .background(Color.black.opacity(0.8))
    }
}
#endif
