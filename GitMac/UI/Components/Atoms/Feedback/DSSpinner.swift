//
//  DSSpinner.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Design System Loading Spinner component
struct DSSpinner: View {
    let size: DSIconSize

    init(size: DSIconSize = .md) {
        self.size = size
    }

    var body: some View {
        ProgressView()
            .scaleEffect(scaleForSize)
            .frame(width: size.dimension, height: size.dimension)
    }

    private var scaleForSize: CGFloat {
        switch size {
        case .sm: return 0.7
        case .md: return 1.0
        case .lg: return 1.3
        case .xl: return 1.6
        }
    }
}

#Preview("DSSpinner Sizes") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        HStack(spacing: DesignTokens.Spacing.xl) {
            VStack {
                DSSpinner(size: .sm)
                Text("Small")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }

            VStack {
                DSSpinner(size: .md)
                Text("Medium")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }

            VStack {
                DSSpinner(size: .lg)
                Text("Large")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }

            VStack {
                DSSpinner(size: .xl)
                Text("Extra Large")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
        }

        // In context examples
        HStack(spacing: DesignTokens.Spacing.md) {
            DSSpinner(size: .sm)
            Text("Loading...")
                .font(DesignTokens.Typography.body)
        }
    }
    .padding()
    .background(AppTheme.background)
}
