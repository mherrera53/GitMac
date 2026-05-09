import Foundation

@MainActor
struct PreCommitGuardResult {
    let canCommit: Bool
    let remoteAhead: Int
    let conflictingFiles: [String]
    let warning: String?
}

@MainActor
class PreCommitGuard {
    static let shared = PreCommitGuard()
    private let shell = ShellExecutor.shared

    // Keys match @AppStorage defaults in GitSettingsTab
    private static let fetchKey = "fetchBeforeCommit"
    private static let warnKey = "warnRemoteAhead"

    init() {
        // Register defaults so UserDefaults.bool(forKey:) returns true
        // before the user has ever visited Settings
        UserDefaults.standard.register(defaults: [
            Self.fetchKey: true,
            Self.warnKey: true
        ])
    }

    func runPreCommitChecks(at repoPath: String) async -> PreCommitGuardResult {
        let fetchEnabled = UserDefaults.standard.bool(forKey: Self.fetchKey)
        let warnEnabled = UserDefaults.standard.bool(forKey: Self.warnKey)

        // Step 1: Get current branch
        let branchResult = await shell.execute(
            "git",
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            workingDirectory: repoPath
        )
        let currentBranch = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentBranch.isEmpty, currentBranch != "HEAD" else {
            return PreCommitGuardResult(canCommit: true, remoteAhead: 0, conflictingFiles: [], warning: nil)
        }

        // Step 2: Fetch origin (silent, fast)
        if fetchEnabled {
            _ = await shell.execute(
                "git",
                arguments: ["fetch", "origin", currentBranch, "--quiet"],
                workingDirectory: repoPath
            )
        }

        // Step 3: Check if remote is ahead
        var remoteAhead = 0
        var conflictingFiles: [String] = []

        if warnEnabled {
            let remoteBranch = "origin/\(currentBranch)"

            // Check if remote branch exists
            let remoteCheck = await shell.execute(
                "git",
                arguments: ["rev-parse", "--verify", remoteBranch],
                workingDirectory: repoPath
            )
            guard remoteCheck.exitCode == 0 else {
                return PreCommitGuardResult(canCommit: true, remoteAhead: 0, conflictingFiles: [], warning: nil)
            }

            // Count commits remote is ahead
            let aheadResult = await shell.execute(
                "git",
                arguments: ["rev-list", "--count", "HEAD..\(remoteBranch)"],
                workingDirectory: repoPath
            )
            remoteAhead = Int(aheadResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            if remoteAhead > 0 {
                // Find files that changed on BOTH local (staged) and remote
                let stagedResult = await shell.execute(
                    "git",
                    arguments: ["diff", "--cached", "--name-only"],
                    workingDirectory: repoPath
                )
                let stagedFiles = Set(
                    stagedResult.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
                )

                let remoteChangedResult = await shell.execute(
                    "git",
                    arguments: ["diff", "--name-only", "HEAD", remoteBranch],
                    workingDirectory: repoPath
                )
                let remoteFiles = Set(
                    remoteChangedResult.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
                )

                conflictingFiles = Array(stagedFiles.intersection(remoteFiles)).sorted()
            }
        }

        // Build warning message
        var warning: String? = nil
        if remoteAhead > 0 {
            if conflictingFiles.isEmpty {
                warning = "Remote has \(remoteAhead) new commit\(remoteAhead == 1 ? "" : "s"). Consider pulling before committing."
            } else {
                let fileList = conflictingFiles.prefix(5).joined(separator: "\n")
                warning = "Remote has \(remoteAhead) new commit\(remoteAhead == 1 ? "" : "s") and \(conflictingFiles.count) file\(conflictingFiles.count == 1 ? "" : "s") may conflict:\n\(fileList)"
            }
        }

        return PreCommitGuardResult(
            canCommit: true, // always allow, just warn
            remoteAhead: remoteAhead,
            conflictingFiles: conflictingFiles,
            warning: warning
        )
    }
}
