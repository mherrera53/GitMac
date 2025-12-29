import Foundation

/// Represents a Git commit
struct Commit: Identifiable, Equatable, Hashable {
    let id: UUID
    let sha: String
    let shortSHA: String
    let message: String
    let summary: String // First line of message
    let body: String? // Rest of message
    let author: String
    let authorEmail: String
    let authorDate: Date
    let committer: String
    let committerEmail: String
    let committerDate: Date
    let parentSHAs: [String]

    // Graph visualization properties
    var column: Int = 0
    var row: Int = 0
    var branchColor: Int = 0

    // Relationships (populated separately)
    var branches: [Branch] = []
    var tags: [Tag] = []
    var isHead: Bool = false
    var isStash: Bool = false

    init(
        sha: String,
        message: String,
        author: String,
        authorEmail: String,
        authorDate: Date,
        committer: String,
        committerEmail: String,
        committerDate: Date,
        parentSHAs: [String]
    ) {
        self.id = UUID()
        self.sha = sha
        self.shortSHA = String(sha.prefix(7))
        self.message = message

        // Split message into summary and body
        let lines = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        self.summary = String(lines.first ?? "")
        self.body = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : nil

        self.author = author
        self.authorEmail = authorEmail
        self.authorDate = authorDate
        self.committer = committer
        self.committerEmail = committerEmail
        self.committerDate = committerDate
        self.parentSHAs = parentSHAs
    }

    var date: Date { authorDate }

    var isMergeCommit: Bool {
        parentSHAs.count > 1
    }

    var isInitialCommit: Bool {
        parentSHAs.isEmpty
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: authorDate, relativeTo: Date())
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: authorDate)
    }

    var gravatarURL: URL? {
        let email = authorEmail.lowercased().trimmingCharacters(in: .whitespaces)
        guard let data = email.data(using: .utf8) else { return nil }
        let hash = data.md5Hash
        return URL(string: "https://www.gravatar.com/avatar/\(hash)?d=identicon&s=80")
    }

    static func == (lhs: Commit, rhs: Commit) -> Bool {
        lhs.sha == rhs.sha
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sha)
    }
}

/// Commit signature information
struct CommitSignature {
    let name: String
    let email: String
    let date: Date
    let timezone: TimeZone
}

/// Commit diff information
struct CommitDiff {
    let commit: Commit
    let files: [FileDiff]
    let stats: DiffStats

    var totalAdditions: Int { stats.additions }
    var totalDeletions: Int { stats.deletions }
    var filesChanged: Int { files.count }
}

struct DiffStats {
    let additions: Int
    let deletions: Int
    let filesChanged: Int
}

struct FileDiff: Identifiable {
    let id: UUID
    let oldPath: String?
    let newPath: String
    let status: FileStatusType
    let hunks: [DiffHunk]
    let isBinary: Bool
    let additions: Int
    let deletions: Int

    init(
        oldPath: String?,
        newPath: String,
        status: FileStatusType,
        hunks: [DiffHunk] = [],
        isBinary: Bool = false,
        additions: Int = 0,
        deletions: Int = 0
    ) {
        self.id = UUID()
        self.oldPath = oldPath
        self.newPath = newPath
        self.status = status
        self.hunks = hunks
        self.isBinary = isBinary
        self.additions = additions
        self.deletions = deletions
    }

    var displayPath: String {
        newPath
    }

    var filename: String {
        URL(fileURLWithPath: newPath).lastPathComponent
    }
}

struct DiffHunk: Identifiable {
    let id: UUID
    let header: String
    let oldStart: Int
    let oldLines: Int
    let newStart: Int
    let newLines: Int
    let lines: [DiffLine]
    
    // Large File Mode: byte offsets in the original diff output
    let byteOffsets: (start: Int, end: Int)?
    
    // Estimated line count (for hunks not yet materialized)
    var estimatedLineCount: Int {
        byteOffsets != nil ? oldLines + newLines : lines.count
    }
    
    // UI state: whether this hunk is collapsed
    var isCollapsed: Bool = false
    
    // Statistics
    var additions: Int {
        lines.filter { $0.type == .addition }.count
    }
    
    var deletions: Int {
        lines.filter { $0.type == .deletion }.count
    }

    init(
        header: String,
        oldStart: Int,
        oldLines: Int,
        newStart: Int,
        newLines: Int,
        lines: [DiffLine],
        byteOffsets: (start: Int, end: Int)? = nil
    ) {
        self.id = UUID()
        self.header = header
        self.oldStart = oldStart
        self.oldLines = oldLines
        self.newStart = newStart
        self.newLines = newLines
        self.lines = lines
        self.byteOffsets = byteOffsets
    }
}

struct DiffLine: Identifiable {
    let id: UUID
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
    
    // Large File Mode: byte offsets in the original diff output (if not materialized)
    let byteOffset: (start: Int, end: Int)?
    
    // Optional: intraline change ranges (for word-level diff)
    let intralineRanges: [NSRange]?
    
    var isMaterialized: Bool {
        byteOffset == nil
    }

    init(
        type: DiffLineType,
        content: String,
        oldLineNumber: Int?,
        newLineNumber: Int?,
        byteOffset: (start: Int, end: Int)? = nil,
        intralineRanges: [NSRange]? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.byteOffset = byteOffset
        self.intralineRanges = intralineRanges
    }
}

enum DiffLineType {
    case context
    case addition
    case deletion
    case hunkHeader
}

// MARK: - MD5 Hash Extension
import CryptoKit

extension Data {
    var md5Hash: String {
        // Use CryptoKit's Insecure.MD5 for Gravatar compatibility
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
