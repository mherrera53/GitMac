import Foundation
import AppKit

/// GitHub OAuth 2.0 with Device Flow
/// This allows authentication with GitHub including 2FA support
/// https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow
actor GitHubOAuth {
    // GitHub OAuth App Client ID
    // To use this feature, register your own OAuth App at:
    // GitHub Settings > Developer settings > OAuth Apps > New OAuth App
    // Device Flow doesn't require a client secret
    private var clientId: String {
        get {
            (UserDefaults.standard.string(forKey: "GitHubOAuthClientId") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "GitHubOAuthClientId")
        }
    }

    // Scopes to request
    private let scopes = "repo,user,read:org"

    // Endpoints
    private let deviceCodeURL = "https://github.com/login/device/code"
    private let tokenURL = "https://github.com/login/oauth/access_token"

    // State
    private var currentDeviceCode: String?
    private var pollingTask: Task<String, Error>?

    // MARK: - Device Code Response

    struct DeviceCodeResponse: Codable {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let expiresIn: Int
        let interval: Int

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationUri = "verification_uri"
            case expiresIn = "expires_in"
            case interval
        }
    }

    // MARK: - Token Response

    struct TokenResponse: Codable {
        let accessToken: String
        let tokenType: String
        let scope: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case scope
        }
    }

    // MARK: - Error Response

    struct ErrorResponse: Codable {
        let error: String
        let errorDescription: String?
        let errorUri: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
            case errorUri = "error_uri"
        }
    }

    // MARK: - Errors

    enum OAuthError: LocalizedError {
        case noClientId
        case invalidResponse
        case authorizationPending
        case slowDown
        case accessDenied
        case expiredToken
        case unsupportedGrantType
        case incorrectClientCredentials
        case incorrectDeviceCode
        case unknown(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .noClientId:
                return "No GitHub OAuth Client ID configured. Please add your Client ID in Settings."
            case .invalidResponse:
                return "Invalid response from GitHub"
            case .authorizationPending:
                return "Waiting for authorization..."
            case .slowDown:
                return "Too many requests, slowing down..."
            case .accessDenied:
                return "Access denied by user"
            case .expiredToken:
                return "The device code has expired. Please try again."
            case .unsupportedGrantType:
                return "Unsupported grant type"
            case .incorrectClientCredentials:
                return "Incorrect client credentials"
            case .incorrectDeviceCode:
                return "Incorrect device code"
            case .unknown(let msg):
                return "Unknown error: \(msg)"
            case .cancelled:
                return "Authentication cancelled"
            }
        }
    }

    // MARK: - Configuration

    func setClientId(_ id: String) {
        self.clientId = id
    }

    func getClientId() -> String {
        return clientId
    }

    var hasClientId: Bool {
        !clientId.isEmpty
    }

    // MARK: - Step 1: Request Device Code

    func requestDeviceCode() async throws -> DeviceCodeResponse {
        guard !clientId.isEmpty else {
            throw OAuthError.noClientId
        }

        var request = URLRequest(url: URL(string: deviceCodeURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&scope=\(scopes)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        // Check for error status
        if httpResponse.statusCode != 200 {
            if let errorStr = String(data: data, encoding: .utf8) {
                throw OAuthError.unknown("HTTP \(httpResponse.statusCode): \(errorStr)")
            }
            throw OAuthError.invalidResponse
        }

        // Try JSON first
        if let deviceCode = try? JSONDecoder().decode(DeviceCodeResponse.self, from: data) {
            currentDeviceCode = deviceCode.deviceCode
            return deviceCode
        }

        // Try form-urlencoded (GitHub sometimes returns this)
        if let responseStr = String(data: data, encoding: .utf8) {
            let params = parseFormURLEncoded(responseStr)
            if let deviceCode = params["device_code"],
               let userCode = params["user_code"],
               let verificationUri = params["verification_uri"],
               let expiresIn = params["expires_in"].flatMap({ Int($0) }),
               let interval = params["interval"].flatMap({ Int($0) }) {
                let response = DeviceCodeResponse(
                    deviceCode: deviceCode,
                    userCode: userCode,
                    verificationUri: verificationUri,
                    expiresIn: expiresIn,
                    interval: interval
                )
                currentDeviceCode = response.deviceCode
                return response
            }

            // Check for error in response
            if let error = params["error"] {
                throw OAuthError.unknown(error)
            }
        }

        throw OAuthError.invalidResponse
    }

    private func parseFormURLEncoded(_ string: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in string.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Step 2: Poll for Access Token

    func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        var currentInterval = interval

        while true {
            // Wait before polling
            try await Task.sleep(nanoseconds: UInt64(currentInterval) * 1_000_000_000)

            // Check if cancelled
            try Task.checkCancellation()

            // Make request
            var request = URLRequest(url: URL(string: tokenURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            request.httpBody = body.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OAuthError.invalidResponse
            }

            // Try to decode as token response
            if httpResponse.statusCode == 200 {
                // Could be success or error
                if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                    return tokenResponse.accessToken
                }

                // Check for error
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    switch errorResponse.error {
                    case "authorization_pending":
                        // Keep polling
                        continue
                    case "slow_down":
                        // Increase interval
                        currentInterval += 5
                        continue
                    case "access_denied":
                        throw OAuthError.accessDenied
                    case "expired_token":
                        throw OAuthError.expiredToken
                    default:
                        throw OAuthError.unknown(errorResponse.error)
                    }
                }
            }

            // Try to decode error response for non-200
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                switch errorResponse.error {
                case "authorization_pending":
                    continue
                case "slow_down":
                    currentInterval += 5
                    continue
                case "access_denied":
                    throw OAuthError.accessDenied
                case "expired_token":
                    throw OAuthError.expiredToken
                default:
                    throw OAuthError.unknown(errorResponse.error)
                }
            }

            throw OAuthError.invalidResponse
        }
    }

    // MARK: - Complete Flow

    /// Start the full authentication flow
    /// Returns the device code response so UI can display the user code
    func startAuthentication() async throws -> DeviceCodeResponse {
        let deviceCode = try await requestDeviceCode()
        return deviceCode
    }

    /// Wait for user to complete authentication
    /// Call this after startAuthentication and after user has been shown the code
    func waitForAuthentication(deviceCode: DeviceCodeResponse) async throws -> String {
        return try await pollForToken(deviceCode: deviceCode.deviceCode, interval: deviceCode.interval)
    }

    /// Cancel any ongoing authentication
    func cancelAuthentication() {
        pollingTask?.cancel()
        pollingTask = nil
        currentDeviceCode = nil
    }

    // MARK: - Helper

    /// Open GitHub device verification page in browser
    func openVerificationPage() {
        if let url = URL(string: "https://github.com/login/device") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Singleton

extension GitHubOAuth {
    static let shared = GitHubOAuth()
}
