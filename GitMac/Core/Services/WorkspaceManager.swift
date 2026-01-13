//
//  WorkspaceManager.swift
//  GitMac
//
//  Centralized workspace configuration manager for multi-repo setups
//

import Foundation
import SwiftUI

/// Workspace template for reusable configurations
struct WorkspaceTemplate: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var config: WorkspaceConfig
    var icon: String
    var color: String
    var tags: [String]
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        config: WorkspaceConfig,
        icon: String = "folder.fill",
        color: String = "blue",
        tags: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.config = config
        self.icon = icon
        self.color = color
        self.tags = tags
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Workspace group for organizing related repositories
struct WorkspaceGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var repositoryPaths: [String]
    var sharedConfig: WorkspaceConfig?
    var icon: String
    var color: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        repositoryPaths: [String] = [],
        sharedConfig: WorkspaceConfig? = nil,
        icon: String = "folder.badge.gearshape",
        color: String = "purple",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.repositoryPaths = repositoryPaths
        self.sharedConfig = sharedConfig
        self.icon = icon
        self.color = color
        self.createdAt = createdAt
    }

    var repositoryCount: Int {
        repositoryPaths.count
    }
}

/// Centralized workspace manager for multi-repo configurations
@MainActor
class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()

    @Published var templates: [WorkspaceTemplate] = []
    @Published var groups: [WorkspaceGroup] = []

    private let templatesKey = "workspace_templates"
    private let groupsKey = "workspace_groups"

    private init() {
        loadTemplates()
        loadGroups()
        createDefaultTemplates()
    }

    // MARK: - Templates Management

    /// Create default workspace templates
    private func createDefaultTemplates() {
        guard templates.isEmpty else { return }

        // Template 1: Open Source Project
        var openSourceConfig = WorkspaceConfig()
        openSourceConfig.displayName = "Open Source Project"
        openSourceConfig.mainBranchName = "main"
        openSourceConfig.featureBranchPrefix = "feature/"
        openSourceConfig.bugfixBranchPrefix = "bugfix/"
        openSourceConfig.releaseBranchPrefix = "release/"
        openSourceConfig.autoDeleteMergedBranches = true
        openSourceConfig.requireIssueReference = true
        openSourceConfig.defaultPRBaseBranch = "main"

        templates.append(WorkspaceTemplate(
            name: "Open Source",
            description: "Standard configuration for open source projects",
            config: openSourceConfig,
            icon: "globe",
            color: "green",
            tags: ["open-source", "public", "community"]
        ))

        // Template 2: Enterprise Project
        var enterpriseConfig = WorkspaceConfig()
        enterpriseConfig.displayName = "Enterprise Project"
        enterpriseConfig.mainBranchName = "master"
        enterpriseConfig.featureBranchPrefix = "feature/"
        enterpriseConfig.bugfixBranchPrefix = "fix/"
        enterpriseConfig.releaseBranchPrefix = "release/"
        enterpriseConfig.hotfixBranchPrefix = "hotfix/"
        enterpriseConfig.signCommits = true
        enterpriseConfig.requireIssueReference = true
        enterpriseConfig.commitMessageTemplate = "[TICKET-XXX] \n\nWhat:\n\nWhy:\n\nHow:"

        templates.append(WorkspaceTemplate(
            name: "Enterprise",
            description: "Corporate workflow with strict conventions",
            config: enterpriseConfig,
            icon: "building.2",
            color: "blue",
            tags: ["enterprise", "corporate", "strict"]
        ))

        // Template 3: Personal Project
        var personalConfig = WorkspaceConfig()
        personalConfig.displayName = "Personal Project"
        personalConfig.mainBranchName = "main"
        personalConfig.autoDeleteMergedBranches = false
        personalConfig.requireIssueReference = false

        templates.append(WorkspaceTemplate(
            name: "Personal",
            description: "Lightweight config for personal projects",
            config: personalConfig,
            icon: "person.fill",
            color: "orange",
            tags: ["personal", "simple"]
        ))

        // Template 4: Microservices
        var microservicesConfig = WorkspaceConfig()
        microservicesConfig.displayName = "Microservice"
        microservicesConfig.mainBranchName = "main"
        microservicesConfig.featureBranchPrefix = "feat/"
        microservicesConfig.bugfixBranchPrefix = "fix/"
        microservicesConfig.releaseBranchPrefix = "release/"
        microservicesConfig.autoDeleteMergedBranches = true
        microservicesConfig.commitMessageTemplate = "type(scope): subject\n\nbody\n\nfooter"

        templates.append(WorkspaceTemplate(
            name: "Microservices",
            description: "Configuration for microservice architecture",
            config: microservicesConfig,
            icon: "server.rack",
            color: "purple",
            tags: ["microservices", "architecture", "conventional-commits"]
        ))

        saveTemplates()
    }

    func addTemplate(_ template: WorkspaceTemplate) {
        templates.append(template)
        saveTemplates()
    }

    func updateTemplate(_ template: WorkspaceTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            var updated = template
            updated.modifiedAt = Date()
            templates[index] = updated
            saveTemplates()
        }
    }

    func deleteTemplate(_ template: WorkspaceTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    func applyTemplate(_ template: WorkspaceTemplate, to repositoryPath: String) {
        var config = template.config
        // Preserve repository-specific display name if exists
        if let existing = WorkspaceSettingsManager.shared.workspaces[repositoryPath] {
            config.displayName = existing.displayName
        }
        WorkspaceSettingsManager.shared.workspaces[repositoryPath] = config
        WorkspaceSettingsManager.shared.save()
    }

    func applyTemplateToGroup(_ template: WorkspaceTemplate, groupId: UUID) {
        guard let group = groups.first(where: { $0.id == groupId }) else { return }
        for repoPath in group.repositoryPaths {
            applyTemplate(template, to: repoPath)
        }
    }

    // MARK: - Groups Management

    func addGroup(_ group: WorkspaceGroup) {
        groups.append(group)
        saveGroups()
    }

    func updateGroup(_ group: WorkspaceGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups()
        }
    }

    func deleteGroup(_ group: WorkspaceGroup) {
        groups.removeAll { $0.id == group.id }
        saveGroups()
    }

    func addRepositoryToGroup(_ repositoryPath: String, groupId: UUID) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            if !groups[index].repositoryPaths.contains(repositoryPath) {
                groups[index].repositoryPaths.append(repositoryPath)
                saveGroups()
            }
        }
    }

    func removeRepositoryFromGroup(_ repositoryPath: String, groupId: UUID) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].repositoryPaths.removeAll { $0 == repositoryPath }
            saveGroups()
        }
    }

    func applyGroupConfig(_ groupId: UUID) {
        guard let group = groups.first(where: { $0.id == groupId }),
              let sharedConfig = group.sharedConfig else { return }

        for repoPath in group.repositoryPaths {
            WorkspaceSettingsManager.shared.workspaces[repoPath] = sharedConfig
        }
        WorkspaceSettingsManager.shared.save()
    }

    // MARK: - Import/Export

    struct WorkspaceExport: Codable {
        let version: String
        let exportDate: Date
        let templates: [WorkspaceTemplate]
        let groups: [WorkspaceGroup]
        let workspaces: [String: WorkspaceConfig]
    }

    func exportConfiguration() -> Data? {
        let export = WorkspaceExport(
            version: "1.0",
            exportDate: Date(),
            templates: templates,
            groups: groups,
            workspaces: WorkspaceSettingsManager.shared.workspaces
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? encoder.encode(export)
    }

    func importConfiguration(from data: Data, merge: Bool = true) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let imported = try decoder.decode(WorkspaceExport.self, from: data)

        if merge {
            // Merge templates (avoid duplicates by name)
            for template in imported.templates {
                if !templates.contains(where: { $0.name == template.name }) {
                    templates.append(template)
                }
            }

            // Merge groups (avoid duplicates by name)
            for group in imported.groups {
                if !groups.contains(where: { $0.name == group.name }) {
                    groups.append(group)
                }
            }

            // Merge workspace configs
            for (path, config) in imported.workspaces {
                WorkspaceSettingsManager.shared.workspaces[path] = config
            }
        } else {
            // Replace all
            templates = imported.templates
            groups = imported.groups
            WorkspaceSettingsManager.shared.workspaces = imported.workspaces
        }

        saveTemplates()
        saveGroups()
        WorkspaceSettingsManager.shared.save()
    }

    // MARK: - Bulk Operations

    func applyConfigToMultipleRepos(_ config: WorkspaceConfig, repositories: [String]) {
        for repoPath in repositories {
            var repoConfig = config
            // Preserve repository-specific display name
            if let existing = WorkspaceSettingsManager.shared.workspaces[repoPath] {
                repoConfig.displayName = existing.displayName
            }
            WorkspaceSettingsManager.shared.workspaces[repoPath] = repoConfig
        }
        WorkspaceSettingsManager.shared.save()
    }

    func resetAllRepositories() {
        WorkspaceSettingsManager.shared.workspaces.removeAll()
        WorkspaceSettingsManager.shared.save()
    }

    // MARK: - Statistics

    var totalRepositories: Int {
        WorkspaceSettingsManager.shared.workspaces.count
    }

    var totalGroups: Int {
        groups.count
    }

    var totalTemplates: Int {
        templates.count
    }

    func repositoriesWithIntegrations() -> [String] {
        WorkspaceSettingsManager.shared.workspaces.filter { _, config in
            config.taigaProjectId != nil ||
            config.jiraProjectKey != nil ||
            config.linearTeamId != nil ||
            config.notionDatabaseId != nil ||
            config.codeBuildProjectName != nil
        }.map { $0.key }
    }

    // MARK: - Auto-Discovery

    /// Auto-discover groups from GitHub organizations and local repositories
    func discoverGroups() async -> [WorkspaceGroup] {
        var discoveredGroups: [WorkspaceGroup] = []

        // Strategy 1: Discover GitHub organizations
        let orgsResult = await executeShell("gh", args: ["org", "list"])
        if orgsResult.success {
            let orgNames = orgsResult.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }

            for orgName in orgNames where !orgName.isEmpty {
                // Get repos for this org
                let reposResult = await executeShell("gh", args: ["repo", "list", orgName, "--json", "nameWithOwner", "--jq", ".[].nameWithOwner"])

                if reposResult.success {
                    let repoPaths = reposResult.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }

                    if !repoPaths.isEmpty {
                        let group = WorkspaceGroup(
                            name: orgName,
                            description: "GitHub organization: \(orgName)",
                            repositoryPaths: repoPaths.filter { !$0.isEmpty },
                            icon: "building.2",
                            color: "blue"
                        )
                        discoveredGroups.append(group)
                    }
                }
            }
        }

        // Strategy 2: Group by common prefix in local repos
        let localRepos = Array(WorkspaceSettingsManager.shared.workspaces.keys)
        var prefixGroups: [String: [String]] = [:]

        for repoPath in localRepos {
            // Extract organization/owner from path
            let components = repoPath.split(separator: "/")
            if components.count >= 2 {
                let possibleOrg = String(components[components.count - 2])
                prefixGroups[possibleOrg, default: []].append(repoPath)
            }
        }

        // Create groups for common prefixes with 2+ repos
        for (prefix, repos) in prefixGroups where repos.count >= 2 {
            let group = WorkspaceGroup(
                name: prefix,
                description: "Local repositories under \(prefix)",
                repositoryPaths: repos,
                icon: "folder.badge.gearshape",
                color: "purple"
            )
            discoveredGroups.append(group)
        }

        return discoveredGroups
    }

    /// Apply discovered groups (merge with existing)
    func applyDiscoveredGroups(_ discoveredGroups: [WorkspaceGroup]) {
        for discovered in discoveredGroups {
            // Check if group already exists
            if let existing = groups.first(where: { $0.name == discovered.name }) {
                // Update existing group with new repos
                var updated = existing
                let newRepos = Set(discovered.repositoryPaths).subtracting(existing.repositoryPaths)
                updated.repositoryPaths.append(contentsOf: newRepos)
                updateGroup(updated)
            } else {
                // Add new group
                addGroup(discovered)
            }
        }
    }

    private func executeShell(_ command: String, args: [String]) async -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return (process.terminationStatus == 0, output)
        } catch {
            return (false, "")
        }
    }

    // MARK: - Persistence

    private func saveTemplates() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: templatesKey)
        }
    }

    private func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([WorkspaceTemplate].self, from: data) {
            templates = decoded
        }
    }

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
    }

    private func loadGroups() {
        if let data = UserDefaults.standard.data(forKey: groupsKey),
           let decoded = try? JSONDecoder().decode([WorkspaceGroup].self, from: data) {
            groups = decoded
        }
    }
}
