import Foundation

/// Represents a Git worktree
struct Worktree: Identifiable, Hashable {
    let id: UUID
    let path: String
    let branch: String?
    let commitSHA: String
    let isMain: Bool        // Is this the main worktree
    let isPrunable: Bool    // Can be removed (linked worktree that no longer exists)
    let isLocked: Bool      // Is locked to prevent removal
    let isDetached: Bool    // HEAD is detached (not on a branch)

    /// Directory name of the worktree
    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// Short SHA for display
    var shortSHA: String {
        String(commitSHA.prefix(7))
    }

    init(
        id: UUID = UUID(),
        path: String,
        branch: String? = nil,
        commitSHA: String,
        isMain: Bool = false,
        isPrunable: Bool = false,
        isLocked: Bool = false,
        isDetached: Bool = false
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.commitSHA = commitSHA
        self.isMain = isMain
        self.isPrunable = isPrunable
        self.isLocked = isLocked
        self.isDetached = isDetached
    }

    /// Parse worktrees from `git worktree list --porcelain` output
    static func parseFromPorcelain(_ output: String) -> [Worktree] {
        var worktrees: [Worktree] = []
        var currentPath: String?
        var currentBranch: String?
        var currentSHA: String?
        var isMain = false
        var isPrunable = false
        var isLocked = false
        var isDetached = false

        for line in output.components(separatedBy: .newlines) {
            if line.isEmpty {
                // End of a worktree entry
                if let path = currentPath, let sha = currentSHA {
                    worktrees.append(Worktree(
                        path: path,
                        branch: currentBranch,
                        commitSHA: sha,
                        isMain: isMain,
                        isPrunable: isPrunable,
                        isLocked: isLocked,
                        isDetached: isDetached
                    ))
                }
                // Reset for next entry
                currentPath = nil
                currentBranch = nil
                currentSHA = nil
                isMain = false
                isPrunable = false
                isLocked = false
                isDetached = false
            } else if line.hasPrefix("worktree ") {
                currentPath = String(line.dropFirst("worktree ".count))
            } else if line.hasPrefix("HEAD ") {
                currentSHA = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                let fullBranch = String(line.dropFirst("branch ".count))
                // Remove refs/heads/ prefix
                currentBranch = fullBranch.replacingOccurrences(of: "refs/heads/", with: "")
            } else if line == "detached" {
                isDetached = true
            } else if line == "bare" {
                // Bare repository main worktree
                isMain = true
            } else if line == "locked" {
                isLocked = true
            } else if line == "prunable" {
                isPrunable = true
            }

            // First worktree is always the main one
            if worktrees.isEmpty && currentPath != nil && !isMain {
                isMain = true
            }
        }

        // Handle last entry if output doesn't end with newline
        if let path = currentPath, let sha = currentSHA {
            worktrees.append(Worktree(
                path: path,
                branch: currentBranch,
                commitSHA: sha,
                isMain: isMain || worktrees.isEmpty,
                isPrunable: isPrunable,
                isLocked: isLocked,
                isDetached: isDetached
            ))
        }

        return worktrees
    }
}
