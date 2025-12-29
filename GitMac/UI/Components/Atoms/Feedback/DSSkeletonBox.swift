//
//  DSSkeletonBox.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Design System Skeleton Loading Placeholder
struct DSSkeletonBox: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var isAnimating = false

    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = DesignTokens.CornerRadius.sm) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Rectangle()
            .fill(AppTheme.backgroundSecondary)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        AppTheme.backgroundTertiary.opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: isAnimating ? 300 : -300)
                .mask(
                    Rectangle()
                        .frame(width: width, height: height)
                        .cornerRadius(cornerRadius)
                )
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

#Preview("DSSkeletonBox Variants") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
        // Text-like skeletons
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Text Loading Skeletons")
                .font(DesignTokens.Typography.headline)

            DSSkeletonBox(width: 200, height: 16)
            DSSkeletonBox(width: 150, height: 16)
            DSSkeletonBox(width: 180, height: 16)
        }

        Divider()

        // Card skeleton
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Card Skeleton")
                .font(DesignTokens.Typography.headline)

            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                DSSkeletonBox(width: 48, height: 48, cornerRadius: DesignTokens.CornerRadius.md)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    DSSkeletonBox(width: 120, height: 14)
                    DSSkeletonBox(width: 180, height: 12)
                    DSSkeletonBox(width: 100, height: 12)
                }
            }
            .padding()
            .background(AppTheme.backgroundTertiary.opacity(0.3))
            .cornerRadius(DesignTokens.CornerRadius.md)
        }

        Divider()

        // List skeletons
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("List Item Skeletons")
                .font(DesignTokens.Typography.headline)

            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: DesignTokens.Spacing.md) {
                    DSSkeletonBox(width: 32, height: 32, cornerRadius: 16)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        DSSkeletonBox(width: 140, height: 12)
                        DSSkeletonBox(width: 80, height: 10)
                    }
                }
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}
