//
//  BottomPanelContent.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

struct BottomPanelContent: View {
    let tab: BottomPanelTab
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch tab.type {
            case .terminal:
                TerminalPanelContent()
            case .taiga:
                TaigaPanelContent()
            case .planner:
                PlannerPanelContent()
            case .linear:
                LinearPanelContent()
            case .jira:
                JiraPanelContent()
            case .notion:
                NotionPanelContent()
            case .teamActivity:
                TeamActivityPanelContent()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.panel)
    }
}

// MARK: - Panel Content Views

struct TerminalPanelContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if GHOSTTY_AVAILABLE
        EnhancedTerminalPanel()
            .environmentObject(appState)
        #else
        TerminalView()
            .environmentObject(appState)
        #endif
    }
}

struct TaigaPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        TaigaTicketsPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlannerPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        PlannerTasksPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LinearPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        LinearPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JiraPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        JiraPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotionPanelContent: View {
    @State private var dummyHeight: CGFloat = 300
    var body: some View {
        NotionPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TeamActivityPanelContent: View {
    @State private var dummyHeight: CGFloat = 400
    var body: some View {
        TeamActivityPanel(height: $dummyHeight, onClose: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlaceholderPanelContent: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textMuted)

            Text(title)
                .font(DesignTokens.Typography.title3)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.textPrimary)

            Text(message)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// Empty state view when no tabs are open
struct EmptyPanelView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "tray")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textMuted)

            Text("No panels open")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textSecondary)

            Text("Click the + button or toolbar icons to add panels")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.panel)
    }
}
