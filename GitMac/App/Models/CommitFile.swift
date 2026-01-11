import SwiftUI

// MARK: - Commit File Model
struct CommitFile: Identifiable {
    let id = UUID()
    let path: String
    let status: CommitFileStatus
    let additions: Int
    let deletions: Int

    enum CommitFileStatus {
        case added, modified, deleted, renamed, copied

        @MainActor
        var color: Color {
            switch self {
            case .added: return AppTheme.success
            case .modified: return AppTheme.warning
            case .deleted: return AppTheme.error
            case .renamed: return AppTheme.accent
            case .copied: return AppTheme.accent
            }
        }

        var icon: String {
            switch self {
            case .added: return "plus"
            case .modified: return "pencil"
            case .deleted: return "minus"
            case .renamed: return "arrow.right"
            case .copied: return "doc.on.doc"
            }
        }
    }
}
