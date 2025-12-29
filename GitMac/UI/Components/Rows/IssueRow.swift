//
//  IssueRow.swift
//  GitMac
//
//  Created by GitMac on 2025-12-28.
//

import SwiftUI

/// Generic reusable issue/task row component
/// Consolidates duplicate rows from Notion, Linear, Jira, and Taiga panels
struct PanelIssueRow<LeadingIcon: View, StatusBadge: View, Metadata: View>: View {
    let identifier: String?
    let title: String

    @ViewBuilder let leadingIcon: () -> LeadingIcon
    @ViewBuilder let statusBadge: () -> StatusBadge
    @ViewBuilder let metadata: () -> Metadata

    let onInsert: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            leadingIcon()

            if let id = identifier {
                Text(id)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            metadata()

            statusBadge()

            if isHovered {
                Button(action: onInsert) {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert into commit message")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .cornerRadius(4)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Standard Status Badge

/// Standard status badge with text and color
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .cornerRadius(4)
    }
}

// MARK: - Previews

#Preview("Simple Issue") {
    PanelIssueRow(
        identifier: "ABC-123",
        title: "Implement dark mode toggle",
        leadingIcon: {
            Image(systemName: "circle")
                .foregroundColor(AppTheme.textSecondary)
                .font(.system(size: 12))
        },
        statusBadge: {
            StatusBadge(text: "In Progress", color: AppTheme.accent)
        },
        metadata: {
            EmptyView()
        },
        onInsert: { print("Insert") }
    )
}

#Preview("Completed Issue") {
    PanelIssueRow(
        identifier: "DEF-456",
        title: "Fix navigation bug in settings",
        leadingIcon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.success)
                .font(.system(size: 12))
        },
        statusBadge: {
            StatusBadge(text: "Done", color: AppTheme.success)
        },
        metadata: {
            EmptyView()
        },
        onInsert: { print("Insert") }
    )
}
