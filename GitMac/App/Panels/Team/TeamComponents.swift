//
//  TeamComponents.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Supporting Views

struct TeamMemberRow: View {
    let member: TeamMember
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: member.user.avatarUrl)) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(member.user.login)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    Label("\(member.activePRs.count)", systemImage: "arrow.triangle.pull")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accent)

                    Label("\(member.filesBeingModified.count)", systemImage: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)

                    if member.filesBeingModified.contains(where: { $0.hasConflict }) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.warning)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : Color.clear)
        .clipShape(.rect(cornerRadius: 8))
        .onTapGesture { onSelect() }
    }
}

// MARK: - Models

struct TeamMember: Identifiable {
    var id: String { user.login }
    let user: GitHubUser
    var activePRs: [GitHubPullRequest]
    var filesBeingModified: [FileBeingModified]
    var recentCommits: [GitHubCommit]
    var lastActiveDate: Date?
}

struct FileBeingModified: Identifiable {
    var id: String { filename }
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let source: String?
    let hasConflict: Bool
}
