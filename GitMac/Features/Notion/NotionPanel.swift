import SwiftUI

// MARK: - Notion Panel (Bottom Panel)

struct NotionPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = NotionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Header
            HStack(spacing: DesignTokens.Spacing.md) {
                DSIcon("doc.text.fill", size: .md, color: AppTheme.textPrimary)

                Text("Notion")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                // Refresh button
                DSIconButton(
                    iconName: "arrow.clockwise",
                    variant: .ghost,
                    size: .sm
                ) {
                    try? await viewModel.refresh()
                }
                .disabled(viewModel.isLoading)

                // Settings button
                DSIconButton(
                    iconName: "gear",
                    variant: .ghost,
                    size: .sm
                ) {
                    viewModel.showSettings = true
                }

                // Close button
                DSCloseButton {
                    onClose()
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            DSDivider()

            // Content
            if viewModel.isLoading && !viewModel.isAuthenticated {
                DSLoadingState(message: "Loading...")
            } else if let error = viewModel.error {
                DSErrorState(
                    message: error,
                    onRetry: {
                        try? await viewModel.refresh()
                    }
                )
            } else if !viewModel.isAuthenticated {
                NotionLoginPrompt(viewModel: viewModel)
            } else {
                NotionContentView(viewModel: viewModel)
            }
        }
        .frame(height: height)
        .background(AppTheme.background)
        .sheet(isPresented: $viewModel.showSettings) {
            NotionSettingsSheet(viewModel: viewModel)
        }
    }
}

// MARK: - View Model

@MainActor
class NotionViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    @Published var databases: [NotionDatabase] = []
    @Published var selectedDatabaseId: String?
    @Published var tasks: [NotionTask] = []

    private let service = NotionService.shared

    nonisolated init() {
        Task { [weak self] in
            guard let self = self else { return }
            if let token = try? await KeychainManager.shared.getNotionToken() {
                await service.setAccessToken(token)
                await MainActor.run { [weak self] in
                    self?.isAuthenticated = true
                }
                await self.loadDatabases()

                // Restore selected database
                if let savedId = UserDefaults.standard.string(forKey: "notion_selected_database_id") {
                    await MainActor.run { [weak self] in
                        self?.selectedDatabaseId = savedId
                    }
                    await self.loadTasks(databaseId: savedId)
                }
            }
        }
    }

    // MARK: - IntegrationViewModel Protocol

    func authenticate() async throws {
        // Authentication is handled by NotionLoginPrompt
        // This method is called after credentials are stored in Keychain
        guard let token = try? await KeychainManager.shared.getNotionToken() else {
            throw NSError(domain: "NotionViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token found"])
        }

        await service.setAccessToken(token)

        // Test the connection
        _ = try await service.search()

        isAuthenticated = true
        await loadDatabases()
    }

    func refresh() async throws {
        await loadDatabases()
        if let dbId = selectedDatabaseId {
            await loadTasks(databaseId: dbId)
        }
    }

    // MARK: - Notion-specific methods

    func loadDatabases() async {
        do {
            databases = try await service.listDatabases()
        } catch {
            self.self.error = error.localizedDescription
        }
    }

    func loadTasks(databaseId: String) async {
        isLoading = true
        do {
            tasks = try await service.queryTasks(databaseId: databaseId)
        } catch {
            self.self.error = error.localizedDescription
        }
        isLoading = false
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
// Note: Custom login prompt for Notion that handles token-based authentication
// This is needed because the generic DSLoginPrompt doesn't handle the specific
// authentication flow for Notion (integration token + database sharing instructions)

struct NotionLoginPrompt: View {
    @ObservedObject var viewModel: NotionViewModel
    @State private var integrationToken = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.text.fill")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(AppTheme.textPrimary)

            Text("Connect to Notion")
                .font(DesignTokens.Typography.headline) // Was: .system(size: 15, weight: .semibold)
                .foregroundColor(AppTheme.textPrimary)

            Text("Enter your Notion integration token")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            SecureField("Integration Token", text: $integrationToken)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)

            if let error = error {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.error)
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

            VStack(spacing: DesignTokens.Spacing.xs) {
                Link("Create integration at Notion",
                     destination: URL(string: "https://www.notion.so/my-integrations")!)
                    .font(DesignTokens.Typography.caption)

                Text("Make sure to share your databases with the integration")
                    .font(DesignTokens.Typography.caption2)
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
                    self.self.error = "Failed to connect: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
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
                    .font(DesignTokens.Typography.headline) // Was: .system(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.callout) // Was: .system(size: 12, weight: .medium)
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                        Text("Connected to Notion")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Text("\(viewModel.databases.count) databases available")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textSecondary)

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.error)
                } else {
                    Text("Not connected to Notion")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
        }
        .frame(width: 350, height: 220)
        .background(AppTheme.backgroundSecondary)
    }
}

// MARK: - Content View

struct NotionContentView: View {
    @ObservedObject var viewModel: NotionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Database selector
            if !viewModel.databases.isEmpty {
                HStack(spacing: DesignTokens.Spacing.md) {
                    DSIcon("folder.fill", size: .sm, color: AppTheme.textSecondary)

                    Picker("", selection: $viewModel.selectedDatabaseId) {
                        Text("Select database...").tag(nil as String?)
                        ForEach(viewModel.databases) { db in
                            Text(db.displayTitle).tag(db.id as String?)
                        }
                    }
                    .labelsHidden()
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                DSDivider()
            }

            // Content
            if viewModel.isLoading {
                DSLoadingState(message: "Loading tasks...")
            } else if viewModel.selectedDatabaseId == nil {
                DSEmptyState(
                    icon: "tray",
                    title: "No Database Selected",
                    description: "Select a database to view tasks"
                )
            } else if viewModel.tasks.isEmpty {
                DSEmptyState(
                    icon: "checkmark.circle",
                    title: "No Tasks",
                    description: "This database has no tasks"
                )
            } else {
                NotionTasksListView(tasks: viewModel.tasks)
            }
        }
        .onChange(of: viewModel.selectedDatabaseId) { _, newId in
            if let id = newId {
                UserDefaults.standard.set(id, forKey: "notion_selected_database_id")
                Task { await viewModel.loadTasks(databaseId: id) }
            }
        }
    }
}

// MARK: - Tasks List

struct NotionTasksListView: View {
    let tasks: [NotionTask]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(tasks) { task in
                    NotionTaskRow(task: task)
                }
            }
            .padding(DesignTokens.Spacing.sm)
        }
    }
}

struct NotionTaskRow: View {
    let task: NotionTask
    @State private var isHovered = false

    var body: some View {
        let isDone = task.status?.lowercased() == "done"

        HStack(spacing: DesignTokens.Spacing.md) {
            // Completion indicator
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(DesignTokens.Typography.callout) // Was: .system(size: 12)
                .foregroundColor(isDone ? AppTheme.success : AppTheme.textSecondary)

            // Task title
            Text(task.title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            // Link to Notion
            if let url = task.url {
                Link(destination: URL(string: url)!) {
                    Image(systemName: "arrow.up.right.square")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.textMuted)
                }
                .help("Open in Notion")
            }

            // Status badge
            if let status = task.status {
                Text(status)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(statusColor(task.statusColor))
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(statusColor(task.statusColor).opacity(0.2))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }

            // Insert button (shown on hover)
            if isHovered {
                DSIconButton(
                    iconName: "arrow.right.doc.on.clipboard",
                    variant: .ghost,
                    size: .sm
                ) {
                    NotificationCenter.default.post(
                        name: .insertNotionRef,
                        object: nil,
                        userInfo: ["title": task.title, "id": task.id]
                    )
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isHovered ? AppTheme.backgroundSecondary : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fastEasing) {
                isHovered = hovering
            }
        }
    }

    private func statusColor(_ color: String?) -> Color {
        guard let color = color else { return AppTheme.textSecondary }
        switch color {
        case "gray": return AppTheme.textSecondary
        case "brown": return Color(hex: "8B4513")  // Notion API color, do not change
        case "orange": return AppTheme.warning
        case "yellow": return AppTheme.warning
        case "green": return AppTheme.success
        case "blue": return AppTheme.accent
        case "purple": return AppTheme.accentPurple
        case "pink": return Color(hex: "FF69B4")  // Notion API color, do not change
        case "red": return AppTheme.error
        default: return AppTheme.textSecondary
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let insertNotionRef = Notification.Name("insertNotionRef")
}
