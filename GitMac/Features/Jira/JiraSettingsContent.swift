//
//  JiraSettingsContent.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Settings content view for Jira integration
//

import SwiftUI

/// Settings content for Jira integration
/// Displays connection status and logout option
struct JiraSettingsContent: View {
    @ObservedObject var viewModel: JiraViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if viewModel.isAuthenticated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                    Text("Connected to Jira")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Button("Disconnect") {
                    viewModel.logout()
                    dismiss()
                }
                .foregroundColor(AppTheme.error)
            } else {
                Text("Not connected to Jira")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }
}
