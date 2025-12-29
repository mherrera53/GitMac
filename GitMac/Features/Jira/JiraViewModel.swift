//
//  JiraViewModel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  ViewModel for Jira integration
//

import Foundation

// MARK: - Filter Mode

enum JiraFilterMode {
    case myIssues
    case project
}

// MARK: - View Model

@MainActor
class JiraViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    @Published var sites: [JiraCloudSite] = []
    @Published var selectedSiteId: String?
    @Published var projects: [JiraProject] = []
    @Published var selectedProjectKey: String?
    @Published var issues: [JiraIssue] = []
    @Published var filterMode: JiraFilterMode = .myIssues

    private let service = JiraService.shared

    nonisolated init() {
        Task { [weak self] in
            guard let self = self else { return }
            if let token = try? await KeychainManager.shared.getJiraToken(),
               let cloudId = try? await KeychainManager.shared.getJiraCloudId() {
                await service.setAccessToken(token)
                await service.setCloudId(cloudId)
                await MainActor.run { [weak self] in
                    self?.isAuthenticated = true
                }
                await self.loadProjects()
                try? await self.refresh()
            }
        }
    }

    // MARK: - IntegrationViewModel Protocol

    func authenticate() async throws {
        // Jira uses custom login form, authentication is handled by JiraLoginPrompt
        // This method is called after successful login to load initial data
        isLoading = true
        defer { isLoading = false }
        await loadProjects()
        try? await refresh()
    }

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            switch filterMode {
            case .myIssues:
                issues = try await service.getMyIssues()
            case .project:
                if let projectKey = selectedProjectKey {
                    issues = try await service.getProjectIssues(projectKey: projectKey)
                } else {
                    issues = try await service.getMyIssues()
                }
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Jira-specific methods

    func loadProjects() async {
        do {
            projects = try await service.listProjects()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() {
        Task { [weak self] in
            try? await KeychainManager.shared.deleteJiraToken()
            try? await KeychainManager.shared.deleteJiraCloudId()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isAuthenticated = false
                self.projects = []
                self.issues = []
            }
        }
    }
}
