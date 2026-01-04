import Foundation

// MARK: - Linear Service

/// Service to connect with Linear API
actor LinearService {
    static let shared = LinearService()

    private let baseURL = "https://api.linear.app/graphql"
    private var accessToken: String?

    private init() {}

    // MARK: - Authentication

    func setAccessToken(_ token: String) {
        accessToken = token
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - GraphQL Helper

    private func graphQL<T: Decodable>(query: String, variables: [String: Any]? = nil) async throws -> T {
        guard let token = accessToken else { throw LinearError.notAuthenticated }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue(authorizationHeaderValue(for: token), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinearError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw LinearError.requestFailed("Authentication failed. Please check your API key.")
            }
            if let body, !body.isEmpty {
                throw LinearError.requestFailed("HTTP \(httpResponse.statusCode): \(body)")
            }
            throw LinearError.requestFailed("HTTP \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if let errorEnvelope = try? JSONDecoder().decode(LinearGraphQLErrorEnvelope.self, from: data) {
                let message = errorEnvelope.errors.map { error -> String in
                    if error.message.contains("authentication") {
                        return "Invalid API key or insufficient permissions."
                    }
                    return error.message
                }.joined(separator: "\n")
                
                if !message.isEmpty {
                    throw LinearError.requestFailed(message)
                }
            }

            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                throw LinearError.requestFailed(body)
            }

            throw error
        }
    }

    private func authorizationHeaderValue(for token: String) -> String {
        if token.hasPrefix("lin_api_") {
            return token
        }

        if token.hasPrefix("lin_oauth_") || token.hasPrefix("eyJ") {
            return "Bearer \(token)"
        }

        return token
    }

    func listTeams() async throws -> [LinearTeam] {
        let query = """
        query {
            teams {
                nodes {
                    id
                    name
                    key
                }
            }
        }
        """

        let response: LinearTeamsResponse = try await graphQL(query: query)
        return response.data.teams.nodes
    }

    // MARK: - Issues

    func listIssues(teamId: String? = nil, limit: Int = 50) async throws -> [LinearIssue] {
        var filter = ""
        if let teamId = teamId {
            filter = "(filter: { team: { id: { eq: \"\(teamId)\" } } })"
        }

        let query = """
        query {
            issues\(filter) {
                nodes {
                    id
                    identifier
                    title
                    description
                    priority
                    state {
                        id
                        name
                        color
                        type
                    }
                    assignee {
                        id
                        name
                        avatarUrl
                    }
                    labels {
                        nodes {
                            id
                            name
                            color
                        }
                    }
                    createdAt
                    updatedAt
                }
            }
        }
        """

        let response: LinearIssuesResponse = try await graphQL(query: query)
        return response.data.issues.nodes
    }

    func listMyIssues() async throws -> [LinearIssue] {
        let query = """
        query {
            viewer {
                assignedIssues {
                    nodes {
                        id
                        identifier
                        title
                        description
                        priority
                        state {
                            id
                            name
                            color
                            type
                        }
                        labels {
                            nodes {
                                id
                                name
                                color
                            }
                        }
                        createdAt
                        updatedAt
                    }
                }
            }
        }
        """

        let response: LinearMyIssuesResponse = try await graphQL(query: query)
        return response.data.viewer.assignedIssues.nodes
    }

    // MARK: - Workflow States

    func listWorkflowStates(teamId: String) async throws -> [LinearWorkflowState] {
        let query = """
        query($teamId: String!) {
            workflowStates(filter: { team: { id: { eq: $teamId } } }) {
                nodes {
                    id
                    name
                    color
                    type
                    position
                }
            }
        }
        """

        let response: LinearWorkflowStatesResponse = try await graphQL(
            query: query,
            variables: ["teamId": teamId]
        )
        return response.data.workflowStates.nodes
    }

    // MARK: - Update Issue

    func updateIssueState(issueId: String, stateId: String) async throws {
        let query = """
        mutation($issueId: String!, $stateId: String!) {
            issueUpdate(id: $issueId, input: { stateId: $stateId }) {
                success
            }
        }
        """

        let _: LinearMutationResponse = try await graphQL(
            query: query,
            variables: ["issueId": issueId, "stateId": stateId]
        )
    }
}

private struct LinearGraphQLErrorEnvelope: Decodable {
    let errors: [LinearGraphQLError]
}

private struct LinearGraphQLError: Decodable {
    let message: String
}

// MARK: - Errors

enum LinearError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Linear"
        case .invalidResponse:
            return "Invalid response from Linear"
        case .requestFailed(let message):
            return "Linear request failed: \(message)"
        }
    }
}

// MARK: - Models

struct LinearTeam: Codable, Identifiable {
    let id: String
    let name: String
    let key: String
}

struct LinearIssue: Codable, Identifiable {
    let id: String
    let identifier: String
    let title: String
    let description: String?
    let priority: Int
    let state: LinearWorkflowState?
    let assignee: LinearUser?
    let labels: LinearLabelsConnection?
    let createdAt: String
    let updatedAt: String

    var priorityName: String {
        switch priority {
        case 0: return "No priority"
        case 1: return "Urgent"
        case 2: return "High"
        case 3: return "Medium"
        case 4: return "Low"
        default: return "Unknown"
        }
    }
}

struct LinearWorkflowState: Codable, Identifiable {
    let id: String
    let name: String
    let color: String
    let type: String?
    let position: Double?
}

struct LinearUser: Codable, Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
}

struct LinearLabel: Codable, Identifiable {
    let id: String
    let name: String
    let color: String
}

struct LinearLabelsConnection: Codable {
    let nodes: [LinearLabel]
}

// MARK: - Response Types

struct LinearTeamsResponse: Codable {
    let data: LinearTeamsData
}

struct LinearTeamsData: Codable {
    let teams: LinearTeamsNodes
}

struct LinearTeamsNodes: Codable {
    let nodes: [LinearTeam]
}

struct LinearIssuesResponse: Codable {
    let data: LinearIssuesData
}

struct LinearIssuesData: Codable {
    let issues: LinearIssuesNodes
}

struct LinearIssuesNodes: Codable {
    let nodes: [LinearIssue]
}

struct LinearMyIssuesResponse: Codable {
    let data: LinearViewerData
}

struct LinearViewerData: Codable {
    let viewer: LinearViewerIssues
}

struct LinearViewerIssues: Codable {
    let assignedIssues: LinearIssuesNodes
}

struct LinearWorkflowStatesResponse: Codable {
    let data: LinearWorkflowStatesData
}

struct LinearWorkflowStatesData: Codable {
    let workflowStates: LinearWorkflowStatesNodes
}

struct LinearWorkflowStatesNodes: Codable {
    let nodes: [LinearWorkflowState]
}

struct LinearMutationResponse: Codable {
    let data: LinearMutationData
}

struct LinearMutationData: Codable {
    let issueUpdate: LinearMutationResult?
}

struct LinearMutationResult: Codable {
    let success: Bool
}

// MARK: - Linear OAuth

@MainActor
class LinearOAuth: ObservableObject {
    static let shared = LinearOAuth()

    // Linear OAuth configuration
    // Register your app at https://linear.app/settings/api
    private let clientId = "YOUR_LINEAR_CLIENT_ID"
    private let clientSecret = "YOUR_LINEAR_CLIENT_SECRET"
    private let redirectUri = "gitmac://oauth/linear"
    private let scope = "read,write"

    @Published var isAuthenticating = false

    func startOAuth() -> URL? {
        let authURL = "https://linear.app/oauth/authorize"
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope)
        ]
        return components.url
    }

    func handleCallback(url: URL) async throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw LinearError.invalidResponse
        }

        // Exchange code for token
        var request = URLRequest(url: URL(string: "https://api.linear.app/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "client_id=\(clientId)",
            "client_secret=\(clientSecret)",
            "redirect_uri=\(redirectUri)",
            "code=\(code)"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LinearTokenResponse.self, from: data)

        return response.accessToken
    }
}

struct LinearTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}
