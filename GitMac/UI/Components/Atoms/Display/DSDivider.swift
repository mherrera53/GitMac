//
//  DSDivider.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Divider orientation
enum DSDividerOrientation {
    case horizontal
    case vertical
}

/// Design System Divider component
struct DSDivider: View {
    let orientation: DSDividerOrientation
    let color: Color?
    let thickness: CGFloat

    init(orientation: DSDividerOrientation = .horizontal, color: Color? = nil, thickness: CGFloat = 1) {
        self.orientation = orientation
        self.color = color
        self.thickness = thickness
    }

    var body: some View {
        Rectangle()
            .fill(color ?? AppTheme.border)
            .frame(
                width: orientation == .horizontal ? nil : thickness,
                height: orientation == .vertical ? nil : thickness
            )
    }
}

#Preview("DSDivider Variants") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // Horizontal dividers
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text("Section 1")
            DSDivider()
            Text("Section 2")
            DSDivider(color: AppTheme.accent)
            Text("Section 3")
            DSDivider(thickness: 2)
        }

        Spacer()
            .frame(height: DesignTokens.Spacing.xl)

        // Vertical dividers
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text("Left")
            DSDivider(orientation: .vertical)
                .frame(height: 50)
            Text("Center")
            DSDivider(orientation: .vertical, color: AppTheme.accent)
                .frame(height: 50)
            Text("Right")
            DSDivider(orientation: .vertical, thickness: 2)
                .frame(height: 50)
        }
    }
    .padding()
    .background(AppTheme.background)
}
