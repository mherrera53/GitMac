import Foundation

// MARK: - Pro API Client

/// Client for GitMac Pro server-side features
/// All Pro features (AI, integrations) go through this API client
/// This ensures features cannot be bypassed - they require valid license validation on server
class ProAPIClient: ObservableObject {
    // Singleton
    static let shared = ProAPIClient()

    // Production server
    private let baseURL = "https://gitmac-license-server-production.up.railway.app"

    // License validator for getting current license
    private let licenseValidator = GitMacLicenseValidator.shared

    @Published var isLoading = false
    @Published var lastError: String?

    private init() {}

    // MARK: - AI Features

    /// Generate AI-powered commit message from diff
    func generateCommitMessage(diff: String, context: CommitContext? = nil) async throws -> String {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let request = AICommitRequest(
            diff: diff,
            context: context,
            license_key: licenseKey
        )

        let response: AICommitResponse = try await post("/api/pro/ai/commit", body: request)
        return response.message
    }

    /// Resolve merge conflict with AI assistance
    func resolveConflict(
        file: String,
        ours: String,
        theirs: String,
        base: String?
    ) async throws -> ConflictResolution {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let request = AIConflictRequest(
            file: file,
            ours: ours,
            theirs: theirs,
            base: base,
            license_key: licenseKey
        )

        return try await post("/api/pro/ai/conflict", body: request)
    }

    /// Get AI code review for changes
    func reviewCode(diff: String, files: [String]) async throws -> CodeReview {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let request = AIReviewRequest(
            diff: diff,
            files: files,
            license_key: licenseKey
        )

        return try await post("/api/pro/ai/review", body: request)
    }

    // MARK: - AI Provider Selection

    /// Get available AI providers for user's license
    func getAvailableProviders() async throws -> [AIProvider] {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let response: ProvidersResponse = try await get(
            "/api/pro/ai/providers",
            params: ["license_key": licenseKey]
        )

        return response.providers
    }

    /// Set preferred AI provider
    func setPreferredProvider(_ provider: AIProvider) async throws {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let request = SetProviderRequest(
            provider: provider.id,
            license_key: licenseKey
        )

        let _: EmptyResponse = try await post("/api/pro/ai/set-provider", body: request)
    }

    // MARK: - Jira Integration

    /// Initialize Jira OAuth flow
    func jiraOAuthURL() async throws -> URL {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let response: OAuthURLResponse = try await post(
            "/api/pro/integrations/jira/oauth",
            body: ["license_key": licenseKey]
        )

        guard let url = URL(string: response.url) else {
            throw ProAPIError.invalidResponse
        }

        return url
    }

    /// Link commit to Jira issue
    func linkJiraIssue(issueKey: String, commitHash: String) async throws {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let request = LinkIssueRequest(
            issue_key: issueKey,
            commit_hash: commitHash,
            license_key: licenseKey
        )

        let _: EmptyResponse = try await post("/api/pro/integrations/jira/link", body: request)
    }

    /// Get Jira issues for current sprint
    func getJiraIssues() async throws -> [JiraIssue] {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let response: JiraIssuesResponse = try await get(
            "/api/pro/integrations/jira/issues",
            params: ["license_key": licenseKey]
        )

        return response.issues
    }

    // MARK: - Linear Integration

    /// Initialize Linear OAuth flow
    func linearOAuthURL() async throws -> URL {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let response: OAuthURLResponse = try await post(
            "/api/pro/integrations/linear/oauth",
            body: ["license_key": licenseKey]
        )

        guard let url = URL(string: response.url) else {
            throw ProAPIError.invalidResponse
        }

        return url
    }

    /// Sync commit with Linear issue
    func syncLinearIssue(issueId: String, commitHash: String) async throws {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let request = SyncLinearRequest(
            issue_id: issueId,
            commit_hash: commitHash,
            license_key: licenseKey
        )

        let _: EmptyResponse = try await post("/api/pro/integrations/linear/sync", body: request)
    }

    // MARK: - Custom Themes

    /// Save custom theme to cloud
    func saveTheme(_ theme: CustomTheme) async throws {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        var request = theme
        request.license_key = licenseKey

        let _: EmptyResponse = try await post("/api/pro/themes/save", body: request)
    }

    /// Get user's custom themes from cloud
    func getThemes() async throws -> [CustomTheme] {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let response: ThemesResponse = try await get(
            "/api/pro/themes",
            params: ["license_key": licenseKey]
        )

        return response.themes
    }

    // MARK: - Git Hooks

    /// Get available hook templates
    func getHookTemplates() async throws -> [HookTemplate] {
        guard let licenseKey = getCurrentLicenseKey() else {
            throw ProAPIError.noLicense
        }

        let response: HookTemplatesResponse = try await get(
            "/api/pro/hooks/templates",
            params: ["license_key": licenseKey]
        )

        return response.templates
    }

    // MARK: - Helper Methods

    private func getCurrentLicenseKey() -> String? {
        guard licenseValidator.isLicenseValid,
              let licenseInfo = licenseValidator.licenseInfo else {
            return nil
        }
        return licenseInfo.key
    }

    private func get<T: Decodable>(
        _ endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        var urlComponents = URLComponents(string: baseURL + endpoint)!
        urlComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = urlComponents.url else {
            throw ProAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProAPIError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            throw ProAPIError.licenseInvalid
        }

        if httpResponse.statusCode == 429 {
            throw ProAPIError.rateLimitExceeded
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProAPIError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Encodable, R: Decodable>(
        _ endpoint: String,
        body: T
    ) async throws -> R {
        guard let url = URL(string: baseURL + endpoint) else {
            throw ProAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        await MainActor.run {
            self.isLoading = true
        }

        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProAPIError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            throw ProAPIError.licenseInvalid
        }

        if httpResponse.statusCode == 429 {
            throw ProAPIError.rateLimitExceeded
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ProAPIError.serverErrorWithMessage(errorResponse.error)
            }
            throw ProAPIError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(R.self, from: data)
    }
}

// MARK: - Request/Response Models

// AI Commit
struct AICommitRequest: Codable {
    let diff: String
    let context: CommitContext?
    let license_key: String
}

struct CommitContext: Codable {
    let branch: String?
    let recentCommits: [String]?
    let files: [String]?
}

struct AICommitResponse: Codable {
    let message: String
    let confidence: Double?
}

// AI Conflict Resolution
struct AIConflictRequest: Codable {
    let file: String
    let ours: String
    let theirs: String
    let base: String?
    let license_key: String
}

struct ConflictResolution: Codable {
    let resolved: String
    let explanation: String
    let confidence: Double
}

// AI Code Review
struct AIReviewRequest: Codable {
    let diff: String
    let files: [String]
    let license_key: String
}

struct CodeReview: Codable {
    let issues: [ReviewIssue]
    let suggestions: [String]
    let security: [SecurityIssue]
}

struct ReviewIssue: Codable {
    let severity: String // "error", "warning", "info"
    let file: String
    let line: Int?
    let message: String
}

struct SecurityIssue: Codable {
    let type: String
    let file: String
    let line: Int?
    let description: String
}

// AI Providers
struct AIProvider: Codable, Identifiable {
    let id: String
    let name: String
    let models: [String]
    let available: Bool
}

struct ProvidersResponse: Codable {
    let providers: [AIProvider]
}

struct SetProviderRequest: Codable {
    let provider: String
    let license_key: String
}

// OAuth
struct OAuthURLResponse: Codable {
    let url: String
}

// Jira
struct LinkIssueRequest: Codable {
    let issue_key: String
    let commit_hash: String
    let license_key: String
}

struct JiraIssue: Codable, Identifiable {
    let id: String
    let key: String
    let summary: String
    let status: String
    let assignee: String?
}

struct JiraIssuesResponse: Codable {
    let issues: [JiraIssue]
}

// Linear
struct SyncLinearRequest: Codable {
    let issue_id: String
    let commit_hash: String
    let license_key: String
}

// Themes
struct CustomTheme: Codable, Identifiable {
    let id: String?
    let name: String
    let colors: ThemeColors
    var license_key: String?
}

struct ThemeColors: Codable {
    let background: String
    let foreground: String
    let accent: String
    let secondary: String
}

struct ThemesResponse: Codable {
    let themes: [CustomTheme]
}

// Hooks
struct HookTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let script: String
    let type: String // "pre-commit", "post-commit", etc.
}

struct HookTemplatesResponse: Codable {
    let templates: [HookTemplate]
}

// Generic
struct EmptyResponse: Codable {}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Errors

enum ProAPIError: LocalizedError {
    case noLicense
    case licenseInvalid
    case rateLimitExceeded
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case serverErrorWithMessage(String)

    var errorDescription: String? {
        switch self {
        case .noLicense:
            return "No valid Pro license found. Please activate your license first."
        case .licenseInvalid:
            return "Your license is not valid or has expired."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (\(code))"
        case .serverErrorWithMessage(let message):
            return message
        }
    }
}

// MARK: - Usage Example

/*
// In your view:
@StateObject private var proAPI = ProAPIClient.shared

// Generate AI commit:
Button("Generate AI Commit") {
    Task {
        do {
            let message = try await proAPI.generateCommitMessage(diff: currentDiff)
            commitMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
.disabled(proAPI.isLoading)

// Resolve conflict:
Button("AI Resolve Conflict") {
    Task {
        do {
            let resolution = try await proAPI.resolveConflict(
                file: conflictFile,
                ours: oursContent,
                theirs: theirsContent,
                base: baseContent
            )
            resolvedContent = resolution.resolved
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
*/
