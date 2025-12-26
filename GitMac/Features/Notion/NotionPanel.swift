import SwiftUI

// MARK: - Notion Panel (Bottom Panel)

struct NotionPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = NotionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            NotionPanelResizer(height: $height)

            // Header
            HStack(spacing: 12) {
                // Notion logo
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.primary)

                Text("Notion")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                // Database selector
                if !viewModel.databases.isEmpty {
                    Picker("", selection: $viewModel.selectedDatabaseId) {
                        Text("Select database...").tag(nil as String?)
                        ForEach(viewModel.databases) { db in
                            Text(db.displayTitle).tag(db.id as String?)
                        }
                    }
                    .frame(maxWidth: 250)
                    .labelsHidden()
                }

                Spacer()

                // Refresh
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textMuted)

                // Settings
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textMuted)

                // Close
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.toolbar)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Content
            if !viewModel.isAuthenticated {
                NotionLoginPrompt(viewModel: viewModel)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedDatabaseId == nil {
                NotionEmptyView(message: "Select a database to view tasks")
            } else {
                NotionTasksListView(tasks: viewModel.tasks)
            }
        }
        .frame(height: height)
        .background(AppTheme.panel)
        .sheet(isPresented: $viewModel.showSettings) {
            NotionSettingsSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedDatabaseId) { _, newId in
            if let id = newId {
                UserDefaults.standard.set(id, forKey: "notion_selected_database_id")
                Task { await viewModel.loadTasks(databaseId: id) }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class NotionViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    @Published var databases: [NotionDatabase] = []
    @Published var selectedDatabaseId: String?
    @Published var tasks: [NotionTask] = []

    private let service = NotionService.shared

    init() {
        Task {
            if let token = try? await KeychainManager.shared.getNotionToken() {
                await service.setAccessToken(token)
                await MainActor.run { isAuthenticated = true }
                await loadDatabases()

                // Restore selected database
                if let savedId = UserDefaults.standard.string(forKey: "notion_selected_database_id") {
                    await MainActor.run { selectedDatabaseId = savedId }
                    await loadTasks(databaseId: savedId)
                }
            }
        }
    }

    func loadDatabases() async {
        do {
            databases = try await service.listDatabases()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadTasks(databaseId: String) async {
        isLoading = true
        do {
            tasks = try await service.queryTasks(databaseId: databaseId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadDatabases()
        if let dbId = selectedDatabaseId {
            await loadTasks(databaseId: dbId)
        }
    }

    func logout() {
        Task {
            try? await KeychainManager.shared.deleteNotionToken()
        }
        isAuthenticated = false
        databases = []
        tasks = []
        selectedDatabaseId = nil
    }
}

// MARK: - Login Prompt

struct NotionLoginPrompt: View {
    @ObservedObject var viewModel: NotionViewModel
    @State private var integrationToken = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40))
                .foregroundColor(.primary)

            Text("Connect to Notion")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Enter your Notion integration token")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            SecureField("Integration Token", text: $integrationToken)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)

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
            .disabled(integrationToken.isEmpty || isLoading)

            VStack(spacing: 4) {
                Link("Create integration at Notion",
                     destination: URL(string: "https://www.notion.so/my-integrations")!)
                    .font(.system(size: 11))

                Text("Make sure to share your databases with the integration")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func login() {
        isLoading = true
        error = nil

        Task {
            do {
                try await KeychainManager.shared.saveNotionToken(integrationToken)
                await NotionService.shared.setAccessToken(integrationToken)

                // Test the connection
                _ = try await NotionService.shared.search()

                await MainActor.run {
                    viewModel.isAuthenticated = true
                    isLoading = false
                }

                await viewModel.loadDatabases()
            } catch {
                await MainActor.run {
                    self.error = "Failed to connect: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Tasks List

struct NotionTasksListView: View {
    let tasks: [NotionTask]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(tasks) { task in
                    NotionTaskRow(task: task)
                }
            }
            .padding(8)
        }
    }
}

struct NotionTaskRow: View {
    let task: NotionTask
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox style indicator
            Image(systemName: task.status?.lowercased() == "done" ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(task.status?.lowercased() == "done" ? .green : .secondary)

            // Title
            Text(task.title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .strikethrough(task.status?.lowercased() == "done")

            Spacer()

            // Status badge
            if let status = task.status {
                Text(status)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(task.statusColor).opacity(0.2))
                    .foregroundColor(statusColor(task.statusColor))
                    .cornerRadius(4)
            }

            // Open in Notion
            if let url = task.url {
                Link(destination: URL(string: url)!) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                .help("Open in Notion")
            }

            // Insert to commit
            Button {
                NotificationCenter.default.post(
                    name: .insertNotionRef,
                    object: nil,
                    userInfo: ["title": task.title, "id": task.id]
                )
            } label: {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .help("Insert into commit message")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .cornerRadius(4)
        .onHover { isHovered = $0 }
    }

    func statusColor(_ color: String?) -> Color {
        guard let color = color else { return .gray }
        switch color {
        case "gray": return .gray
        case "brown": return Color(hex: "8B4513")
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Empty View

struct NotionEmptyView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textMuted)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings Sheet

struct NotionSettingsSheet: View {
    @ObservedObject var viewModel: NotionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notion Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.toolbar)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Notion")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Text("\(viewModel.databases.count) databases available")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                } else {
                    Text("Not connected to Notion")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 350, height: 220)
        .background(AppTheme.panel)
    }
}

// MARK: - Panel Resizer

struct NotionPanelResizer: View {
    @Binding var height: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(AppTheme.border)
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
    static let insertNotionRef = Notification.Name("insertNotionRef")
}
