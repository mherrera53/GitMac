import Foundation

// MARK: - Taiga Service

/// Service to connect with Taiga API (tree.taiga.io)
actor TaigaService {
    static let shared = TaigaService()

    private let baseURL = "https://api.taiga.io/api/v1"
    private var authToken: String?
    private var refreshToken: String?
    private var userId: Int?

    private init() {}

    // MARK: - Authentication

    struct AuthResponse: Codable {
        let authToken: String
        let refresh: String
        let id: Int
        let username: String
        let fullName: String
        let email: String
        let photo: String?

        enum CodingKeys: String, CodingKey {
            case authToken = "auth_token"
            case refresh
            case id
            case username
            case fullName = "full_name"
            case email
            case photo
        }
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/auth")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["username": username, "password": password, "type": "normal"]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TaigaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TaigaError.authFailed
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        authToken = authResponse.authToken
        refreshToken = authResponse.refresh
        userId = authResponse.id

        return authResponse
    }

    func setToken(_ token: String) {
        authToken = token
    }

    func setUserId(_ id: Int) {
        userId = id
    }

    var isAuthenticated: Bool {
        authToken != nil
    }

    /// Authenticate with username and password, stores token in keychain
    func authenticate(username: String, password: String) async throws {
        let response = try await login(username: username, password: password)
        try await KeychainManager.shared.saveTaigaToken(response.authToken)
        try await KeychainManager.shared.saveTaigaUserId(String(response.id))
    }

    // MARK: - Projects

    func listProjects() async throws -> [TaigaProject] {
        guard let token = authToken else { throw TaigaError.notAuthenticated }

        var urlString = "\(baseURL)/projects?order_by=user_order"
        if let memberId = userId {
            urlString += "&member=\(memberId)"
        }

        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([TaigaProject].self, from: data)
    }

    // MARK: - User Stories (Tickets)

    func listUserStories(projectId: Int, status: TaigaStatus? = nil) async throws -> [TaigaUserStory] {
        guard let token = authToken else { throw TaigaError.notAuthenticated }

        var urlString = "\(baseURL)/userstories?project=\(projectId)"
        if let status = status {
            urlString += "&status=\(status.id)"
        }

        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Debug logging
        if let httpResponse = response as? HTTPURLResponse {
            print("📋 Taiga User Stories - URL: \(urlString)")
            print("📋 Taiga User Stories - Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📋 Taiga User Stories - Response: \(jsonString.prefix(500))")
            }
        }

        return try JSONDecoder().decode([TaigaUserStory].self, from: data)
    }

    // MARK: - Tasks

    func listTasks(projectId: Int, userStoryId: Int? = nil) async throws -> [TaigaTask] {
        guard let token = authToken else { throw TaigaError.notAuthenticated }

        var urlString = "\(baseURL)/tasks?project=\(projectId)"
        if let usId = userStoryId {
            urlString += "&user_story=\(usId)"
        }

        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([TaigaTask].self, from: data)
    }

    // MARK: - Issues (Bugs)

    func listIssues(projectId: Int) async throws -> [TaigaIssue] {
        guard let token = authToken else { throw TaigaError.notAuthenticated }

        let urlString = "\(baseURL)/issues?project=\(projectId)"

        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([TaigaIssue].self, from: data)
    }

    // MARK: - Epics

    func listEpics(projectId: Int) async throws -> [TaigaEpic] {
        guard let token = authToken else { throw TaigaError.notAuthenticated }

        let urlString = "\(baseURL)/epics?project=\(projectId)"

        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([TaigaEpic].self, from: data)
    }

    // MARK: - Statuses

    func getProjectStatuses(projectId: Int) async throws -> [TaigaStatus] {
        guard let token = authToken else { throw TaigaError.notAuthenticated }

        let urlString = "\(baseURL)/userstory-statuses?project=\(projectId)"

        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([TaigaStatus].self, from: data)
    }
}

// MARK: - Errors

enum TaigaError: Error, LocalizedError {
    case notAuthenticated
    case authFailed
    case invalidResponse
    case projectNotFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Taiga"
        case .authFailed:
            return "Authentication failed. Check your credentials."
        case .invalidResponse:
            return "Invalid response from Taiga server"
        case .projectNotFound:
            return "Project not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Models

struct TaigaProject: Identifiable, Codable {
    let id: Int
    let name: String
    let slug: String
    let description: String?
    let isPrivate: Bool
    let totalMilestones: Int?
    let totalStoryPoints: Double?
    let iAmOwner: Bool?
    let iAmAdmin: Bool?
    let iAmMember: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case isPrivate = "is_private"
        case totalMilestones = "total_milestones"
        case totalStoryPoints = "total_story_points"
        case iAmOwner = "i_am_owner"
        case iAmAdmin = "i_am_admin"
        case iAmMember = "i_am_member"
    }
}

struct TaigaUserStory: Identifiable, Codable {
    let id: Int
    let ref: Int
    let subject: String
    let description: String?
    let status: Int
    let statusExtraInfo: TaigaStatusInfo?
    let totalPoints: Double?
    let assignedTo: Int?
    let assignedToExtraInfo: TaigaUserInfo?
    let createdDate: String
    let modifiedDate: String
    let isClosed: Bool
    let tags: [[String]]?

    enum CodingKeys: String, CodingKey {
        case id, ref, subject, description, status, tags
        case statusExtraInfo = "status_extra_info"
        case totalPoints = "total_points"
        case assignedTo = "assigned_to"
        case assignedToExtraInfo = "assigned_to_extra_info"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
        case isClosed = "is_closed"
    }
}

struct TaigaTask: Identifiable, Codable {
    let id: Int
    let ref: Int
    let subject: String
    let description: String?
    let status: Int
    let statusExtraInfo: TaigaStatusInfo?
    let userStory: Int?
    let assignedTo: Int?
    let assignedToExtraInfo: TaigaUserInfo?
    let isClosed: Bool

    enum CodingKeys: String, CodingKey {
        case id, ref, subject, description, status
        case statusExtraInfo = "status_extra_info"
        case userStory = "user_story"
        case assignedTo = "assigned_to"
        case assignedToExtraInfo = "assigned_to_extra_info"
        case isClosed = "is_closed"
    }
}

struct TaigaIssue: Identifiable, Codable {
    let id: Int
    let ref: Int
    let subject: String
    let description: String?
    let status: Int
    let statusExtraInfo: TaigaStatusInfo?
    let type: Int?
    let typeExtraInfo: TaigaTypeInfo?
    let severity: Int?
    let priority: Int?
    let assignedTo: Int?
    let assignedToExtraInfo: TaigaUserInfo?
    let isClosed: Bool

    enum CodingKeys: String, CodingKey {
        case id, ref, subject, description, status, type, severity, priority
        case statusExtraInfo = "status_extra_info"
        case typeExtraInfo = "type_extra_info"
        case assignedTo = "assigned_to"
        case assignedToExtraInfo = "assigned_to_extra_info"
        case isClosed = "is_closed"
    }
}

struct TaigaEpic: Identifiable, Codable {
    let id: Int
    let ref: Int
    let subject: String
    let description: String?
    let status: Int
    let statusExtraInfo: TaigaStatusInfo?
    let color: String?
    let assignedTo: Int?

    enum CodingKeys: String, CodingKey {
        case id, ref, subject, description, status, color
        case statusExtraInfo = "status_extra_info"
        case assignedTo = "assigned_to"
    }
}

struct TaigaStatus: Identifiable, Codable {
    let id: Int
    let name: String
    let slug: String
    let color: String
    let isClosed: Bool
    let order: Int

    enum CodingKeys: String, CodingKey {
        case id, name, slug, color, order
        case isClosed = "is_closed"
    }
}

struct TaigaStatusInfo: Codable {
    let name: String
    let color: String
    let isClosed: Bool

    enum CodingKeys: String, CodingKey {
        case name, color
        case isClosed = "is_closed"
    }
}

struct TaigaUserInfo: Codable {
    let id: Int
    let username: String
    let fullName: String
    let photo: String?

    enum CodingKeys: String, CodingKey {
        case id, username, photo
        case fullName = "full_name_display"
    }
}

struct TaigaTypeInfo: Codable {
    let name: String
    let color: String
}
