import Foundation

// MARK: - File Change Model
struct FileChange: Identifiable {
    let id = UUID()
    let path: String
    let status: FileStatus

    enum FileStatus {
        case added, modified, deleted, renamed, untracked
    }
}
