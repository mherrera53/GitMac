import SwiftUI

// MARK: - Staging File Status
enum StagingFileStatus {
    case added, modified, deleted, renamed, untracked, conflicted

    @MainActor
    var color: Color {
        switch self {
        case .added: return AppTheme.success
        case .modified: return AppTheme.warning
        case .deleted: return AppTheme.error
        case .renamed: return AppTheme.accent
        case .untracked: return AppTheme.textMuted
        case .conflicted: return AppTheme.error
        }
    }

    var icon: String {
        switch self {
        case .added: return "plus"
        case .modified: return "pencil"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        case .untracked: return "questionmark"
        case .conflicted: return "exclamationmark.triangle"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .added: return "added"
        case .modified: return "modified"
        case .deleted: return "deleted"
        case .renamed: return "renamed"
        case .untracked: return "untracked"
        case .conflicted: return "conflicted"
        }
    }
}

// MARK: - Staging File Model
struct StagingFile: Identifiable, Hashable {
    // Use path as stable identity to preserve scroll position across reloads
    var id: String { path }
    let path: String
    let status: StagingFileStatus
    var isStaged: Bool = false
    var additions: Int = 0
    var deletions: Int = 0

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: StagingFile, rhs: StagingFile) -> Bool {
        lhs.path == rhs.path && lhs.status == rhs.status && lhs.isStaged == rhs.isStaged
    }

    var hasChanges: Bool {
        additions > 0 || deletions > 0
    }

    init(path: String, status: StagingFileStatus, isStaged: Bool = false, additions: Int = 0, deletions: Int = 0) {
        self.path = path
        self.status = status
        self.isStaged = isStaged
        self.additions = additions
        self.deletions = deletions
    }

    init(from fileStatus: FileStatus, staged: Bool = false) {
        self.path = fileStatus.path
        self.isStaged = staged
        self.additions = fileStatus.additions
        self.deletions = fileStatus.deletions
        switch fileStatus.status {
        case .added: self.status = .added
        case .modified: self.status = .modified
        case .deleted: self.status = .deleted
        case .renamed: self.status = .renamed
        default: self.status = .modified
        }
    }
}
