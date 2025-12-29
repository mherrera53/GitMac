//
//  DSSettingsSheet.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 5: Settings Sheet Organism
//

import SwiftUI

/// Generic settings modal for integrations
/// Provides consistent UI for configuration screens
struct DSSettingsSheet<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                DSCloseButton {
                    onClose()
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(AppTheme.backgroundSecondary)

            DSDivider()

            // Content
            ScrollView {
                content()
                    .padding(DesignTokens.Spacing.lg)
            }
        }
        .frame(width: 500, height: 400)
        .background(AppTheme.background)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Previews

#Preview("Settings Sheet - Basic") {
    DSSettingsSheet(
        title: "GitHub Settings",
        onClose: { print("Close tapped") }
    ) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Configure your GitHub integration")
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("API Token")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Text("Your personal access token for GitHub API")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Settings Sheet - With Form") {
    DSSettingsSheet(
        title: "Jira Settings",
        onClose: { print("Close tapped") }
    ) {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Server URL
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Server URL")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(AppTheme.textPrimary)

                TextField("https://your-domain.atlassian.net", text: .constant(""))
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.Spacing.sm)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.md)
            }

            // API Token
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("API Token")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(AppTheme.textPrimary)

                SecureField("Enter your API token", text: .constant(""))
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.Spacing.sm)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.md)
            }

            // Project Key
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Default Project")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(AppTheme.textPrimary)

                TextField("PROJ", text: .constant(""))
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.Spacing.sm)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(DesignTokens.CornerRadius.md)
            }

            Spacer()

            // Save button
            DSButton(variant: .primary) {
                print("Save settings")
            } label: {
                Text("Save Settings")
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}

#Preview("Settings Sheet - Multiple Sections") {
    DSSettingsSheet(
        title: "Integration Settings",
        onClose: { print("Close tapped") }
    ) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            // Authentication Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Authentication")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                HStack {
                    DSIcon("checkmark.circle.fill", size: .sm, color: AppTheme.success)
                    Text("Connected")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    DSButton(variant: .secondary, size: .sm) {
                        print("Disconnect")
                    } label: {
                        Text("Disconnect")
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }

            // Notifications Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Notifications")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Toggle(isOn: .constant(true)) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("New Issues")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Get notified when new issues are created")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Toggle(isOn: .constant(false)) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Issue Updates")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Get notified when issues are updated")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }

            // Refresh Interval Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Refresh Interval")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                HStack {
                    Text("5 minutes")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
        }
    }
    .padding()
    .background(AppTheme.background)
}
