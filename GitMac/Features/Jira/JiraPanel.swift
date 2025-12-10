import SwiftUI

// MARK: - Jira Panel (Bottom Panel)

struct JiraPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = JiraViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            JiraPanelResizer(height: $height)

            // Header
            HStack(spacing: 12) {
                // Jira logo
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(Color(hex: "0052CC"))

                Text("Jira")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)

                // Project selector
                if !viewModel.projects.isEmpty {
                    Picker("", selection: $viewModel.selectedProjectKey) {
                        Text("All projects").tag(nil as String?)
                        ForEach(viewModel.projects) { project in
                            Text("\(project.key) - \(project.name)").tag(project.key as String?)
                        }
                    }
                    .frame(maxWidth: 250)
                    .labelsHidden()
                }

                // Filter
                Picker("", selection: $viewModel.filterMode) {
                    Text("My Issues").tag(JiraFilterMode.myIssues)
                    Text("Project").tag(JiraFilterMode.project)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Spacer()

                // Refresh
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(GitKrakenTheme.textMuted)

                // Settings
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(GitKrakenTheme.textMuted)

                // Close
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(GitKrakenTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(GitKrakenTheme.toolbar)

            Rectangle().fill(GitKrakenTheme.border).frame(height: 1)

            // Content
            if !viewModel.isAuthenticated {
                JiraLoginPrompt(viewModel: viewModel)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                JiraIssuesListView(issues: viewModel.issues)
            }
        }
        .frame(height: height)
        .background(GitKrakenTheme.panel)
        .sheet(isPresented: $viewModel.showSettings) {
            JiraSettingsSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedProjectKey) { _, _ in
            Task { await viewModel.refresh() }
        }
        .onChange(of: viewModel.filterMode) { _, _ in
            Task { await viewModel.refresh() }
        }
    }
}

// MARK: - Filter Mode

enum JiraFilterMode {
    case myIssues
    case project
}

// MARK: - View Model

@MainActor
class JiraViewModel: ObservableObject {
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

    init() {
        Task {
            if let token = try? await KeychainManager.shared.getJiraToken(),
               let cloudId = try? await KeychainManager.shared.getJiraCloudId() {
                await service.setAccessToken(token)
                await service.setCloudId(cloudId)
                await MainActor.run { isAuthenticated = true }
                await loadProjects()
                await refresh()
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

    func refresh() async {
        isLoading = true
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
        }
        isLoading = false
    }

    func logout() {
        Task {
            try? await KeychainManager.shared.deleteJiraToken()
            try? await KeychainManager.shared.deleteJiraCloudId()
        }
        isAuthenticated = false
        projects = []
        issues = []
    }
}

// MARK: - Login Prompt

struct JiraLoginPrompt: View {
    @ObservedObject var viewModel: JiraViewModel
    @State private var email = ""
    @State private var apiToken = ""
    @State private var siteUrl = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "0052CC"))

            Text("Connect to Jira")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GitKrakenTheme.textPrimary)

            Text("Enter your Jira Cloud credentials")
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                TextField("Site URL (e.g., yourcompany.atlassian.net)", text: $siteUrl)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)

                SecureField("API Token", text: $apiToken)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)
            }

            if let error = error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            Button {
                login()
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || apiToken.isEmpty || siteUrl.isEmpty || isLoading)

            Link("Get API token from Atlassian",
                 destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func login() {
        isLoading = true
        error = nil

        Task {
            do {
                // Create Basic auth token
                let credentials = "\(email):\(apiToken)"
                let encodedCredentials = Data(credentials.utf8).base64EncodedString()
                let basicToken = "Basic \(encodedCredentials)"

                // For Jira Server/Data Center, we use Basic auth
                // For Jira Cloud with API token, we also use Basic auth
                // Extract cloud ID from site URL
                var cleanSiteUrl = siteUrl.trimmingCharacters(in: .whitespaces)
                if !cleanSiteUrl.hasPrefix("https://") {
                    cleanSiteUrl = "https://\(cleanSiteUrl)"
                }

                // For cloud, we need to get the cloud ID
                // Using the REST API directly with Basic auth
                let cloudId = cleanSiteUrl
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: ".atlassian.net", with: "")
                    .replacingOccurrences(of: "/", with: "")

                // Save credentials
                try await KeychainManager.shared.saveJiraToken(basicToken)
                try await KeychainManager.shared.saveJiraCloudId(cloudId)
                try await KeychainManager.shared.saveJiraSiteUrl(cleanSiteUrl)

                // Configure service for direct REST API access
                await JiraService.shared.setAccessToken(basicToken, cloudId: cloudId, siteUrl: cleanSiteUrl)

                await MainActor.run {
                    viewModel.isAuthenticated = true
                    isLoading = false
                }

                await viewModel.loadProjects()
                await viewModel.refresh()
            } catch {
                await MainActor.run {
                    self.error = "Failed to connect: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Issues List

struct JiraIssuesListView: View {
    let issues: [JiraIssue]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(issues) { issue in
                    JiraIssueRow(issue: issue)
                }
            }
            .padding(8)
        }
    }
}

struct JiraIssueRow: View {
    let issue: JiraIssue
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Issue type icon
            if let issueType = issue.fields.issuetype {
                Image(systemName: issueTypeIcon(issueType.name))
                    .font(.system(size: 12))
                    .foregroundColor(issueTypeColor(issueType.name))
            }

            // Key
            Text(issue.key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "0052CC"))

            // Summary
            Text(issue.fields.summary)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Priority
            if let priority = issue.fields.priority {
                Text(priority.name)
                    .font(.system(size: 10))
                    .foregroundColor(priorityColor(priority.name))
            }

            // Status badge
            if let status = issue.fields.status {
                Text(status.name)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(status).opacity(0.2))
                    .foregroundColor(statusColor(status))
                    .cornerRadius(4)
            }

            // Insert to commit
            Button {
                NotificationCenter.default.post(
                    name: .insertJiraRef,
                    object: nil,
                    userInfo: ["key": issue.key, "summary": issue.fields.summary]
                )
            } label: {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 10))
                    .foregroundColor(GitKrakenTheme.accent)
            }
            .buttonStyle(.plain)
            .help("Insert into commit message")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? GitKrakenTheme.hover : Color.clear)
        .cornerRadius(4)
        .onHover { isHovered = $0 }
    }

    func issueTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "bug": return "ladybug.fill"
        case "story", "user story": return "book.fill"
        case "task": return "checkmark.square"
        case "epic": return "bolt.fill"
        case "subtask", "sub-task": return "arrow.turn.down.right"
        default: return "circle.fill"
        }
    }

    func issueTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "bug": return .red
        case "story", "user story": return .green
        case "task": return .blue
        case "epic": return .purple
        default: return .gray
        }
    }

    func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "highest", "blocker": return .red
        case "high", "critical": return .orange
        case "medium": return .yellow
        case "low": return .blue
        case "lowest": return .gray
        default: return .gray
        }
    }

    func statusColor(_ status: JiraStatus) -> Color {
        if let category = status.statusCategory {
            switch category.key {
            case "new", "undefined": return .gray
            case "indeterminate": return .blue
            case "done": return .green
            default: return .gray
            }
        }
        return .gray
    }
}

// MARK: - Settings Sheet

struct JiraSettingsSheet: View {
    @ObservedObject var viewModel: JiraViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jira Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GitKrakenTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(GitKrakenTheme.toolbar)

            Rectangle().fill(GitKrakenTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Jira")
                            .font(.system(size: 13))
                            .foregroundColor(GitKrakenTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                } else {
                    Text("Not connected to Jira")
                        .font(.system(size: 13))
                        .foregroundColor(GitKrakenTheme.textSecondary)
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(GitKrakenTheme.panel)
    }
}

// MARK: - Panel Resizer

struct JiraPanelResizer: View {
    @Binding var height: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(GitKrakenTheme.border)
            .frame(height: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newHeight = height - value.translation.height
                        height = min(max(newHeight, 150), 500)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let insertJiraRef = Notification.Name("insertJiraRef")
}
