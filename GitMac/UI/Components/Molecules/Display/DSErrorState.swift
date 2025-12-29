//
//  DSErrorState.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 3: Error State Molecule
//

import SwiftUI

/// Error state display component - Error icon + Message + Retry button
struct DSErrorState: View {
    let title: String
    let message: String
    let retryTitle: String?
    let onRetry: (() async -> Void)?

    init(
        title: String = "Something went wrong",
        message: String,
        retryTitle: String? = "Try Again",
        onRetry: (() async -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            DSIcon("exclamationmark.triangle.fill", size: .lg, color: AppTheme.error)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Text(message)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retryTitle = retryTitle, let onRetry = onRetry {
                DSButton(variant: .primary) {
                    await onRetry()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        DSIcon("arrow.clockwise", size: .sm)
                        Text(retryTitle)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Error State - Basic") {
    DSErrorState(
        message: "Unable to load the requested data."
    )
    .frame(width: 400, height: 300)
    .background(AppTheme.background)
}

#Preview("Error State - With Retry") {
    DSErrorState(
        title: "Connection Failed",
        message: "Could not connect to the remote repository. Please check your internet connection and try again.",
        retryTitle: "Retry",
        onRetry: {
            print("Retry tapped")
        }
    )
    .frame(width: 400, height: 300)
    .background(AppTheme.background)
}

#Preview("Error State - Git Error") {
    DSErrorState(
        title: "Push Failed",
        message: "Failed to push commits to origin/main. The remote contains work that you do not have locally.",
        retryTitle: "Pull and Retry",
        onRetry: {
            print("Pull and retry tapped")
        }
    )
    .frame(width: 450, height: 300)
    .background(AppTheme.background)
}

#Preview("Error State - No Retry") {
    DSErrorState(
        title: "Permission Denied",
        message: "You do not have permission to access this repository.",
        retryTitle: nil,
        onRetry: nil
    )
    .frame(width: 400, height: 300)
    .background(AppTheme.background)
}
