import Foundation

/// Represents a Git repository
struct Repository: Identifiable, Equatable {
    let id: UUID
    let path: String
    let name: String

    var workingDirectory: URL {
        URL(fileURLWithPath: path)
    }

    var gitDirectory: URL {
        workingDirectory.appendingPathComponent(".git")
    }

    // Current state
    var head: Reference?
    var branches: [Branch] = []
    var remoteBranches: [Branch] = []
    var tags: [Tag] = []
    var remotes: [Remote] = []
    var stashes: [Stash] = []
    var submodules: [Submodule] = []

    // Working directory state
    var status: RepositoryStatus = RepositoryStatus()

    init(path: String) {
        self.id = UUID()
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent
    }

    init(id: UUID = UUID(), path: String, name: String) {
        self.id = id
        self.path = path
        self.name = name
    }

    /// The currently checked out branch
    var currentBranch: Branch? {
        branches.first { $0.isHead }
    }

    /// All commits (loaded on demand)
    var commits: [Commit] = []

    static func == (lhs: Repository, rhs: Repository) -> Bool {
        lhs.path == rhs.path
    }
}

/// Repository status (working directory state)
struct RepositoryStatus: Equatable {
    var staged: [FileStatus] = []
    var unstaged: [FileStatus] = []
    var untracked: [String] = []
    var conflicted: [FileStatus] = []

    var hasChanges: Bool {
        !staged.isEmpty || !unstaged.isEmpty || !untracked.isEmpty
    }

    var isDirty: Bool {
        hasChanges
    }

    var hasConflicts: Bool {
        !conflicted.isEmpty
    }

    var stagedCount: Int { staged.count }
    var unstagedCount: Int { unstaged.count }
    var untrackedCount: Int { untracked.count }

    var totalChanges: Int {
        stagedCount + unstagedCount + untrackedCount
    }
}

/// File status in the working directory
struct FileStatus: Identifiable, Equatable {
    let id: UUID
    let path: String
    let status: FileStatusType
    let oldPath: String? // For renamed files
    var additions: Int = 0
    var deletions: Int = 0

    init(path: String, status: FileStatusType, oldPath: String? = nil, additions: Int = 0, deletions: Int = 0) {
        self.id = UUID()
        self.path = path
        self.status = status
        self.oldPath = oldPath
        self.additions = additions
        self.deletions = deletions
    }

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    var fileExtension: String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }

    var hasChanges: Bool {
        additions > 0 || deletions > 0
    }
}

/// Type of file status
enum FileStatusType: String, CaseIterable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"
    case typeChanged = "T"
    case unmerged = "U"

    var displayName: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        case .typeChanged: return "Type Changed"
        case .unmerged: return "Unmerged"
        }
    }

    var color: String {
        switch self {
        case .added: return "green"
        case .modified: return "orange"
        case .deleted: return "red"
        case .renamed: return "blue"
        case .copied: return "blue"
        case .untracked: return "gray"
        case .ignored: return "gray"
        case .typeChanged: return "purple"
        case .unmerged: return "red"
        }
    }
}

/// Git reference (branch, tag, etc.)
struct Reference: Identifiable, Equatable {
    let id: UUID
    let name: String
    let fullName: String
    let type: ReferenceType
    let targetSHA: String

    init(name: String, fullName: String, type: ReferenceType, targetSHA: String) {
        self.id = UUID()
        self.name = name
        self.fullName = fullName
        self.type = type
        self.targetSHA = targetSHA
    }
}

enum ReferenceType {
    case branch
    case remoteBranch
    case tag
    case head
    case stash
}

/// Git submodule
struct Submodule: Identifiable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let url: String
    let headSHA: String?

    init(name: String, path: String, url: String, headSHA: String? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.url = url
        self.headSHA = headSHA
    }
}

/// Clone progress
struct CloneProgress {
    let phase: ClonePhase
    let current: Int
    let total: Int
    let message: String?

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

enum ClonePhase {
    case counting
    case compressing
    case receiving
    case resolving
    case checkingOut
    case done
}
