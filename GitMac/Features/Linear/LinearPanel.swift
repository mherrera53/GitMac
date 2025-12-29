import SwiftUI

// MARK: - Linear Panel (Bottom Panel)

struct LinearPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = LinearViewModel()

    var body: some View {
        DSIntegrationBottomPanel(
            title: "Linear",
            icon: "lineweight",
            iconColor: Color(hex: "5E6AD2"),
            viewModel: viewModel,
            content: {
                LinearContentView(viewModel: viewModel)
            },
            loginView: {
                LinearLoginPrompt(viewModel: viewModel)
            },
            height: $height,
            onSettings: {
                viewModel.showSettings = true
            },
            onClose: onClose
        )
        .sheet(isPresented: $viewModel.showSettings) {
            LinearSettingsSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Filter Mode

enum LinearFilterMode {
    case myIssues
    case allIssues
}

// MARK: - View Model

@MainActor
class LinearViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    @Published var teams: [LinearTeam] = []
    @Published var selectedTeamId: String?
    @Published var issues: [LinearIssue] = []
    @Published var filterMode: LinearFilterMode = .myIssues

    private let service = LinearService.shared

    nonisolated init() {
        Task { [weak self] in
            guard let self = self else { return }
            if let token = try? await KeychainManager.shared.getLinearToken() {
                await service.setAccessToken(token)
                await MainActor.run { [weak self] in
                    self?.isAuthenticated = true
                }
                await self.loadTeams()
                try? await self.refresh()
            }
        }
    }

    // MARK: - IntegrationViewModel Protocol

    func authenticate() async throws {
        // Authentication is handled by LinearLoginPrompt
        // This method is called after credentials are stored in Keychain
        guard let token = try? await KeychainManager.shared.getLinearToken() else {
            throw NSError(domain: "LinearViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token found"])
        }

        await service.setAccessToken(token)

        // Test the connection
        _ = try await service.listTeams()

        isAuthenticated = true
        await loadTeams()
        try await refresh()
    }

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            switch filterMode {
            case .myIssues:
                issues = try await service.listMyIssues()
            case .allIssues:
                issues = try await service.listIssues(teamId: selectedTeamId)
            }
        } catch {
            self.self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Linear-specific methods

    func loadTeams() async {
        do {
            teams = try await service.listTeams()
        } catch {
            self.self.error = error.localizedDescription
        }
    }

    func logout() {
        Task { [weak self] in
            try? await KeychainManager.shared.deleteLinearToken()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isAuthenticated = false
                self.teams = []
                self.issues = []
            }
        }
    }
}

// MARK: - Login Prompt

struct LinearLoginPrompt: View {
    @ObservedObject var viewModel: LinearViewModel
    @State private var apiKey = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "lineweight")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(Color(hex: "5E6AD2"))

            Text("Connect to Linear")
                .font(DesignTokens.Typography.headline) // Was: .system(size: 15, weight: .semibold)
                .foregroundColor(AppTheme.textPrimary)

            Text("Enter your Linear API key to view and manage issues")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            DSSecureField(placeholder: "API Key", text: $apiKey)
                .frame(maxWidth: 300)

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
            .disabled(apiKey.isEmpty || isLoading)

            Link("Get API key from Linear Settings",
                 destination: URL(string: "https://linear.app/settings/api")!)
                .font(DesignTokens.Typography.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func login() {
        isLoading = true
        error = nil

        Task {
            do {
                try await KeychainManager.shared.saveLinearToken(apiKey)
                await LinearService.shared.setAccessToken(apiKey)

                // Test the connection
                _ = try await LinearService.shared.listTeams()

                await MainActor.run {
                    viewModel.isAuthenticated = true
                    isLoading = false
                }

                await viewModel.loadTeams()
                try await viewModel.refresh()
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

struct LinearSettingsSheet: View {
    @ObservedObject var viewModel: LinearViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Linear Settings")
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
            .background(AppTheme.toolbar)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                        Text("Connected to Linear")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.error)
                } else {
                    Text("Not connected to Linear")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(AppTheme.panel)
    }
}

// MARK: - Content View

struct LinearContentView: View {
    @ObservedObject var viewModel: LinearViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Team and filter controls
            HStack(spacing: DesignTokens.Spacing.md) {
                // Team selector
                if !viewModel.teams.isEmpty {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        DSIcon("person.2.fill", size: .sm, color: AppTheme.textSecondary)

                        Picker("", selection: $viewModel.selectedTeamId) {
                            Text("All teams").tag(nil as String?)
                            ForEach(viewModel.teams) { team in
                                Text(team.name).tag(team.id as String?)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Spacer()

                // Filter mode
                Picker("", selection: $viewModel.filterMode) {
                    Text("My Issues").tag(LinearFilterMode.myIssues)
                    Text("All Issues").tag(LinearFilterMode.allIssues)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            DSDivider()

            // Content
            if viewModel.isLoading {
                DSLoadingState(message: "Loading issues...")
            } else if viewModel.issues.isEmpty {
                DSEmptyState(
                    icon: "checkmark.circle",
                    title: "No Issues",
                    description: "No issues found for the selected filter"
                )
            } else {
                LinearIssuesListView(issues: viewModel.issues)
            }
        }
        .onChange(of: viewModel.selectedTeamId) { _, _ in
            Task { try? await viewModel.refresh() }
        }
        .onChange(of: viewModel.filterMode) { _, _ in
            Task { try? await viewModel.refresh() }
        }
    }
}

// MARK: - Issues List

struct LinearIssuesListView: View {
    let issues: [LinearIssue]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(issues) { issue in
                    LinearIssueRow(issue: issue)
                }
            }
            .padding(DesignTokens.Spacing.sm)
        }
    }
}

struct LinearIssueRow: View {
    let issue: LinearIssue
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            // Issue identifier
            Text(issue.identifier)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)

            // Issue title
            Text(issue.title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            // Status badge
            if let state = issue.state {
                Text(state.name)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(Color(hex: state.color))
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(Color(hex: state.color).opacity(0.2))
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
                        name: .insertLinearRef,
                        object: nil,
                        userInfo: ["identifier": issue.identifier, "title": issue.title]
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

    private var priorityColor: Color {
        switch issue.priority {
        case 1: return AppTheme.error      // Urgent
        case 2: return AppTheme.warning    // High
        case 3: return AppTheme.warning    // Medium
        case 4: return AppTheme.accent     // Low
        default: return AppTheme.textSecondary  // No priority
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let insertLinearRef = Notification.Name("insertLinearRef")
}
