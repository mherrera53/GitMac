import Foundation
import Combine

// MARK: - Git Profiles Service

/// Manages multiple Git identities for different repositories
class GitProfilesService: ObservableObject {
    static let shared = GitProfilesService()
    
    @Published var profiles: [GitProfile] = []
    @Published var repoProfileMappings: [String: String] = [:] // repoPath -> profileId
    
    private let userDefaults = UserDefaults.standard
    private let profilesKey = "git_profiles"
    private let mappingsKey = "git_profile_mappings"
    
    private init() {
        loadProfiles()
    }
    
    // MARK: - Models
    
    struct GitProfile: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var email: String
        var signingKey: String?
        var isDefault: Bool
        var color: String // hex color for visual identification
        
        init(id: String = UUID().uuidString, name: String, email: String, signingKey: String? = nil, isDefault: Bool = false, color: String = "007AFF") {
            self.id = id
            self.name = name
            self.email = email
            self.signingKey = signingKey
            self.isDefault = isDefault
            self.color = color
        }
    }
    
    // MARK: - Profile Management
    
    func addProfile(_ profile: GitProfile) {
        var newProfile = profile
        
        // If this is the first profile, make it default
        if profiles.isEmpty {
            newProfile.isDefault = true
        }
        
        // If new profile is default, unset others
        if newProfile.isDefault {
            for i in profiles.indices {
                profiles[i].isDefault = false
            }
        }
        
        profiles.append(newProfile)
        saveProfiles()
    }
    
    func updateProfile(_ profile: GitProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        
        var updatedProfile = profile
        
        // If this profile is being set as default, unset others
        if updatedProfile.isDefault {
            for i in profiles.indices {
                profiles[i].isDefault = false
            }
        }
        
        profiles[index] = updatedProfile
        saveProfiles()
    }
    
    func deleteProfile(_ profileId: String) {
        profiles.removeAll { $0.id == profileId }
        
        // Remove any repo mappings using this profile
        repoProfileMappings = repoProfileMappings.filter { $0.value != profileId }
        
        // If no default profile exists, make first one default
        if !profiles.isEmpty && !profiles.contains(where: { $0.isDefault }) {
            profiles[0].isDefault = true
        }
        
        saveProfiles()
        saveMappings()
    }
    
    func getDefaultProfile() -> GitProfile? {
        profiles.first(where: { $0.isDefault }) ?? profiles.first
    }
    
    func getProfile(for repoPath: String) -> GitProfile? {
        if let mappedId = repoProfileMappings[repoPath],
           let profile = profiles.first(where: { $0.id == mappedId }) {
            return profile
        }
        return getDefaultProfile()
    }
    
    // MARK: - Repository Mapping
    
    func setProfile(_ profileId: String, for repoPath: String) {
        repoProfileMappings[repoPath] = profileId
        saveMappings()
    }
    
    func removeProfileMapping(for repoPath: String) {
        repoProfileMappings.removeValue(forKey: repoPath)
        saveMappings()
    }
    
    // MARK: - Apply to Repository
    
    /// Apply a profile's settings to a repository
    func applyProfile(_ profile: GitProfile, to repoPath: String) async throws {
        // Set user.name
        _ = try await ShellExecutor.shared.execute(
            "cd '\(repoPath)' && git config user.name '\(profile.name)'"
        )
        
        // Set user.email
        _ = try await ShellExecutor.shared.execute(
            "cd '\(repoPath)' && git config user.email '\(profile.email)'"
        )
        
        // Set signing key if present
        if let signingKey = profile.signingKey, !signingKey.isEmpty {
            _ = try await ShellExecutor.shared.execute(
                "cd '\(repoPath)' && git config user.signingkey '\(signingKey)'"
            )
            _ = try await ShellExecutor.shared.execute(
                "cd '\(repoPath)' && git config commit.gpgsign true"
            )
        }
        
        // Update mapping
        setProfile(profile.id, for: repoPath)
    }
    
    /// Get current Git config from a repository
    func getCurrentConfig(at repoPath: String) async -> (name: String?, email: String?, signingKey: String?) {
        let name = try? await ShellExecutor.shared.execute("cd '\(repoPath)' && git config user.name").output.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = try? await ShellExecutor.shared.execute("cd '\(repoPath)' && git config user.email").output.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = try? await ShellExecutor.shared.execute("cd '\(repoPath)' && git config user.signingkey").output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (name, email, key)
    }
    
    // MARK: - Persistence
    
    private func loadProfiles() {
        if let data = userDefaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([GitProfile].self, from: data) {
            profiles = decoded
        }
        
        if let mappings = userDefaults.dictionary(forKey: mappingsKey) as? [String: String] {
            repoProfileMappings = mappings
        }
    }
    
    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            userDefaults.set(data, forKey: profilesKey)
        }
    }
    
    private func saveMappings() {
        userDefaults.set(repoProfileMappings, forKey: mappingsKey)
    }
}
