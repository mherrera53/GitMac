import Foundation

/// Represents a Git hook in the repository
struct GitHook: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let isEnabled: Bool
    let content: String?
    let path: String

    var displayName: String {
        name.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

/// All available Git hooks
enum GitHookType: String, CaseIterable {
    case applypatchMsg = "applypatch-msg"
    case preApplypatch = "pre-applypatch"
    case postApplypatch = "post-applypatch"
    case preCommit = "pre-commit"
    case premergeCommit = "pre-merge-commit"
    case prepareCommitMsg = "prepare-commit-msg"
    case commitMsg = "commit-msg"
    case postCommit = "post-commit"
    case preRebase = "pre-rebase"
    case postCheckout = "post-checkout"
    case postMerge = "post-merge"
    case prePush = "pre-push"
    case preReceive = "pre-receive"
    case update = "update"
    case procReceive = "proc-receive"
    case postReceive = "post-receive"
    case postUpdate = "post-update"
    case referenceTransaction = "reference-transaction"
    case pushToCheckout = "push-to-checkout"
    case preAutoGc = "pre-auto-gc"
    case postRewrite = "post-rewrite"
    case sendEmail = "sendemail-validate"
    case fsMonitorWatchman = "fsmonitor-watchman"
    case p4Changelist = "p4-changelist"
    case p4PrepareChangelist = "p4-prepare-changelist"
    case p4PostChangelist = "p4-post-changelist"
    case p4PreSubmit = "p4-pre-submit"
    case postIndexChange = "post-index-change"

    var description: String {
        switch self {
        case .preCommit:
            return "Invoked before a commit. Can prevent commit if exits with non-zero status."
        case .prepareCommitMsg:
            return "Called after preparing default commit message, before editor is started."
        case .commitMsg:
            return "Invoked after commit message is saved. Can be used to validate message format."
        case .postCommit:
            return "Invoked after a commit is made. Used for notifications or cleanup."
        case .preRebase:
            return "Invoked before rebase operation. Can prevent rebase if exits non-zero."
        case .postCheckout:
            return "Invoked after a checkout operation completes."
        case .postMerge:
            return "Invoked after a merge operation completes."
        case .prePush:
            return "Invoked before git push. Can prevent push if exits with non-zero status."
        case .preReceive:
            return "Invoked before receiving refs from remote. Server-side hook."
        case .update:
            return "Invoked for each ref being updated on server."
        case .postReceive:
            return "Invoked after receiving refs from remote. Server-side hook for notifications."
        case .postUpdate:
            return "Invoked after all refs have been updated on server."
        case .preAutoGc:
            return "Invoked before automatic garbage collection."
        case .postRewrite:
            return "Invoked after commit rewrites (rebase, amend, etc)."
        default:
            return "Git hook: \(rawValue)"
        }
    }

    var templateContent: String {
        switch self {
        case .preCommit:
            return """
            #!/bin/sh
            #
            # Pre-commit hook
            # Runs before each commit

            # Example: Run linter
            # npm run lint

            # Example: Run tests
            # npm test

            exit 0
            """
        case .commitMsg:
            return """
            #!/bin/sh
            #
            # Commit message hook
            # $1 = .git/COMMIT_EDITMSG

            commit_msg_file=$1
            commit_msg=$(cat "$commit_msg_file")

            # Example: Check commit message format
            # if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore):"; then
            #     echo "Error: Commit message must start with type (feat, fix, docs, etc.)"
            #     exit 1
            # fi

            exit 0
            """
        case .prePush:
            return """
            #!/bin/sh
            #
            # Pre-push hook
            # Runs before git push

            # Example: Prevent push to main/master
            # current_branch=$(git symbolic-ref HEAD | sed -e 's,.*/\\(.*\\),\\1,')
            # if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
            #     echo "Direct push to $current_branch is not allowed"
            #     exit 1
            # fi

            exit 0
            """
        case .postCommit:
            return """
            #!/bin/sh
            #
            # Post-commit hook
            # Runs after each commit

            # Example: Send notification
            # echo "Commit created: $(git log -1 --pretty=%B)"

            exit 0
            """
        default:
            return """
            #!/bin/sh
            #
            # \(rawValue) hook
            # \(description)

            # Add your hook logic here

            exit 0
            """
        }
    }
}
