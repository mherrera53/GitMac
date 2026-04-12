//
//  JiraSettingsSheet.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Settings sheet for Jira integration
//

import SwiftUI

struct JiraSettingsSheet: View {
    @ObservedObject var viewModel: JiraViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jira Settings")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.callout)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(AppTheme.toolbar)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                        Text("Connected to Jira")
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.error)
                } else {
                    Text("Not connected to Jira")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(AppTheme.panel)
    }
}
