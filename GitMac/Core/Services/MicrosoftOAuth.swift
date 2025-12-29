import Foundation
import AppKit

// MARK: - Microsoft OAuth Service

/// OAuth 2.0 Device Code Flow for Microsoft Graph API
actor MicrosoftOAuth {
    static let shared = MicrosoftOAuth()

    // Azure AD endpoints
    private let authorizeURL = "https://login.microsoftonline.com/common/oauth2/v2.0/devicecode"
    private let tokenURL = "https://login.microsoftonline.com/common/oauth2/v2.0/token"

    // Default client ID for multi-tenant apps (you can register your own)
    // This is a placeholder - user should register their own app
    private var clientId: String?

    // Required scopes for Planner
    private let scopes = "offline_access Tasks.ReadWrite Group.Read.All User.Read"

    private var isPolling = false

    private init() {}

    // MARK: - Configuration

    func setClientId(_ id: String) async {
        clientId = id
        try? await KeychainManager.shared.saveMicrosoftClientId(id)
    }

    func loadClientId() async -> String? {
        if let id = clientId { return id }
        clientId = try? await KeychainManager.shared.getMicrosoftClientId()
        return clientId
    }

    var hasClientId: Bool {
        get async {
            await loadClientId() != nil
        }
    }

    // MARK: - Device Code Flow

    struct DeviceCodeResponse: Codable {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let expiresIn: Int
        let interval: Int
        let message: String

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationUri = "verification_uri"
            case expiresIn = "expires_in"
            case interval
            case message
        }
    }

    struct TokenResponse: Codable {
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

    struct TokenErrorResponse: Codable {
        let error: String
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }

    // MARK: - Authentication Flow

    /// Step 1: Request device code
    func startAuthentication() async throws -> DeviceCodeResponse {
        guard let clientId = await loadClientId() else {
            throw MicrosoftOAuthError.clientIdNotConfigured
        }

        var request = URLRequest(url: URL(string: authorizeURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MicrosoftOAuthError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
                throw MicrosoftOAuthError.serverError(errorResponse.errorDescription ?? errorResponse.error)
            }
            throw MicrosoftOAuthError.invalidResponse
        }

        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    /// Step 2: Open browser for user to enter code
    nonisolated func openVerificationPage(uri: String) {
        if let url = URL(string: uri) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Step 3: Poll for access token
    func waitForAuthentication(deviceCode: DeviceCodeResponse) async throws -> TokenResponse {
        guard let clientId = await loadClientId() else {
            throw MicrosoftOAuthError.clientIdNotConfigured
        }

        isPolling = true
        let interval = TimeInterval(deviceCode.interval)
        let expiresAt = Date().addingTimeInterval(TimeInterval(deviceCode.expiresIn))

        while isPolling && Date() < expiresAt {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

            if !isPolling { throw MicrosoftOAuthError.cancelled }

            var request = URLRequest(url: URL(string: tokenURL)!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let body = "client_id=\(clientId)&grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=\(deviceCode.deviceCode)"
            request.httpBody = body.data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: request)

            // Check for success
            if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                isPolling = false
                return tokenResponse
            }

            // Check for error
            if let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
                switch errorResponse.error {
                case "authorization_pending":
                    // User hasn't authorized yet, keep polling
                    continue
                case "slow_down":
                    // Slow down polling
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                case "expired_token":
                    throw MicrosoftOAuthError.expired
                case "authorization_declined":
                    throw MicrosoftOAuthError.denied
                default:
                    throw MicrosoftOAuthError.serverError(errorResponse.errorDescription ?? errorResponse.error)
                }
            }
        }

        throw MicrosoftOAuthError.expired
    }

    func cancelAuthentication() {
        isPolling = false
    }

    // MARK: - Token Refresh

    func refreshAccessToken() async throws -> TokenResponse {
        guard let clientId = await loadClientId() else {
            throw MicrosoftOAuthError.clientIdNotConfigured
        }

        guard let refreshToken = try? await KeychainManager.shared.getMicrosoftRefreshToken() else {
            throw MicrosoftOAuthError.noRefreshToken
        }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&grant_type=refresh_token&refresh_token=\(refreshToken)&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MicrosoftOAuthError.refreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Save new tokens
        try await KeychainManager.shared.savePlannerToken(tokenResponse.accessToken)
        if let newRefreshToken = tokenResponse.refreshToken {
            try await KeychainManager.shared.saveMicrosoftRefreshToken(newRefreshToken)
        }

        return tokenResponse
    }

    // MARK: - Full Authentication

    /// Complete OAuth flow - returns access token
    func authenticate() async throws -> String {
        let deviceCode = try await startAuthentication()

        // Open browser
        openVerificationPage(uri: deviceCode.verificationUri)

        // Wait for user to authorize
        let tokenResponse = try await waitForAuthentication(deviceCode: deviceCode)

        // Save tokens
        try await KeychainManager.shared.savePlannerToken(tokenResponse.accessToken)
        if let refreshToken = tokenResponse.refreshToken {
            try await KeychainManager.shared.saveMicrosoftRefreshToken(refreshToken)
        }

        // Update Planner service
        await MicrosoftPlannerService.shared.setAccessToken(tokenResponse.accessToken)

        return tokenResponse.accessToken
    }
}

// MARK: - Errors

enum MicrosoftOAuthError: Error, LocalizedError {
    case clientIdNotConfigured
    case invalidResponse
    case serverError(String)
    case expired
    case denied
    case cancelled
    case noRefreshToken
    case refreshFailed

    var errorDescription: String? {
        switch self {
        case .clientIdNotConfigured:
            return "Microsoft OAuth Client ID not configured. Register an app in Azure AD."
        case .invalidResponse:
            return "Invalid response from Microsoft"
        case .serverError(let message):
            return "Microsoft error: \(message)"
        case .expired:
            return "Authentication request expired. Please try again."
        case .denied:
            return "Authentication was denied by user"
        case .cancelled:
            return "Authentication was cancelled"
        case .noRefreshToken:
            return "No refresh token available. Please sign in again."
        case .refreshFailed:
            return "Failed to refresh access token. Please sign in again."
        }
    }
}

// MARK: - Keychain Extensions

extension KeychainManager {
    func saveMicrosoftClientId(_ id: String) throws {
        try save(key: "microsoft_client_id", value: id)
    }

    func getMicrosoftClientId() throws -> String? {
        try get(key: "microsoft_client_id")
    }

    func saveMicrosoftRefreshToken(_ token: String) throws {
        try save(key: "microsoft_refresh_token", value: token)
    }

    func getMicrosoftRefreshToken() throws -> String? {
        try get(key: "microsoft_refresh_token")
    }

    func deleteMicrosoftTokens() throws {
        try delete(key: "planner_access_token")
        try delete(key: "microsoft_refresh_token")
        try delete(key: "microsoft_client_id")
    }
}
