//
//  DSSpacer.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Spacing size enum matching DesignTokens
enum DSSpacing {
    case xxs
    case xs
    case sm
    case md
    case lg
    case xl
    case xxl

    var value: CGFloat {
        switch self {
        case .xxs: return DesignTokens.Spacing.xxs
        case .xs: return DesignTokens.Spacing.xs
        case .sm: return DesignTokens.Spacing.sm
        case .md: return DesignTokens.Spacing.md
        case .lg: return DesignTokens.Spacing.lg
        case .xl: return DesignTokens.Spacing.xl
        case .xxl: return DesignTokens.Spacing.xxl
        }
    }
}

/// Design System Spacer component with preset sizes
struct DSSpacer: View {
    let spacing: DSSpacing
    let orientation: DSDividerOrientation

    init(_ spacing: DSSpacing = .md, orientation: DSDividerOrientation = .horizontal) {
        self.spacing = spacing
        self.orientation = orientation
    }

    var body: some View {
        if orientation == .horizontal {
            Spacer()
                .frame(height: spacing.value)
        } else {
            Spacer()
                .frame(width: spacing.value)
        }
    }
}

#Preview("DSSpacer Sizes") {
    VStack(alignment: .leading, spacing: 0) {
        Text("Start")

        DSSpacer(.xxs)
        Text("After XXS (2pt)")

        DSSpacer(.xs)
        Text("After XS (4pt)")

        DSSpacer(.sm)
        Text("After SM (8pt)")

        DSSpacer(.md)
        Text("After MD (12pt)")

        DSSpacer(.lg)
        Text("After LG (16pt)")

        DSSpacer(.xl)
        Text("After XL (24pt)")

        DSSpacer(.xxl)
        Text("After XXL (32pt)")

        Divider()
            .padding(.vertical, DesignTokens.Spacing.md)

        // Vertical spacers
        HStack(alignment: .top, spacing: 0) {
            Text("A")
            DSSpacer(.xs, orientation: .vertical)
            Text("B")
            DSSpacer(.sm, orientation: .vertical)
            Text("C")
            DSSpacer(.md, orientation: .vertical)
            Text("D")
            DSSpacer(.lg, orientation: .vertical)
            Text("E")
        }
    }
    .padding()
    .background(AppTheme.background)
}
