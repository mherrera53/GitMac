//
//  TaigaSettingsContent.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Settings content view for Taiga integration
//

import SwiftUI

/// Settings content for Taiga integration
/// Displays connection status and logout option
struct TaigaSettingsContent: View {
    @ObservedObject var viewModel: TaigaTicketsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if viewModel.isAuthenticated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                    Text("Connected to Taiga")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Button("Disconnect") {
                    viewModel.logout()
                    dismiss()
                }
                .foregroundColor(AppTheme.error)
            } else {
                Text("Not connected to Taiga")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }
}
