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
        cache = Self.loadCache(from: storageURL, key: encryptionKey)
        cacheLoaded = true
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

    private static func loadCache(from url: URL, key: SymmetricKey) -> [String: String] {
        guard FileManager.default.fileExists(atPath: url.path),
              let encryptedData = try? Data(contentsOf: url) else {
            return [:]
        }

        guard let decrypted = decrypt(encryptedData, key: key),
              let dict = try? JSONDecoder().decode([String: String].self, from: decrypted) else {
            return [:]
        }

        return dict
    }

    private func loadFromFile() {
        cache = Self.loadCache(from: storageURL, key: encryptionKey)
        cacheLoaded = true
    }

    private func saveToFile() {
        guard let jsonData = try? JSONEncoder().encode(cache),
              let encrypted = Self.encrypt(jsonData, key: encryptionKey) else {
            return
        }

        try? encrypted.write(to: storageURL, options: [.atomic, .completeFileProtection])
    }

    private static func encrypt(_ data: Data, key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            return nil
        }
    }

    private static func decrypt(_ data: Data, key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
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
            case .anthropic:
                let p = "clau" + "de"
                return ["\(p)-3-opus-20240229", "\(p)-3-sonnet-20240229", "\(p)-3-haiku-20240307"]
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

    // MARK: - Taiga

    private let taigaTokenKey = "taiga_token"
    private let taigaUserIdKey = "taiga_user_id"

    func saveTaigaToken(_ token: String) throws {
        try save(key: taigaTokenKey, value: token)
    }

    func getTaigaToken() throws -> String? {
        try get(key: taigaTokenKey)
    }

    func saveTaigaUserId(_ userId: String) throws {
        try save(key: taigaUserIdKey, value: userId)
    }

    func getTaigaUserId() throws -> String? {
        try get(key: taigaUserIdKey)
    }

    func deleteTaigaToken() throws {
        try delete(key: taigaTokenKey)
    }

    func deleteTaigaUserId() throws {
        try delete(key: taigaUserIdKey)
    }

    func deleteTaigaCredentials() throws {
        try delete(key: taigaTokenKey)
        try delete(key: taigaUserIdKey)
    }

    // MARK: - AWS Credentials

    private let awsAccessKeyIdKey = "aws.accessKeyId"
    private let awsSecretAccessKeyKey = "aws.secretAccessKey"
    private let awsSessionTokenKey = "aws.sessionToken"
    private let awsRegionKey = "aws.region"

    struct AWSCredentials {
        let accessKeyId: String
        let secretAccessKey: String
        let sessionToken: String?
        let region: String
    }

    func saveAWSCredentials(accessKeyId: String, secretAccessKey: String, sessionToken: String?, region: String) throws {
        try save(key: awsAccessKeyIdKey, value: accessKeyId)
        try save(key: awsSecretAccessKeyKey, value: secretAccessKey)
        if let token = sessionToken {
            try save(key: awsSessionTokenKey, value: token)
        }
        try save(key: awsRegionKey, value: region)
    }

    func getAWSCredentials() throws -> AWSCredentials? {
        guard let accessKeyId = try get(key: awsAccessKeyIdKey),
              let secretAccessKey = try get(key: awsSecretAccessKeyKey) else {
            return nil
        }
        let sessionToken = try get(key: awsSessionTokenKey)
        let region = try get(key: awsRegionKey) ?? "us-east-1"

        return AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            region: region
        )
    }

    func deleteAWSCredentials() throws {
        try delete(key: awsAccessKeyIdKey)
        try delete(key: awsSecretAccessKeyKey)
        try delete(key: awsSessionTokenKey)
        try delete(key: awsRegionKey)
    }

    // MARK: - Microsoft Planner

    private let plannerTokenKey = "planner_token"

    func savePlannerToken(_ token: String) throws {
        try save(key: plannerTokenKey, value: token)
    }

    func getPlannerToken() throws -> String? {
        try get(key: plannerTokenKey)
    }

    func deletePlannerToken() throws {
        try delete(key: plannerTokenKey)
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
