//
//  CICDComponents.swift
//  GitMac
//
//  Extracted from ContentView.swift
//  Contains: CICDSidebarSection, UnifiedCICDPanel, CICDSidebarViewModel, CICDProviderRow, WorkflowsPanel
//

import SwiftUI
import Foundation

// MARK: - CI/CD Sidebar Section
struct CICDSidebarSection: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CICDSidebarViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showCICDPanel = false
    @State private var selectedTab: CICDTab = .github

    enum CICDTab: String, CaseIterable {
        case github = "GitHub Actions"
        case aws = "AWS CodeBuild"

        var icon: String {
            switch self {
            case .github: return "bolt.circle.fill"
            case .aws: return "cloud.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // GitHub Actions
            if viewModel.hasGitHub {
                CICDProviderRow(
                    icon: "bolt.circle.fill",
                    name: "GitHub Actions",
                    status: viewModel.githubStatus,
                    statusColor: viewModel.githubStatusColor,
                    count: viewModel.githubRunningCount
                ) {
                    selectedTab = .github
                    showCICDPanel = true
                }
            }

            // AWS CodeBuild
            if viewModel.hasAWS {
                CICDProviderRow(
                    icon: "cloud.fill",
                    name: "AWS CodeBuild",
                    status: viewModel.awsStatus,
                    statusColor: viewModel.awsStatusColor,
                    count: viewModel.awsRunningCount
                ) {
                    selectedTab = .aws
                    showCICDPanel = true
                }
            }

            if !viewModel.hasGitHub && !viewModel.hasAWS {
                HStack {
                    Text("No CI/CD configured")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .task {
            await viewModel.refresh(appState: appState)
        }
        .sheet(isPresented: $showCICDPanel) {
            UnifiedCICDPanel(selectedTab: $selectedTab, hasGitHub: viewModel.hasGitHub, hasAWS: viewModel.hasAWS)
                .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCICD)) { _ in
            selectedTab = viewModel.hasAWS ? .aws : .github
            showCICDPanel = true
        }
    }
}

// MARK: - Unified CI/CD Panel with Tabs

struct UnifiedCICDPanel: View {
    @Binding var selectedTab: CICDSidebarSection.CICDTab
    let hasGitHub: Bool
    let hasAWS: Bool
    @Environment(\.dismiss) private var dismiss

    private var tabs: [DSTabInfo] {
        var result: [DSTabInfo] = []
        if hasGitHub {
            result.append(DSTabInfo(id: "github", title: "GitHub", icon: "arrow.triangle.branch"))
        }
        if hasAWS {
            result.append(DSTabInfo(id: "aws", title: "AWS", icon: "cloud.fill"))
        }
        return result
    }

    private var selectedTabId: Binding<String> {
        Binding(
            get: { selectedTab == .github ? "github" : "aws" },
            set: { newValue in
                selectedTab = newValue == "github" ? .github : .aws
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header usando Design System
            HStack(spacing: DesignTokens.Spacing.md) {
                DSText(
                    "CI/CD",
                    variant: .headline,
                    color: AppTheme.textPrimary
                )

                Spacer()

                DSIconButton(
                    iconName: "xmark.circle.fill",
                    size: .md
                ) {
                    dismiss()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            // Tab container con Design System
            DSTabContainer(
                tabs: tabs,
                selectedTab: selectedTabId
            ) { tabId in
                tabContent(for: tabId)
            }
        }
        .frame(width: DesignTokens.Layout.CICDPanel.width, height: DesignTokens.Layout.CICDPanel.height)
        .background(AppTheme.background)
    }

    @ViewBuilder
    private func tabContent(for tabId: String) -> some View {
        switch tabId {
        case "github":
            WorkflowsView()
                .background(AppTheme.background)
        case "aws":
            AWSCodeBuildPanel()
        default:
            DSEmptyState(
                icon: "exclamationmark.triangle",
                title: "Unknown Tab",
                description: "Tab not found"
            )
        }
    }
}

// MARK: - CI/CD Provider Row
struct CICDProviderRow: View {
    let icon: String
    let name: String
    let status: String
    let statusColor: Color
    let count: Int
    let action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.warning)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if count > 0 {
                    HStack(spacing: 2) {
                        ProgressView()
                            .scaleEffect(0.4)
                        Text("\(count)")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.info)
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - CI/CD Sidebar ViewModel
@MainActor
class CICDSidebarViewModel: ObservableObject {
    @Published var hasGitHub = false
    @Published var hasAWS = false
    @Published var githubStatus = "unknown"
    @Published var awsStatus = "unknown"
    @Published var githubRunningCount = 0
    @Published var awsRunningCount = 0

    var githubStatusColor: Color {
        switch githubStatus {
        case "success": return AppTheme.success
        case "failure": return AppTheme.error
        case "running": return AppTheme.accent
        default: return AppTheme.textSecondary
        }
    }

    var awsStatusColor: Color {
        switch awsStatus {
        case "success": return AppTheme.success
        case "failure": return AppTheme.error
        case "running": return AppTheme.accent
        default: return AppTheme.textSecondary
        }
    }

    func refresh(appState: AppState) async {
        // Check GitHub
        let githubToken = (try? await KeychainManager.shared.getGitHubToken()) ?? ""
        hasGitHub = !githubToken.isEmpty

        // Check AWS (look for AWS credentials in file or environment)
        let awsFileConfigured = FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.aws/credentials")
        let awsEnvConfigured = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] != nil
        hasAWS = awsFileConfigured || awsEnvConfigured

        if hasGitHub {
            await fetchGitHubStatus(appState: appState, token: githubToken)
        }
    }

    private func fetchGitHubStatus(appState: AppState, token: String) async {
        guard let remote = appState.currentRepository?.remotes.first,
              let url = URL(string: remote.fetchURL) else { return }

        let pathComponents = url.path
            .replacingOccurrences(of: ".git", with: "")
            .split(separator: "/")
            .map(String.init)

        guard pathComponents.count >= 2 else { return }

        let owner = pathComponents[pathComponents.count - 2]
        let repo = pathComponents[pathComponents.count - 1]

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/actions/runs?per_page=10"
        guard let apiURL = URL(string: urlString) else { return }

        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            struct Response: Codable {
                let workflowRuns: [Run]
                enum CodingKeys: String, CodingKey { case workflowRuns = "workflow_runs" }
                struct Run: Codable {
                    let status: String
                    let conclusion: String?
                }
            }

            let response = try decoder.decode(Response.self, from: data)

            // Count running
            githubRunningCount = response.workflowRuns.filter { $0.status == "in_progress" || $0.status == "queued" }.count

            // Get latest status
            if let latest = response.workflowRuns.first {
                if latest.status == "in_progress" || latest.status == "queued" {
                    githubStatus = "running"
                } else if latest.conclusion == "success" {
                    githubStatus = "success"
                } else if latest.conclusion == "failure" {
                    githubStatus = "failure"
                }
            }
        } catch {
            // Ignore errors silently
        }
    }
}

// MARK: - Workflows Panel (Sheet)
struct WorkflowsPanel: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header usando Design System
            HStack(spacing: DesignTokens.Spacing.md) {
                DSText(
                    "GitHub Actions",
                    variant: .headline,
                    color: AppTheme.textPrimary
                )

                Spacer()

                DSButton(variant: .primary, size: .sm) {
                    dismiss()
                } label: {
                    Text("Done")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)

            DSDivider()

            WorkflowsView()
        }
        .frame(width: DesignTokens.Layout.WorkflowsPanel.width, height: DesignTokens.Layout.WorkflowsPanel.height)
        .background(AppTheme.background)
    }
}
