//
//  TaigaViewModel.swift
//  GitMac
//
//  Created on 2025-12-28.
//  ViewModel for Taiga integration
//

import Foundation
import SwiftUI

// MARK: - Tabs

enum TaigaTab: String, CaseIterable {
    case userStories = "Stories"
    case tasks = "Tasks"
    case issues = "Issues"
    case epics = "Epics"
}

// MARK: - View Model

@MainActor
class TaigaTicketsViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    @Published var projects: [TaigaProject] = []
    @Published var selectedProjectId: Int? {
        didSet {
            // Persist selected project
            if let id = selectedProjectId {
                UserDefaults.standard.set(id, forKey: "taiga_selected_project_id")
            }
        }
    }

    @Published var userStories: [TaigaUserStory] = []
    @Published var tasks: [TaigaTask] = []
    @Published var issues: [TaigaIssue] = []
    @Published var epics: [TaigaEpic] = []
    @Published var statuses: [TaigaStatus] = []
    @Published var serverURL: String = "https://api.taiga.io"

    private let service = TaigaService.shared

    nonisolated init() {
        // Check if token exists in keychain
        Task { [weak self] in
            guard let self else { return }
            if let token = try? await KeychainManager.shared.getTaigaToken() {
                await service.setToken(token)
                // Also restore userId for project filtering
                if let userId = try? await KeychainManager.shared.getTaigaUserId(),
                   let userIdInt = Int(userId) {
                    await service.setUserId(userIdInt)
                    print("🔐 Taiga: Restored userId \(userId)")
                }
                
                // Restore server URL
                if let savedURL = UserDefaults.standard.string(forKey: "taiga_base_url_display") {
                    await MainActor.run { [weak self] in
                        self?.serverURL = savedURL
                    }
                }

                await MainActor.run { [weak self] in
                    self?.isAuthenticated = true
                }
                await self.loadProjects()

                // Restore selected project
                let savedProjectId = UserDefaults.standard.integer(forKey: "taiga_selected_project_id")
                if savedProjectId > 0 {
                    await MainActor.run { [weak self] in
                        self?.selectedProjectId = savedProjectId
                    }
                    await self.loadProjectData(projectId: savedProjectId)
                }
            }
        }
    }

    // MARK: - IntegrationViewModel Protocol

    func authenticate() async throws {
        // Taiga uses custom login form, authentication is handled by TaigaLoginPrompt
        // This method is called after successful login to load initial data
        isLoading = true
        defer { isLoading = false }
        await loadProjects()
    }

    func refresh() async throws {
        if let projectId = selectedProjectId {
            await loadProjectData(projectId: projectId)
        } else {
            throw TaigaError.projectNotFound
        }
    }

    // MARK: - Taiga-specific methods

    func login(username: String, password: String, serverURL: String) async {
        isLoading = true
        error = nil

        do {
            // Update service with new base URL before login
            await service.setBaseURL(serverURL)
            UserDefaults.standard.set(serverURL, forKey: "taiga_base_url_display")
            
            let response = try await service.login(username: username, password: password)
            try await KeychainManager.shared.saveTaigaToken(response.authToken)
            // Save userId for project filtering
            try await KeychainManager.shared.saveTaigaUserId(String(response.id))
            await service.setUserId(response.id)
            isAuthenticated = true
            await loadProjects()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        Task { [weak self] in
            try? await KeychainManager.shared.deleteTaigaToken()
            try? await KeychainManager.shared.deleteTaigaUserId()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isAuthenticated = false
                self.projects = []
                self.selectedProjectId = nil
                self.userStories = []
                self.tasks = []
                self.issues = []
                self.epics = []
            }
        }
    }

    func loadProjects() async {
        do {
            projects = try await service.listProjects()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadProjectData(projectId: Int) async {
        isLoading = true
        print("📂 Taiga: Loading data for project \(projectId)")

        do {
            async let storiesTask = service.listUserStories(projectId: projectId)
            async let tasksTask = service.listTasks(projectId: projectId)
            async let issuesTask = service.listIssues(projectId: projectId)
            async let epicsTask = service.listEpics(projectId: projectId)
            async let statusesTask = service.getProjectStatuses(projectId: projectId)

            userStories = try await storiesTask
            tasks = try await tasksTask
            issues = try await issuesTask
            epics = try await epicsTask
            statuses = try await statusesTask

            print("📂 Taiga: Loaded \(userStories.count) stories, \(tasks.count) tasks, \(issues.count) issues, \(epics.count) epics")
        } catch {
            print("❌ Taiga Error: \(error)")
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
