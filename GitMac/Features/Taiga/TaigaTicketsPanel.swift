import SwiftUI

// MARK: - Taiga Tickets Panel (Bottom Panel)

struct TaigaTicketsPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = TaigaTicketsViewModel()
    @State private var selectedTab: TaigaTab = .userStories

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            TaigaPanelResizer(height: $height)

            // Header
            HStack(spacing: 12) {
                // Taiga logo
                Image(systemName: "ticket.fill")
                    .foregroundColor(.green)

                Text("Taiga")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)

                // Project selector
                if !viewModel.projects.isEmpty {
                    Picker("", selection: $viewModel.selectedProjectId) {
                        Text("Select project...").tag(nil as Int?)
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(project.id as Int?)
                        }
                    }
                    .frame(maxWidth: 200)
                    .labelsHidden()
                }

                // Tabs
                Picker("", selection: $selectedTab) {
                    ForEach(TaigaTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

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
                TaigaLoginPrompt(viewModel: viewModel)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedTab {
                case .userStories:
                    TaigaUserStoriesView(stories: viewModel.userStories, viewModel: viewModel)
                case .tasks:
                    TaigaTasksView(tasks: viewModel.tasks)
                case .issues:
                    TaigaIssuesView(issues: viewModel.issues)
                case .epics:
                    TaigaEpicsView(epics: viewModel.epics)
                }
            }
        }
        .frame(height: height)
        .background(GitKrakenTheme.panel)
        .sheet(isPresented: $viewModel.showSettings) {
            TaigaSettingsSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedProjectId) { _, newId in
            if let id = newId {
                Task { await viewModel.loadProjectData(projectId: id) }
            }
        }
    }
}

// MARK: - Tabs

enum TaigaTab: String, CaseIterable {
    case userStories = "Stories"
    case tasks = "Tasks"
    case issues = "Issues"
    case epics = "Epics"
}

// MARK: - View Model

@MainActor
class TaigaTicketsViewModel: ObservableObject {
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

    private let service = TaigaService.shared

    init() {
        // Check if token exists in keychain
        Task {
            if let token = try? await KeychainManager.shared.getTaigaToken() {
                await service.setToken(token)
                // Also restore userId for project filtering
                if let userId = try? await KeychainManager.shared.getTaigaUserId() {
                    await service.setUserId(userId)
                    print("🔐 Taiga: Restored userId \(userId)")
                }
                await MainActor.run {
                    isAuthenticated = true
                }
                await loadProjects()

                // Restore selected project
                let savedProjectId = UserDefaults.standard.integer(forKey: "taiga_selected_project_id")
                if savedProjectId > 0 {
                    await MainActor.run {
                        selectedProjectId = savedProjectId
                    }
                    await loadProjectData(projectId: savedProjectId)
                }
            }
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await service.login(username: username, password: password)
            try await KeychainManager.shared.saveTaigaToken(response.authToken)
            // Save userId for project filtering
            try await KeychainManager.shared.saveTaigaUserId(response.id)
            await service.setUserId(response.id)
            isAuthenticated = true
            await loadProjects()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        Task {
            try? await KeychainManager.shared.deleteTaigaToken()
            try? await KeychainManager.shared.deleteTaigaUserId()
        }
        isAuthenticated = false
        projects = []
        selectedProjectId = nil
        userStories = []
        tasks = []
        issues = []
        epics = []
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

    func refresh() async {
        if let projectId = selectedProjectId {
            await loadProjectData(projectId: projectId)
        }
    }
}

// MARK: - Login Prompt

struct TaigaLoginPrompt: View {
    @ObservedObject var viewModel: TaigaTicketsViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("Connect to Taiga")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GitKrakenTheme.textPrimary)

            Text("Log in to view your project tickets from tree.taiga.io")
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                TextField("Username or Email", text: $username)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(GitKrakenTheme.backgroundSecondary)
                    .cornerRadius(6)
                    .frame(width: 250)

                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(GitKrakenTheme.backgroundSecondary)
                    .cornerRadius(6)
                    .frame(width: 250)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(GitKrakenTheme.accentRed)
            }

            Button {
                Task {
                    await viewModel.login(username: username, password: password)
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 100, height: 24)
                } else {
                    Text("Log In")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || viewModel.isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - User Stories View

struct TaigaUserStoriesView: View {
    let stories: [TaigaUserStory]
    @ObservedObject var viewModel: TaigaTicketsViewModel

    var body: some View {
        if stories.isEmpty {
            TaigaEmptyView(type: "user stories")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(groupedStories.keys.sorted(), id: \.self) { statusId in
                        TaigaKanbanColumn(
                            status: viewModel.statuses.first { $0.id == statusId },
                            items: groupedStories[statusId] ?? []
                        )
                    }
                }
                .padding(12)
            }
        }
    }

    var groupedStories: [Int: [TaigaUserStory]] {
        Dictionary(grouping: stories) { $0.status }
    }
}

// MARK: - Kanban Column

struct TaigaKanbanColumn: View {
    let status: TaigaStatus?
    let items: [TaigaUserStory]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: status?.color ?? "888888"))
                    .frame(width: 8, height: 8)

                Text(status?.name ?? "Unknown")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)

                Text("\(items.count)")
                    .font(.system(size: 10))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(GitKrakenTheme.backgroundTertiary)
                    .cornerRadius(4)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(GitKrakenTheme.backgroundSecondary)
            .cornerRadius(6)

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(items) { story in
                        TaigaStoryCard(story: story)
                    }
                }
            }
        }
        .frame(width: 280)
    }
}

// MARK: - Story Card

struct TaigaStoryCard: View {
    let story: TaigaUserStory
    @State private var isHovered = false
    @State private var showCopied = false

    var taigaRef: String {
        "TG-\(story.ref)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // TG Reference & Subject
            HStack(spacing: 6) {
                // Clickable TG reference badge
                Button {
                    copyToClipboard(taigaRef)
                } label: {
                    Text(taigaRef)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                        )
                }
                .buttonStyle(.plain)
                .help("Click to copy \(taigaRef)")

                Text(story.subject)
                    .font(.system(size: 12))
                    .foregroundColor(GitKrakenTheme.textPrimary)
                    .lineLimit(2)
            }

            // Tags
            if let tags = story.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(3), id: \.first) { tag in
                        if let tagName = tag.first, let tagColor = tag.last {
                            Text(tagName)
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: tagColor).opacity(0.3))
                                .foregroundColor(Color(hex: tagColor))
                                .cornerRadius(3)
                        }
                    }
                }
            }

            // Points & Assignee & Copy button
            HStack {
                if let points = story.totalPoints {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                        Text("\(Int(points))")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(GitKrakenTheme.textMuted)
                }

                Spacer()

                // Insert to commit button
                Button {
                    NotificationCenter.default.post(
                        name: .insertTaigaRef,
                        object: nil,
                        userInfo: ["ref": taigaRef, "subject": story.subject]
                    )
                } label: {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(GitKrakenTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert \(taigaRef) into commit message")

                if let assignee = story.assignedToExtraInfo {
                    Text(assignee.fullName.split(separator: " ").first.map(String.init) ?? assignee.username)
                        .font(.system(size: 10))
                        .foregroundColor(GitKrakenTheme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(isHovered ? GitKrakenTheme.hover : GitKrakenTheme.backgroundSecondary)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color.green.opacity(0.5) : GitKrakenTheme.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .overlay(alignment: .topTrailing) {
            if showCopied {
                Text("Copied!")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
                    .offset(x: -4, y: 4)
                    .transition(.opacity)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Notification for Taiga Reference
extension Notification.Name {
    static let insertTaigaRef = Notification.Name("insertTaigaRef")
}

// MARK: - Tasks View

struct TaigaTasksView: View {
    let tasks: [TaigaTask]

    var body: some View {
        if tasks.isEmpty {
            TaigaEmptyView(type: "tasks")
        } else {
            List(tasks) { task in
                TaigaTaskRow(task: task)
            }
            .listStyle(.plain)
        }
    }
}

struct TaigaTaskRow: View {
    let task: TaigaTask
    @State private var isHovered = false

    var taigaRef: String {
        "TG-\(task.ref)"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(Color(hex: task.statusExtraInfo?.color ?? "888888"))
                .frame(width: 8, height: 8)

            // TG Reference badge
            Button {
                copyToClipboard(taigaRef)
            } label: {
                Text(taigaRef)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.orange)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .help("Click to copy \(taigaRef)")

            // Subject
            Text(task.subject)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Insert button
            if isHovered {
                Button {
                    NotificationCenter.default.post(
                        name: .insertTaigaRef,
                        object: nil,
                        userInfo: ["ref": taigaRef, "subject": task.subject]
                    )
                } label: {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(GitKrakenTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert into commit")
            }

            // Status badge
            if let status = task.statusExtraInfo {
                Text(status.name)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: status.color).opacity(0.2))
                    .foregroundColor(Color(hex: status.color))
                    .cornerRadius(4)
            }

            // Assignee
            if let assignee = task.assignedToExtraInfo {
                Text(assignee.username)
                    .font(.system(size: 10))
                    .foregroundColor(GitKrakenTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Issues View

struct TaigaIssuesView: View {
    let issues: [TaigaIssue]

    var body: some View {
        if issues.isEmpty {
            TaigaEmptyView(type: "issues")
        } else {
            List(issues) { issue in
                TaigaIssueRow(issue: issue)
            }
            .listStyle(.plain)
        }
    }
}

struct TaigaIssueRow: View {
    let issue: TaigaIssue
    @State private var isHovered = false

    var taigaRef: String {
        "TG-\(issue.ref)"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: "ladybug.fill")
                .foregroundColor(Color(hex: issue.typeExtraInfo?.color ?? "ff6b6b"))
                .font(.system(size: 12))

            // TG Reference badge
            Button {
                copyToClipboard(taigaRef)
            } label: {
                Text(taigaRef)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.red)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .help("Click to copy \(taigaRef)")

            // Subject
            Text(issue.subject)
                .font(.system(size: 12))
                .foregroundColor(GitKrakenTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Insert button
            if isHovered {
                Button {
                    NotificationCenter.default.post(
                        name: .insertTaigaRef,
                        object: nil,
                        userInfo: ["ref": taigaRef, "subject": issue.subject]
                    )
                } label: {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(GitKrakenTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert into commit")
            }

            // Type badge
            if let type = issue.typeExtraInfo {
                Text(type.name)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: type.color).opacity(0.2))
                    .foregroundColor(Color(hex: type.color))
                    .cornerRadius(4)
            }

            // Status badge
            if let status = issue.statusExtraInfo {
                Text(status.name)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: status.color).opacity(0.2))
                    .foregroundColor(Color(hex: status.color))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Epics View

struct TaigaEpicsView: View {
    let epics: [TaigaEpic]

    var body: some View {
        if epics.isEmpty {
            TaigaEmptyView(type: "epics")
        } else {
            List(epics) { epic in
                TaigaEpicRow(epic: epic)
            }
            .listStyle(.plain)
        }
    }
}

struct TaigaEpicRow: View {
    let epic: TaigaEpic

    var body: some View {
        HStack(spacing: 10) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: epic.color ?? "7b68ee"))
                .frame(width: 4, height: 24)

            // Ref
            Text("#\(epic.ref)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(GitKrakenTheme.textMuted)

            // Subject
            Text(epic.subject)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GitKrakenTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Status badge
            if let status = epic.statusExtraInfo {
                Text(status.name)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: status.color).opacity(0.2))
                    .foregroundColor(Color(hex: status.color))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty View

struct TaigaEmptyView: View {
    let type: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(GitKrakenTheme.textMuted)

            Text("No \(type) found")
                .font(.system(size: 13))
                .foregroundColor(GitKrakenTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings Sheet

struct TaigaSettingsSheet: View {
    @ObservedObject var viewModel: TaigaTicketsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Taiga Settings")
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

            // Content
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Taiga")
                            .font(.system(size: 13))
                            .foregroundColor(GitKrakenTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                } else {
                    Text("Not connected to Taiga")
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

struct TaigaPanelResizer: View {
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

// MARK: - Keychain Extension for Taiga

extension KeychainManager {
    func saveTaigaToken(_ token: String) throws {
        try save(key: "taiga_auth_token", value: token)
    }

    func getTaigaToken() throws -> String? {
        try get(key: "taiga_auth_token")
    }

    func deleteTaigaToken() throws {
        try delete(key: "taiga_auth_token")
    }

    func saveTaigaUserId(_ id: Int) throws {
        try save(key: "taiga_user_id", value: String(id))
    }

    func getTaigaUserId() throws -> Int? {
        guard let idString = try get(key: "taiga_user_id") else { return nil }
        return Int(idString)
    }

    func deleteTaigaUserId() throws {
        try delete(key: "taiga_user_id")
    }
}
