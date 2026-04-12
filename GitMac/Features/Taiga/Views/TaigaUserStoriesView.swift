//
//  TaigaUserStoriesView.swift
//  GitMac
//
//  Created on 2025-12-28.
//  User stories kanban view for Taiga integration
//

import SwiftUI

struct TaigaUserStoriesView: View {
    let stories: [TaigaUserStory]
    @ObservedObject var viewModel: TaigaTicketsViewModel

    var body: some View {
        if stories.isEmpty {
            TaigaEmptyView(type: "user stories")
        } else {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    ForEach(groupedStories.keys.sorted(), id: \.self) { statusId in
                        TaigaKanbanColumn(
                            status: viewModel.statuses.first { $0.id == statusId },
                            items: groupedStories[statusId] ?? []
                        )
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .scrollIndicators(.hidden)
        }
    }

    var groupedStories: [Int: [TaigaUserStory]] {
        Dictionary(grouping: stories) { $0.status }
    }
}

struct TaigaKanbanColumn: View {
    let status: TaigaStatus?
    let items: [TaigaUserStory]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Column header
            HStack(spacing: DesignTokens.Spacing.sm) {
                Circle()
                    .fill(SwiftUI.Color(hex: status?.color ?? "888888"))
                    .frame(width: 8, height: 8)

                Text(status?.name ?? "Unknown")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(items.count)")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(AppTheme.backgroundTertiary)
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(AppTheme.backgroundSecondary)
            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))

            // Cards
            ScrollView(.vertical) {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(items) { story in
                        TaigaStoryCard(story: story)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 280)
    }
}

struct TaigaStoryCard: View {
    let story: TaigaUserStory
    @State private var isHovered = false
    @State private var showCopied = false

    var taigaRef: String {
        "TG-\(story.ref)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // TG Reference & Subject
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Clickable TG reference badge
                Button {
                    copyToClipboard(taigaRef)
                } label: {
                    Text(taigaRef)
                        .font(DesignTokens.Typography.caption2)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                .fill(AppTheme.success)
                        )
                }
                .buttonStyle(.plain)
                .help("Click to copy \(taigaRef)")

                Text(story.subject)
                    .font(DesignTokens.Typography.callout)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
            }

            // Tags
            if let tags = story.tags, !tags.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(Array(tags.prefix(3).enumerated()), id: \.offset) { item in
                        let values = item.element.compactMap { $0 }
                        if values.count >= 2 {
                            let tagName = values[0]
                            let tagColor = values[1]
                            Text(tagName)
                                .font(DesignTokens.Typography.caption2)
                                .padding(.horizontal, DesignTokens.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(SwiftUI.Color(hex: tagColor).opacity(0.3))
                                .foregroundStyle(SwiftUI.Color(hex: tagColor))
                                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                        }
                    }
                }
            }

            // Points & Assignee & Copy button
            HStack {
                if let points = story.totalPoints {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(DesignTokens.Typography.caption2)
                        Text("\(Int(points))")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                // Insert to commit button
                Button {
                    NotificationCenter.default.post(
                        name: .insertTaigaRef,
                        object: nil,
                        userInfo: ["ref": taigaRef, "subject": story.subject]
                    )
                } label: {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert \(taigaRef) into commit message")

                if let assignee = story.assignedToExtraInfo {
                    Text(assignee.fullName.split(separator: " ").first.map(String.init) ?? assignee.username)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .cardStyle(isHovered: $isHovered, accentColor: AppTheme.success)
        .overlay(alignment: .topTrailing) {
            if showCopied {
                Text("Copied!")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(AppTheme.success)
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                    .offset(x: -DesignTokens.Spacing.xs, y: DesignTokens.Spacing.xs)
                    .transition(.opacity)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}
