import Foundation
import KeychainAccess

/// Manages secure storage of credentials and API keys
actor KeychainManager {
    private let keychain: Keychain

    static let shared = KeychainManager()

    private init() {
        keychain = Keychain(service: "com.gitmac.credentials")
            .accessibility(.whenUnlocked)
    }

    // MARK: - Generic Operations

    /// Save a string value
    func save(key: String, value: String) throws {
        try keychain.set(value, key: key)
    }

    /// Get a string value
    func get(key: String) throws -> String? {
        try keychain.get(key)
    }

    /// Delete a value
    func delete(key: String) throws {
        try keychain.remove(key)
    }

    /// Check if a key exists
    func exists(key: String) -> Bool {
        (try? keychain.get(key)) != nil
    }

    // MARK: - GitHub Credentials

    private let githubTokenKey = "github_token"
    private let githubUsernameKey = "github_username"

    /// Save GitHub personal access token
    func saveGitHubToken(_ token: String, username: String? = nil) throws {
        try keychain.set(token, key: githubTokenKey)
        if let username = username {
            try keychain.set(username, key: githubUsernameKey)
        }
    }

    /// Get GitHub token
    func getGitHubToken() throws -> String? {
        try keychain.get(githubTokenKey)
    }

    /// Get GitHub username
    func getGitHubUsername() throws -> String? {
        try keychain.get(githubUsernameKey)
    }

    /// Delete GitHub credentials
    func deleteGitHubCredentials() throws {
        try keychain.remove(githubTokenKey)
        try keychain.remove(githubUsernameKey)
    }

    /// Check if GitHub is configured
    var hasGitHubCredentials: Bool {
        exists(key: githubTokenKey)
    }

    // MARK: - AI API Keys

    enum AIProvider: String, CaseIterable {
        case openai = "openai"
        case anthropic = "anthropic"
        case gemini = "gemini"

        var keyName: String {
            "\(rawValue)_api_key"
        }

        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .gemini: return "Google Gemini"
            }
        }

        var models: [String] {
            switch self {
            case .openai:
                return ["gpt-4-turbo", "gpt-4", "gpt-3.5-turbo"]
            case .anthropic:
                return ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"]
            case .gemini:
                return ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-pro"]
            }
        }
    }

    /// Save AI API key
    func saveAIKey(provider: AIProvider, key: String) throws {
        try keychain.set(key, key: provider.keyName)
    }

    /// Get AI API key
    func getAIKey(provider: AIProvider) throws -> String? {
        try keychain.get(provider.keyName)
    }

    /// Delete AI API key
    func deleteAIKey(provider: AIProvider) throws {
        try keychain.remove(provider.keyName)
    }

    /// Check if AI provider is configured
    func hasAIKey(provider: AIProvider) -> Bool {
        exists(key: provider.keyName)
    }

    /// Get all configured AI providers
    func configuredAIProviders() -> [AIProvider] {
        AIProvider.allCases.filter { hasAIKey(provider: $0) }
    }

    // MARK: - Preferred AI Provider

    private let preferredAIProviderKey = "preferred_ai_provider"
    private let preferredAIModelKey = "preferred_ai_model"

    /// Save preferred AI provider
    func savePreferredAIProvider(_ provider: AIProvider, model: String) throws {
        try keychain.set(provider.rawValue, key: preferredAIProviderKey)
        try keychain.set(model, key: preferredAIModelKey)
    }

    /// Get preferred AI provider
    func getPreferredAIProvider() -> (provider: AIProvider, model: String)? {
        guard let providerStr = try? keychain.get(preferredAIProviderKey),
              let provider = AIProvider(rawValue: providerStr),
              let model = try? keychain.get(preferredAIModelKey) else {
            return nil
        }
        return (provider, model)
    }

    // MARK: - Git Credentials

    /// Save Git credentials for a remote
    func saveGitCredentials(
        remote: String,
        username: String,
        password: String
    ) throws {
        let key = "git_\(remote.sha256Hash)"
        let value = "\(username):\(password)"
        try keychain.set(value, key: key)
    }

    /// Get Git credentials for a remote
    func getGitCredentials(remote: String) throws -> (username: String, password: String)? {
        let key = "git_\(remote.sha256Hash)"
        guard let value = try keychain.get(key) else { return nil }

        let parts = value.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        return (String(parts[0]), String(parts[1]))
    }

    /// Delete Git credentials for a remote
    func deleteGitCredentials(remote: String) throws {
        let key = "git_\(remote.sha256Hash)"
        try keychain.remove(key)
    }
}

// MARK: - String Hash Extension

extension String {
    var sha256Hash: String {
        guard let data = self.data(using: .utf8) else { return self }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

import CommonCrypto
