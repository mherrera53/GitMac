import Foundation

/// Represents a Git remote
struct Remote: Identifiable, Equatable {
    let id: UUID
    let name: String
    let fetchURL: String
    let pushURL: String
    var branches: [Branch]

    init(name: String, fetchURL: String, pushURL: String? = nil, branches: [Branch] = []) {
        self.id = UUID()
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL ?? fetchURL
        self.branches = branches
    }

    var isGitHub: Bool {
        fetchURL.contains("github.com")
    }

    var isGitLab: Bool {
        fetchURL.contains("gitlab.com") || fetchURL.contains("gitlab")
    }

    var isBitbucket: Bool {
        fetchURL.contains("bitbucket.org")
    }

    var provider: RemoteProvider {
        if isGitHub { return .github }
        if isGitLab { return .gitlab }
        if isBitbucket { return .bitbucket }
        return .other
    }

    /// Extract owner/repo from URL
    var ownerAndRepo: (owner: String, repo: String)? {
        // Handle SSH URLs: git@github.com:owner/repo.git
        // Handle HTTPS URLs: https://github.com/owner/repo.git

        var urlString = fetchURL

        // Remove .git suffix
        if urlString.hasSuffix(".git") {
            urlString = String(urlString.dropLast(4))
        }

        // Handle SSH format
        if urlString.hasPrefix("git@") {
            let parts = urlString.split(separator: ":")
            if parts.count == 2 {
                let pathParts = parts[1].split(separator: "/")
                if pathParts.count >= 2 {
                    return (String(pathParts[0]), String(pathParts[1]))
                }
            }
        }

        // Handle HTTPS format
        if let url = URL(string: urlString) {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if pathComponents.count >= 2 {
                return (pathComponents[0], pathComponents[1])
            }
        }

        return nil
    }

    static func == (lhs: Remote, rhs: Remote) -> Bool {
        lhs.name == rhs.name
    }
}

enum RemoteProvider: String {
    case github = "GitHub"
    case gitlab = "GitLab"
    case bitbucket = "Bitbucket"
    case azureDevOps = "Azure DevOps"
    case other = "Git"

    var icon: String {
        switch self {
        case .github: return "github"
        case .gitlab: return "gitlab"
        case .bitbucket: return "bitbucket"
        case .azureDevOps: return "azure"
        case .other: return "git"
        }
    }
}

/// Push options
struct PushOptions {
    var force: Bool = false
    var forceWithLease: Bool = false
    var setUpstream: Bool = false
    var tags: Bool = false
    var dryRun: Bool = false
    var remote: String = "origin"
    var branch: String?

    var arguments: [String] {
        var args: [String] = []

        if forceWithLease {
            args.append("--force-with-lease")
        } else if force {
            args.append("--force")
        }

        if setUpstream {
            args.append("--set-upstream")
        }

        if tags {
            args.append("--tags")
        }

        if dryRun {
            args.append("--dry-run")
        }

        return args
    }
}

/// Pull options
struct PullOptions {
    var rebase: Bool = false
    var autostash: Bool = true
    var remote: String = "origin"
    var branch: String?

    var arguments: [String] {
        var args: [String] = []

        if rebase {
            args.append("--rebase")
        }

        if autostash {
            args.append("--autostash")
        }

        return args
    }
}

/// Fetch options
struct FetchOptions {
    var all: Bool = false
    var prune: Bool = true
    var tags: Bool = true
    var remote: String?

    var arguments: [String] {
        var args: [String] = []

        if all {
            args.append("--all")
        }

        if prune {
            args.append("--prune")
        }

        if tags {
            args.append("--tags")
        }

        return args
    }
}

/// Clone options
struct CloneOptions {
    var depth: Int? = nil // Shallow clone
    var branch: String? = nil
    var recursive: Bool = true
    var bare: Bool = false

    var arguments: [String] {
        var args: [String] = []

        if let depth = depth {
            args.append("--depth")
            args.append(String(depth))
        }

        if let branch = branch {
            args.append("--branch")
            args.append(branch)
        }

        if recursive {
            args.append("--recursive")
        }

        if bare {
            args.append("--bare")
        }

        return args
    }
}

/// Remote operation progress
struct RemoteProgress: Identifiable {
    let id: UUID
    let operation: RemoteOperationKind
    let phase: String
    let current: Int
    let total: Int
    let message: String?

    init(operation: RemoteOperationKind, phase: String, current: Int, total: Int, message: String? = nil) {
        self.id = UUID()
        self.operation = operation
        self.phase = phase
        self.current = current
        self.total = total
        self.message = message
    }

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total) * 100
    }

    var isComplete: Bool {
        current >= total
    }
}

enum RemoteOperationKind: String {
    case fetch = "Fetching"
    case pull = "Pulling"
    case push = "Pushing"
    case clone = "Cloning"
}
