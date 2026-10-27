import Foundation
import AppKit

/// GitHub Device Flow. The registered OAuth app must have Device Flow enabled.
actor GitHubOAuth {
    private let keychain: KeychainManager
    private let defaults: UserDefaults
    private let session: URLSession
    private let uptime: @Sendable () -> TimeInterval
    private let pause: @Sendable (TimeInterval) async throws -> Void
    private var clientIdCache: String?
    private var currentDeviceCode: String?
    private var activeClientId: String?
    private var deadline: TimeInterval = 0
    private var generation = UUID()
    private var pollingTask: Task<String, Error>?

    init(keychain: KeychainManager = .shared, defaults: UserDefaults = .standard,
         session: URLSession = .shared,
         uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         pause: @escaping @Sendable (TimeInterval) async throws -> Void = {
             try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
         }) {
        self.keychain = keychain
        self.defaults = defaults
        self.session = session
        self.uptime = uptime
        self.pause = pause
    }

    private func loadClientId() async throws -> String {
        if let clientIdCache { return clientIdCache }
        do {
            if let value = try await keychain.get(key: "github_oauth_client_id"), !value.isEmpty {
                clientIdCache = value
                return value
            }
        } catch CredentialStorageError.migrationRequiresApproval {
            // Importing old encrypted secrets is separate from saving a new public Client ID.
        }
        if let legacy = defaults.string(forKey: "GitHubOAuthClientId"),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
            try await keychain.save(key: "github_oauth_client_id", value: trimmed)
            clientIdCache = trimmed
            defaults.removeObject(forKey: "GitHubOAuthClientId")
            return trimmed
        }
        return ""
    }

    func setClientId(_ id: String) async throws {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OAuthError.noClientId }
        try await keychain.save(key: "github_oauth_client_id", value: trimmed)
        clientIdCache = trimmed
        defaults.removeObject(forKey: "GitHubOAuthClientId")
        cancelAuthentication()
    }

    func getClientId() async throws -> String { try await loadClientId() }
    var hasClientId: Bool { get async throws { try await !loadClientId().isEmpty } }

    struct DeviceCodeResponse: Codable, Sendable {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let expiresIn: Int
        let interval: Int
        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code", userCode = "user_code", verificationUri = "verification_uri"
            case expiresIn = "expires_in", interval
        }
    }

    enum OAuthError: LocalizedError {
        case noClientId, invalidResponse, accessDenied, expiredToken, cancelled, deviceFlowDisabled
        case unknown(String)
        var errorDescription: String? {
            switch self {
            case .noClientId: return "Save your GitHub OAuth App Client ID below before signing in."
            case .invalidResponse: return "Invalid response from GitHub. Please retry."
            case .accessDenied: return "GitHub authorization was denied. Please retry if this was unintended."
            case .expiredToken: return "The GitHub code expired. Start sign-in again to get a new code."
            case .cancelled: return "Authentication cancelled."
            case .deviceFlowDisabled: return "Enable Device Flow in your GitHub OAuth App settings, save those settings on GitHub, then try again."
            case .unknown(let message): return message
            }
        }
    }

    private func parameters(_ data: Data) throws -> [String: String] {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json.reduce(into: [:]) { result, pair in
                if let string = pair.value as? String { result[pair.key] = string }
                else if let number = pair.value as? NSNumber { result[pair.key] = number.stringValue }
            }
        }
        guard let text = String(data: data, encoding: .utf8) else { throw OAuthError.invalidResponse }
        return text.split(separator: "&").reduce(into: [:]) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let key = String(parts[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                let value = String(parts[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                if let key, let value { result[key] = value }
            }
        }
    }

    private func responseError(_ code: String) -> OAuthError {
        switch code {
        case "device_flow_disabled": return .deviceFlowDisabled
        case "access_denied": return .accessDenied
        case "expired_token": return .expiredToken
        case "incorrect_client_credentials": return .unknown("GitHub rejected this Client ID. Check the OAuth App's Client ID and retry.")
        case "incorrect_device_code": return .unknown("GitHub rejected this device code. Start sign-in again.")
        default: return .invalidResponse
        }
    }

    private func post(_ path: String, fields: [String: String]) async throws -> [String: String] {
        var request = URLRequest(url: URL(string: "https://github.com/login/" + path)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.httpBody = fields.sorted { $0.key < $1.key }.map {
            $0.key.addingPercentEncoding(withAllowedCharacters: allowed)! + "=" + $0.value.addingPercentEncoding(withAllowedCharacters: allowed)!
        }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw OAuthError.invalidResponse }
        let values = try parameters(data)
        if let error = values["error"], !["authorization_pending", "slow_down"].contains(error) {
            throw responseError(error)
        }
        guard http.statusCode == 200 else { throw OAuthError.unknown("GitHub sign-in failed (HTTP \(http.statusCode)). Please retry.") }
        return values
    }

    func requestDeviceCode() async throws -> DeviceCodeResponse {
        cancelAuthentication()
        let attempt = generation
        let clientId = try await loadClientId()
        guard generation == attempt else { throw OAuthError.cancelled }
        guard !clientId.isEmpty else { throw OAuthError.noClientId }
        let values = try await post("device/code", fields: ["client_id": clientId, "scope": "repo read:user read:org"])
        guard generation == attempt else { throw OAuthError.cancelled }
        guard let code = values["device_code"], !code.isEmpty,
              let user = values["user_code"], !user.isEmpty,
              values["verification_uri"] == "https://github.com/login/device",
              let expires = values["expires_in"].flatMap(Int.init), (1...3600).contains(expires),
              let interval = values["interval"].flatMap(Int.init), interval > 0, interval <= expires else {
            throw OAuthError.invalidResponse
        }
        currentDeviceCode = code
        activeClientId = clientId
        deadline = uptime() + TimeInterval(expires)
        return DeviceCodeResponse(deviceCode: code, userCode: user, verificationUri: "https://github.com/login/device", expiresIn: expires, interval: interval)
    }

    func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        guard currentDeviceCode == deviceCode, let clientId = activeClientId, interval > 0 else { throw OAuthError.cancelled }
        let attempt = generation
        var delay = TimeInterval(interval)
        while true {
            try Task.checkCancellation()
            guard generation == attempt else { throw OAuthError.cancelled }
            guard uptime() + delay < deadline else { throw OAuthError.expiredToken }
            try await pause(delay)
            try Task.checkCancellation()
            guard generation == attempt else { throw OAuthError.cancelled }
            guard uptime() < deadline else { throw OAuthError.expiredToken }
            let values = try await post("oauth/access_token", fields: ["client_id": clientId, "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"])
            guard generation == attempt else { throw OAuthError.cancelled }
            guard uptime() < deadline else { throw OAuthError.expiredToken }
            if let error = values["error"] {
                if error == "authorization_pending" { continue }
                if error == "slow_down" {
                    delay = max(delay + 5, Double(values["interval"] ?? "") ?? 0)
                    continue
                }
                throw responseError(error)
            }
            guard let token = values["access_token"], !token.isEmpty,
                  values["token_type"]?.lowercased() == "bearer" else { throw OAuthError.invalidResponse }
            currentDeviceCode = nil
            activeClientId = nil
            return token
        }
    }

    func startAuthentication() async throws -> DeviceCodeResponse { try await requestDeviceCode() }

    func waitForAuthentication(deviceCode: DeviceCodeResponse) async throws -> String {
        guard pollingTask == nil, currentDeviceCode == deviceCode.deviceCode else { throw OAuthError.cancelled }
        let attempt = generation
        let task = Task { try await self.pollForToken(deviceCode: deviceCode.deviceCode, interval: deviceCode.interval) }
        pollingTask = task
        defer { if generation == attempt { pollingTask = nil } }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    func cancelAuthentication() {
        generation = UUID()
        pollingTask?.cancel()
        pollingTask = nil
        currentDeviceCode = nil
        activeClientId = nil
    }

    func openVerificationPage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/login/device")!)
    }
}

extension GitHubOAuth { static let shared = GitHubOAuth() }
