import SwiftUI

// MARK: - Ghost Branches (nearby branches overlay on hover)

/// Shows nearby branches when hovering over a commit in the graph
struct GhostBranchesOverlay: View {
    let commit: Commit
    let allBranches: [Branch]
    let repoPath: String
    @State private var nearbyBranches: [NearbyBranch] = []
    @State private var isLoading = false

    var body: some View {
        return Group {
            if !nearbyBranches.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Nearby Branches")
                        .font(DesignTokens.Typography.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textPrimary)

                    ForEach(nearbyBranches.prefix(5)) { branch in
                        NearbyBranchRow(branch: branch)
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(AppTheme.backgroundSecondary)
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
                .shadow(color: .black.opacity(0.2), radius: DesignTokens.Spacing.xs)
            }
        }
        .task {
            await findNearbyBranches()
        }
    }

    private func findNearbyBranches() async {
        isLoading = true

        var nearby: [NearbyBranch] = []

        for branch in allBranches {
            // Skip if this commit IS the branch tip
            guard branch.targetSHA != commit.sha else { continue }

            // Check distance to this branch
            if let distance = await getCommitDistance(from: commit.sha, to: branch.targetSHA) {
                if distance.ahead <= 10 || distance.behind <= 10 {
                    nearby.append(NearbyBranch(
                        name: branch.name,
                        sha: branch.targetSHA,
                        ahead: distance.ahead,
                        behind: distance.behind,
                        isCurrent: branch.isCurrent
                    ))
                }
            }
        }

        // Sort by total distance
        nearbyBranches = nearby.sorted { ($0.ahead + $0.behind) < ($1.ahead + $1.behind) }
        isLoading = false
    }

    private func getCommitDistance(from: String, to: String) async -> (ahead: Int, behind: Int)? {
        let executor = ShellExecutor.shared
        let result = await executor.execute(
            "git",
            arguments: ["rev-list", "--left-right", "--count", "\(from)...\(to)"],
            workingDirectory: repoPath
        )

        guard result.exitCode == 0 else { return nil }

        let parts = result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard parts.count == 2,
              let ahead = Int(parts[0]),
              let behind = Int(parts[1]) else { return nil }

        return (ahead, behind)
    }
}

struct NearbyBranch: Identifiable {
    let id = UUID()
    let name: String
    let sha: String
    let ahead: Int
    let behind: Int
    let isCurrent: Bool

    var distanceDescription: String {
        var parts: [String] = []
        if ahead > 0 { parts.append("\(ahead) ahead") }
        if behind > 0 { parts.append("\(behind) behind") }
        return parts.joined(separator: ", ")
    }
}

struct NearbyBranchRow: View {
    let branch: NearbyBranch

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
            // Branch icon with color
            Image(systemName: "arrow.triangle.branch")
                .font(DesignTokens.Typography.caption2)
                .foregroundStyle(branch.isCurrent ? AppTheme.success : AppTheme.accent)

            // Branch name
            Text(branch.name)
                .font(DesignTokens.Typography.caption)
                .fontWeight(branch.isCurrent ? .semibold : .regular)
                .lineLimit(1)

            Spacer()

            // Distance indicator
            HStack(spacing: DesignTokens.Spacing.xs) {
                if branch.ahead > 0 {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8)) // Graph badge font - intentionally small
                        Text("\(branch.ahead)")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundStyle(AppTheme.success)
                }

                if branch.behind > 0 {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8)) // Graph badge font - intentionally small
                        Text("\(branch.behind)")
                            .font(DesignTokens.Typography.caption2)
                    }
                    .foregroundStyle(AppTheme.warning)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
    }
}

extension View {
    /// Add ghost branches overlay on hover
    func withGhostBranches(
        commit: Commit,
        branches: [Branch],
        repoPath: String,
        isHovered: Bool
    ) -> some View {
        self.overlay(alignment: .topTrailing) {
            if isHovered {
                GhostBranchesOverlay(
                    commit: commit,
                    allBranches: branches,
                    repoPath: repoPath
                )
                .offset(x: 10, y: -10)
            }
        }
    }
}
