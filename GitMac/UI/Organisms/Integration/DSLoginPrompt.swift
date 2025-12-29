//
//  DSLoginPrompt.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 5: Login Prompt Organism
//

import SwiftUI

/// Generic login form for integrations
/// Displays authentication UI and handles login flow
struct DSLoginPrompt<ViewModel: IntegrationViewModel>: View {
    @ObservedObject var viewModel: ViewModel

    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            DSEmptyState(
                icon: "key.fill",
                title: "Authentication Required",
                description: "Please authenticate to access this integration."
            )

            VStack(spacing: DesignTokens.Spacing.md) {
                DSLabeledField(
                    label: "API Key",
                    isRequired: true,
                    text: $apiKey,
                    placeholder: "Enter your API key"
                )

                DSButton(variant: .primary) {
                    try? await viewModel.authenticate()
                } label: {
                    Text("Authenticate")
                }
                .disabled(apiKey.isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mock ViewModel for Previews

private class MockIntegrationViewModel: IntegrationViewModel {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

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

#Preview("Login Prompt - Empty") {
    DSLoginPrompt(viewModel: MockIntegrationViewModel())
        .frame(width: 400, height: 600)
        .background(AppTheme.background)
}

#Preview("Login Prompt - Loading") {
    let viewModel = MockIntegrationViewModel()
    viewModel.isLoading = true
    return DSLoginPrompt(viewModel: viewModel)
        .frame(width: 400, height: 600)
        .background(AppTheme.background)
}

#Preview("Login Prompt - In Context") {
    VStack(spacing: 0) {
        // Header
        HStack {
            DSIcon("github", size: .md, color: .blue)

            Text("GitHub Integration")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            DSCloseButton {
                print("Close tapped")
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)

        DSDivider()

        // Login prompt
        DSLoginPrompt(viewModel: MockIntegrationViewModel())
    }
    .frame(width: 400, height: 600)
    .background(AppTheme.background)
    .cornerRadius(DesignTokens.CornerRadius.lg)
}
