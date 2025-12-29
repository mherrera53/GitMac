//
//  TaigaTicketsPanel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Main panel for Taiga integration
//

import SwiftUI

// MARK: - Taiga Tickets Panel (Bottom Panel)

struct TaigaTicketsPanel: View {
    @StateObject private var themeManager = ThemeManager.shared

    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = TaigaTicketsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Panel content
            VStack(spacing: 0) {
                // Header
                HStack(spacing: DesignTokens.Spacing.md) {
                    DSIcon("ticket.fill", size: .md, color: AppTheme.success)

                    Text("Taiga")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    // Refresh button
                    DSIconButton(
                        iconName: "arrow.clockwise",
                        variant: .ghost,
                        size: .sm
                    ) {
                        try? await viewModel.refresh()
                    }
                    .disabled(viewModel.isLoading)

                    // Settings button
                    DSIconButton(
                        iconName: "gear",
                        variant: .ghost,
                        size: .sm
                    ) {
                        viewModel.showSettings = true
                    }

                    // Close button
                    DSCloseButton {
                        onClose()
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                DSDivider()

                // Content
                if viewModel.isLoading && !viewModel.isAuthenticated {
                    DSLoadingState(message: "Loading...")
                } else if let error = viewModel.error {
                    DSErrorState(
                        message: error,
                        onRetry: {
                            try? await viewModel.refresh()
                        }
                    )
                } else if !viewModel.isAuthenticated {
                    TaigaLoginPrompt(viewModel: viewModel)
                } else {
                    TaigaContentView(viewModel: viewModel)
                }
            }
            .background(AppTheme.background)
        }
        .frame(height: height)
        .sheet(isPresented: $viewModel.showSettings) {
            TaigaSettingsSheet(viewModel: viewModel)
        }
    }
}
