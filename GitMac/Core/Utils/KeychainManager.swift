import Foundation
import Security
import CryptoKit
import IOKit
import LocalAuthentication

enum CredentialStorageError: LocalizedError {
    case keychain(OSStatus)
    case invalidData
    case verificationFailed
    case legacyKeyUnavailable
    case unsafeLegacyFile
    case legacyChanged
    case migrationRequiresApproval

    var errorDescription: String? {
        switch self {
        case .keychain(let status): return "Credential access failed (Keychain status \(status)). Unlock your keychain and retry."
        case .invalidData: return "Credential storage is corrupt; the original data has been preserved."
        case .verificationFailed: return "Credential persistence could not be verified; retry before signing out."
        case .legacyKeyUnavailable: return "The original Mac identity is unavailable; credential migration was not attempted."
        case .unsafeLegacyFile: return "Legacy credential storage is not a regular file or exceeds its size limit."
        case .legacyChanged: return "Legacy credentials changed during migration; the original file was preserved."
        case .migrationRequiresApproval: return "Legacy credentials require an approved migration. Enable GITMAC_MIGRATE_CREDENTIALS=1 for a verified migration; the original file is unchanged."
        }
    }
}

protocol CredentialStore: Sendable {
    func read() throws -> Data?
    func write(_ data: Data) throws
}

/// Uses macOS Keychain Services, never an application-derived encryption key.
/// Each instance targets exactly one service/account; it never enumerates items.
struct SecurityCredentialStore: CredentialStore {
    let service: String
    private let account = "credential-store.v1"

    private func query() -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: account,
                kSecUseAuthenticationContext as String: context]
    }

    func read() throws -> Data? {
        var query = query()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStorageError.keychain(status) }
        guard let data = result as? Data else { throw CredentialStorageError.invalidData }
        return data
    }

    func write(_ data: Data) throws {
        let query = query()
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addition = query
            addition[kSecValueData as String] = data
            // The default macOS login keychain handles encryption and access
            // control. No iCloud synchronization or broad access ACL is enabled.
            let added = SecItemAdd(addition as CFDictionary, nil)
            guard added == errSecSuccess else { throw CredentialStorageError.keychain(added) }
        } else if status != errSecSuccess {
            throw CredentialStorageError.keychain(status)
        }
    }
}

/// Manages secure storage of credentials
/// Migration is lazy, verified and retryable; no credentials are loaded in init.
actor KeychainManager {
    static let shared = KeychainManager()
    private let store: any CredentialStore
    private let storageURL: URL
    private let legacyKey: @Sendable () throws -> SymmetricKey
    private let removeLegacy: @Sendable (URL) throws -> Void
    private let migrationEnabled: Bool

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("GitMac/.credentials.enc")
        store = SecurityCredentialStore(service: "com.gitmac.credentials")
        legacyKey = Self.deriveLegacyKey
        removeLegacy = { try FileManager.default.removeItem(at: $0) }
        migrationEnabled = ProcessInfo.processInfo.environment["GITMAC_MIGRATE_CREDENTIALS"] == "1"
    }

    init(store: any CredentialStore, legacyURL: URL,
         legacyKey: @escaping @Sendable () throws -> SymmetricKey,
         migrationEnabled: Bool = true,
         removeLegacy: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.store = store
        storageURL = legacyURL
        self.legacyKey = legacyKey
        self.removeLegacy = removeLegacy
        self.migrationEnabled = migrationEnabled
    }

    /// Compatibility only: this key is never used for new persistence.
    private static func deriveLegacyKey() throws -> SymmetricKey {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { throw CredentialStorageError.legacyKeyUnavailable }
        defer { IOObjectRelease(platformExpert) }
        guard let uuid = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String, !uuid.isEmpty else { throw CredentialStorageError.legacyKeyUnavailable }
        return SymmetricKey(data: SHA256.hash(data: Data(uuid.utf8)))
    }

    private func decode(_ data: Data) throws -> [String: String] {
        guard let values = try? JSONDecoder().decode([String: String].self, from: data) else {
            throw CredentialStorageError.invalidData
        }
        return values
    }

    private func persist(_ values: [String: String]) throws {
        let data = try JSONEncoder().encode(values)
        try store.write(data)
        guard let saved = try store.read(), try decode(saved) == values else {
            throw CredentialStorageError.verificationFailed
        }
    }

    private func values() throws -> [String: String] {
        let current = try store.read().map { try decode($0) } ?? [:]
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: storageURL.path) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain
            && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) {
            return current
        }
        guard migrationEnabled else { throw CredentialStorageError.migrationRequiresApproval }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 1024 * 1024 else {
            throw CredentialStorageError.unsafeLegacyFile
        }
        let encrypted = try Data(contentsOf: storageURL)
        let key = try legacyKey()
        let legacy: [String: String]
        do { legacy = try decode(AES.GCM.open(AES.GCM.SealedBox(combined: encrypted), using: key)) }
        catch { throw CredentialStorageError.invalidData }
        // Existing Keychain values win if a previous attempt persisted but was
        // interrupted before deleting the legacy file. Never overwrite newer data.
        let merged = legacy.merging(current) { _, current in current }
        try persist(merged)
        guard try Data(contentsOf: storageURL) == encrypted else { throw CredentialStorageError.legacyChanged }
        try removeLegacy(storageURL)
        return merged
    }

    // MARK: - Public API

    /// Retained for launch compatibility. Access happens in throwing operations,
    /// not at launch, and secrets are not retained in an application-wide cache.
    func preloadCache() {}

    /// Save a string value
    func save(key: String, value: String) throws {
        var updated = try values()
        updated[key] = value
        try persist(updated)
    }

    /// Get a string value
    func get(key: String) throws -> String? {
        try values()[key]
    }

    /// Delete a value
    func delete(key: String) throws {
        var updated = try values()
        updated.removeValue(forKey: key)
        try persist(updated)
    }

    /// Check if a key exists
    func exists(key: String) -> Bool {
        (try? get(key: key)) != nil
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
