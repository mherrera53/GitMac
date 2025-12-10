import Foundation
import KeychainAccess

/// Manages secure storage of credentials and API keys
actor KeychainManager {
    private let keychain: Keychain

    // In-memory cache to reduce Keychain access prompts
    private var cache: [String: String] = [:]
    private var cacheLoaded = false

    static let shared = KeychainManager()

    private init() {
        keychain = Keychain(service: "com.gitmac.credentials")
            .accessibility(.whenUnlocked)
    }

    // MARK: - Generic Operations

    /// Save a string value
    func save(key: String, value: String) throws {
        cache[key] = value
        try keychain.set(value, key: key)
    }

    /// Get a string value (cached)
    func get(key: String) throws -> String? {
        if let cached = cache[key] {
            return cached
        }
        let value = try keychain.get(key)
        if let value = value {
            cache[key] = value
        }
        return value
    }

    /// Delete a value
    func delete(key: String) throws {
        cache.removeValue(forKey: key)
        try keychain.remove(key)
    }

    /// Check if a key exists
    func exists(key: String) -> Bool {
        if cache[key] != nil { return true }
        return (try? keychain.get(key)) != nil
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

    // MARK: - Linear

    private let linearTokenKey = "linear_token"

    func saveLinearToken(_ token: String) throws {
        try keychain.set(token, key: linearTokenKey)
    }

    func getLinearToken() throws -> String? {
        try keychain.get(linearTokenKey)
    }

    func deleteLinearToken() throws {
        try keychain.remove(linearTokenKey)
    }

    // MARK: - Jira

    private let jiraTokenKey = "jira_token"
    private let jiraCloudIdKey = "jira_cloud_id"
    private let jiraSiteUrlKey = "jira_site_url"

    func saveJiraToken(_ token: String) throws {
        try keychain.set(token, key: jiraTokenKey)
    }

    func getJiraToken() throws -> String? {
        try keychain.get(jiraTokenKey)
    }

    func saveJiraCloudId(_ cloudId: String) throws {
        try keychain.set(cloudId, key: jiraCloudIdKey)
    }

    func getJiraCloudId() throws -> String? {
        try keychain.get(jiraCloudIdKey)
    }

    func saveJiraSiteUrl(_ url: String) throws {
        try keychain.set(url, key: jiraSiteUrlKey)
    }

    func getJiraSiteUrl() throws -> String? {
        try keychain.get(jiraSiteUrlKey)
    }

    func deleteJiraToken() throws {
        try keychain.remove(jiraTokenKey)
    }

    func deleteJiraCloudId() throws {
        try keychain.remove(jiraCloudIdKey)
    }

    func deleteJiraCredentials() throws {
        try keychain.remove(jiraTokenKey)
        try keychain.remove(jiraCloudIdKey)
        try keychain.remove(jiraSiteUrlKey)
    }

    // MARK: - Notion

    private let notionTokenKey = "notion_token"

    func saveNotionToken(_ token: String) throws {
        try keychain.set(token, key: notionTokenKey)
    }

    func getNotionToken() throws -> String? {
        try keychain.get(notionTokenKey)
    }

    func deleteNotionToken() throws {
        try keychain.remove(notionTokenKey)
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
