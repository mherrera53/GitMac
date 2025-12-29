//
//  TaigaLoginPrompt.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Login prompt for Taiga integration
//

import SwiftUI

struct TaigaLoginPrompt: View {
    @ObservedObject var viewModel: TaigaTicketsViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "ticket.fill")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(AppTheme.success)

            Text("Connect to Taiga")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("Log in to view your project tickets from tree.taiga.io")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignTokens.Spacing.sm) {
                TextField("Username or Email", text: $username)
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.Spacing.sm)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.md)
                    .frame(width: 250)

                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.Spacing.sm)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.md)
                    .frame(width: 250)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.error)
            }

            Button {
                Task {
                    await viewModel.login(username: username, password: password)
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 100, height: 24)
                } else {
                    Text("Log In")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || viewModel.isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
