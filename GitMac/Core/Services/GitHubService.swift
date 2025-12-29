import Foundation
import os.signpost

private let githubLog = OSLog(subsystem: "com.gitmac", category: "github")

/// GitHub API service with caching, ETag support, and rate limit handling
actor GitHubService {
    private let baseURL = "https://api.github.com"
    private let keychainManager = KeychainManager.shared

    // Configured URLSession with caching (20MB RAM, 200MB disk)
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default

        // Configure cache
        let cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB RAM
            diskCapacity: 200 * 1024 * 1024,    // 200 MB disk
            diskPath: "com.gitmac.github-cache"
        )
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy

        // Reasonable timeouts
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300

        return URLSession(configuration: config)
    }()

    // Reusable JSON decoder
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // ETag cache for conditional requests
    private var etagCache: [String: String] = [:]

    // Rate limit tracking
    private var rateLimitRemaining: Int = 5000
    private var rateLimitReset: Date?

    private var token: String? {
        get async {
            try? await keychainManager.getGitHubToken()
        }
    }

    // MARK: - Authentication

    /// Check if authenticated
    var isAuthenticated: Bool {
        get async {
            await token != nil
        }
    }

    /// Set authentication token
    func setToken(_ token: String, username: String? = nil) async throws {
        try await keychainManager.saveGitHubToken(token, username: username)
    }

    /// Remove authentication
    func logout() async throws {
        try await keychainManager.deleteGitHubCredentials()
    }

    /// Get authenticated user
    func getCurrentUser() async throws -> GitHubUser {
        let data = try await request(endpoint: "/user")
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    // MARK: - Repositories

    /// List user repositories
    func listRepositories(page: Int = 1, perPage: Int = 30) async throws -> [GitHubRepository] {
        let data = try await request(endpoint: "/user/repos?page=\(page)&per_page=\(perPage)&sort=updated")
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
    }

    /// Get repository details
    func getRepository(owner: String, repo: String) async throws -> GitHubRepository {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)")
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }

    /// Fork a repository
    func forkRepository(owner: String, repo: String) async throws -> GitHubRepository {
        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/forks",
            method: "POST"
        )
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }

    // MARK: - Pull Requests

    /// List pull requests
    func listPullRequests(
        owner: String,
        repo: String,
        state: PRState = .open,
        page: Int = 1
    ) async throws -> [GitHubPullRequest] {
        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls?state=\(state.rawValue)&page=\(page)"
        )
        return try JSONDecoder().decode([GitHubPullRequest].self, from: data)
    }

    /// Get a pull request
    func getPullRequest(owner: String, repo: String, number: Int) async throws -> GitHubPullRequest {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)")
        return try JSONDecoder().decode(GitHubPullRequest.self, from: data)
    }

    /// Create a pull request
    func createPullRequest(
        owner: String,
        repo: String,
        title: String,
        body: String?,
        head: String,
        base: String,
        draft: Bool = false
    ) async throws -> GitHubPullRequest {
        let payload: [String: Any] = [
            "title": title,
            "body": body ?? "",
            "head": head,
            "base": base,
            "draft": draft
        ]

        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls",
            method: "POST",
            body: payload
        )
        return try JSONDecoder().decode(GitHubPullRequest.self, from: data)
    }

    /// Update a pull request
    func updatePullRequest(
        owner: String,
        repo: String,
        number: Int,
        title: String? = nil,
        body: String? = nil,
        state: PRState? = nil
    ) async throws -> GitHubPullRequest {
        var payload: [String: Any] = [:]
        if let title = title { payload["title"] = title }
        if let body = body { payload["body"] = body }
        if let state = state { payload["state"] = state.rawValue }

        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)",
            method: "PATCH",
            body: payload
        )
        return try JSONDecoder().decode(GitHubPullRequest.self, from: data)
    }

    /// Merge a pull request
    func mergePullRequest(
        owner: String,
        repo: String,
        number: Int,
        commitTitle: String? = nil,
        commitMessage: String? = nil,
        mergeMethod: MergeMethod = .merge
    ) async throws {
        var payload: [String: Any] = [
            "merge_method": mergeMethod.rawValue
        ]
        if let title = commitTitle { payload["commit_title"] = title }
        if let message = commitMessage { payload["commit_message"] = message }

        _ = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/merge",
            method: "PUT",
            body: payload
        )
    }

    /// Close a pull request
    func closePullRequest(
        owner: String,
        repo: String,
        number: Int
    ) async throws {
        let payload: [String: Any] = ["state": "closed"]

        _ = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)",
            method: "PATCH",
            body: payload
        )
    }

    /// Get PR reviews
    func getPullRequestReviews(owner: String, repo: String, number: Int) async throws -> [GitHubReview] {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/reviews")
        return try JSONDecoder().decode([GitHubReview].self, from: data)
    }

    /// Get PR files
    func getPullRequestFiles(owner: String, repo: String, number: Int) async throws -> [GitHubPRFile] {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/files")
        return try JSONDecoder().decode([GitHubPRFile].self, from: data)
    }

    // MARK: - Issues

    /// List issues
    func listIssues(
        owner: String,
        repo: String,
        state: IssueState = .open,
        page: Int = 1
    ) async throws -> [GitHubIssue] {
        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/issues?state=\(state.rawValue)&page=\(page)"
        )
        return try JSONDecoder().decode([GitHubIssue].self, from: data)
    }

    /// Get an issue
    func getIssue(owner: String, repo: String, number: Int) async throws -> GitHubIssue {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/issues/\(number)")
        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    /// Create an issue
    func createIssue(
        owner: String,
        repo: String,
        title: String,
        body: String?,
        labels: [String]? = nil,
        assignees: [String]? = nil
    ) async throws -> GitHubIssue {
        var payload: [String: Any] = ["title": title]
        if let body = body { payload["body"] = body }
        if let labels = labels { payload["labels"] = labels }
        if let assignees = assignees { payload["assignees"] = assignees }

        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/issues",
            method: "POST",
            body: payload
        )
        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    // MARK: - GitHub Actions

    /// List workflow runs
    func listWorkflowRuns(owner: String, repo: String, branch: String? = nil) async throws -> GitHubWorkflowRuns {
        var endpoint = "/repos/\(owner)/\(repo)/actions/runs"
        if let branch = branch {
            endpoint += "?branch=\(branch)"
        }
        let data = try await request(endpoint: endpoint)
        return try JSONDecoder().decode(GitHubWorkflowRuns.self, from: data)
    }

    /// Get check runs for a ref
    func getCheckRuns(owner: String, repo: String, ref: String) async throws -> GitHubCheckRuns {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/commits/\(ref)/check-runs")
        return try JSONDecoder().decode(GitHubCheckRuns.self, from: data)
    }

    // MARK: - Collaborators & Labels

    /// Get repository collaborators
    func getCollaborators(owner: String, repo: String) async throws -> [GitHubUser] {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/collaborators")
        return try JSONDecoder().decode([GitHubUser].self, from: data)
    }

    /// Get repository labels
    func getLabels(owner: String, repo: String) async throws -> [GitHubLabel] {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/labels")
        return try JSONDecoder().decode([GitHubLabel].self, from: data)
    }

    /// Request reviewers for a PR
    func requestReviewers(
        owner: String,
        repo: String,
        number: Int,
        reviewers: [String]
    ) async throws {
        let payload: [String: Any] = ["reviewers": reviewers]
        _ = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/requested_reviewers",
            method: "POST",
            body: payload
        )
    }

    /// Add assignees to a PR
    func addAssignees(
        owner: String,
        repo: String,
        number: Int,
        assignees: [String]
    ) async throws {
        let payload: [String: Any] = ["assignees": assignees]
        _ = try await request(
            endpoint: "/repos/\(owner)/\(repo)/issues/\(number)/assignees",
            method: "POST",
            body: payload
        )
    }

    /// Add labels to a PR
    func addLabels(
        owner: String,
        repo: String,
        number: Int,
        labels: [String]
    ) async throws {
        let payload: [String: Any] = ["labels": labels]
        _ = try await request(
            endpoint: "/repos/\(owner)/\(repo)/issues/\(number)/labels",
            method: "POST",
            body: payload
        )
    }

    /// Get PR comments
    func getPullRequestComments(owner: String, repo: String, number: Int) async throws -> [GitHubComment] {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/issues/\(number)/comments")
        return try JSONDecoder().decode([GitHubComment].self, from: data)
    }

    /// Add comment to PR
    func addPullRequestComment(
        owner: String,
        repo: String,
        number: Int,
        body: String
    ) async throws -> GitHubComment {
        let payload: [String: Any] = ["body": body]
        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/issues/\(number)/comments",
            method: "POST",
            body: payload
        )
        return try JSONDecoder().decode(GitHubComment.self, from: data)
    }

    /// Get PR review comments (inline comments)
    func getPullRequestReviewComments(owner: String, repo: String, number: Int) async throws -> [GitHubReviewComment] {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/comments")
        return try JSONDecoder().decode([GitHubReviewComment].self, from: data)
    }

    /// Add inline review comment to specific line
    func addReviewComment(
        owner: String,
        repo: String,
        number: Int,
        body: String,
        commitId: String,
        path: String,
        line: Int
    ) async throws -> GitHubReviewComment {
        let payload: [String: Any] = [
            "body": body,
            "commit_id": commitId,
            "path": path,
            "line": line
        ]
        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/comments",
            method: "POST",
            body: payload
        )
        return try JSONDecoder().decode(GitHubReviewComment.self, from: data)
    }

    /// Create a PR review with comments
    func createReview(
        owner: String,
        repo: String,
        number: Int,
        commitId: String,
        body: String?,
        event: ReviewEvent,
        comments: [ReviewCommentInput]? = nil
    ) async throws -> GitHubReview {
        var payload: [String: Any] = [
            "commit_id": commitId,
            "event": event.rawValue
        ]
        if let body = body {
            payload["body"] = body
        }
        if let comments = comments {
            payload["comments"] = comments.map { comment in
                return [
                    "path": comment.path,
                    "line": comment.line,
                    "body": comment.body
                ] as [String: Any]
            }
        }

        let data = try await request(
            endpoint: "/repos/\(owner)/\(repo)/pulls/\(number)/reviews",
            method: "POST",
            body: payload
        )
        return try JSONDecoder().decode(GitHubReview.self, from: data)
    }

    // MARK: - Team Activity

    /// Get recent commits from all branches
    func listBranches(owner: String, repo: String) async throws -> [GitHubBranch] {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/branches")
        return try JSONDecoder().decode([GitHubBranch].self, from: data)
    }

    /// Get commits for a specific branch
    func getCommitsForBranch(owner: String, repo: String, branch: String, since: Date? = nil) async throws -> [GitHubCommit] {
        var endpoint = "/repos/\(owner)/\(repo)/commits?sha=\(branch)"
        if let since = since {
            let formatter = ISO8601DateFormatter()
            endpoint += "&since=\(formatter.string(from: since))"
        }
        let data = try await request(endpoint: endpoint)
        return try JSONDecoder().decode([GitHubCommit].self, from: data)
    }

    /// Get files changed in a commit
    func getCommitFiles(owner: String, repo: String, sha: String) async throws -> GitHubCommitDetail {
        let data = try await request(endpoint: "/repos/\(owner)/\(repo)/commits/\(sha)")
        return try JSONDecoder().decode(GitHubCommitDetail.self, from: data)
    }

    // MARK: - Private Helpers

    private func request(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Data {
        let signpostID = OSSignpostID(log: githubLog)
        os_signpost(.begin, log: githubLog, name: "github.request", signpostID: signpostID,
                    "%{public}s %{public}s", method, endpoint)
        defer { os_signpost(.end, log: githubLog, name: "github.request", signpostID: signpostID) }

        guard let url = URL(string: baseURL + endpoint) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let token = await token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add ETag for conditional GET requests
        if method == "GET", let etag = etagCache[endpoint] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        // Update rate limit tracking
        updateRateLimitInfo(from: httpResponse)

        // Store ETag for future conditional requests
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            etagCache[endpoint] = etag
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 304:
            // Not Modified - return cached data if available
            if let cachedResponse = session.configuration.urlCache?.cachedResponse(for: request) {
                return cachedResponse.data
            }
            // If no cached data, this is unexpected - throw error
            throw GitHubError.invalidResponse

        case 401:
            throw GitHubError.unauthorized

        case 403:
            // Check if this is a rate limit error
            if rateLimitRemaining == 0 {
                throw GitHubError.rateLimited(resetTime: rateLimitReset)
            }
            throw GitHubError.forbidden

        case 404:
            throw GitHubError.notFound

        case 422:
            throw GitHubError.validationFailed(parseError(data))

        case 429:
            // Too Many Requests
            throw GitHubError.rateLimited(resetTime: rateLimitReset)

        default:
            throw GitHubError.requestFailed(httpResponse.statusCode, parseError(data))
        }
    }

    private func updateRateLimitInfo(from response: HTTPURLResponse) {
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remainingInt = Int(remaining) {
            rateLimitRemaining = remainingInt
        }

        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let resetTimestamp = TimeInterval(reset) {
            rateLimitReset = Date(timeIntervalSince1970: resetTimestamp)
        }
    }

    private func parseError(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    // MARK: - Rate Limit Info

    /// Get current rate limit status
    var rateLimitStatus: (remaining: Int, resetTime: Date?) {
        (rateLimitRemaining, rateLimitReset)
    }

    /// Check if we should wait before making requests
    var shouldThrottle: Bool {
        rateLimitRemaining < 10 && rateLimitReset != nil && rateLimitReset! > Date()
    }

    /// Clear ETag cache (useful when data might have changed externally)
    func clearETagCache() {
        etagCache.removeAll()
    }
}

// MARK: - Models

struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let email: String?
    let avatarUrl: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, login, name, email
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

struct GitHubRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let cloneUrl: String
    let sshUrl: String
    let defaultBranch: String
    let isPrivate: Bool
    let isFork: Bool
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let owner: GitHubUser

    enum CodingKeys: String, CodingKey {
        case id, name, description, owner
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
        case sshUrl = "ssh_url"
        case defaultBranch = "default_branch"
        case isPrivate = "private"
        case isFork = "fork"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
    }
}

struct GitHubPullRequest: Codable, Identifiable, Hashable {
    static func == (lhs: GitHubPullRequest, rhs: GitHubPullRequest) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let htmlUrl: String
    let user: GitHubUser
    let head: GitHubBranchRef
    let base: GitHubBranchRef
    let createdAt: String
    let updatedAt: String
    let mergeable: Bool?
    let draft: Bool
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, head, base, mergeable, draft, additions, deletions
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case changedFiles = "changed_files"
    }
}

struct GitHubBranchRef: Codable {
    let ref: String
    let sha: String
    let repo: GitHubRepository?
}

struct GitHubIssue: Codable, Identifiable, Hashable {
    static func == (lhs: GitHubIssue, rhs: GitHubIssue) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let htmlUrl: String
    let user: GitHubUser
    let labels: [GitHubLabel]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubLabel: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}

struct GitHubReview: Codable, Identifiable {
    let id: Int
    let user: GitHubUser
    let body: String?
    let state: String
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, user, body, state
        case submittedAt = "submitted_at"
    }
}

struct GitHubPRFile: Codable {
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let changes: Int
    let patch: String?
}

struct GitHubWorkflowRuns: Codable {
    let totalCount: Int
    let workflowRuns: [GitHubWorkflowRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

struct GitHubWorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let htmlUrl: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case htmlUrl = "html_url"
        case createdAt = "created_at"
    }
}

struct GitHubCheckRuns: Codable {
    let totalCount: Int
    let checkRuns: [GitHubCheckRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case checkRuns = "check_runs"
    }
}

struct GitHubCheckRun: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case htmlUrl = "html_url"
    }
}

struct GitHubComment: Codable, Identifiable {
    let id: Int
    let user: GitHubUser
    let body: String
    let createdAt: String
    let updatedAt: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, user, body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
    }
}

struct GitHubReviewComment: Codable, Identifiable {
    let id: Int
    let user: GitHubUser
    let body: String
    let path: String
    let line: Int?
    let originalLine: Int?
    let commitId: String
    let createdAt: String
    let updatedAt: String
    let htmlUrl: String
    let diffHunk: String

    enum CodingKeys: String, CodingKey {
        case id, user, body, path, line
        case originalLine = "original_line"
        case commitId = "commit_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case diffHunk = "diff_hunk"
    }
}

struct ReviewCommentInput {
    let path: String
    let line: Int
    let body: String
}

struct GitHubBranch: Codable, Identifiable {
    var id: String { name }
    let name: String
    let commit: GitHubBranchCommit
    let protected: Bool
}

struct GitHubBranchCommit: Codable {
    let sha: String
    let url: String
}

struct GitHubCommit: Codable, Identifiable {
    var id: String { sha }
    let sha: String
    let commit: GitHubCommitInfo
    let author: GitHubUser?
    let committer: GitHubUser?
}

struct GitHubCommitInfo: Codable {
    let message: String
    let author: GitHubCommitAuthor
    let committer: GitHubCommitAuthor
}

struct GitHubCommitAuthor: Codable {
    let name: String
    let email: String
    let date: String
}

struct GitHubCommitDetail: Codable {
    let sha: String
    let commit: GitHubCommitInfo
    let author: GitHubUser?
    let files: [GitHubCommitFile]?
    let stats: GitHubCommitStats?
}

struct GitHubCommitFile: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let changes: Int
    let patch: String?
}

struct GitHubCommitStats: Codable {
    let additions: Int
    let deletions: Int
    let total: Int
}

// MARK: - Enums

enum PRState: String {
    case open
    case closed
    case all
}

enum IssueState: String {
    case open
    case closed
    case all
}

enum MergeMethod: String {
    case merge
    case squash
    case rebase
}

enum ReviewEvent: String {
    case approve = "APPROVE"
    case requestChanges = "REQUEST_CHANGES"
    case comment = "COMMENT"
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case validationFailed(String)
    case requestFailed(Int, String)
    case rateLimited(resetTime: Date?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required. Please check your GitHub token."
        case .forbidden:
            return "Access forbidden. Check your permissions."
        case .notFound:
            return "Resource not found"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .requestFailed(let code, let message):
            return "Request failed (\(code)): \(message)"
        case .rateLimited(let resetTime):
            if let reset = resetTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Rate limit exceeded. Resets at \(formatter.string(from: reset))"
            }
            return "Rate limit exceeded. Please wait before retrying."
        }
    }
}
