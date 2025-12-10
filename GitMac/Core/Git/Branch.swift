import Foundation

/// Represents a Git branch
struct Branch: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let fullName: String
    let isRemote: Bool
    let isHead: Bool
    let remoteName: String?
    let trackingBranch: String?
    let targetSHA: String
    let upstream: UpstreamInfo?

    init(
        name: String,
        fullName: String,
        isRemote: Bool = false,
        isHead: Bool = false,
        remoteName: String? = nil,
        trackingBranch: String? = nil,
        targetSHA: String,
        upstream: UpstreamInfo? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.fullName = fullName
        self.isRemote = isRemote
        self.isHead = isHead
        self.remoteName = remoteName
        self.trackingBranch = trackingBranch
        self.targetSHA = targetSHA
        self.upstream = upstream
    }

    var shortSHA: String {
        String(targetSHA.prefix(7))
    }

    var displayName: String {
        if isRemote, let remote = remoteName {
            return name.replacingOccurrences(of: "\(remote)/", with: "")
        }
        return name
    }

    var isMainBranch: Bool {
        let mainNames = ["main", "master", "develop", "development"]
        return mainNames.contains(name.lowercased())
    }

    /// Alias for isHead - whether this is the current checked out branch
    var isCurrent: Bool {
        isHead
    }

    /// Ahead/behind information (if tracking upstream)
    var aheadBehind: (ahead: Int, behind: Int)? {
        guard let upstream = upstream else { return nil }
        return (ahead: upstream.ahead, behind: upstream.behind)
    }

    static func == (lhs: Branch, rhs: Branch) -> Bool {
        lhs.fullName == rhs.fullName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(fullName)
    }
}

/// Upstream tracking information
struct UpstreamInfo: Equatable {
    let name: String
    let ahead: Int
    let behind: Int

    var hasChanges: Bool {
        ahead > 0 || behind > 0
    }

    var statusText: String {
        if ahead > 0 && behind > 0 {
            return "↑\(ahead) ↓\(behind)"
        } else if ahead > 0 {
            return "↑\(ahead)"
        } else if behind > 0 {
            return "↓\(behind)"
        }
        return "✓"
    }
}

/// Git Flow branch types
enum GitFlowBranchType: String, CaseIterable {
    case feature = "feature"
    case release = "release"
    case hotfix = "hotfix"
    case bugfix = "bugfix"
    case support = "support"

    var prefix: String {
        "\(rawValue)/"
    }

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .feature: return "blue"
        case .release: return "green"
        case .hotfix: return "red"
        case .bugfix: return "orange"
        case .support: return "purple"
        }
    }
}

/// Git Flow configuration
struct GitFlowConfig {
    var masterBranch: String = "main"
    var developBranch: String = "develop"
    var featurePrefix: String = "feature/"
    var releasePrefix: String = "release/"
    var hotfixPrefix: String = "hotfix/"
    var bugfixPrefix: String = "bugfix/"
    var supportPrefix: String = "support/"
    var versionTagPrefix: String = "v"

    var isInitialized: Bool {
        !masterBranch.isEmpty && !developBranch.isEmpty
    }
}

/// Branch comparison result
struct BranchComparison {
    let baseBranch: Branch
    let compareBranch: Branch
    let aheadBy: Int
    let behindBy: Int
    let commits: [Commit]
    let mergeBase: String?

    var canFastForward: Bool {
        behindBy == 0
    }

    var isDiverged: Bool {
        aheadBy > 0 && behindBy > 0
    }
}

/// Merge options
struct MergeOptions {
    var noFastForward: Bool = false
    var squash: Bool = false
    var commitMessage: String?
    var strategy: MergeStrategy = .recursive

    enum MergeStrategy: String, CaseIterable {
        case recursive = "recursive"
        case resolve = "resolve"
        case octopus = "octopus"
        case ours = "ours"
        case subtree = "subtree"
    }
}

/// Rebase options
struct RebaseOptions {
    var interactive: Bool = false
    var autosquash: Bool = false
    var preserveMerges: Bool = false
    var onto: String?
}

/// Interactive rebase item (commit + action)
struct GitRebaseItem: Identifiable {
    let id: UUID
    let commit: Commit
    var action: RebaseActionType

    init(commit: Commit, action: RebaseActionType = .pick) {
        self.id = UUID()
        self.commit = commit
        self.action = action
    }
}

enum RebaseActionType: String, CaseIterable {
    case pick = "pick"
    case reword = "reword"
    case edit = "edit"
    case squash = "squash"
    case fixup = "fixup"
    case drop = "drop"

    var shortcut: String {
        String(rawValue.prefix(1))
    }

    var description: String {
        switch self {
        case .pick: return "use commit"
        case .reword: return "use commit, but edit the commit message"
        case .edit: return "use commit, but stop for amending"
        case .squash: return "use commit, but meld into previous commit"
        case .fixup: return "like squash, but discard this commit's log message"
        case .drop: return "remove commit"
        }
    }
}
