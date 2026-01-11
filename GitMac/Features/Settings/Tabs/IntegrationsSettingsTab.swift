import SwiftUI

struct IntegrationsSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var workspaceManager = WorkspaceSettingsManager.shared
    @StateObject private var recentReposManager = RecentRepositoriesManager.shared

    // Taiga state
    @State private var isTaigaConnected = false
    @State private var taigaUsername = ""
    @State private var taigaPassword = ""
    @State private var taigaProjects: [TaigaProject] = []
    @State private var isLoadingTaiga = false
    @State private var taigaError: String?

    // Microsoft Planner state
    @State private var isPlannerConnected = false
    @State private var plannerPlans: [PlannerPlan] = []
    @State private var isLoadingPlanner = false
    @State private var plannerError: String?

    // Linear state
    @State private var isLinearConnected = false
    @State private var linearApiKey = ""
    @State private var linearTeams: [LinearTeam] = []
    @State private var isLoadingLinear = false
    @State private var linearError: String?

    // Jira state
    @State private var isJiraConnected = false
    @State private var jiraSiteUrl = ""
    @State private var jiraEmail = ""
    @State private var jiraApiToken = ""
    @State private var jiraProjects: [JiraProject] = []
    @State private var isLoadingJira = false
    @State private var jiraError: String?

    // Notion state
    @State private var isNotionConnected = false
    @State private var notionToken = ""
    @State private var notionDatabases: [NotionDatabase] = []
    @State private var isLoadingNotion = false
    @State private var notionError: String?

    // AWS state
    @State private var isAWSConnected = false
    @State private var awsAccessKeyId = ""
    @State private var awsSecretAccessKey = ""
    @State private var awsSessionToken = ""  // For MFA/2FA
    @State private var awsRegion = "us-east-1"
    @State private var isLoadingAWS = false
    @State private var awsError: String?
    @State private var awsProjects: [String] = []

    // Current repo
    @State private var selectedRepoPath: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Repository selection
            SettingsSection(title: "Repository") {
                if recentReposManager.recentRepos.isEmpty {
                    Text("Open a repository to configure integrations")
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Configure for")
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(AppTheme.textSecondary)

                        DSPicker(
                            items: recentReposManager.recentRepos,
                            selection: Binding(
                                get: {
                                    guard let path = selectedRepoPath else { return nil }
                                    return recentReposManager.recentRepos.first { $0.path == path }
                                },
                                set: { repo in
                                    selectedRepoPath = repo?.path
                                }
                            )
                        ) { repo in
                            Text(repo.name)
                        }
                    }
                    .onAppear {
                        if selectedRepoPath == nil {
                            selectedRepoPath = recentReposManager.recentRepos.first?.path
                        }
                    }
                }
            }

            // Taiga Integration
            SettingsSection(title: "Taiga") {
                if isTaigaConnected {
                    TaigaConnectedView(
                        selectedRepoPath: selectedRepoPath,
                        projects: taigaProjects,
                        workspaceManager: workspaceManager,
                        onDisconnect: disconnectTaiga
                    )
                } else {
                    TaigaLoginView(
                        username: $taigaUsername,
                        password: $taigaPassword,
                        isLoading: isLoadingTaiga,
                        error: taigaError,
                        onLogin: loginTaiga
                    )
                }
            }

            // Microsoft Planner Integration
            SettingsSection(title: "Microsoft Planner") {
                if isPlannerConnected {
                    PlannerConnectedView(
                        selectedRepoPath: selectedRepoPath,
                        plans: plannerPlans,
                        workspaceManager: workspaceManager,
                        onDisconnect: disconnectPlanner
                    )
                } else {
                    PlannerLoginView(
                        isLoading: isLoadingPlanner,
                        error: plannerError,
                        onLogin: loginPlanner
                    )
                }
            }

            // Linear Integration
            SettingsSection(title: "Linear") {
                if isLinearConnected {
                    LinearConnectedView(
                        teams: linearTeams,
                        onDisconnect: disconnectLinear
                    )
                } else {
                    LinearLoginSettingsView(
                        apiKey: $linearApiKey,
                        isLoading: isLoadingLinear,
                        error: linearError,
                        onLogin: loginLinear
                    )
                }
            }

            // Jira Integration
            SettingsSection(title: "Jira") {
                if isJiraConnected {
                    JiraConnectedView(
                        projects: jiraProjects,
                        onDisconnect: disconnectJira
                    )
                } else {
                    JiraLoginSettingsView(
                        siteUrl: $jiraSiteUrl,
                        email: $jiraEmail,
                        apiToken: $jiraApiToken,
                        isLoading: isLoadingJira,
                        error: jiraError,
                        onLogin: loginJira
                    )
                }
            }

            // Notion Integration
            SettingsSection(title: "Notion") {
                if isNotionConnected {
                    NotionConnectedView(
                        databases: notionDatabases,
                        onDisconnect: disconnectNotion
                    )
                } else {
                    NotionLoginSettingsView(
                        token: $notionToken,
                        isLoading: isLoadingNotion,
                        error: notionError,
                        onLogin: loginNotion
                    )
                }
            }

            // AWS CodeBuild Integration
            SettingsSection(title: "AWS CodeBuild") {
                if isAWSConnected {
                    AWSConnectedView(
                        region: awsRegion,
                        projects: awsProjects,
                        selectedRepoPath: selectedRepoPath,
                        workspaceManager: workspaceManager,
                        onDisconnect: disconnectAWS,
                        onRefresh: refreshAWSProjects
                    )
                } else {
                    AWSLoginView(
                        accessKeyId: $awsAccessKeyId,
                        secretAccessKey: $awsSecretAccessKey,
                        sessionToken: $awsSessionToken,
                        region: $awsRegion,
                        isLoading: isLoadingAWS,
                        error: awsError,
                        onConnect: connectAWS
                    )
                }
            }

            // Available integrations
            SettingsSection(title: "Other Integrations") {
                ForEach(IntegrationType.allCases.filter { !$0.isAvailable }) { integration in
                    HStack {
                        Image(systemName: integration.icon)
                            .foregroundColor(Color(hex: integration.color))
                            .frame(width: 24)
                        Text(integration.rawValue)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("Coming Soon")
                            .foregroundColor(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(AppTheme.textSecondary.opacity(0.2))
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                }
            }
            }
        }
        .padding()
        .background(AppTheme.background)
        .task {
            await loadState()
        }
    }

    private func repoName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private func loadState() async {
        // Set initial selected repo
        if selectedRepoPath == nil, let first = recentReposManager.recentRepos.first {
            selectedRepoPath = first.path
        }

        // Check Taiga connection
        if let token = try? await KeychainManager.shared.getTaigaToken(), !token.isEmpty {
            isTaigaConnected = true
            await TaigaService.shared.setToken(token)
            if let userIdStr = try? await KeychainManager.shared.getTaigaUserId(),
               let userId = Int(userIdStr) {
                await TaigaService.shared.setUserId(userId)
            }
            await loadTaigaProjects()
        }

        // Check Planner connection
        if let token = try? await KeychainManager.shared.getPlannerToken(), !token.isEmpty {
            await MicrosoftPlannerService.shared.setAccessToken(token)
            isPlannerConnected = true
            await loadPlannerPlans()
        }

        // Check Linear connection
        if let token = try? await KeychainManager.shared.getLinearToken(), !token.isEmpty {
            await LinearService.shared.setAccessToken(token)
            isLinearConnected = true
            await loadLinearTeams()
        }

        // Check Jira connection
        if let token = try? await KeychainManager.shared.getJiraToken(),
           let cloudId = try? await KeychainManager.shared.getJiraCloudId(),
           !token.isEmpty, !cloudId.isEmpty {
            await JiraService.shared.setAccessToken(token)
            await JiraService.shared.setCloudId(cloudId)
            isJiraConnected = true
            await loadJiraProjects()
        }

        // Check Notion connection
        if let token = try? await KeychainManager.shared.getNotionToken(), !token.isEmpty {
            await NotionService.shared.setAccessToken(token)
            isNotionConnected = true
            await loadNotionDatabases()
        }

        // Check AWS connection
        await loadAWSState()
    }

    private func loginTaiga() {
        isLoadingTaiga = true
        taigaError = nil

        Task {
            do {
                try await TaigaService.shared.authenticate(username: taigaUsername, password: taigaPassword)
                isTaigaConnected = true
                taigaPassword = ""
                await loadTaigaProjects()
            } catch {
                taigaError = error.localizedDescription
            }
            isLoadingTaiga = false
        }
    }

    private func loadTaigaProjects() async {
        do {
            taigaProjects = try await TaigaService.shared.listProjects()
        } catch {
            taigaError = "Failed to load projects"
        }
    }

    private func disconnectTaiga() {
        Task {
            try? await KeychainManager.shared.deleteTaigaToken()
            isTaigaConnected = false
            taigaProjects = []
        }
    }

    private func loginPlanner() {
        isLoadingPlanner = true
        plannerError = nil

        Task {
            // For Microsoft OAuth, we need to implement device flow
            // For now, show info about how to get a token
            plannerError = "Use Microsoft Azure AD to obtain an access token"
            isLoadingPlanner = false
        }
    }

    private func loadPlannerPlans() async {
        do {
            plannerPlans = try await MicrosoftPlannerService.shared.listPlans()
        } catch {
            plannerError = "Failed to load plans"
        }
    }

    private func disconnectPlanner() {
        Task {
            try? await KeychainManager.shared.deletePlannerToken()
            isPlannerConnected = false
            plannerPlans = []
        }
    }

    // MARK: - Linear Functions

    private func loginLinear() {
        isLoadingLinear = true
        linearError = nil

        Task {
            do {
                try await KeychainManager.shared.saveLinearToken(linearApiKey)
                await LinearService.shared.setAccessToken(linearApiKey)
                // Test connection
                _ = try await LinearService.shared.listTeams()
                isLinearConnected = true
                linearApiKey = ""
                await loadLinearTeams()
            } catch {
                linearError = error.localizedDescription
            }
            isLoadingLinear = false
        }
    }

    private func loadLinearTeams() async {
        do {
            linearTeams = try await LinearService.shared.listTeams()
        } catch {
            linearError = "Failed to load teams"
        }
    }

    private func disconnectLinear() {
        Task {
            try? await KeychainManager.shared.deleteLinearToken()
            isLinearConnected = false
            linearTeams = []
        }
    }

    // MARK: - Jira Functions

    private func loginJira() {
        isLoadingJira = true
        jiraError = nil

        Task {
            do {
                // Create Basic auth token
                let credentials = "\(jiraEmail):\(jiraApiToken)"
                let encodedCredentials = Data(credentials.utf8).base64EncodedString()
                let basicToken = "Basic \(encodedCredentials)"

                var cleanSiteUrl = jiraSiteUrl.trimmingCharacters(in: .whitespaces)
                if !cleanSiteUrl.hasPrefix("https://") {
                    cleanSiteUrl = "https://\(cleanSiteUrl)"
                }

                let cloudId = cleanSiteUrl
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: ".atlassian.net", with: "")
                    .replacingOccurrences(of: "/", with: "")

                try await KeychainManager.shared.saveJiraToken(basicToken)
                try await KeychainManager.shared.saveJiraCloudId(cloudId)
                try await KeychainManager.shared.saveJiraSiteUrl(cleanSiteUrl)

                await JiraService.shared.setAccessToken(basicToken, cloudId: cloudId, siteUrl: cleanSiteUrl)

                isJiraConnected = true
                jiraApiToken = ""
                await loadJiraProjects()
            } catch {
                jiraError = error.localizedDescription
            }
            isLoadingJira = false
        }
    }

    private func loadJiraProjects() async {
        do {
            jiraProjects = try await JiraService.shared.listProjects()
        } catch {
            jiraError = "Failed to load projects"
        }
    }

    private func disconnectJira() {
        Task {
            try? await KeychainManager.shared.deleteJiraCredentials()
            isJiraConnected = false
            jiraProjects = []
        }
    }

    // MARK: - Notion Functions

    private func loginNotion() {
        isLoadingNotion = true
        notionError = nil

        Task {
            do {
                try await KeychainManager.shared.saveNotionToken(notionToken)
                await NotionService.shared.setAccessToken(notionToken)
                // Test connection
                _ = try await NotionService.shared.search()
                isNotionConnected = true
                notionToken = ""
                await loadNotionDatabases()
            } catch {
                notionError = error.localizedDescription
            }
            isLoadingNotion = false
        }
    }

    private func loadNotionDatabases() async {
        do {
            notionDatabases = try await NotionService.shared.listDatabases()
        } catch {
            notionError = "Failed to load databases"
        }
    }

    private func disconnectNotion() {
        Task {
            try? await KeychainManager.shared.deleteNotionToken()
            isNotionConnected = false
            notionDatabases = []
        }
    }

    // MARK: - AWS Functions

    private func connectAWS() {
        isLoadingAWS = true
        awsError = nil

        Task {
            do {
                // Save credentials to keychain
                try await KeychainManager.shared.saveAWSCredentials(
                    accessKeyId: awsAccessKeyId,
                    secretAccessKey: awsSecretAccessKey,
                    sessionToken: awsSessionToken.isEmpty ? nil : awsSessionToken,
                    region: awsRegion
                )

                // Write to ~/.aws/credentials and ~/.aws/config
                try writeAWSCredentialsToFile()

                // Test connection
                let result = await testAWSConnection()
                if result.success {
                    isAWSConnected = true
                    awsProjects = result.projects
                } else {
                    awsError = result.error ?? "Connection failed"
                }
            } catch {
                awsError = error.localizedDescription
            }

            isLoadingAWS = false
        }
    }

    private func writeAWSCredentialsToFile() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let awsDir = homeDir.appendingPathComponent(".aws")

        // Create .aws directory if needed
        try FileManager.default.createDirectory(at: awsDir, withIntermediateDirectories: true)

        // Write credentials file
        var credentialsContent = "[default]\n"
        credentialsContent += "aws_access_key_id = \(awsAccessKeyId)\n"
        credentialsContent += "aws_secret_access_key = \(awsSecretAccessKey)\n"
        if !awsSessionToken.isEmpty {
            credentialsContent += "aws_session_token = \(awsSessionToken)\n"
        }

        let credentialsPath = awsDir.appendingPathComponent("credentials")
        try credentialsContent.write(to: credentialsPath, atomically: true, encoding: .utf8)

        // Write config file
        let configContent = "[default]\nregion = \(awsRegion)\noutput = json\n"
        let configPath = awsDir.appendingPathComponent("config")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
    }

    private func testAWSConnection() async -> (success: Bool, projects: [String], error: String?) {
        // Test with STS get-caller-identity
        let identityResult = runAWSCommand(["sts", "get-caller-identity"])
        if !identityResult.success {
            return (false, [], identityResult.output)
        }

        // List CodeBuild projects
        let projectsResult = runAWSCommand(["codebuild", "list-projects", "--output", "json"])
        if projectsResult.success {
            if let data = projectsResult.output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let projects = json["projects"] as? [String] {
                return (true, projects, nil)
            }
        }

        return (true, [], nil)  // Connected but no projects
    }

    private func runAWSCommand(_ arguments: [String]) -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aws")
        process.arguments = arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return (true, output)
            } else {
                return (false, error.isEmpty ? output : error)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func disconnectAWS() {
        Task {
            try? await KeychainManager.shared.deleteAWSCredentials()

            // Remove credentials files
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let credentialsPath = homeDir.appendingPathComponent(".aws/credentials")
            let configPath = homeDir.appendingPathComponent(".aws/config")
            try? FileManager.default.removeItem(at: credentialsPath)
            try? FileManager.default.removeItem(at: configPath)

            isAWSConnected = false
            awsProjects = []
            awsAccessKeyId = ""
            awsSecretAccessKey = ""
            awsSessionToken = ""
        }
    }

    private func refreshAWSProjects() {
        Task {
            isLoadingAWS = true
            let result = await testAWSConnection()
            awsProjects = result.projects
            isLoadingAWS = false
        }
    }

    private func loadAWSState() async {
        if let creds = try? await KeychainManager.shared.getAWSCredentials() {
            awsAccessKeyId = creds.accessKeyId
            awsSecretAccessKey = creds.secretAccessKey
            awsSessionToken = creds.sessionToken ?? ""
            awsRegion = creds.region

            let result = await testAWSConnection()
            isAWSConnected = result.success
            awsProjects = result.projects
        }
    }
}
