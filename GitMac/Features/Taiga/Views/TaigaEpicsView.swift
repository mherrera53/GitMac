//
//  TaigaEpicsView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Epics list view for Taiga integration
//

import SwiftUI

struct TaigaEpicsView: View {
    let epics: [TaigaEpic]

    var body: some View {
        if epics.isEmpty {
            TaigaEmptyView(type: "epics")
        } else {
            List(epics) { epic in
                TaigaEpicRow(epic: epic)
            }
            .listStyle(.plain)
        }
    }
}

struct TaigaEpicRow: View {
    let epic: TaigaEpic

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Color bar
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .fill(Color(hex: epic.color ?? "7b68ee"))
                .frame(width: 4, height: 24)

            // Ref
            Text("#\(epic.ref)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textMuted)

            // Subject
            Text(epic.subject)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Status badge
            if let status = epic.statusExtraInfo {
                Text(status.name)
                    .font(DesignTokens.Typography.caption2)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color(hex: status.color).opacity(0.2))
                    .foregroundColor(Color(hex: status.color))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}
