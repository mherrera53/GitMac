//
//  JiraPanelGeneric.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Test implementation using DSGenericIntegrationPanel
//

import SwiftUI

/// Test implementation of JiraPanel using the generic DSGenericIntegrationPanel
///
/// This demonstrates how the original JiraPanel can be simplified from ~170 lines to ~20 lines
/// by using the generic integration panel component.
///
/// To use this implementation:
/// 1. Build the project to verify it compiles
/// 2. Replace references from JiraPanel to JiraPanelGeneric in the app
/// 3. Test all functionality to ensure it works correctly
/// 4. If successful, rename this file to JiraPanel.swift and delete the old one
struct JiraPanelGeneric: View {
    @Binding var height: CGFloat
    let onClose: () -> Void

    var body: some View {
        DSGenericIntegrationPanel(
            plugin: JiraPlugin(),
            height: $height,
            onClose: onClose,
            loginPrompt: { viewModel in
                JiraLoginPrompt(viewModel: viewModel)
            },
            settingsContent: { viewModel in
                JiraSettingsContentView(viewModel: viewModel)
            }
        )
    }
}

// MARK: - Settings Content

/// Extracted settings content from JiraSettingsSheet
///
/// This is the inner content that was previously inside JiraSettingsSheet.
/// The sheet wrapper is now provided by DSGenericIntegrationPanel.
struct JiraSettingsContentView: View {
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

// MARK: - Comparison

/// Code Reduction Summary:
///
/// Original JiraPanel.swift: ~450 lines
/// - Panel structure: ~90 lines
/// - ContentView: ~145 lines
/// - JiraIssuesListView: ~30 lines
/// - JiraIssueRow: ~80 lines
/// - LoginPrompt: ~95 lines
/// - SettingsSheet: ~50 lines
///
/// New implementation with generic panel:
/// - JiraPanelGeneric: ~20 lines (this file)
/// - JiraSettingsContentView: ~30 lines (extracted content)
/// - JiraContentView: ~145 lines (unchanged, already separated)
/// - JiraLoginPrompt: ~95 lines (unchanged, reused)
/// - JiraIssuesListView: ~30 lines (unchanged)
/// - JiraIssueRow: ~80 lines (unchanged)
///
/// Eliminated code:
/// - Panel boilerplate: ~90 lines (now in DSGenericIntegrationPanel)
/// - Settings sheet wrapper: ~20 lines (now in DSGenericIntegrationPanel)
/// - State management: ~30 lines (now in DSGenericIntegrationPanel)
///
/// Total reduction: ~140 lines of duplicated code per integration
/// Across 5 integrations: ~700 lines of duplicate code eliminated!
