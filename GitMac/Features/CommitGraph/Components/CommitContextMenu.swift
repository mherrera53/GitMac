import SwiftUI
import AppKit

// MARK: - Commit Context Menu
struct CommitContextMenu: View {
    let commits: [Commit]
    @Environment(AppState.self) var appState

    var body: some View {
        Group {
            if commits.count == 1, let commit = commits.first {
                singleCommitActions(commit: commit)
            } else if commits.count > 1 {
                multiCommitActions()
            }
        }
    }

    @ViewBuilder
    private func singleCommitActions(commit: Commit) -> some View {
        // Copy actions
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commit.sha, forType: .string)
        } label: {
            Label("Copy SHA", systemImage: "doc.on.doc")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commit.message, forType: .string)
        } label: {
            Label("Copy Message", systemImage: "text.quote")
        }

        Divider()

        // Branch/Tag actions
        Button {
            NotificationCenter.default.post(
                name: .createBranchFromCommit,
                object: commit.sha
            )
        } label: {
            Label("Create Branch Here...", systemImage: "arrow.triangle.branch")
        }

        Button {
            NotificationCenter.default.post(
                name: .createTagFromCommit,
                object: commit.sha
            )
        } label: {
            Label("Create Tag Here...", systemImage: "tag")
        }

        Button {
            NotificationCenter.default.post(
                name: .createWorktreeFromCommit,
                object: commit.sha
            )
        } label: {
            Label("Create Worktree Here...", systemImage: "folder.badge.plus")
        }

        Divider()

        // Checkout
        Button {
            Task {
                try? await appState.gitService.checkout(commit.sha)
            }
        } label: {
            Label("Checkout This Commit", systemImage: "arrow.uturn.backward")
        }

        Divider()

        // Advanced operations
        Button {
            NotificationCenter.default.post(
                name: .cherryPickCommit,
                object: commit.sha
            )
        } label: {
            Label("Cherry-pick...", systemImage: "arrow.right.doc.on.clipboard")
        }

        Button {
            NotificationCenter.default.post(
                name: .revertCommit,
                object: [commit]
            )
        } label: {
            Label("Revert Commit...", systemImage: "arrow.uturn.left")
        }

        Divider()

        // Rebase actions
        Button {
            NotificationCenter.default.post(
                name: .rebaseOntoCommit,
                object: commit.sha
            )
        } label: {
            Label("Rebase current branch onto this...", systemImage: "arrow.triangle.pull")
        }

        Button {
            NotificationCenter.default.post(
                name: .interactiveRebase,
                object: commit.sha
            )
        } label: {
            Label("Interactive Rebase...", systemImage: "list.bullet.rectangle.portrait")
        }

        Divider()

        Button {
            NotificationCenter.default.post(
                name: .diffWithHead,
                object: commit.sha
            )
        } label: {
            Label("Diff with HEAD", systemImage: "arrow.left.arrow.right")
        }

        Button {
            NotificationCenter.default.post(
                name: .compareCommit,
                object: commit
            )
        } label: {
            Label("Compare with...", systemImage: "arrow.left.arrow.right.square")
        }

        Button {
             let process = Process()
             process.launchPath = "/usr/bin/open"
             process.arguments = ["-a", "Terminal", appState.currentRepository?.path ?? "."]
             try? process.run()
        } label: {
            Label("Open in Terminal", systemImage: "terminal")
        }

        Divider()

        // Reset operations
        Menu {
            Button("Soft (keep changes staged)") {
                NotificationCenter.default.post(
                    name: .resetToCommit,
                    object: ["sha": commit.sha, "mode": "soft"]
                )
            }
            Button("Mixed (keep changes unstaged)") {
                NotificationCenter.default.post(
                    name: .resetToCommit,
                    object: ["sha": commit.sha, "mode": "mixed"]
                )
            }
            Button("Hard (discard all changes)") {
                NotificationCenter.default.post(
                    name: .resetToCommit,
                    object: ["sha": commit.sha, "mode": "hard"]
                )
            }
        } label: {
            Label("Reset to This Commit", systemImage: "clock.arrow.circlepath")
        }
    }

    @ViewBuilder
    private func multiCommitActions() -> some View {
        if commits.count == 2 {
            Button {
                NotificationCenter.default.post(
                    name: .compareCommit,
                    object: commits
                )
            } label: {
                Label("Compare These 2 Commits", systemImage: "arrow.left.arrow.right.square")
            }

            Divider()
        }

        Button {
            NotificationCenter.default.post(
                name: .revertCommit,
                object: commits
            )
        } label: {
            Label("Revert \(commits.count) Commits...", systemImage: "arrow.uturn.left")
        }

        Button {
            // Placeholder for multi cherry-pick
        } label: {
            Label("Cherry-pick \(commits.count) Commits...", systemImage: "arrow.right.doc.on.clipboard")
        }

        Divider()

        Button {
            let shas = commits.map { $0.sha }.joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(shas, forType: .string)
        } label: {
            Label("Copy \(commits.count) SHAs", systemImage: "doc.on.doc")
        }
    }
}
