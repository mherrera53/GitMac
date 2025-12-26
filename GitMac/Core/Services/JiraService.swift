import Foundation

// MARK: - Jira Service

/// Service to connect with Jira Cloud API
actor JiraService {
    static let shared = JiraService()

    private var cloudId: String?
    private var accessToken: String?
    private var siteUrl: String?

    private var baseURL: String {
        guard let cloudId = cloudId else { return "" }
        return "https://api.atlassian.com/ex/jira/\(cloudId)/rest/api/3"
    }

    private init() {}

    // MARK: - Authentication

    func setAccessToken(_ token: String, cloudId: String, siteUrl: String) {
        self.accessToken = token
        self.cloudId = cloudId
        self.siteUrl = siteUrl
    }

    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    func setCloudId(_ id: String) {
        self.cloudId = id
    }

    var isAuthenticated: Bool {
        accessToken != nil && cloudId != nil
    }

    // MARK: - API Helper

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let token = accessToken else { throw JiraError.notAuthenticated }
        guard !baseURL.isEmpty else { throw JiraError.noCloudId }

        var request = URLRequest(url: URL(string: "\(baseURL)\(endpoint)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiraError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw JiraError.requestFailed("HTTP \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Cloud ID Discovery

    func discoverCloudId(token: String) async throws -> [JiraCloudSite] {
        var request = URLRequest(url: URL(string: "https://api.atlassian.com/oauth/token/accessible-resources")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([JiraCloudSite].self, from: data)
    }

    // MARK: - Projects

    func listProjects() async throws -> [JiraProject] {
        let response: JiraProjectsResponse = try await request(endpoint: "/project/search")
        return response.values
    }

    // MARK: - Issues

    func searchIssues(jql: String, maxResults: Int = 50) async throws -> [JiraIssue] {
        let encodedJql = jql.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jql
        let response: JiraSearchResponse = try await request(
            endpoint: "/search?jql=\(encodedJql)&maxResults=\(maxResults)&fields=summary,status,priority,assignee,issuetype,labels,created,updated"
        )
        return response.issues
    }

    func getMyIssues() async throws -> [JiraIssue] {
        return try await searchIssues(jql: "assignee=currentUser() AND resolution=Unresolved ORDER BY priority DESC, updated DESC")
    }

    func getProjectIssues(projectKey: String) async throws -> [JiraIssue] {
        return try await searchIssues(jql: "project=\(projectKey) AND resolution=Unresolved ORDER BY priority DESC, updated DESC")
    }

    // MARK: - Issue Details

    func getIssue(issueKey: String) async throws -> JiraIssue {
        return try await request(endpoint: "/issue/\(issueKey)")
    }

    // MARK: - Transitions

    func getTransitions(issueKey: String) async throws -> [JiraTransition] {
        let response: JiraTransitionsResponse = try await request(endpoint: "/issue/\(issueKey)/transitions")
        return response.transitions
    }

    func transitionIssue(issueKey: String, transitionId: String) async throws {
        let body = try JSONEncoder().encode(["transition": ["id": transitionId]])
        let _: EmptyResponse = try await request(
            endpoint: "/issue/\(issueKey)/transitions",
            method: "POST",
            body: body
        )
    }

    // MARK: - Comments

    func addComment(issueKey: String, body: String) async throws {
        let commentBody = JiraCommentBody(body: JiraDocumentBody(
            type: "doc",
            version: 1,
            content: [JiraDocumentContent(
                type: "paragraph",
                content: [JiraDocumentText(type: "text", text: body)]
            )]
        ))
        let bodyData = try JSONEncoder().encode(commentBody)
        let _: JiraComment = try await request(
            endpoint: "/issue/\(issueKey)/comment",
            method: "POST",
            body: bodyData
        )
    }
}

// MARK: - Empty Response for void endpoints
struct EmptyResponse: Decodable {}

// MARK: - Errors

enum JiraError: Error, LocalizedError {
    case notAuthenticated
    case noCloudId
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Jira"
        case .noCloudId:
            return "No Jira cloud ID configured"
        case .invalidResponse:
            return "Invalid response from Jira"
        case .requestFailed(let message):
            return "Jira request failed: \(message)"
        }
    }
}

// MARK: - Models

struct JiraCloudSite: Codable, Identifiable {
    let id: String
    let name: String
    let url: String
    let scopes: [String]?
    let avatarUrl: String?
}

struct JiraProject: Codable, Identifiable {
    let id: String
    let key: String
    let name: String
    let avatarUrls: JiraAvatarUrls?
    let projectTypeKey: String?
}

struct JiraAvatarUrls: Codable {
    let x48: String?
    let x24: String?
    let x16: String?
    let x32: String?

    enum CodingKeys: String, CodingKey {
        case x48 = "48x48"
        case x24 = "24x24"
        case x16 = "16x16"
        case x32 = "32x32"
    }
}

struct JiraIssue: Codable, Identifiable {
    let id: String
    let key: String
    let fields: JiraIssueFields
}

struct JiraIssueFields: Codable {
    let summary: String
    let status: JiraStatus?
    let priority: JiraPriority?
    let assignee: JiraUser?
    let issuetype: JiraIssueType?
    let labels: [String]?
    let created: String?
    let updated: String?
}

struct JiraStatus: Codable {
    let id: String
    let name: String
    let statusCategory: JiraStatusCategory?
}

struct JiraStatusCategory: Codable {
    let id: Int
    let key: String
    let name: String
    let colorName: String
}

struct JiraPriority: Codable {
    let id: String
    let name: String
    let iconUrl: String?
}

struct JiraUser: Codable {
    let accountId: String
    let displayName: String
    let avatarUrls: JiraAvatarUrls?
}

struct JiraIssueType: Codable {
    let id: String
    let name: String
    let iconUrl: String?
    let subtask: Bool
}

struct JiraTransition: Codable, Identifiable {
    let id: String
    let name: String
    let to: JiraStatus?
}

struct JiraComment: Codable {
    let id: String
    let body: JiraDocumentBody?
}

struct JiraDocumentBody: Codable {
    let type: String
    let version: Int
    let content: [JiraDocumentContent]
}

struct JiraDocumentContent: Codable {
    let type: String
    let content: [JiraDocumentText]?
}

struct JiraDocumentText: Codable {
    let type: String
    let text: String
}

struct JiraCommentBody: Codable {
    let body: JiraDocumentBody
}

// MARK: - Response Types

struct JiraProjectsResponse: Codable {
    let values: [JiraProject]
    let total: Int?
}

struct JiraSearchResponse: Codable {
    let issues: [JiraIssue]
    let total: Int
    let maxResults: Int
}

struct JiraTransitionsResponse: Codable {
    let transitions: [JiraTransition]
}

// MARK: - Jira OAuth

@MainActor
class JiraOAuth: ObservableObject {
    static let shared = JiraOAuth()

    // Jira OAuth configuration
    // Register your app at https://developer.atlassian.com/console/myapps/
    private let clientId = "YOUR_JIRA_CLIENT_ID"
    private let clientSecret = "YOUR_JIRA_CLIENT_SECRET"
    private let redirectUri = "gitmac://oauth/jira"
    private let scope = "read:jira-work read:jira-user write:jira-work offline_access"

    @Published var isAuthenticating = false

    func startOAuth() -> URL? {
        let authURL = "https://auth.atlassian.com/authorize"
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "audience", value: "api.atlassian.com"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url
    }

    func handleCallback(url: URL) async throws -> JiraTokenResponse {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw JiraError.invalidResponse
        }

        // Exchange code for token
        var request = URLRequest(url: URL(string: "https://auth.atlassian.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectUri,
            "code": code
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(JiraTokenResponse.self, from: data)
    }

    func refreshToken(_ refreshToken: String) async throws -> JiraTokenResponse {
        var request = URLRequest(url: URL(string: "https://auth.atlassian.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(JiraTokenResponse.self, from: data)
    }
}

struct JiraTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}
