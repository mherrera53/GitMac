import SwiftUI

enum RibbonSide: Equatable {
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
    let themeColors: ColorScheme

    var body: some View {
        let yMap = (side == .left) ? leftYMap : rightYMap
        let maxY = yMap.values.max() ?? 0
        let canvasHeight = maxY + lineHeight * 10

        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            drawHalfRibbons(context: context, size: size)
        }
        .frame(width: panelWidth, height: canvasHeight)
        .offset(y: -scrollOffset)
        .clipped()
        .drawingGroup()
    }

    private func drawHalfRibbons(context: GraphicsContext, size: CGSize) {
        let theme = Color.Theme(themeColors)
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

                    if hasRight {
                        guard let rightFirst = rightIndices.first,
                              rightYMap[rightFirst] != nil else {
                            i = j
                            continue
                        }
                        drawHalfBand(context: context, topY: ltY, bottomY: lbY + lineHeight, color: color, effectiveOverlap: effectiveOverlap, isLeft: true)
                    } else {
                        drawHalfBand(context: context, topY: ltY, bottomY: lbY + lineHeight, color: color, effectiveOverlap: effectiveOverlap, isLeft: true)
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

                    if hasLeft {
                        guard let leftFirst = leftIndices.first,
                              leftYMap[leftFirst] != nil else {
                            i = j
                            continue
                        }
                        drawHalfBand(context: context, topY: rtY, bottomY: rbY + lineHeight, color: color, effectiveOverlap: effectiveOverlap, isLeft: false)
                    } else {
                        drawHalfBand(context: context, topY: rtY, bottomY: rbY + lineHeight, color: color, effectiveOverlap: effectiveOverlap, isLeft: false)
                    }
                }
            }

            i = j
        }
    }

    @inline(__always)
    private func drawHalfBand(context: GraphicsContext, topY: CGFloat, bottomY: CGFloat, color: Color, effectiveOverlap: CGFloat, isLeft: Bool) {
        let leftX: CGFloat
        let rightX: CGFloat

        if isLeft {
            leftX = max(0, panelWidth - effectiveOverlap)
            rightX = panelWidth
        } else {
            leftX = 0
            rightX = min(panelWidth, effectiveOverlap)
        }

        var band = Path()
        band.move(to: CGPoint(x: leftX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: topY))
        band.addLine(to: CGPoint(x: rightX, y: bottomY))
        band.addLine(to: CGPoint(x: leftX, y: bottomY))
        band.closeSubpath()

        let gradient: Gradient
        if isLeft {
            gradient = Gradient(stops: [
                .init(color: color.opacity(0.0), location: 0.0),
                .init(color: color.opacity(0.16), location: 0.20),
                .init(color: color.opacity(0.28), location: 0.50),
                .init(color: color.opacity(0.34), location: 1.0)
            ])
        } else {
            gradient = Gradient(stops: [
                .init(color: color.opacity(0.34), location: 0.0),
                .init(color: color.opacity(0.28), location: 0.50),
                .init(color: color.opacity(0.16), location: 0.80),
                .init(color: color.opacity(0.0), location: 1.0)
            ])
        }

        let midY = (topY + bottomY) / 2
        context.fill(
            band,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: leftX, y: midY),
                endPoint: CGPoint(x: rightX, y: midY)
            )
        )
    }
}
