import SwiftUI

// MARK: - Workspace Settings Tab

struct WorkspaceConfigView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var workspaceManager = WorkspaceSettingsManager.shared
    @EnvironmentObject var appState: AppState

    // MARK: - State
    @State private var config = WorkspaceConfig()
    @State private var saveStatus: String?
    @State private var selectedSection: WorkspaceSection = .repository

    enum WorkspaceSection: String, CaseIterable {
        case repository = "Repository"
        case git = "Git"
        case branches = "Branches"
        case commits = "Commits"
        case pullRequests = "Pull Requests"
        case integrations = "Integrations"

        var icon: String {
            switch self {
            case .repository: return "folder.fill"
            case .git: return "arrow.triangle.branch"
            case .branches: return "arrow.triangle.swap"
            case .commits: return "text.alignleft"
            case .pullRequests: return "arrow.triangle.pull"
            case .integrations: return "link"
            }
        }
    }

    var body: some View {
        if let repoPath = appState.currentRepository?.path {
            HSplitView {
                // Sidebar with sections
                sectionsSidebar
                    .frame(minWidth: 150, maxWidth: 180)

                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        sectionContent(for: selectedSection, repoPath: repoPath)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.background)
            .task { loadConfig() }
            .onChange(of: appState.currentRepository?.path) { _, _ in loadConfig() }
        } else {
            emptyStateView
        }
    }

    // MARK: - Sections Sidebar

    private var sectionsSidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(WorkspaceSection.allCases, id: \.self) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.icon)
                            .frame(width: 16)
                            .foregroundStyle(selectedSection == section ? AppTheme.accent : AppTheme.textSecondary)
                        Text(section.rawValue)
                            .foregroundStyle(selectedSection == section ? AppTheme.textPrimary : AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedSection == section ? AppTheme.accent.opacity(0.15) : Color.clear)
                    .clipShape(.rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(for section: WorkspaceSection, repoPath: String) -> some View {
        switch section {
        case .repository:
            repositorySection(repoPath: repoPath)
        case .git:
            gitSection(repoPath: repoPath)
        case .branches:
            branchesSection(repoPath: repoPath)
        case .commits:
            commitsSection(repoPath: repoPath)
        case .pullRequests:
            pullRequestsSection(repoPath: repoPath)
        case .integrations:
            integrationsSection(repoPath: repoPath)
        }
    }

    // MARK: - Repository Section

    private func repositorySection(repoPath: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            sectionHeader(title: "Repository", subtitle: "General repository settings and identification")

            SettingsSection(title: "Display Name") {
                DSTextField(
                    placeholder: appState.currentRepository?.name ?? "Repository name",
                    text: Binding(
                        get: { config.displayName ?? "" },
                        set: { config.displayName = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                    )
                )
                Text("Custom name to display instead of folder name")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "Repository Path") {
                HStack {
                    Text(repoPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(repoPath, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy path")
                }
            }

            SettingsSection(title: "Repository Color") {
                HStack(spacing: 12) {
                    ForEach(["FF6B6B", "4ECDC4", "45B7D1", "96CEB4", "FFEAA7", "DDA0DD", "87CEEB", "98D8C8"], id: \.self) { hex in
                        Button {
                            config.repositoryColor = hex
                            saveConfig(for: repoPath)
                        } label: {
                            Circle()
                                .fill(SwiftUI.Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(config.repositoryColor == hex ? AppTheme.textPrimary : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if config.repositoryColor != nil {
                        Button("Clear") {
                            config.repositoryColor = nil
                            saveConfig(for: repoPath)
                        }
                        .font(.caption)
                    }
                }
                Text("Color used to identify this repository in tabs and lists")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Git Section

    private func gitSection(repoPath: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            sectionHeader(title: "Git Configuration", subtitle: "Repository-specific git settings")

            SettingsSection(title: "Main Branch") {
                DSTextField(
                    placeholder: "main",
                    text: Binding(
                        get: { config.mainBranchName ?? "" },
                        set: { config.mainBranchName = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                    )
                )
                Text("Branch used for comparisons, badges, and as default PR target")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "Default Remote") {
                DSTextField(
                    placeholder: "origin",
                    text: Binding(
                        get: { config.defaultRemote ?? "" },
                        set: { config.defaultRemote = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                    )
                )
                Text("Default remote for push/pull operations")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "Git Identity (Override Global)") {
                VStack(alignment: .leading, spacing: 8) {
                    DSTextField(
                        placeholder: "User name (leave empty to use global)",
                        text: Binding(
                            get: { config.gitUserName ?? "" },
                            set: { config.gitUserName = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                        )
                    )
                    DSTextField(
                        placeholder: "Email (leave empty to use global)",
                        text: Binding(
                            get: { config.gitUserEmail ?? "" },
                            set: { config.gitUserEmail = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                        )
                    )
                }
                Text("Override global git config for this repository only")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "Signing") {
                Toggle(isOn: Binding(
                    get: { config.signCommits ?? false },
                    set: { config.signCommits = $0; saveConfig(for: repoPath) }
                )) {
                    Text("Sign commits with GPG")
                }
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Branches Section

    private func branchesSection(repoPath: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            sectionHeader(title: "Branch Settings", subtitle: "Branch naming conventions and automation")

            SettingsSection(title: "Branch Prefixes") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Feature:")
                            .frame(width: 70, alignment: .leading)
                            .foregroundStyle(AppTheme.textSecondary)
                        DSTextField(
                            placeholder: "feature/",
                            text: Binding(
                                get: { config.featureBranchPrefix ?? "" },
                                set: { config.featureBranchPrefix = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                            )
                        )
                    }
                    HStack {
                        Text("Bugfix:")
                            .frame(width: 70, alignment: .leading)
                            .foregroundStyle(AppTheme.textSecondary)
                        DSTextField(
                            placeholder: "bugfix/",
                            text: Binding(
                                get: { config.bugfixBranchPrefix ?? "" },
                                set: { config.bugfixBranchPrefix = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                            )
                        )
                    }
                    HStack {
                        Text("Release:")
                            .frame(width: 70, alignment: .leading)
                            .foregroundStyle(AppTheme.textSecondary)
                        DSTextField(
                            placeholder: "release/",
                            text: Binding(
                                get: { config.releaseBranchPrefix ?? "" },
                                set: { config.releaseBranchPrefix = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                            )
                        )
                    }
                    HStack {
                        Text("Hotfix:")
                            .frame(width: 70, alignment: .leading)
                            .foregroundStyle(AppTheme.textSecondary)
                        DSTextField(
                            placeholder: "hotfix/",
                            text: Binding(
                                get: { config.hotfixBranchPrefix ?? "" },
                                set: { config.hotfixBranchPrefix = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                            )
                        )
                    }
                }
                Text("Used when creating new branches to suggest naming")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "Automation") {
                Toggle(isOn: Binding(
                    get: { config.autoDeleteMergedBranches ?? false },
                    set: { config.autoDeleteMergedBranches = $0; saveConfig(for: repoPath) }
                )) {
                    Text("Auto-delete local branches after merge")
                }
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Commits Section

    private func commitsSection(repoPath: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            sectionHeader(title: "Commit Settings", subtitle: "Commit message templates and validation")

            SettingsSection(title: "Commit Message Template") {
                TextEditor(text: Binding(
                    get: { config.commitMessageTemplate ?? "" },
                    set: { config.commitMessageTemplate = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .padding(8)
                .background(AppTheme.backgroundSecondary)
                .clipShape(.rect(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

                Text("Template for new commit messages. Use {branch} for branch name, {issue} for issue number.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "Validation") {
                Toggle(isOn: Binding(
                    get: { config.requireIssueReference ?? false },
                    set: { config.requireIssueReference = $0; saveConfig(for: repoPath) }
                )) {
                    Text("Require issue reference in commit messages")
                }
                .toggleStyle(.switch)
                Text("Warn if commit message doesn't contain issue reference (e.g., #123, JIRA-456)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Pull Requests Section

    private func pullRequestsSection(repoPath: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            sectionHeader(title: "Pull Request Settings", subtitle: "Default PR configuration")

            SettingsSection(title: "Default Base Branch") {
                DSTextField(
                    placeholder: config.mainBranchName ?? "main",
                    text: Binding(
                        get: { config.defaultPRBaseBranch ?? "" },
                        set: { config.defaultPRBaseBranch = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                    )
                )
                Text("Default target branch when creating pull requests")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "PR Title Prefix") {
                DSTextField(
                    placeholder: "e.g., [WIP], feat:, fix:",
                    text: Binding(
                        get: { config.prTitlePrefix ?? "" },
                        set: { config.prTitlePrefix = $0.isEmpty ? nil : $0; saveConfig(for: repoPath) }
                    )
                )
                Text("Prefix added to PR titles by default")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SettingsSection(title: "Default Reviewers") {
                DSTextField(
                    placeholder: "username1, username2",
                    text: Binding(
                        get: { config.defaultReviewers?.joined(separator: ", ") ?? "" },
                        set: {
                            let reviewers = $0.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
                            config.defaultReviewers = reviewers.isEmpty ? nil : reviewers
                            saveConfig(for: repoPath)
                        }
                    )
                )
                Text("GitHub usernames separated by commas")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Integrations Section

    private func integrationsSection(repoPath: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            sectionHeader(title: "Linked Integrations", subtitle: "External services connected to this repository")

            // Taiga
            integrationRow(
                icon: "ticket.fill",
                color: SwiftUI.Color(hex: "4DC8A8"),
                name: "Taiga",
                value: config.taigaProjectName,
                onClear: {
                    config.taigaProjectId = nil
                    config.taigaProjectName = nil
                    saveConfig(for: repoPath)
                }
            )

            // Planner
            integrationRow(
                icon: "calendar.badge.checkmark",
                color: SwiftUI.Color(hex: "0078D4"),
                name: "Microsoft Planner",
                value: config.plannerPlanName,
                onClear: {
                    config.plannerPlanId = nil
                    config.plannerPlanName = nil
                    config.plannerGroupId = nil
                    saveConfig(for: repoPath)
                }
            )

            // Jira
            integrationRow(
                icon: "square.stack.3d.up.fill",
                color: SwiftUI.Color(hex: "0052CC"),
                name: "Jira",
                value: config.jiraProjectKey,
                onClear: {
                    config.jiraProjectKey = nil
                    saveConfig(for: repoPath)
                }
            )

            // Linear
            integrationRow(
                icon: "lineweight",
                color: SwiftUI.Color(hex: "5E6AD2"),
                name: "Linear",
                value: config.linearTeamId,
                onClear: {
                    config.linearTeamId = nil
                    saveConfig(for: repoPath)
                }
            )

            // CodeBuild
            integrationRow(
                icon: "hammer.fill",
                color: SwiftUI.Color(hex: "FF9900"),
                name: "AWS CodeBuild",
                value: config.codeBuildProjectName,
                onClear: {
                    config.codeBuildProjectName = nil
                    config.awsRegion = nil
                    saveConfig(for: repoPath)
                }
            )

            Text("Configure integrations in Settings > Integrations")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 8)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.bottom, 8)
    }

    private func integrationRow(icon: String, color: Color, name: String, value: String?, onClear: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(name)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            if let value = value, !value.isEmpty {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.backgroundSecondary)
                    .clipShape(.rect(cornerRadius: 4))

                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            } else {
                Text("Not configured")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.backgroundSecondary.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "folder.badge.questionmark")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundStyle(AppTheme.textSecondary)

            Text("No Repository Open")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Open a repository to configure workspace settings")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    // MARK: - Data Management

    private func loadConfig() {
        guard let repoPath = appState.currentRepository?.path else {
            config = WorkspaceConfig()
            return
        }
        config = workspaceManager.getConfig(for: repoPath)
    }

    private func saveConfig(for repoPath: String) {
        workspaceManager.setConfig(for: repoPath, config: config)
        showSaveStatus()
    }

    private func showSaveStatus() {
        saveStatus = "Saved"
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            saveStatus = nil
        }
    }
}

