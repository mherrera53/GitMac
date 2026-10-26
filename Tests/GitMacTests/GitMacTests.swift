import XCTest
@testable import GitMac

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
            sha: "abc123456789",
            message: "Test commit\n\nTest body",
            author: "Test Author",
            authorEmail: "test@example.com",
            authorDate: Date(),
            committer: "Test Author",
            committerEmail: "test@example.com",
            committerDate: Date(),
            parentSHAs: ["def456"]
        )

        XCTAssertEqual(commit.sha, "abc123456789")
        XCTAssertEqual(commit.shortSHA, "abc1234")
        XCTAssertEqual(commit.summary, "Test commit")
        XCTAssertEqual(commit.body, "Test body")
        XCTAssertEqual(commit.author, "Test Author")
        XCTAssertEqual(commit.parentSHAs.count, 1)
    }

    func testCommitIsMerge() {
        // Merge commit has 2+ parents
        let mergeCommit = Commit(
            sha: "abc123",
            message: "Merge branch",
            author: "Test",
            authorEmail: "test@example.com",
            authorDate: Date(),
            committer: "Test",
            committerEmail: "test@example.com",
            committerDate: Date(),
            parentSHAs: ["def456", "ghi789"]
        )
        XCTAssertTrue(mergeCommit.isMergeCommit)

        // Regular commit has 1 parent
        let regularCommit = Commit(
            sha: "abc123",
            message: "Regular commit",
            author: "Test",
            authorEmail: "test@example.com",
            authorDate: Date(),
            committer: "Test",
            committerEmail: "test@example.com",
            committerDate: Date(),
            parentSHAs: ["def456"]
        )
        XCTAssertFalse(regularCommit.isMergeCommit)
    }

    // MARK: - Branch Model Tests

    func testCommitRelativeDatePreservesNumericAbbreviation() {
        let reference = Date()
        let legacy = RelativeDateTimeFormatter()
        legacy.unitsStyle = .abbreviated
        for interval: TimeInterval in [-40_000_000, -400_000, -4_000, 4_000, 400_000, 40_000_000] {
            let date = reference.addingTimeInterval(interval)
            let commit = Commit(sha: "fixture", message: "Fixture", author: "Fixture",
                                authorEmail: "fixture@example.invalid", authorDate: date,
                                committer: "Fixture", committerEmail: "fixture@example.invalid",
                                committerDate: date, parentSHAs: [])
            XCTAssertEqual(commit.relativeDate, legacy.localizedString(for: date, relativeTo: reference))
        }
    }

    func testBranchInitialization() {
        let branch = Branch(
            name: "feature/test",
            fullName: "refs/heads/feature/test",
            isRemote: false,
            isHead: true,
            targetSHA: "abc123",
            upstream: UpstreamInfo(name: "origin/feature/test", ahead: 2, behind: 1)
        )

        XCTAssertEqual(branch.name, "feature/test")
        XCTAssertFalse(branch.isRemote)
        XCTAssertTrue(branch.isCurrent)
        XCTAssertEqual(branch.upstream?.name, "origin/feature/test")
        XCTAssertEqual(branch.aheadBehind?.ahead, 2)
        XCTAssertEqual(branch.aheadBehind?.behind, 1)
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
        XCTAssertEqual(status.totalChanges, 5)
    }
}
