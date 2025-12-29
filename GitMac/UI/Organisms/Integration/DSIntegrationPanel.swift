//
//  DSIntegrationPanel.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 5: Integration Panel Organism
//

import SwiftUI

/// Generic panel component for plugin integrations
/// Provides consistent UI for authentication, loading, error states
struct DSIntegrationPanel<ViewModel: IntegrationViewModel, Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ObservedObject var viewModel: ViewModel
    @ViewBuilder let content: () -> Content

    let onSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DesignTokens.Spacing.md) {
                DSIcon(icon, size: .md, color: iconColor)

                Text(title)
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
                    onSettings()
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
                DSLoginPrompt(viewModel: viewModel)
            } else {
                content()
            }
        }
        .frame(width: 400, height: 600)
        .background(AppTheme.background)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Mock ViewModel for Previews

private class MockIntegrationViewModel: IntegrationViewModel {
    @Published var isAuthenticated: Bool
    @Published var isLoading: Bool
    @Published var error: String?

    init(isAuthenticated: Bool = false, isLoading: Bool = false, error: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.isLoading = isLoading
        self.error = error
    }

    func authenticate() async throws {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isAuthenticated = true
        isLoading = false
    }

    func refresh() async throws {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }
}

// MARK: - Previews

#Preview("Integration Panel - Authenticated") {
    DSIntegrationPanel(
        title: "GitHub Issues",
        icon: "github",
        iconColor: .blue,
        viewModel: MockIntegrationViewModel(isAuthenticated: true),
        content: {
            VStack {
                Text("Issue content goes here")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        },
        onSettings: { print("Settings tapped") },
        onClose: { print("Close tapped") }
    )
    .padding()
    .background(AppTheme.background)
}

#Preview("Integration Panel - Not Authenticated") {
    DSIntegrationPanel(
        title: "GitHub Issues",
        icon: "github",
        iconColor: .blue,
        viewModel: MockIntegrationViewModel(isAuthenticated: false),
        content: {
            EmptyView()
        },
        onSettings: { print("Settings tapped") },
        onClose: { print("Close tapped") }
    )
    .padding()
    .background(AppTheme.background)
}

#Preview("Integration Panel - Loading") {
    DSIntegrationPanel(
        title: "GitHub Issues",
        icon: "github",
        iconColor: .blue,
        viewModel: MockIntegrationViewModel(isAuthenticated: false, isLoading: true),
        content: {
            EmptyView()
        },
        onSettings: { print("Settings tapped") },
        onClose: { print("Close tapped") }
    )
    .padding()
    .background(AppTheme.background)
}

#Preview("Integration Panel - Error") {
    DSIntegrationPanel(
        title: "GitHub Issues",
        icon: "github",
        iconColor: .blue,
        viewModel: MockIntegrationViewModel(isAuthenticated: false, error: "Failed to connect to GitHub API"),
        content: {
            EmptyView()
        },
        onSettings: { print("Settings tapped") },
        onClose: { print("Close tapped") }
    )
    .padding()
    .background(AppTheme.background)
}
