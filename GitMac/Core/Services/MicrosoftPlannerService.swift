import Foundation

// MARK: - Microsoft Planner Service

/// Service to connect with Microsoft Planner via Microsoft Graph API
actor MicrosoftPlannerService {
    static let shared = MicrosoftPlannerService()

    private let graphBaseURL = "https://graph.microsoft.com/v1.0"
    private var accessToken: String?

    private init() {}

    // MARK: - Authentication

    func setAccessToken(_ token: String) {
        accessToken = token
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - Plans

    func listPlans() async throws -> [PlannerPlan] {
        guard let token = accessToken else { throw PlannerError.notAuthenticated }

        var request = URLRequest(url: URL(string: "\(graphBaseURL)/me/planner/plans")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(PlannerPlanResponse.self, from: data)
        return response.value
    }

    // MARK: - Buckets

    func listBuckets(planId: String) async throws -> [PlannerBucket] {
        guard let token = accessToken else { throw PlannerError.notAuthenticated }

        var request = URLRequest(url: URL(string: "\(graphBaseURL)/planner/plans/\(planId)/buckets")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(PlannerBucketResponse.self, from: data)
        return response.value
    }

    // MARK: - Tasks

    func listTasks(planId: String) async throws -> [PlannerTask] {
        guard let token = accessToken else { throw PlannerError.notAuthenticated }

        var request = URLRequest(url: URL(string: "\(graphBaseURL)/planner/plans/\(planId)/tasks")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(PlannerTaskResponse.self, from: data)
        return response.value
    }

    func createTask(planId: String, bucketId: String, title: String) async throws -> PlannerTask {
        guard let token = accessToken else { throw PlannerError.notAuthenticated }

        var request = URLRequest(url: URL(string: "\(graphBaseURL)/planner/tasks")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "planId": planId,
            "bucketId": bucketId,
            "title": title
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(PlannerTask.self, from: data)
    }

    func updateTaskProgress(taskId: String, percentComplete: Int, etag: String) async throws {
        guard let token = accessToken else { throw PlannerError.notAuthenticated }

        var request = URLRequest(url: URL(string: "\(graphBaseURL)/planner/tasks/\(taskId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(etag, forHTTPHeaderField: "If-Match")

        let body = ["percentComplete": percentComplete]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, _) = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Errors

enum PlannerError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Microsoft"
        case .invalidResponse:
            return "Invalid response from Microsoft Graph"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Models

struct PlannerPlanResponse: Codable {
    let value: [PlannerPlan]
}

struct PlannerPlan: Identifiable, Codable {
    let id: String
    let title: String
    let owner: String?
    let createdDateTime: String?

    var displayTitle: String { title }
}

struct PlannerBucketResponse: Codable {
    let value: [PlannerBucket]
}

struct PlannerBucket: Identifiable, Codable {
    let id: String
    let name: String
    let planId: String
    let orderHint: String?
}

struct PlannerTaskResponse: Codable {
    let value: [PlannerTask]
}

struct PlannerTask: Identifiable, Codable {
    let id: String
    let title: String
    let planId: String
    let bucketId: String?
    let percentComplete: Int
    let priority: Int?
    let startDateTime: String?
    let dueDateTime: String?
    let createdDateTime: String?
    let assignments: [String: PlannerAssignment]?

    var isComplete: Bool {
        percentComplete == 100
    }

    var priorityLabel: String {
        switch priority {
        case 1: return "Urgent"
        case 3: return "Important"
        case 5: return "Medium"
        case 9: return "Low"
        default: return "Normal"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, planId, bucketId, percentComplete, priority
        case startDateTime, dueDateTime, createdDateTime, assignments
    }
}

struct PlannerAssignment: Codable {
    let assignedBy: PlannerIdentity?
    let assignedDateTime: String?
    let orderHint: String?
}

struct PlannerIdentity: Codable {
    let user: PlannerUser?
}

struct PlannerUser: Codable {
    let id: String?
    let displayName: String?
}
