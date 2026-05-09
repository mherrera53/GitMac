//
//  TeamActivityPanel.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Team Activity Panel

struct TeamActivityPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Team Activity content
            TeamActivityView()
                .frame(height: height)
        }
        .background(AppTheme.backgroundSecondary)
    }
}

/// Team activity view to prevent merge conflicts
struct TeamActivityView: View {
    nonisolated(unsafe) private static let isoFormatter = ISO8601DateFormatter()

    @Environment(AppState.self) var appState
    @StateObject private var viewModel = TeamActivityViewModel()
    @State private var selectedMember: TeamMember?
    @State private var showConflictAlert = false

    var body: some View {
        HSplitView {
            // Left: Team members list
            VStack(spacing: 0) {
                teamListHeader
                Divider()
                teamMembersList
            }
            .frame(minWidth: 280, idealWidth: 320)

            // Right: Member activity detail
            if let member = selectedMember {
                memberDetailView(member)
            } else {
                emptyStateView
            }
        }
        .task {
            if let repo = appState.currentRepository,
               let remote = repo.remotes.first(where: { $0.isGitHub }),
               let ownerRepo = remote.ownerAndRepo {
                await viewModel.loadTeamActivity(
                    owner: ownerRepo.owner,
                    repo: ownerRepo.repo,
                    localChanges: []
                )
                if let firstMember = viewModel.teamMembers.first {
                    selectedMember = firstMember
                }
            }
        }
        .alert("Potential Conflicts Detected", isPresented: $showConflictAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.conflictMessage)
        }
    }

    // MARK: - Team List Header

    private var teamListHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Team Activity")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(viewModel.teamMembers.count) active members")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            // Refresh button
            Button {
                Task { await refreshActivity() }
            } label: {
                Image(systemName: viewModel.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)

            // Conflict indicator
            if viewModel.hasConflicts {
                Button {
                    showConflictAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(viewModel.conflictCount)")
                    }
                    .foregroundStyle(AppTheme.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Team Members List

    private var teamMembersList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.teamMembers) { member in
                    TeamMemberRow(
                        member: member,
                        isSelected: selectedMember?.id == member.id,
                        onSelect: { selectedMember = member }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Member Detail View

    private func memberDetailView(_ member: TeamMember) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Member header
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: member.user.avatarUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.user.login)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 12) {
                            Label("\(member.activePRs.count) PRs", systemImage: "arrow.triangle.pull")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)

                            Label("\(member.filesBeingModified.count) files", systemImage: "doc.text")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    if let lastActive = member.lastActiveDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last active")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(formatDate(lastActive))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .padding()
                .background(AppTheme.backgroundSecondary)
                .clipShape(.rect(cornerRadius: 8))

                // Active PRs
                if !member.activePRs.isEmpty {
                    activePRsSection(member)
                }

                // Files being modified
                if !member.filesBeingModified.isEmpty {
                    filesBeingModifiedSection(member)
                }

                // Recent commits
                if !member.recentCommits.isEmpty {
                    recentCommitsSection(member)
                }
            }
            .padding()
        }
    }

    private func activePRsSection(_ member: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Pull Requests")
                .font(.headline)

            ForEach(member.activePRs, id: \.number) { pr in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.pull")
                        .foregroundStyle(AppTheme.success)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(pr.number) \(pr.title)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(pr.head.ref)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent.opacity(0.2))
                                .foregroundStyle(AppTheme.accent)
                                .clipShape(.rect(cornerRadius: 4))

                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(pr.base.ref)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.success.opacity(0.2))
                                .foregroundStyle(AppTheme.success)
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }

                    Spacer()

                    Button {
                        if let url = URL(string: pr.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(AppTheme.backgroundSecondary)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

    private func filesBeingModifiedSection(_ member: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Files Being Modified")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(member.filesBeingModified) { file in
                HStack(spacing: 8) {
                    StatusIcon(status: fileStatus(file.status))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.textPrimary)

                        if let source = file.source {
                            Text("in \(source)")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    // Conflict warning
                    if file.hasConflict {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Conflict")
                        }
                        .font(.caption2)
                        .foregroundStyle(AppTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 4))
                    }

                    HStack(spacing: 4) {
                        Text("+\(file.additions)")
                            .foregroundStyle(AppTheme.success)
                        Text("-\(file.deletions)")
                            .foregroundStyle(AppTheme.error)
                    }
                    .font(.caption2.monospacedDigit())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(file.hasConflict ? Color.orange.opacity(0.05) : AppTheme.backgroundSecondary)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

    private func recentCommitsSection(_ member: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Commits")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(member.recentCommits) { commit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.commit.message.components(separatedBy: "\n").first ?? commit.commit.message)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(AppTheme.textPrimary)

                        HStack(spacing: 8) {
                            Text(commit.sha.prefix(7))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(formatDate(commit.commit.author.date))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.textSecondary)

            Text("No Team Member Selected")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Select a team member to view their activity")
                .font(.callout)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func fileStatus(_ status: String) -> FileStatusType {
        switch status {
        case "added": return .added
        case "removed": return .deleted
        case "modified": return .modified
        case "renamed": return .renamed
        default: return .modified
        }
    }

    private func formatDate(_ dateString: String) -> String {
        guard let date = Self.isoFormatter.date(from: dateString) else { return dateString }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    private func refreshActivity() async {
        if let repo = appState.currentRepository,
           let remote = repo.remotes.first(where: { $0.isGitHub }),
           let ownerRepo = remote.ownerAndRepo {
            await viewModel.loadTeamActivity(
                owner: ownerRepo.owner,
                repo: ownerRepo.repo,
                localChanges: []
            )
        }
    }
}
