//
//  TeamActivityViewModel.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - View Model

@MainActor
class TeamActivityViewModel: ObservableObject {
    @Published var teamMembers: [TeamMember] = []
    @Published var isLoading = false
    @Published var hasConflicts = false
    @Published var conflictCount = 0
    @Published var conflictMessage = ""

    private let githubService = GitHubService()

    func loadTeamActivity(owner: String, repo: String, localChanges: [StagingFile]) async {
        isLoading = true

        do {
            // Get all open PRs
            let openPRs = try await githubService.listPullRequests(
                owner: owner,
                repo: repo,
                state: .open
            )

            // Group PRs by author
            var memberDict: [String: TeamMember] = [:]
            let localFilePaths = Set(localChanges.map { $0.path })

            for pr in openPRs {
                let userId = pr.user.login

                // Get files for this PR
                let prFiles = try await githubService.getPullRequestFiles(
                    owner: owner,
                    repo: repo,
                    number: pr.number
                )

                // Convert to FileBeingModified with conflict detection
                let filesBeingModified = prFiles.map { file in
                    FileBeingModified(
                        filename: file.filename,
                        status: file.status,
                        additions: file.additions,
                        deletions: file.deletions,
                        source: "PR #\(pr.number)",
                        hasConflict: localFilePaths.contains(file.filename)
                    )
                }

                // Get recent commits for the PR branch
                let recentCommits = try await githubService.getCommitsForBranch(
                    owner: owner,
                    repo: repo,
                    branch: pr.head.ref,
                    since: Calendar.current.date(byAdding: .day, value: -7, to: Date())
                )

                if var member = memberDict[userId] {
                    member.activePRs.append(pr)
                    member.filesBeingModified.append(contentsOf: filesBeingModified)
                    member.recentCommits.append(contentsOf: recentCommits)

                    // Update last active date
                    if let prUpdated = ISO8601DateFormatter().date(from: pr.updatedAt),
                       let currentLast = member.lastActiveDate {
                        member.lastActiveDate = max(currentLast, prUpdated)
                    } else if let prUpdated = ISO8601DateFormatter().date(from: pr.updatedAt) {
                        member.lastActiveDate = prUpdated
                    }

                    memberDict[userId] = member
                } else {
                    let lastActiveDate = ISO8601DateFormatter().date(from: pr.updatedAt)
                    memberDict[userId] = TeamMember(
                        user: pr.user,
                        activePRs: [pr],
                        filesBeingModified: filesBeingModified,
                        recentCommits: recentCommits,
                        lastActiveDate: lastActiveDate
                    )
                }
            }

            teamMembers = Array(memberDict.values).sorted { a, b in
                (a.lastActiveDate ?? .distantPast) > (b.lastActiveDate ?? .distantPast)
            }

            // Calculate conflicts
            let allConflicts = teamMembers.flatMap { $0.filesBeingModified }.filter { $0.hasConflict }
            conflictCount = allConflicts.count
            hasConflicts = conflictCount > 0

            if hasConflicts {
                let uniqueFiles = Set(allConflicts.map { $0.filename })
                conflictMessage = """
                You have local changes to \(uniqueFiles.count) file(s) that are also being modified by your team:

                \(uniqueFiles.sorted().prefix(5).joined(separator: "\n"))
                \(uniqueFiles.count > 5 ? "\n...and \(uniqueFiles.count - 5) more" : "")
                """
            }
        } catch {
            print("Failed to load team activity: \(error)")
        }

        isLoading = false
    }
}
