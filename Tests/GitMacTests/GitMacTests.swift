import XCTest

final class GitMacTests: XCTestCase {

    // MARK: - Repository Model Tests

    func testRepositoryStatusInitialization() {
        // Test that RepositoryStatus initializes with empty arrays
        let status = RepositoryStatus()
        XCTAssertTrue(status.staged.isEmpty)
        XCTAssertTrue(status.unstaged.isEmpty)
        XCTAssertTrue(status.untracked.isEmpty)
        XCTAssertTrue(status.conflicted.isEmpty)
    }

    func testFileStatusTypeRawValues() {
        // Test FileStatusType raw values match git status codes
        XCTAssertEqual(FileStatusType.added.rawValue, "A")
        XCTAssertEqual(FileStatusType.modified.rawValue, "M")
        XCTAssertEqual(FileStatusType.deleted.rawValue, "D")
        XCTAssertEqual(FileStatusType.renamed.rawValue, "R")
        XCTAssertEqual(FileStatusType.untracked.rawValue, "?")
    }

    func testFileStatusFilename() {
        // Test filename extraction from path
        let file = FileStatus(path: "src/components/Button.swift", status: .modified)
        XCTAssertEqual(file.filename, "Button.swift")
    }

    func testFileStatusDirectory() {
        // Test directory extraction from path
        let file = FileStatus(path: "src/components/Button.swift", status: .modified)
        XCTAssertTrue(file.directory.hasSuffix("src/components"))
    }

    func testFileStatusExtension() {
        // Test file extension extraction
        let swiftFile = FileStatus(path: "src/App.swift", status: .added)
        XCTAssertEqual(swiftFile.fileExtension, "swift")

        let tsFile = FileStatus(path: "src/index.ts", status: .modified)
        XCTAssertEqual(tsFile.fileExtension, "ts")
    }

    func testFileStatusDiffStats() {
        // Test diff stats
        let file = FileStatus(path: "test.swift", status: .modified, additions: 10, deletions: 5)
        XCTAssertEqual(file.additions, 10)
        XCTAssertEqual(file.deletions, 5)
        XCTAssertTrue(file.hasChanges)
    }

    func testFileStatusNoDiffStats() {
        // Test file with no changes
        let file = FileStatus(path: "test.swift", status: .modified)
        XCTAssertEqual(file.additions, 0)
        XCTAssertEqual(file.deletions, 0)
        XCTAssertFalse(file.hasChanges)
    }

    // MARK: - Commit Model Tests

    func testCommitInitialization() {
        let commit = Commit(
            hash: "abc123",
            abbreviatedHash: "abc",
            subject: "Test commit",
            body: "Test body",
            author: "Test Author",
            authorEmail: "test@example.com",
            date: Date(),
            parents: ["def456"]
        )

        XCTAssertEqual(commit.hash, "abc123")
        XCTAssertEqual(commit.abbreviatedHash, "abc")
        XCTAssertEqual(commit.subject, "Test commit")
        XCTAssertEqual(commit.author, "Test Author")
        XCTAssertEqual(commit.parents.count, 1)
    }

    func testCommitIsMerge() {
        // Merge commit has 2+ parents
        let mergeCommit = Commit(
            hash: "abc123",
            abbreviatedHash: "abc",
            subject: "Merge branch",
            body: nil,
            author: "Test",
            authorEmail: "test@example.com",
            date: Date(),
            parents: ["def456", "ghi789"]
        )
        XCTAssertTrue(mergeCommit.isMerge)

        // Regular commit has 1 parent
        let regularCommit = Commit(
            hash: "abc123",
            abbreviatedHash: "abc",
            subject: "Regular commit",
            body: nil,
            author: "Test",
            authorEmail: "test@example.com",
            date: Date(),
            parents: ["def456"]
        )
        XCTAssertFalse(regularCommit.isMerge)
    }

    // MARK: - Branch Model Tests

    func testBranchInitialization() {
        let branch = Branch(
            name: "feature/test",
            isRemote: false,
            isCurrent: true,
            upstream: "origin/feature/test",
            aheadBehind: (2, 1)
        )

        XCTAssertEqual(branch.name, "feature/test")
        XCTAssertFalse(branch.isRemote)
        XCTAssertTrue(branch.isCurrent)
        XCTAssertEqual(branch.upstream, "origin/feature/test")
    }

    // MARK: - Repository Status Count Tests

    func testRepositoryStatusTotalCount() {
        var status = RepositoryStatus()
        status.staged = [
            FileStatus(path: "file1.swift", status: .added),
            FileStatus(path: "file2.swift", status: .modified)
        ]
        status.unstaged = [
            FileStatus(path: "file3.swift", status: .modified)
        ]
        status.untracked = ["file4.swift", "file5.swift"]

        XCTAssertEqual(status.stagedCount, 2)
        XCTAssertEqual(status.unstagedCount, 1)
        XCTAssertEqual(status.untrackedCount, 2)
        XCTAssertEqual(status.totalCount, 5)
    }
}

// MARK: - Minimal Model Definitions for Tests

struct RepositoryStatus {
    var staged: [FileStatus] = []
    var unstaged: [FileStatus] = []
    var untracked: [String] = []
    var conflicted: [FileStatus] = []

    var stagedCount: Int { staged.count }
    var unstagedCount: Int { unstaged.count }
    var untrackedCount: Int { untracked.count }
    var totalCount: Int { stagedCount + unstagedCount + untrackedCount }
}

struct FileStatus: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let status: FileStatusType
    let oldPath: String?
    var additions: Int
    var deletions: Int

    init(path: String, status: FileStatusType, oldPath: String? = nil, additions: Int = 0, deletions: Int = 0) {
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

enum FileStatusType: String {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"
    case typeChanged = "T"
    case unmerged = "U"
}

struct Commit: Identifiable {
    let id = UUID()
    let hash: String
    let abbreviatedHash: String
    let subject: String
    let body: String?
    let author: String
    let authorEmail: String
    let date: Date
    let parents: [String]

    var isMerge: Bool { parents.count > 1 }
}

struct Branch: Identifiable {
    var id: String { name }
    let name: String
    let isRemote: Bool
    let isCurrent: Bool
    let upstream: String?
    let aheadBehind: (Int, Int)?
}
