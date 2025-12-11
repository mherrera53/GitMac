import Foundation
import Security
import CommonCrypto
import CryptoKit

/// Manages secure storage of credentials
/// Uses encrypted file storage to avoid keychain password prompts on unsigned apps
actor KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.gitmac.credentials"

    // In-memory cache
    private var cache: [String: String] = [:]
    private var cacheLoaded = false

    // File-based encrypted storage
    private let storageURL: URL
    private let encryptionKey: SymmetricKey

    private init() {
        // Setup storage directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("GitMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        storageURL = appDir.appendingPathComponent(".credentials.enc")

        // Generate or load encryption key based on machine ID
        encryptionKey = Self.deriveKey()

        // Load existing data
        loadFromFile()
    }

    /// Derive a key from machine-specific identifier
    private static func deriveKey() -> SymmetricKey {
        // Use hardware UUID as base for key derivation
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(platformExpert) }

        var serialNumber = "GitMac-Default-Key-2024"
        if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault, 0
        )?.takeUnretainedValue() as? String {
            serialNumber = serialNumberAsCFString
        }

        // Derive key using SHA256
        let keyData = SHA256.hash(data: Data(serialNumber.utf8))
        return SymmetricKey(data: keyData)
    }

    // MARK: - Encrypted File Storage

    private func loadFromFile() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let encryptedData = try? Data(contentsOf: storageURL) else {
            return
        }

        guard let decrypted = decrypt(encryptedData),
              let dict = try? JSONDecoder().decode([String: String].self, from: decrypted) else {
            return
        }

        cache = dict
        cacheLoaded = true
    }

    private func saveToFile() {
        guard let jsonData = try? JSONEncoder().encode(cache),
              let encrypted = encrypt(jsonData) else {
            return
        }

        try? encrypted.write(to: storageURL, options: [.atomic, .completeFileProtection])
    }

    private func encrypt(_ data: Data) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            return sealedBox.combined
        } catch {
            return nil
        }
    }

    private func decrypt(_ data: Data) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: encryptionKey)
        } catch {
            return nil
        }
    }

    // MARK: - Public API

    /// Preload cache (already loaded in init, but kept for compatibility)
    func preloadCache() {
        if !cacheLoaded {
            loadFromFile()
            cacheLoaded = true
        }
    }

    /// Save a string value
    func save(key: String, value: String) throws {
        cache[key] = value
        saveToFile()
    }

    /// Get a string value
    func get(key: String) throws -> String? {
        return cache[key]
    }

    /// Delete a value
    func delete(key: String) throws {
        cache.removeValue(forKey: key)
        saveToFile()
    }

    /// Check if a key exists
    func exists(key: String) -> Bool {
        return cache[key] != nil
    }

    // MARK: - GitHub Credentials

    private let githubTokenKey = "github_token"
    private let githubUsernameKey = "github_username"

    func saveGitHubToken(_ token: String, username: String? = nil) throws {
        try save(key: githubTokenKey, value: token)
        if let username = username {
            try save(key: githubUsernameKey, value: username)
        }
    }

    func getGitHubToken() throws -> String? {
        try get(key: githubTokenKey)
    }

    func getGitHubUsername() throws -> String? {
        try get(key: githubUsernameKey)
    }

    func deleteGitHubCredentials() throws {
        try delete(key: githubTokenKey)
        try delete(key: githubUsernameKey)
    }

    var hasGitHubCredentials: Bool {
        exists(key: githubTokenKey)
    }

    // MARK: - AI API Keys

    enum AIProvider: String, CaseIterable {
        case openai = "openai"
        case anthropic = "anthropic"
        case gemini = "gemini"

        var keyName: String { "\(rawValue)_api_key" }

        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .gemini: return "Google Gemini"
            }
        }

        var models: [String] {
            switch self {
            case .openai: return ["gpt-4-turbo", "gpt-4", "gpt-3.5-turbo"]
            case .anthropic: return ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"]
            case .gemini: return ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-pro"]
            }
        }
    }

    func saveAIKey(provider: AIProvider, key: String) throws {
        try save(key: provider.keyName, value: key)
    }

    func getAIKey(provider: AIProvider) throws -> String? {
        try get(key: provider.keyName)
    }

    func deleteAIKey(provider: AIProvider) throws {
        try delete(key: provider.keyName)
    }

    func hasAIKey(provider: AIProvider) -> Bool {
        exists(key: provider.keyName)
    }

    func configuredAIProviders() -> [AIProvider] {
        AIProvider.allCases.filter { hasAIKey(provider: $0) }
    }

    // MARK: - Preferred AI Provider

    private let preferredAIProviderKey = "preferred_ai_provider"
    private let preferredAIModelKey = "preferred_ai_model"

    func savePreferredAIProvider(_ provider: AIProvider, model: String) throws {
        try save(key: preferredAIProviderKey, value: provider.rawValue)
        try save(key: preferredAIModelKey, value: model)
    }

    func getPreferredAIProvider() -> (provider: AIProvider, model: String)? {
        guard let providerStr = try? get(key: preferredAIProviderKey),
              let provider = AIProvider(rawValue: providerStr),
              let model = try? get(key: preferredAIModelKey) else {
            return nil
        }
        return (provider, model)
    }

    // MARK: - Git Credentials

    func saveGitCredentials(remote: String, username: String, password: String) throws {
        let key = "git_\(remote.sha256Hash)"
        try save(key: key, value: "\(username):\(password)")
    }

    func getGitCredentials(remote: String) throws -> (username: String, password: String)? {
        let key = "git_\(remote.sha256Hash)"
        guard let value = try get(key: key) else { return nil }
        let parts = value.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    func deleteGitCredentials(remote: String) throws {
        try delete(key: "git_\(remote.sha256Hash)")
    }

    // MARK: - Linear

    private let linearTokenKey = "linear_token"

    func saveLinearToken(_ token: String) throws {
        try save(key: linearTokenKey, value: token)
    }

    func getLinearToken() throws -> String? {
        try get(key: linearTokenKey)
    }

    func deleteLinearToken() throws {
        try delete(key: linearTokenKey)
    }

    // MARK: - Jira

    private let jiraTokenKey = "jira_token"
    private let jiraCloudIdKey = "jira_cloud_id"
    private let jiraSiteUrlKey = "jira_site_url"

    func saveJiraToken(_ token: String) throws {
        try save(key: jiraTokenKey, value: token)
    }

    func getJiraToken() throws -> String? {
        try get(key: jiraTokenKey)
    }

    func saveJiraCloudId(_ cloudId: String) throws {
        try save(key: jiraCloudIdKey, value: cloudId)
    }

    func getJiraCloudId() throws -> String? {
        try get(key: jiraCloudIdKey)
    }

    func saveJiraSiteUrl(_ url: String) throws {
        try save(key: jiraSiteUrlKey, value: url)
    }

    func getJiraSiteUrl() throws -> String? {
        try get(key: jiraSiteUrlKey)
    }

    func deleteJiraToken() throws {
        try delete(key: jiraTokenKey)
    }

    func deleteJiraCloudId() throws {
        try delete(key: jiraCloudIdKey)
    }

    func deleteJiraCredentials() throws {
        try delete(key: jiraTokenKey)
        try delete(key: jiraCloudIdKey)
        try delete(key: jiraSiteUrlKey)
    }

    // MARK: - Notion

    private let notionTokenKey = "notion_token"

    func saveNotionToken(_ token: String) throws {
        try save(key: notionTokenKey, value: token)
    }

    func getNotionToken() throws -> String? {
        try get(key: notionTokenKey)
    }

    func deleteNotionToken() throws {
        try delete(key: notionTokenKey)
    }
}

// MARK: - String Hash Extension

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
