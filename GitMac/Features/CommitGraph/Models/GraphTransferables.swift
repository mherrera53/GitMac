import SwiftUI
import UniformTypeIdentifiers

// MARK: - Commit Transferable (for drag & drop)

/// Transferable representation of a commit for drag & drop operations
struct CommitTransferable: Transferable, Codable {
    let sha: String
    let message: String
    let author: String
    let branchName: String?

    init(commit: Commit, branchName: String? = nil) {
        self.sha = commit.sha
        self.message = commit.message
        self.author = commit.author
        self.branchName = branchName
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .commitData)
    }
}

extension UTType {
    static let commitData = UTType(exportedAs: "com.gitmac.commit")
    static let branchData = UTType(exportedAs: "com.gitmac.branch")
}

/// Transferable representation of a branch for drag & drop PR creation
struct BranchTransferable: Transferable, Codable {
    let name: String
    let isHead: Bool
    let targetSHA: String?

    init(name: String, isHead: Bool = false, targetSHA: String? = nil) {
        self.name = name
        self.isHead = isHead
        self.targetSHA = targetSHA
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .branchData)
    }
}
