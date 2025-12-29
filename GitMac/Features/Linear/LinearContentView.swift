//
//  LinearContentView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Linear Integration - Content View for DSIntegrationPanel
//

import SwiftUI

/// Content view for Linear integration
/// Displays team selector, filter mode, and issues list
struct LinearContentView: View {
    @ObservedObject var viewModel: LinearViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Team and filter controls
            HStack(spacing: DesignTokens.Spacing.md) {
                // Team selector
                if !viewModel.teams.isEmpty {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        DSIcon("person.2.fill", size: .sm, color: AppTheme.textSecondary)

                        Picker("", selection: $viewModel.selectedTeamId) {
                            Text("All teams").tag(nil as String?)
                            ForEach(viewModel.teams) { team in
                                Text(team.name).tag(team.id as String?)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Spacer()

                // Filter mode
                Picker("", selection: $viewModel.filterMode) {
                    Text("My Issues").tag(LinearFilterMode.myIssues)
                    Text("All Issues").tag(LinearFilterMode.allIssues)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            DSDivider()

            // Content
            if viewModel.isLoading {
                DSLoadingState(message: "Loading issues...")
            } else if viewModel.issues.isEmpty {
                DSEmptyState(
                    icon: "checkmark.circle",
                    title: "No Issues",
                    description: "No issues found for the selected filter"
                )
            } else {
                LinearIssuesListView(issues: viewModel.issues)
            }
        }
        .onChange(of: viewModel.selectedTeamId) { _, _ in
            Task { try? await viewModel.refresh() }
        }
        .onChange(of: viewModel.filterMode) { _, _ in
            Task { try? await viewModel.refresh() }
        }
    }
}

// MARK: - Issues List

struct LinearIssuesListView: View {
    let issues: [LinearIssue]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(issues) { issue in
                    LinearIssueRow(issue: issue)
                }
            }
            .padding(DesignTokens.Spacing.sm)
        }
    }
}

struct LinearIssueRow: View {
    let issue: LinearIssue

    var body: some View {
        PanelIssueRow(
            identifier: issue.identifier,
            title: issue.title,
            leadingIcon: {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            },
            statusBadge: {
                if let state = issue.state {
                    StatusBadge(text: state.name, color: Color(hex: state.color))
                }
            },
            metadata: {
                EmptyView()
            },
            onInsert: {
                NotificationCenter.default.post(
                    name: .insertLinearRef,
                    object: nil,
                    userInfo: ["identifier": issue.identifier, "title": issue.title]
                )
            }
        )
    }

    private var priorityColor: Color {
        switch issue.priority {
        case 1: return AppTheme.error      // Urgent
        case 2: return AppTheme.warning    // High
        case 3: return AppTheme.warning    // Medium
        case 4: return AppTheme.accent     // Low
        default: return AppTheme.textSecondary  // No priority
        }
    }
}
