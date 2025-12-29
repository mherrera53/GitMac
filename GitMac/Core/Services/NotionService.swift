import Foundation

// MARK: - Notion Service

/// Service to connect with Notion API
actor NotionService {
    static let shared = NotionService()

    private let baseURL = "https://api.notion.com/v1"
    private let notionVersion = "2022-06-28"
    private var accessToken: String?

    private init() {}

    // MARK: - Authentication

    func setAccessToken(_ token: String) {
        accessToken = token
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - API Helper

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let token = accessToken else { throw NotionError.notAuthenticated }

        var request = URLRequest(url: URL(string: "\(baseURL)\(endpoint)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NotionError.requestFailed("HTTP \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Search

    func search(query: String? = nil, filter: NotionSearchFilter? = nil) async throws -> [NotionObject] {
        var bodyDict: [String: Any] = [:]
        if let query = query {
            bodyDict["query"] = query
        }
        if let filter = filter {
            bodyDict["filter"] = ["value": filter.rawValue, "property": "object"]
        }
        bodyDict["page_size"] = 100

        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        let response: NotionSearchResponse = try await request(
            endpoint: "/search",
            method: "POST",
            body: body
        )
        return response.results
    }

    // MARK: - Databases

    func listDatabases() async throws -> [NotionDatabase] {
        let objects = try await search(filter: .database)
        return objects.compactMap { obj -> NotionDatabase? in
            guard case .database(let db) = obj else { return nil }
            return db
        }
    }

    func queryDatabase(databaseId: String, filter: [String: Any]? = nil, sorts: [[String: Any]]? = nil) async throws -> [NotionPage] {
        var bodyDict: [String: Any] = ["page_size": 100]
        if let filter = filter {
            bodyDict["filter"] = filter
        }
        if let sorts = sorts {
            bodyDict["sorts"] = sorts
        }

        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        let response: NotionDatabaseQueryResponse = try await request(
            endpoint: "/databases/\(databaseId)/query",
            method: "POST",
            body: body
        )
        return response.results
    }

    // MARK: - Pages

    func getPage(pageId: String) async throws -> NotionPage {
        return try await request(endpoint: "/pages/\(pageId)")
    }

    func createPage(parentDatabaseId: String, properties: [String: Any]) async throws -> NotionPage {
        let bodyDict: [String: Any] = [
            "parent": ["database_id": parentDatabaseId],
            "properties": properties
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        return try await request(endpoint: "/pages", method: "POST", body: body)
    }

    func updatePage(pageId: String, properties: [String: Any]) async throws -> NotionPage {
        let bodyDict: [String: Any] = ["properties": properties]
        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        return try await request(endpoint: "/pages/\(pageId)", method: "PATCH", body: body)
    }

    // MARK: - Task-specific helpers

    /// Query a database as a task list (assuming standard task properties)
    func queryTasks(databaseId: String, statusProperty: String = "Status", onlyIncomplete: Bool = true) async throws -> [NotionTask] {
        var filter: [String: Any]? = nil
        if onlyIncomplete {
            filter = [
                "property": statusProperty,
                "status": ["does_not_equal": "Done"]
            ]
        }

        let sorts: [[String: Any]] = [
            ["property": statusProperty, "direction": "ascending"]
        ]

        let pages = try await queryDatabase(databaseId: databaseId, filter: filter, sorts: sorts)
        return pages.map { NotionTask(from: $0) }
    }

    /// Update task status
    func updateTaskStatus(pageId: String, statusProperty: String = "Status", status: String) async throws {
        let properties: [String: Any] = [
            statusProperty: ["status": ["name": status]]
        ]
        _ = try await updatePage(pageId: pageId, properties: properties)
    }
}

// MARK: - Errors

enum NotionError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Notion"
        case .invalidResponse:
            return "Invalid response from Notion"
        case .requestFailed(let message):
            return "Notion request failed: \(message)"
        }
    }
}

// MARK: - Search Filter

enum NotionSearchFilter: String {
    case page
    case database
}

// MARK: - Models

enum NotionObject: Decodable {
    case page(NotionPage)
    case database(NotionDatabase)

    enum CodingKeys: String, CodingKey {
        case object
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let objectType = try container.decode(String.self, forKey: .object)

        switch objectType {
        case "page":
            self = .page(try NotionPage(from: decoder))
        case "database":
            self = .database(try NotionDatabase(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .object,
                in: container,
                debugDescription: "Unknown object type: \(objectType)"
            )
        }
    }
}

struct NotionDatabase: Codable, Identifiable {
    let id: String
    let title: [NotionRichText]?
    let icon: NotionIcon?
    let createdTime: String?
    let lastEditedTime: String?

    var displayTitle: String {
        title?.first?.plainText ?? "Untitled"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, icon
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }
}

struct NotionPage: Decodable, Identifiable {
    let id: String
    let properties: [String: NotionProperty]
    let icon: NotionIcon?
    let createdTime: String?
    let lastEditedTime: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id, properties, icon, url
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }

    var title: String {
        for (_, prop) in properties {
            if case .title(let texts) = prop {
                return texts.first?.plainText ?? "Untitled"
            }
        }
        return "Untitled"
    }

    var status: String? {
        for (_, prop) in properties {
            if case .status(let status) = prop {
                return status?.name
            }
        }
        return nil
    }
}

enum NotionProperty: Decodable {
    case title([NotionRichText])
    case richText([NotionRichText])
    case status(NotionStatus?)
    case select(NotionSelectOption?)
    case multiSelect([NotionSelectOption])
    case date(NotionDate?)
    case checkbox(Bool)
    case number(Double?)
    case url(String?)
    case people([NotionPerson])
    case unknown

    enum CodingKeys: String, CodingKey {
        case type, title
        case richText = "rich_text"
        case status, select
        case multiSelect = "multi_select"
        case date, checkbox, number, url, people
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "title":
            self = .title(try container.decode([NotionRichText].self, forKey: .title))
        case "rich_text":
            self = .richText(try container.decode([NotionRichText].self, forKey: .richText))
        case "status":
            self = .status(try container.decodeIfPresent(NotionStatus.self, forKey: .status))
        case "select":
            self = .select(try container.decodeIfPresent(NotionSelectOption.self, forKey: .select))
        case "multi_select":
            self = .multiSelect(try container.decode([NotionSelectOption].self, forKey: .multiSelect))
        case "date":
            self = .date(try container.decodeIfPresent(NotionDate.self, forKey: .date))
        case "checkbox":
            self = .checkbox(try container.decode(Bool.self, forKey: .checkbox))
        case "number":
            self = .number(try container.decodeIfPresent(Double.self, forKey: .number))
        case "url":
            self = .url(try container.decodeIfPresent(String.self, forKey: .url))
        case "people":
            self = .people(try container.decode([NotionPerson].self, forKey: .people))
        default:
            self = .unknown
        }
    }
}

struct NotionRichText: Codable {
    let plainText: String
    let href: String?

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case href
    }
}

struct NotionStatus: Codable {
    let id: String?
    let name: String
    let color: String?
}

struct NotionSelectOption: Codable {
    let id: String?
    let name: String
    let color: String?
}

struct NotionDate: Codable {
    let start: String?
    let end: String?
}

struct NotionPerson: Codable {
    let id: String
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case avatarUrl = "avatar_url"
    }
}

struct NotionIcon: Codable {
    let type: String
    let emoji: String?
    let external: NotionExternalFile?
}

struct NotionExternalFile: Codable {
    let url: String
}

// MARK: - Task Model (simplified view of a page as a task)

struct NotionTask: Identifiable {
    let id: String
    let title: String
    let status: String?
    let statusColor: String?
    let url: String?

    init(from page: NotionPage) {
        self.id = page.id
        self.title = page.title
        self.url = page.url

        // Try to extract status
        for (_, prop) in page.properties {
            if case .status(let status) = prop {
                self.status = status?.name
                self.statusColor = status?.color
                return
            }
        }
        self.status = nil
        self.statusColor = nil
    }
}

// MARK: - Response Types

struct NotionSearchResponse: Decodable {
    let results: [NotionObject]
    let hasMore: Bool?
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

struct NotionDatabaseQueryResponse: Decodable {
    let results: [NotionPage]
    let hasMore: Bool?
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

// MARK: - Notion OAuth

@MainActor
class NotionOAuth: ObservableObject {
    static let shared = NotionOAuth()

    // Notion OAuth configuration
    // Register your integration at https://www.notion.so/my-integrations
    private let clientId = "YOUR_NOTION_CLIENT_ID"
    private let clientSecret = "YOUR_NOTION_CLIENT_SECRET"
    private let redirectUri = "gitmac://oauth/notion"

    @Published var isAuthenticating = false

    func startOAuth() -> URL? {
        let authURL = "https://api.notion.com/v1/oauth/authorize"
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "owner", value: "user")
        ]
        return components.url
    }

    func handleCallback(url: URL) async throws -> NotionTokenResponse {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw NotionError.invalidResponse
        }

        // Exchange code for token
        var request = URLRequest(url: URL(string: "https://api.notion.com/v1/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Notion requires Basic auth for token exchange
        let credentials = "\(clientId):\(clientSecret)"
        let encodedCredentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(NotionTokenResponse.self, from: data)
    }
}

struct NotionTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let botId: String
    let workspaceName: String?
    let workspaceIcon: String?
    let workspaceId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case botId = "bot_id"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
        case workspaceId = "workspace_id"
    }
}
