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
            // Try Gravatar first
            if let gravatarURL = await fetchGravatarAvatar(email: normalizedEmail) {
                setAvatarURL(gravatarURL, for: cacheKey)
                saveCachedMappings()
                return gravatarURL
            }

            // Try GitHub if token available
            if let token = githubToken,
               let githubURL = await fetchGitHubAvatar(email: normalizedEmail, token: token) {
                setAvatarURL(githubURL, for: cacheKey)
                saveCachedMappings()
                return githubURL
            }

            // Fallback to Gravatar identicon
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

    private func fetchGitHubAvatar(email: String, token: String) async -> URL? {
        // First check if we already know the username for this email
        if let username = githubUsernameCache[email] {
            return URL(string: "https://github.com/\(username).png?size=80")
        }

        // Search GitHub for user by email
        guard let searchURL = URL(string: "https://api.github.com/search/users?q=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")+in:email") else {
            return nil
        }

        var request = URLRequest(url: searchURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let searchResult = try JSONDecoder().decode(GitHubUserSearchResponse.self, from: data)

            if let user = searchResult.items.first {
                // Cache the username with LRU eviction
                setGithubUsername(user.login, for: email)
                saveCachedMappings()

                return URL(string: user.avatarUrl)
            }
        } catch {
            print("GitHub avatar fetch error: \(error)")
        }

        return nil
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

    private func saveCachedMappings() {
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
            try? data.write(to: mappingsFileURL)
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
                    case .failure:
                        fallbackView
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.5)
                    @unknown default:
                        fallbackView
                    }
                }
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
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
                .fill(Color.gray.opacity(0.3))
            Text(fallbackInitial)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
    }

    @MainActor
    private func loadAvatar() async {
        defer { isLoading = false }  // Guarantee state update

        do {
            let token = try await KeychainManager.shared.getGitHubToken()
            #if DEBUG
            print("[Avatar] Loading for \(email), has token: \(token != nil)")
            #endif

            avatarURL = await AvatarService.shared.getAvatarURL(for: email, githubToken: token)

            #if DEBUG
            print("[Avatar] \(email) -> \(avatarURL?.absoluteString ?? "fallback")")
            #endif
        } catch {
            #if DEBUG
            print("[Avatar] Token error for \(email): \(error)")
            #endif
            // Still try to load without token (Gravatar only)
            avatarURL = await AvatarService.shared.getAvatarURL(for: email, githubToken: nil)
        }
    }
}
