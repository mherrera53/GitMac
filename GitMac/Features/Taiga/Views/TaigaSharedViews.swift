//
//  TaigaSharedViews.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Shared views and utilities for Taiga integration
//

import SwiftUI

// MARK: - Empty View

struct TaigaEmptyView: View {
    let type: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "tray")
                .font(DesignTokens.Typography.iconXXL)
                .foregroundStyle(AppTheme.textMuted)

            Text("No \(type) found")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings Sheet

struct TaigaSettingsSheet: View {
    @ObservedObject var viewModel: TaigaTicketsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Taiga Settings")
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
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                        Text("Connected to Taiga")
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.error)
                } else {
                    Text("Not connected to Taiga")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Notification for Taiga Reference

extension Notification.Name {
    static let insertTaigaRef = Notification.Name("insertTaigaRef")
}
