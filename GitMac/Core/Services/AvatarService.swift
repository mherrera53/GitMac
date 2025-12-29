import Foundation
import SwiftUI
import CryptoKit

// MARK: - Avatar Service

/// Service to fetch and cache user avatars from Gravatar and GitHub
/// Uses bounded caches to prevent memory growth (WWDC 2018 - iOS Memory Deep Dive)
actor AvatarService {
    static let shared = AvatarService()

    // MARK: - Cache Configuration
    private static let avatarCacheLimit = 200    // Max 200 avatar URLs
    private static let usernameCacheLimit = 500  // Max 500 GitHub usernames

    // Bounded in-memory cache with LRU eviction
    private var avatarCache: [String: URL] = [:]
    private var avatarAccessOrder: [String] = []  // LRU tracking
    private var pendingRequests: [String: Task<URL?, Never>] = [:]

    // GitHub username cache with LRU eviction
    private var githubUsernameCache: [String: String] = [:]
    private var usernameAccessOrder: [String] = []

    // Disk cache directory
    private let cacheDirectory: URL

    // Throttled persistence (debounce writes to disk)
    private var persistenceTask: Task<Void, Never>?
    private var needsPersistence = false
    private let persistenceDebounceInterval: TimeInterval = 2.0  // 2 seconds

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("com.gitmac.avatars")

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load cached mappings synchronously during init (limited to cache size)
        if let data = try? Data(contentsOf: cacheDirectory.appendingPathComponent("avatar_mappings.json")),
           let mappings = try? JSONDecoder().decode(AvatarCacheMappings.self, from: data) {
            // Only load up to cache limit
            for (key, urlString) in mappings.avatarURLs.prefix(Self.avatarCacheLimit) {
                if let url = URL(string: urlString) {
                    avatarCache[key] = url
                    avatarAccessOrder.append(key)
                }
            }
            for (key, value) in mappings.githubUsernames.prefix(Self.usernameCacheLimit) {
                githubUsernameCache[key] = value
                usernameAccessOrder.append(key)
            }
        }
    }

    // MARK: - LRU Cache Helpers

    /// Set avatar URL with LRU eviction
    private func setAvatarURL(_ url: URL, for key: String) {
        // Remove from access order if exists (will be re-added at end)
        if let index = avatarAccessOrder.firstIndex(of: key) {
            avatarAccessOrder.remove(at: index)
        }

        // Evict oldest if at limit
        while avatarCache.count >= Self.avatarCacheLimit, let oldest = avatarAccessOrder.first {
            avatarCache.removeValue(forKey: oldest)
            avatarAccessOrder.removeFirst()
        }

        // Add new entry
        avatarCache[key] = url
        avatarAccessOrder.append(key)
    }

    /// Set GitHub username with LRU eviction
    private func setGithubUsername(_ username: String, for email: String) {
        // Remove from access order if exists
        if let index = usernameAccessOrder.firstIndex(of: email) {
            usernameAccessOrder.remove(at: index)
        }

        // Evict oldest if at limit
        while githubUsernameCache.count >= Self.usernameCacheLimit, let oldest = usernameAccessOrder.first {
            githubUsernameCache.removeValue(forKey: oldest)
            usernameAccessOrder.removeFirst()
        }

        // Add new entry
        githubUsernameCache[email] = username
        usernameAccessOrder.append(email)
    }

    // MARK: - Public API

    /// Get avatar URL for an email, checking cache first, then Gravatar, then GitHub
    func getAvatarURL(for email: String, githubToken: String? = nil) async -> URL? {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let cacheKey = normalizedEmail.md5Hash

        // 1. Check memory cache
        if let cached = avatarCache[cacheKey] {
            return cached
        }

        // 2. Check if there's already a pending request for this email
        if let pendingTask = pendingRequests[cacheKey] {
            return await pendingTask.value
        }

        // 3. Create new fetch task
        let task = Task<URL?, Never> {
            // Try GitHub FIRST (real profile photos)
            if let token = githubToken,
               let githubURL = await fetchGitHubAvatar(email: normalizedEmail, token: token) {
                setAvatarURL(githubURL, for: cacheKey)
                saveCachedMappings()
                return githubURL
            }

            // Fallback to Gravatar
            if let gravatarURL = await fetchGravatarAvatar(email: normalizedEmail) {
                setAvatarURL(gravatarURL, for: cacheKey)
                saveCachedMappings()
                return gravatarURL
            }

            // Last resort: Gravatar identicon
            let identiconURL = gravatarIdenticonURL(email: normalizedEmail)
            setAvatarURL(identiconURL, for: cacheKey)
            return identiconURL
        }

        pendingRequests[cacheKey] = task
        let result = await task.value
        pendingRequests.removeValue(forKey: cacheKey)

        return result
    }

    /// Preload avatars for multiple emails (batch operation)
    func preloadAvatars(for emails: [String], githubToken: String? = nil) async {
        await withTaskGroup(of: Void.self) { group in
            for email in emails.prefix(50) { // Limit to avoid too many requests
                group.addTask {
                    _ = await self.getAvatarURL(for: email, githubToken: githubToken)
                }
            }
        }
    }

    /// Cache an avatar URL for an email
    func cacheAvatar(url: URL, for email: String) async {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let cacheKey = normalizedEmail.md5Hash
        avatarCache[cacheKey] = url
        NSLog("💾 Cached avatar for \(email): \(url)")
    }

    /// Clear all cached avatars
    func clearCache() {
        avatarCache.removeAll()
        avatarAccessOrder.removeAll()
        githubUsernameCache.removeAll()
        usernameAccessOrder.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Gravatar

    private func fetchGravatarAvatar(email: String) async -> URL? {
        let hash = email.md5Hash
        let checkURL = URL(string: "https://www.gravatar.com/avatar/\(hash)?d=404&s=80")!

        do {
            let (_, response) = try await URLSession.shared.data(from: checkURL)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // User has a custom Gravatar
                return URL(string: "https://www.gravatar.com/avatar/\(hash)?s=80")
            }
        } catch {
            // Gravatar not available
        }

        return nil
    }

    private func gravatarIdenticonURL(email: String) -> URL {
        let hash = email.md5Hash
        return URL(string: "https://www.gravatar.com/avatar/\(hash)?d=identicon&s=80")!
    }

    // MARK: - GitHub

    // Cache for authenticated user
    private var authenticatedUserEmails: Set<String> = []
    private var authenticatedUserAvatarURL: URL?
    private var authenticatedUserLoaded = false

    // Repository commit authors cache (email -> avatar URL)
    private var repoAuthorsCache: [String: URL] = [:]
    private var repoAuthorsCacheLoaded: Set<String> = []  // repos already loaded

    private func fetchGitHubAvatar(email: String, token: String) async -> URL? {
        let emailLower = email.lowercased()

        // Load authenticated user info once
        if !authenticatedUserLoaded {
            await loadAuthenticatedUser(token: token)
        }

        // If email matches authenticated user, return their avatar
        if authenticatedUserEmails.contains(emailLower),
           let avatarURL = authenticatedUserAvatarURL {
            return avatarURL
        }

        // Check repo authors cache
        if let cachedURL = repoAuthorsCache[emailLower] {
            return cachedURL
        }

        // Check username cache
        if let username = githubUsernameCache[emailLower] {
            return URL(string: "https://avatars.githubusercontent.com/\(username)?size=80")
        }

        return nil
    }

    /// Load commit authors from a GitHub repository
    func loadRepoAuthors(owner: String, repo: String, token: String) async {
        let repoKey = "\(owner)/\(repo)"
        guard !repoAuthorsCacheLoaded.contains(repoKey) else {
            NSLog("⏭️ Avatar cache already loaded for \(repoKey)")
            return
        }
        repoAuthorsCacheLoaded.insert(repoKey)

        // Fetch recent commits to get author avatars
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits?per_page=100") else {
            NSLog("❌ Invalid GitHub URL for \(owner)/\(repo)")
            return
        }

        NSLog("🔍 Fetching commits from GitHub API: \(owner)/\(repo)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                NSLog("📡 GitHub API response: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    if let errorBody = String(data: data, encoding: .utf8) {
                        NSLog("❌ GitHub API error: \(errorBody)")
                    }
                    return
                }
            }

            let commits = try JSONDecoder().decode([AvatarGitHubCommitResponse].self, from: data)
            NSLog("✅ Decoded \(commits.count) commits from GitHub")

            var loadedCount = 0
            for commit in commits {
                if let authorEmail = commit.commit.author?.email?.lowercased(),
                   let avatarUrl = commit.author?.avatarUrl,
                   let url = URL(string: avatarUrl) {
                    repoAuthorsCache[authorEmail] = url
                    loadedCount += 1
                    NSLog("  📧 \(authorEmail) → \(avatarUrl)")
                }
            }

            NSLog("✅ Loaded \(loadedCount) author avatars into cache")
        } catch {
            NSLog("❌ Failed to load repo authors: \(error.localizedDescription)")
        }
    }

    /// Load authenticated user's info from GitHub API
    private func loadAuthenticatedUser(token: String) async {
        authenticatedUserLoaded = true

        // Get user info (includes avatar and ID)
        var userRequest = URLRequest(url: URL(string: "https://api.github.com/user")!)
        userRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (userData, _) = try? await URLSession.shared.data(for: userRequest),
              let userJson = try? JSONSerialization.jsonObject(with: userData) as? [String: Any],
              let avatarUrl = userJson["avatar_url"] as? String else {
            return
        }

        authenticatedUserAvatarURL = URL(string: avatarUrl)

        // Get all emails associated with this GitHub account
        var emailRequest = URLRequest(url: URL(string: "https://api.github.com/user/emails")!)
        emailRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let (emailData, _) = try? await URLSession.shared.data(for: emailRequest),
           let emails = try? JSONDecoder().decode([GitHubEmail].self, from: emailData) {
            authenticatedUserEmails = Set(emails.map { $0.email.lowercased() })
        }

        // Add user-configured email aliases from settings
        let aliases = await EmailAliasSettings.shared.aliases
        for alias in aliases {
            authenticatedUserEmails.insert(alias.lowercased())
        }
    }

    // MARK: - Persistence

    private var mappingsFileURL: URL {
        cacheDirectory.appendingPathComponent("avatar_mappings.json")
    }

    private func loadCachedMappings() {
        guard let data = try? Data(contentsOf: mappingsFileURL),
              let mappings = try? JSONDecoder().decode(AvatarCacheMappings.self, from: data) else {
            return
        }

        // Convert string URLs back to URL objects
        for (key, urlString) in mappings.avatarURLs {
            if let url = URL(string: urlString) {
                avatarCache[key] = url
            }
        }
        githubUsernameCache = mappings.githubUsernames
    }

    /// Schedule a throttled save to disk (debounced to avoid excessive I/O)
    private func saveCachedMappings() {
        needsPersistence = true

        // Cancel any pending persistence task
        persistenceTask?.cancel()

        // Schedule new persistence with debounce
        persistenceTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(persistenceDebounceInterval * 1_000_000_000))

                // Check if we still need to persist and weren't cancelled
                guard !Task.isCancelled, needsPersistence else { return }

                await saveCachedMappingsNow()
            } catch {
                // Task was cancelled, that's fine
            }
        }
    }

    /// Immediately save cached mappings to disk (called after debounce or on explicit flush)
    private func saveCachedMappingsNow() async {
        needsPersistence = false

        // Convert URLs to strings for JSON encoding
        var urlStrings: [String: String] = [:]
        for (key, url) in avatarCache {
            urlStrings[key] = url.absoluteString
        }

        let mappings = AvatarCacheMappings(
            avatarURLs: urlStrings,
            githubUsernames: githubUsernameCache
        )

        if let data = try? JSONEncoder().encode(mappings) {
            try? data.write(to: mappingsFileURL, options: .atomic)
        }
    }

    /// Force immediate persistence (useful before app termination)
    func flushCache() async {
        persistenceTask?.cancel()
        if needsPersistence {
            await saveCachedMappingsNow()
        }
    }
}

// MARK: - Models

private struct AvatarCacheMappings: Codable {
    let avatarURLs: [String: String]
    let githubUsernames: [String: String]
}

private struct GitHubUserSearchResponse: Codable {
    let items: [GitHubUserSearchItem]
}

private struct GitHubUserSearchItem: Codable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

private struct GitHubEmail: Codable {
    let email: String
    let primary: Bool
    let verified: Bool
}

private struct AvatarGitHubCommitResponse: Codable {
    let commit: AvatarGitHubCommitData
    let author: AvatarGitHubCommitAuthor?
}

private struct AvatarGitHubCommitData: Codable {
    let author: AvatarGitHubCommitPerson?
}

private struct AvatarGitHubCommitPerson: Codable {
    let email: String?
}

private struct AvatarGitHubCommitAuthor: Codable {
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
    }
}

// MARK: - String MD5 Extension

extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - Avatar Image View

/// SwiftUI view that loads and displays an avatar with caching
struct AvatarImageView: View {
    let email: String
    let size: CGFloat
    let fallbackInitial: String

    @State private var avatarURL: URL?
    @State private var isLoading = true

    init(email: String, size: CGFloat = 32, fallbackInitial: String? = nil) {
        self.email = email
        self.size = size
        self.fallbackInitial = fallbackInitial ?? String(email.prefix(1)).uppercased()
    }

    var body: some View {
        Group {
            if let url = avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        // Show fallback while loading or on failure
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                // No URL yet (loading or failed) - show fallback
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: email) {
            await loadAvatar()
        }
        .id(email)  // Force unique identity per email for LazyVStack
    }

    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(fallbackColor)
            Text(fallbackInitial)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    /// Color determinístico basado en hash del email
    private var fallbackColor: Color {
        guard !email.isEmpty else { return AppTheme.textMuted }
        let hash = email.md5Hash
        guard let firstChar = hash.first,
              let value = firstChar.unicodeScalars.first?.value else {
            return AppTheme.textMuted
        }
        let hue = Double(value % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }

    @MainActor
    private func loadAvatar() async {
        defer { isLoading = false }

        do {
            let token = try await KeychainManager.shared.getGitHubToken()
            avatarURL = await AvatarService.shared.getAvatarURL(for: email, githubToken: token)
        } catch {
            // Still try to load without token (Gravatar only)
            avatarURL = await AvatarService.shared.getAvatarURL(for: email, githubToken: nil)
        }
    }
}

// MARK: - Email Alias Settings

/// Manages email aliases for avatar matching (configured in Settings)
@MainActor
class EmailAliasSettings: ObservableObject {
    static let shared = EmailAliasSettings()

    private let userDefaultsKey = "email_aliases"

    @Published var aliases: [String] {
        didSet {
            save()
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            aliases = decoded
        } else {
            aliases = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(aliases) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func addAlias(_ email: String) {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        if !normalized.isEmpty && !aliases.contains(normalized) {
            aliases.append(normalized)
        }
    }

    func removeAlias(_ email: String) {
        aliases.removeAll { $0 == email.lowercased() }
    }
}
