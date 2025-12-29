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
struct DSIntegrationPanel<ViewModel: IntegrationViewModel, Content: View, LoginView: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ObservedObject var viewModel: ViewModel
    @ViewBuilder let content: () -> Content
    @ViewBuilder let loginView: () -> LoginView

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
                loginView()
            } else {
                content()
            }
        }
        .frame(width: 400, height: 600)
        .background(AppTheme.background)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Bottom Panel Variant (with Resizer)

/// Generic bottom panel component for plugin integrations
/// Provides consistent UI with resizer for bottom panels
struct DSIntegrationBottomPanel<ViewModel: IntegrationViewModel, Content: View, LoginView: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ObservedObject var viewModel: ViewModel
    @ViewBuilder let content: () -> Content
    @ViewBuilder let loginView: () -> LoginView

    @Binding var height: CGFloat
    let onSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

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
                loginView()
            } else {
                content()
            }
        }
        .frame(height: height)
        .background(AppTheme.background)
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
        loginView: {
            DSLoginPrompt(viewModel: MockIntegrationViewModel())
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
        loginView: {
            DSLoginPrompt(viewModel: MockIntegrationViewModel())
        },
        onSettings: { print("Settings tapped") },
        onClose: { print("Close tapped") }
    )
    .padding()
    .background(AppTheme.background)
}

#Preview("Bottom Panel - Authenticated") {
    struct PreviewWrapper: View {
        @State private var height: CGFloat = 300

        var body: some View {
            DSIntegrationBottomPanel(
                title: "Notion",
                icon: "doc.text.fill",
                iconColor: AppTheme.textPrimary,
                viewModel: MockIntegrationViewModel(isAuthenticated: true),
                content: {
                    VStack {
                        Text("Task content goes here")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                },
                loginView: {
                    DSLoginPrompt(viewModel: MockIntegrationViewModel())
                },
                height: $height,
                onSettings: { print("Settings tapped") },
                onClose: { print("Close tapped") }
            )
        }
    }
    return PreviewWrapper()
}
