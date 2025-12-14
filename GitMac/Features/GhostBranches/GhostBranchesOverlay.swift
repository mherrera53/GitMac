import SwiftUI

// MARK: - Ghost Branches Overlay

/// Shows nearby branches when hovering over a commit in the graph
struct GhostBranchesOverlay: View {
    let commit: Commit
    let allBranches: [Branch]
    let repoPath: String
    @State private var nearbyBranches: [NearbyBranch] = []
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if !nearbyBranches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nearby Branches")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(nearbyBranches.prefix(5)) { branch in
                        NearbyBranchRow(branch: branch)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.2), radius: 4)
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
            guard branch.sha != commit.sha else { continue }
            
            // Check distance to this branch
            if let distance = await getCommitDistance(from: commit.sha, to: branch.sha) {
                if distance.ahead <= 10 || distance.behind <= 10 {
                    nearby.append(NearbyBranch(
                        name: branch.name,
                        sha: branch.sha,
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
        guard let result = try? await ShellExecutor.shared.execute(
            "cd '\(repoPath)' && git rev-list --left-right --count \(from)...\(to) 2>/dev/null"
        ) else { return nil }
        
        let parts = result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard parts.count == 2,
              let ahead = Int(parts[0]),
              let behind = Int(parts[1]) else { return nil }
        
        return (ahead, behind)
    }
}

// MARK: - Nearby Branch Model

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

// MARK: - Nearby Branch Row

struct NearbyBranchRow: View {
    let branch: NearbyBranch
    
    var body: some View {
        HStack(spacing: 6) {
            // Branch icon with color
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10))
                .foregroundColor(branch.isCurrent ? .green : .blue)
            
            // Branch name
            Text(branch.name)
                .font(.system(size: 11, weight: branch.isCurrent ? .semibold : .regular))
                .lineLimit(1)
            
            Spacer()
            
            // Distance indicator
            HStack(spacing: 4) {
                if branch.ahead > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8))
                        Text("\(branch.ahead)")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.green)
                }
                
                if branch.behind > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8))
                        Text("\(branch.behind)")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Ghost Branch Indicator

/// Small indicator shown inline in commit graph
struct GhostBranchIndicator: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 2) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 8))
                Text("\(count)")
                    .font(.system(size: 9))
            }
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(3)
        }
    }
}

// MARK: - Extension for CommitGraphView integration

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
