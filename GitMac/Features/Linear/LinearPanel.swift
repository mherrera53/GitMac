import SwiftUI

// MARK: - Linear Panel (Bottom Panel)

struct LinearPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = LinearViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            LinearPanelResizer(height: $height)

            // Header
            HStack(spacing: 12) {
                // Linear logo
                Image(systemName: "lineweight")
                    .foregroundColor(Color(hex: "5E6AD2"))

                Text("Linear")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                // Team selector
                if !viewModel.teams.isEmpty {
                    Picker("", selection: $viewModel.selectedTeamId) {
                        Text("All teams").tag(nil as String?)
                        ForEach(viewModel.teams) { team in
                            Text(team.name).tag(team.id as String?)
                        }
                    }
                    .frame(maxWidth: 200)
                    .labelsHidden()
                }

                // Filter
                Picker("", selection: $viewModel.filterMode) {
                    Text("My Issues").tag(LinearFilterMode.myIssues)
                    Text("All Issues").tag(LinearFilterMode.allIssues)
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
                LinearLoginPrompt(viewModel: viewModel)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LinearIssuesListView(issues: viewModel.issues)
            }
        }
        .frame(height: height)
        .background(AppTheme.panel)
        .sheet(isPresented: $viewModel.showSettings) {
            LinearSettingsSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedTeamId) { _, _ in
            Task { await viewModel.refresh() }
        }
        .onChange(of: viewModel.filterMode) { _, _ in
            Task { await viewModel.refresh() }
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
class LinearViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    @Published var teams: [LinearTeam] = []
    @Published var selectedTeamId: String?
    @Published var issues: [LinearIssue] = []
    @Published var filterMode: LinearFilterMode = .myIssues

    private let service = LinearService.shared

    init() {
        Task {
            if let token = try? await KeychainManager.shared.getLinearToken() {
                await service.setAccessToken(token)
                await MainActor.run { isAuthenticated = true }
                await loadTeams()
                await refresh()
            }
        }
    }

    func loadTeams() async {
        do {
            teams = try await service.listTeams()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        isLoading = true
        do {
            switch filterMode {
            case .myIssues:
                issues = try await service.listMyIssues()
            case .allIssues:
                issues = try await service.listIssues(teamId: selectedTeamId)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        Task {
            try? await KeychainManager.shared.deleteLinearToken()
        }
        isAuthenticated = false
        teams = []
        issues = []
    }
}

// MARK: - Login Prompt

struct LinearLoginPrompt: View {
    @ObservedObject var viewModel: LinearViewModel
    @State private var apiKey = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lineweight")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "5E6AD2"))

            Text("Connect to Linear")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Enter your Linear API key to view and manage issues")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

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
            .disabled(apiKey.isEmpty || isLoading)

            Link("Get API key from Linear Settings",
                 destination: URL(string: "https://linear.app/settings/api")!)
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
                try await KeychainManager.shared.saveLinearToken(apiKey)
                await LinearService.shared.setAccessToken(apiKey)

                // Test the connection
                _ = try await LinearService.shared.listTeams()

                await MainActor.run {
                    viewModel.isAuthenticated = true
                    isLoading = false
                }

                await viewModel.loadTeams()
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

struct LinearIssuesListView: View {
    let issues: [LinearIssue]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(issues) { issue in
                    LinearIssueRow(issue: issue)
                }
            }
            .padding(8)
        }
    }
}

struct LinearIssueRow: View {
    let issue: LinearIssue
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            // Identifier
            Text(issue.identifier)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "5E6AD2"))

            // Title
            Text(issue.title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // State badge
            if let state = issue.state {
                Text(state.name)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: state.color).opacity(0.2))
                    .foregroundColor(Color(hex: state.color))
                    .cornerRadius(4)
            }

            // Insert to commit
            Button {
                NotificationCenter.default.post(
                    name: .insertLinearRef,
                    object: nil,
                    userInfo: ["identifier": issue.identifier, "title": issue.title]
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

    var priorityColor: Color {
        switch issue.priority {
        case 1: return .red        // Urgent
        case 2: return .orange     // High
        case 3: return .yellow     // Medium
        case 4: return .blue       // Low
        default: return .gray      // No priority
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
                        Text("Connected to Linear")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                } else {
                    Text("Not connected to Linear")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(AppTheme.panel)
    }
}

// MARK: - Panel Resizer

struct LinearPanelResizer: View {
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
    static let insertLinearRef = Notification.Name("insertLinearRef")
}
