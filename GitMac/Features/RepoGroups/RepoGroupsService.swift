import Foundation
import Combine
import SwiftUI

// MARK: - Repository Groups Service

/// Manages favorite repositories and repository groups
class RepoGroupsService: ObservableObject {
    static let shared = RepoGroupsService()
    
    @Published var favorites: Set<String> = [] // Set of repo paths
    @Published var groups: [RepoGroup] = []
    @Published var recentRepositories: [RecentRepo] = []
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "favorite_repos"
    private let groupsKey = "repo_groups"
    private let recentKey = "recent_repos"
    private let maxRecent = 20
    
    private init() {
        loadData()
    }
    
    // MARK: - Models
    
    struct RepoGroup: Identifiable, Codable {
        let id: String
        var name: String
        var color: String // hex color
        var repos: [String] // paths
        var sortOrder: Int
        
        init(id: String = UUID().uuidString, name: String, color: String = "007AFF", repos: [String] = [], sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.color = color
            self.repos = repos
            self.sortOrder = sortOrder
        }
    }
    
    struct RecentRepo: Identifiable, Codable {
        let id: String
        let path: String
        let name: String
        let lastOpened: Date
        
        init(path: String) {
            self.id = path
            self.path = path
            self.name = URL(fileURLWithPath: path).lastPathComponent
            self.lastOpened = Date()
        }
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(_ repoPath: String) {
        if favorites.contains(repoPath) {
            favorites.remove(repoPath)
        } else {
            favorites.insert(repoPath)
        }
        saveFavorites()
    }
    
    func isFavorite(_ repoPath: String) -> Bool {
        favorites.contains(repoPath)
    }
    
    func getFavoriteRepos() -> [String] {
        Array(favorites).sorted()
    }
    
    // MARK: - Groups
    
    func createGroup(name: String, color: String = "007AFF") -> RepoGroup {
        let group = RepoGroup(
            name: name,
            color: color,
            sortOrder: groups.count
        )
        groups.append(group)
        saveGroups()
        return group
    }
    
    func updateGroup(_ group: RepoGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index] = group
        saveGroups()
    }
    
    func deleteGroup(_ groupId: String) {
        groups.removeAll { $0.id == groupId }
        saveGroups()
    }
    
    func addRepoToGroup(_ repoPath: String, groupId: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        if !groups[index].repos.contains(repoPath) {
            groups[index].repos.append(repoPath)
            saveGroups()
        }
    }
    
    func removeRepoFromGroup(_ repoPath: String, groupId: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[index].repos.removeAll { $0 == repoPath }
        saveGroups()
    }
    
    func moveGroup(from source: IndexSet, to destination: Int) {
        groups.move(fromOffsets: source, toOffset: destination)
        // Update sort orders
        for (index, _) in groups.enumerated() {
            groups[index].sortOrder = index
        }
        saveGroups()
    }
    
    func getGroupsForRepo(_ repoPath: String) -> [RepoGroup] {
        groups.filter { $0.repos.contains(repoPath) }
    }
    
    // MARK: - Recent Repositories
    
    func addToRecent(_ repoPath: String) {
        // Remove if already exists
        recentRepositories.removeAll { $0.path == repoPath }
        
        // Add to front
        recentRepositories.insert(RecentRepo(path: repoPath), at: 0)
        
        // Trim to max
        if recentRepositories.count > maxRecent {
            recentRepositories = Array(recentRepositories.prefix(maxRecent))
        }
        
        saveRecent()
    }
    
    func removeFromRecent(_ repoPath: String) {
        recentRepositories.removeAll { $0.path == repoPath }
        saveRecent()
    }
    
    func clearRecent() {
        recentRepositories.removeAll()
        saveRecent()
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        // Load favorites
        if let data = userDefaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favorites = decoded
        }
        
        // Load groups
        if let data = userDefaults.data(forKey: groupsKey),
           let decoded = try? JSONDecoder().decode([RepoGroup].self, from: data) {
            groups = decoded.sorted { $0.sortOrder < $1.sortOrder }
        }
        
        // Load recent
        if let data = userDefaults.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([RecentRepo].self, from: data) {
            recentRepositories = decoded
        }
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            userDefaults.set(data, forKey: favoritesKey)
        }
    }
    
    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            userDefaults.set(data, forKey: groupsKey)
        }
    }
    
    private func saveRecent() {
        if let data = try? JSONEncoder().encode(recentRepositories) {
            userDefaults.set(data, forKey: recentKey)
        }
    }
}

// MARK: - SwiftUI Views

struct FavoriteButton: View {
    let repoPath: String
    @ObservedObject private var service = RepoGroupsService.shared
    
    var body: some View {
        Button {
            service.toggleFavorite(repoPath)
        } label: {
            Image(systemName: service.isFavorite(repoPath) ? "star.fill" : "star")
                .foregroundColor(service.isFavorite(repoPath) ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .help(service.isFavorite(repoPath) ? "Remove from favorites" : "Add to favorites")
    }
}

struct GroupBadge: View {
    let group: RepoGroupsService.RepoGroup
    
    var body: some View {
        Text(group.name)
            .font(DesignTokens.Typography.caption2)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, 1)
            .background(Color(hex: group.color)?.opacity(0.3) ?? AppTheme.textMuted.opacity(0.2))
            .foregroundColor(Color(hex: group.color) ?? AppTheme.textMuted)
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

// Color extension for hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6,
              let int = UInt64(hexSanitized, radix: 16) else {
            return nil
        }
        
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
