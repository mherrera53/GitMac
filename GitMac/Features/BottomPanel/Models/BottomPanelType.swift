//
//  BottomPanelType.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

enum BottomPanelType: String, CaseIterable, Identifiable, Codable {
    case terminal
    case taiga
    case planner
    case linear
    case jira
    case notion
    case teamActivity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal:
            return "Terminal"
        case .taiga:
            return "Taiga"
        case .planner:
            return "Planner"
        case .linear:
            return "Linear"
        case .jira:
            return "Jira"
        case .notion:
            return "Notion"
        case .teamActivity:
            return "Team Activity"
        }
    }

    var icon: String {
        switch self {
        case .terminal:
            return "terminal"
        case .taiga:
            return "tag.fill"
        case .planner:
            return "checklist"
        case .linear:
            return "lineweight"
        case .jira:
            return "square.stack.3d.up"
        case .notion:
            return "doc.text"
        case .teamActivity:
            return "person.3"
        }
    }

    @MainActor
    var accentColor: Color {
        switch self {
        case .terminal:
            return AppTheme.info
        case .taiga:
            return AppTheme.success
        case .planner:
            return AppTheme.warning
        case .linear:
            return AppTheme.accent
        case .jira:
            return AppTheme.info
        case .notion:
            return AppTheme.textPrimary
        case .teamActivity:
            return AppTheme.accent
        }
    }
}
