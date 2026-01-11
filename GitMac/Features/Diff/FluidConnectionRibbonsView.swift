import SwiftUI

enum RibbonSide {
    case left
    case right
}

struct FluidConnectionRibbonsView: View {
    let pairs: [DiffPairWithConnection]
    let leftYMap: [Int: CGFloat]
    let rightYMap: [Int: CGFloat]
    let scrollOffset: CGFloat
    let side: RibbonSide
    let lineHeight: CGFloat
    let panelWidth: CGFloat
    let panelOverlap: CGFloat
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        let yMap = (side == .left) ? leftYMap : rightYMap
        let maxY = yMap.values.max() ?? 0
        let canvasHeight = maxY + lineHeight * 10
        
        Canvas { context, size in
            drawHalfRibbons(context: context, size: size)
        }
        .frame(width: panelWidth, height: canvasHeight)
        .offset(y: -scrollOffset)
        .clipped()
    }
    
    private func drawHalfRibbons(context: GraphicsContext, size: CGSize) {
        let theme = Color.Theme(themeManager.colors)
        let effectiveOverlap = min(panelOverlap, panelWidth)
        
        var i = 0
        while i < pairs.count {
            let pair = pairs[i]
            guard pair.connectionType != .none else {
                i += 1
                continue
            }
            
            var j = i + 1
            while j < pairs.count {
                let next = pairs[j]
                guard next.connectionType != .none else { break }
                j += 1
            }
            
            var hasLeft = false
            var hasRight = false
            var leftIndices: [Int] = []
            var rightIndices: [Int] = []
            
            for idx in i..<j {
                if pairs[idx].left != nil {
                    hasLeft = true
                    leftIndices.append(idx)
                }
                if pairs[idx].right != nil {
                    hasRight = true
                    rightIndices.append(idx)
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
            
            switch side {
            case .left:
                if hasLeft {
                    guard let leftFirst = leftIndices.first,
                          let leftLast = leftIndices.last,
                          let ltY = leftYMap[leftFirst],
                          let lbY = leftYMap[leftLast] else {
                        i = j
                        continue
                    }
                    
                    if hasLeft && hasRight {
                        guard let rightFirst = rightIndices.first,
                              let rtY = rightYMap[rightFirst] else {
                            i = j
                            continue
                        }
                        drawLeftHalfTrapezoid(
                            context: context,
                            topY: ltY,
                            bottomY: lbY + lineHeight,
                            targetY: rtY,
                            color: color,
                            effectiveOverlap: effectiveOverlap
                        )
                    } else {
                        drawLeftTeardrop(
                            context: context,
                            topY: ltY,
                            bottomY: lbY + lineHeight,
                            color: color,
                            effectiveOverlap: effectiveOverlap
                        )
                    }
                }
                
            case .right:
                if hasRight {
                    guard let rightFirst = rightIndices.first,
                          let rightLast = rightIndices.last,
                          let rtY = rightYMap[rightFirst],
                          let rbY = rightYMap[rightLast] else {
                        i = j
                        continue
                    }
                    
                    if hasLeft && hasRight {
                        guard let leftFirst = leftIndices.first,
                              let ltY = leftYMap[leftFirst] else {
                            i = j
                            continue
                        }
                        drawRightHalfTrapezoid(
                            context: context,
                            topY: rtY,
                            bottomY: rbY + lineHeight,
                            targetY: ltY,
                            color: color,
                            effectiveOverlap: effectiveOverlap
                        )
                    } else {
                        drawRightTeardrop(
                            context: context,
                            topY: rtY,
                            bottomY: rbY + lineHeight,
                            color: color,
                            effectiveOverlap: effectiveOverlap
                        )
                    }
                }
            }
            
            i = j
        }
    }
    
    private func drawLeftHalfTrapezoid(
        context: GraphicsContext,
        topY: CGFloat,
        bottomY: CGFloat,
        targetY: CGFloat,
        color: Color,
        effectiveOverlap: CGFloat
    ) {
        let leftX = max(0, panelWidth - effectiveOverlap)
        let rightX = panelWidth

        _ = (topY + targetY) / 2  // topMidY - reserved for future use
        _ = bottomY  // bottomMidY - reserved for future use

        var band = Path()
        band.move(to: CGPoint(x: leftX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: bottomY))
        band.addLine(to: CGPoint(x: leftX, y: bottomY))
        band.closeSubpath()
        
        let gradient = Gradient(stops: [
            .init(color: color.opacity(0.0), location: 0.0),
            .init(color: color.opacity(0.16), location: 0.20),
            .init(color: color.opacity(0.28), location: 0.50),
            .init(color: color.opacity(0.34), location: 1.0)
        ])
        
        context.fill(
            band,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: leftX, y: (topY + bottomY) / 2),
                endPoint: CGPoint(x: rightX, y: (topY + bottomY) / 2)
            )
        )
    }
    
    private func drawRightHalfTrapezoid(
        context: GraphicsContext,
        topY: CGFloat,
        bottomY: CGFloat,
        targetY: CGFloat,
        color: Color,
        effectiveOverlap: CGFloat
    ) {
        let leftX: CGFloat = 0
        let rightX = min(panelWidth, effectiveOverlap)
        
        var band = Path()
        band.move(to: CGPoint(x: leftX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: bottomY))
        band.addLine(to: CGPoint(x: leftX, y: bottomY))
        band.closeSubpath()
        
        let gradient = Gradient(stops: [
            .init(color: color.opacity(0.34), location: 0.0),
            .init(color: color.opacity(0.28), location: 0.50),
            .init(color: color.opacity(0.16), location: 0.80),
            .init(color: color.opacity(0.0), location: 1.0)
        ])
        
        context.fill(
            band,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: leftX, y: (topY + bottomY) / 2),
                endPoint: CGPoint(x: rightX, y: (topY + bottomY) / 2)
            )
        )
    }
    
    private func drawLeftTeardrop(
        context: GraphicsContext,
        topY: CGFloat,
        bottomY: CGFloat,
        color: Color,
        effectiveOverlap: CGFloat
    ) {
        let leftX = max(0, panelWidth - effectiveOverlap)
        let rightX = panelWidth
        
        var band = Path()
        band.move(to: CGPoint(x: leftX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: bottomY))
        band.addLine(to: CGPoint(x: leftX, y: bottomY))
        band.closeSubpath()
        
        let gradient = Gradient(stops: [
            .init(color: color.opacity(0.0), location: 0.0),
            .init(color: color.opacity(0.16), location: 0.20),
            .init(color: color.opacity(0.28), location: 0.50),
            .init(color: color.opacity(0.34), location: 1.0)
        ])
        
        context.fill(
            band,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: leftX, y: (topY + bottomY) / 2),
                endPoint: CGPoint(x: rightX, y: (topY + bottomY) / 2)
            )
        )
    }
    
    private func drawRightTeardrop(
        context: GraphicsContext,
        topY: CGFloat,
        bottomY: CGFloat,
        color: Color,
        effectiveOverlap: CGFloat
    ) {
        let leftX: CGFloat = 0
        let rightX = min(panelWidth, effectiveOverlap)
        
        var band = Path()
        band.move(to: CGPoint(x: leftX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: bottomY))
        band.addLine(to: CGPoint(x: leftX, y: bottomY))
        band.closeSubpath()
        
        let gradient = Gradient(stops: [
            .init(color: color.opacity(0.34), location: 0.0),
            .init(color: color.opacity(0.28), location: 0.50),
            .init(color: color.opacity(0.16), location: 0.80),
            .init(color: color.opacity(0.0), location: 1.0)
        ])
        
        context.fill(
            band,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: leftX, y: (topY + bottomY) / 2),
                endPoint: CGPoint(x: rightX, y: (topY + bottomY) / 2)
            )
        )
    }
}
