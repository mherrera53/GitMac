//
//  TaigaIssuesView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Issues list view for Taiga integration
//

import SwiftUI

struct TaigaIssuesView: View {
    let issues: [TaigaIssue]

    var body: some View {
        if issues.isEmpty {
            TaigaEmptyView(type: "issues")
        } else {
            List(issues) { issue in
                TaigaIssueRow(issue: issue)
            }
            .listStyle(.plain)
        }
    }
}

struct TaigaIssueRow: View {
    let issue: TaigaIssue
    @State private var isHovered = false

    var taigaRef: String {
        "TG-\(issue.ref)"
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Type icon
            Image(systemName: "ladybug.fill")
                .foregroundStyle(SwiftUI.Color(hex: issue.typeExtraInfo?.color ?? "ff6b6b"))
                .font(DesignTokens.Typography.callout)

            // TG Reference badge
            Button {
                copyToClipboard(taigaRef)
            } label: {
                Text(taigaRef)
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(AppTheme.error)
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
            }
            .buttonStyle(.plain)
            .help("Click to copy \(taigaRef)")

            // Subject
            Text(issue.subject)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Insert button
            if isHovered {
                Button {
                    NotificationCenter.default.post(
                        name: .insertTaigaRef,
                        object: nil,
                        userInfo: ["ref": taigaRef, "subject": issue.subject]
                    )
                } label: {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert into commit")
            }

            // Type badge
            if let type = issue.typeExtraInfo {
                Text(type.name)
                    .font(DesignTokens.Typography.caption2)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(SwiftUI.Color(hex: type.color).opacity(0.2))
                    .foregroundStyle(SwiftUI.Color(hex: type.color))
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
            }

            // Status badge
            if let status = issue.statusExtraInfo {
                Text(status.name)
                    .font(DesignTokens.Typography.caption2)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(SwiftUI.Color(hex: status.color).opacity(0.2))
                    .foregroundStyle(SwiftUI.Color(hex: status.color))
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .onHover { isHovered = $0 }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
