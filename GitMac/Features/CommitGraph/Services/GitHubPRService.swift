import Foundation

/// Service for fetching GitHub Pull Request information
class GitHubPRService {
    static let shared = GitHubPRService()

    private var cache: [String: PRInfo] = [:]
    private let session = URLSession.shared

    struct PRInfo: Codable {
        let number: Int
        let title: String
        let state: String
        let url: String
        let author: String
        let createdAt: String
        let mergedAt: String?
        let labels: [String]

        enum CodingKeys: String, CodingKey {
            case number, title, state, url, author = "user"
            case createdAt = "created_at"
            case mergedAt = "merged_at"
            case labels
        }
    }

    /// Fetch PR information for a commit SHA
    func fetchPR(for sha: String, repo: String, token: String?) async throws -> PRInfo? {
        // Check cache
        if let cached = cache[sha] {
            return cached
        }

        // Parse repo owner/name from git remote
        guard let (owner, repoName) = parseRepoInfo(repo) else {
            return nil
        }

        // GitHub API endpoint
        let endpoint = "https://api.github.com/repos/\(owner)/\(repoName)/commits/\(sha)/pulls"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let prs = try JSONDecoder().decode([PRInfo].self, from: data)
        let prInfo = prs.first

        // Cache result
        if let prInfo = prInfo {
            cache[sha] = prInfo
        }

        return prInfo
    }

    /// Parse owner/repo from git remote URL
    private func parseRepoInfo(_ remote: String) -> (String, String)? {
        // Handle formats:
        // - https://github.com/owner/repo.git
        // - git@github.com:owner/repo.git

        var urlString = remote

        if urlString.hasPrefix("git@github.com:") {
            urlString = urlString.replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
        }

        urlString = urlString.replacingOccurrences(of: ".git", with: "")

        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("github.com") else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2 else {
            return nil
        }

        return (components[0], components[1])
    }

    /// Get GitHub token from git config or keychain
    func getGitHubToken(at path: String) async -> String? {
        // Try git config first
        let result = await ShellExecutor().execute(
            "git",
            arguments: ["config", "github.token"],
            workingDirectory: path
        )

        if result.exitCode == 0, !result.output.isEmpty {
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Could also check environment variable or keychain
        return ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
    }

    /// Clear cache
    func clearCache() {
        cache.removeAll()
    }
}
