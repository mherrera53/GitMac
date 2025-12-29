import SwiftUI

/// Git Flow Manager - Initialize and manage Git Flow workflow
struct GitFlowView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GitFlowViewModel()
    @State private var showInitSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(AppTheme.accentPurple)

                Text("Git Flow")
                    .font(.headline)

                Spacer()

                if viewModel.isInitialized {
                    Text("Initialized")
                        .font(.caption)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(AppTheme.success.opacity(0.2))
                        .foregroundColor(AppTheme.success)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                } else {
                    Button("Initialize") {
                        showInitSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if viewModel.isInitialized {
                // Git Flow Actions
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Active branches section
                        ActiveBranchesSection(viewModel: viewModel)

                        // Start new section
                        StartNewSection(viewModel: viewModel)

                        // Branch prefixes info
                        BranchPrefixesInfo(viewModel: viewModel)
                    }
                    .padding()
                }
            } else {
                // Not initialized view
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(DesignTokens.Typography.iconXXXXL)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Git Flow Not Initialized")
                        .font(.headline)

                    Text("Git Flow provides a robust branching model for your project")
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Button("Initialize Git Flow") {
                        showInitSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showInitSheet) {
            GitFlowInitSheet(viewModel: viewModel)
        }
        .task {
            if let repo = appState.currentRepository {
                await viewModel.checkGitFlow(in: repo)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class GitFlowViewModel: ObservableObject {
    @Published var isInitialized = false
    @Published var masterBranch = "main"
    @Published var developBranch = "develop"
    @Published var featurePrefix = "feature/"
    @Published var releasePrefix = "release/"
    @Published var hotfixPrefix = "hotfix/"
    @Published var supportPrefix = "support/"
    @Published var versionTagPrefix = ""

    @Published var activeFeatures: [String] = []
    @Published var activeReleases: [String] = []
    @Published var activeHotfixes: [String] = []

    @Published var isLoading = false
    @Published var error: String?

    private var repositoryPath = ""
    private let shell = ShellExecutor()

    func checkGitFlow(in repo: Repository) async {
        repositoryPath = repo.path

        // Check if git flow is initialized by checking config
        let result = await shell.execute(
            "git",
            arguments: ["config", "--get", "gitflow.branch.master"],
            workingDirectory: repositoryPath
        )

        isInitialized = result.exitCode == 0

        if isInitialized {
            await loadGitFlowConfig()
            await loadActiveBranches(from: repo)
        }
    }

    private func loadGitFlowConfig() async {
        masterBranch = await getConfig("gitflow.branch.master") ?? "main"
        developBranch = await getConfig("gitflow.branch.develop") ?? "develop"
        featurePrefix = await getConfig("gitflow.prefix.feature") ?? "feature/"
        releasePrefix = await getConfig("gitflow.prefix.release") ?? "release/"
        hotfixPrefix = await getConfig("gitflow.prefix.hotfix") ?? "hotfix/"
        supportPrefix = await getConfig("gitflow.prefix.support") ?? "support/"
        versionTagPrefix = await getConfig("gitflow.prefix.versiontag") ?? ""
    }

    private func getConfig(_ key: String) async -> String? {
        let result = await shell.execute(
            "git",
            arguments: ["config", "--get", key],
            workingDirectory: repositoryPath
        )
        return result.exitCode == 0 ? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    private func loadActiveBranches(from repo: Repository) async {
        activeFeatures = repo.branches
            .filter { $0.name.hasPrefix(featurePrefix) }
            .map { String($0.name.dropFirst(featurePrefix.count)) }

        activeReleases = repo.branches
            .filter { $0.name.hasPrefix(releasePrefix) }
            .map { String($0.name.dropFirst(releasePrefix.count)) }

        activeHotfixes = repo.branches
            .filter { $0.name.hasPrefix(hotfixPrefix) }
            .map { String($0.name.dropFirst(hotfixPrefix.count)) }
    }

    func initializeGitFlow() async {
        isLoading = true
        error = nil

        // Set git flow config
        let configs = [
            ("gitflow.branch.master", masterBranch),
            ("gitflow.branch.develop", developBranch),
            ("gitflow.prefix.feature", featurePrefix),
            ("gitflow.prefix.release", releasePrefix),
            ("gitflow.prefix.hotfix", hotfixPrefix),
            ("gitflow.prefix.support", supportPrefix),
            ("gitflow.prefix.versiontag", versionTagPrefix)
        ]

        for (key, value) in configs {
            _ = await shell.execute(
                "git",
                arguments: ["config", key, value],
                workingDirectory: repositoryPath
            )
        }

        // Create develop branch if it doesn't exist
        let checkDevelop = await shell.execute(
            "git",
            arguments: ["rev-parse", "--verify", developBranch],
            workingDirectory: repositoryPath
        )

        if checkDevelop.exitCode != 0 {
            _ = await shell.execute(
                "git",
                arguments: ["branch", developBranch, masterBranch],
                workingDirectory: repositoryPath
            )
        }

        isInitialized = true
        isLoading = false
    }

    func startFeature(name: String) async {
        isLoading = true
        error = nil

        let branchName = "\(featurePrefix)\(name)"

        // Create and checkout feature branch from develop
        let result = await shell.execute(
            "git",
            arguments: ["checkout", "-b", branchName, developBranch],
            workingDirectory: repositoryPath
        )

        if result.exitCode != 0 {
            error = "Failed to create feature: \(result.stderr)"
        } else {
            activeFeatures.append(name)
        }

        isLoading = false
    }

    func finishFeature(name: String) async {
        isLoading = true
        error = nil

        let branchName = "\(featurePrefix)\(name)"

        // Checkout develop
        _ = await shell.execute(
            "git",
            arguments: ["checkout", developBranch],
            workingDirectory: repositoryPath
        )

        // Merge feature into develop
        let mergeResult = await shell.execute(
            "git",
            arguments: ["merge", "--no-ff", branchName],
            workingDirectory: repositoryPath
        )

        if mergeResult.exitCode == 0 {
            // Delete feature branch
            _ = await shell.execute(
                "git",
                arguments: ["branch", "-d", branchName],
                workingDirectory: repositoryPath
            )
            activeFeatures.removeAll { $0 == name }
        } else {
            error = "Merge failed: \(mergeResult.stderr)"
        }

        isLoading = false
    }

    func startRelease(version: String) async {
        isLoading = true
        error = nil

        let branchName = "\(releasePrefix)\(version)"

        let result = await shell.execute(
            "git",
            arguments: ["checkout", "-b", branchName, developBranch],
            workingDirectory: repositoryPath
        )

        if result.exitCode != 0 {
            error = "Failed to create release: \(result.stderr)"
        } else {
            activeReleases.append(version)
        }

        isLoading = false
    }

    func finishRelease(version: String) async {
        isLoading = true
        error = nil

        let branchName = "\(releasePrefix)\(version)"
        let tagName = "\(versionTagPrefix)\(version)"

        // Checkout master
        _ = await shell.execute(
            "git",
            arguments: ["checkout", masterBranch],
            workingDirectory: repositoryPath
        )

        // Merge release into master
        let mergeMaster = await shell.execute(
            "git",
            arguments: ["merge", "--no-ff", branchName],
            workingDirectory: repositoryPath
        )

        guard mergeMaster.exitCode == 0 else {
            error = "Merge to \(masterBranch) failed"
            isLoading = false
            return
        }

        // Tag the release
        _ = await shell.execute(
            "git",
            arguments: ["tag", "-a", tagName, "-m", "Release \(version)"],
            workingDirectory: repositoryPath
        )

        // Checkout develop
        _ = await shell.execute(
            "git",
            arguments: ["checkout", developBranch],
            workingDirectory: repositoryPath
        )

        // Merge release into develop
        _ = await shell.execute(
            "git",
            arguments: ["merge", "--no-ff", branchName],
            workingDirectory: repositoryPath
        )

        // Delete release branch
        _ = await shell.execute(
            "git",
            arguments: ["branch", "-d", branchName],
            workingDirectory: repositoryPath
        )

        activeReleases.removeAll { $0 == version }
        isLoading = false
    }

    func startHotfix(version: String) async {
        isLoading = true
        error = nil

        let branchName = "\(hotfixPrefix)\(version)"

        let result = await shell.execute(
            "git",
            arguments: ["checkout", "-b", branchName, masterBranch],
            workingDirectory: repositoryPath
        )

        if result.exitCode != 0 {
            error = "Failed to create hotfix: \(result.stderr)"
        } else {
            activeHotfixes.append(version)
        }

        isLoading = false
    }

    func finishHotfix(version: String) async {
        isLoading = true
        error = nil

        let branchName = "\(hotfixPrefix)\(version)"
        let tagName = "\(versionTagPrefix)\(version)"

        // Checkout master
        _ = await shell.execute(
            "git",
            arguments: ["checkout", masterBranch],
            workingDirectory: repositoryPath
        )

        // Merge hotfix into master
        _ = await shell.execute(
            "git",
            arguments: ["merge", "--no-ff", branchName],
            workingDirectory: repositoryPath
        )

        // Tag
        _ = await shell.execute(
            "git",
            arguments: ["tag", "-a", tagName, "-m", "Hotfix \(version)"],
            workingDirectory: repositoryPath
        )

        // Merge into develop
        _ = await shell.execute(
            "git",
            arguments: ["checkout", developBranch],
            workingDirectory: repositoryPath
        )

        _ = await shell.execute(
            "git",
            arguments: ["merge", "--no-ff", branchName],
            workingDirectory: repositoryPath
        )

        // Delete hotfix branch
        _ = await shell.execute(
            "git",
            arguments: ["branch", "-d", branchName],
            workingDirectory: repositoryPath
        )

        activeHotfixes.removeAll { $0 == version }
        isLoading = false
    }
}

// MARK: - Subviews

struct ActiveBranchesSection: View {
    @ObservedObject var viewModel: GitFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Active Branches")
                .font(.headline)

            // Features
            GroupBox {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Image(systemName: "star")
                            .foregroundColor(AppTheme.accent)
                        Text("Features")
                            .fontWeight(.medium)
                        Text("(\(viewModel.activeFeatures.count))")
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if viewModel.activeFeatures.isEmpty {
                        Text("No active features")
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        ForEach(viewModel.activeFeatures, id: \.self) { feature in
                            ActiveBranchRow(
                                name: feature,
                                prefix: viewModel.featurePrefix,
                                color: .blue,
                                onFinish: {
                                    Task { await viewModel.finishFeature(name: feature) }
                                }
                            )
                        }
                    }
                }
            }

            // Releases
            GroupBox {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Image(systemName: "shippingbox")
                            .foregroundColor(AppTheme.success)
                        Text("Releases")
                            .fontWeight(.medium)
                        Text("(\(viewModel.activeReleases.count))")
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if viewModel.activeReleases.isEmpty {
                        Text("No active releases")
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        ForEach(viewModel.activeReleases, id: \.self) { release in
                            ActiveBranchRow(
                                name: release,
                                prefix: viewModel.releasePrefix,
                                color: .green,
                                onFinish: {
                                    Task { await viewModel.finishRelease(version: release) }
                                }
                            )
                        }
                    }
                }
            }

            // Hotfixes
            GroupBox {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Image(systemName: "flame")
                            .foregroundColor(AppTheme.warning)
                        Text("Hotfixes")
                            .fontWeight(.medium)
                        Text("(\(viewModel.activeHotfixes.count))")
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if viewModel.activeHotfixes.isEmpty {
                        Text("No active hotfixes")
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        ForEach(viewModel.activeHotfixes, id: \.self) { hotfix in
                            ActiveBranchRow(
                                name: hotfix,
                                prefix: viewModel.hotfixPrefix,
                                color: .orange,
                                onFinish: {
                                    Task { await viewModel.finishHotfix(version: hotfix) }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

struct ActiveBranchRow: View {
    let name: String
    let prefix: String
    let color: Color
    var onFinish: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: DesignTokens.Spacing.sm, height: DesignTokens.Spacing.sm)

            Text("\(prefix)\(name)")
                .font(.system(.body, design: .monospaced))

            Spacer()

            if isHovered {
                Button("Finish") {
                    onFinish()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

struct StartNewSection: View {
    @ObservedObject var viewModel: GitFlowViewModel
    @State private var showFeatureSheet = false
    @State private var showReleaseSheet = false
    @State private var showHotfixSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Start New")
                .font(.headline)

            HStack(spacing: DesignTokens.Spacing.md) {
                StartButton(
                    title: "Feature",
                    icon: "star",
                    color: .blue,
                    description: "New functionality"
                ) {
                    showFeatureSheet = true
                }

                StartButton(
                    title: "Release",
                    icon: "shippingbox",
                    color: .green,
                    description: "Prepare release"
                ) {
                    showReleaseSheet = true
                }

                StartButton(
                    title: "Hotfix",
                    icon: "flame",
                    color: .orange,
                    description: "Quick fix for production"
                ) {
                    showHotfixSheet = true
                }
            }
        }
        .sheet(isPresented: $showFeatureSheet) {
            StartBranchSheet(
                type: "Feature",
                placeholder: "feature-name",
                viewModel: viewModel,
                onStart: { name in
                    Task { await viewModel.startFeature(name: name) }
                }
            )
        }
        .sheet(isPresented: $showReleaseSheet) {
            StartBranchSheet(
                type: "Release",
                placeholder: "1.0.0",
                viewModel: viewModel,
                onStart: { version in
                    Task { await viewModel.startRelease(version: version) }
                }
            )
        }
        .sheet(isPresented: $showHotfixSheet) {
            StartBranchSheet(
                type: "Hotfix",
                placeholder: "1.0.1",
                viewModel: viewModel,
                onStart: { version in
                    Task { await viewModel.startHotfix(version: version) }
                }
            )
        }
    }
}

struct StartButton: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct BranchPrefixesInfo: View {
    @ObservedObject var viewModel: GitFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Branch Prefixes")
                .font(.headline)

            GroupBox {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    PrefixRow(label: "Master", value: viewModel.masterBranch)
                    PrefixRow(label: "Develop", value: viewModel.developBranch)
                    PrefixRow(label: "Feature", value: viewModel.featurePrefix)
                    PrefixRow(label: "Release", value: viewModel.releasePrefix)
                    PrefixRow(label: "Hotfix", value: viewModel.hotfixPrefix)
                    PrefixRow(label: "Version tag", value: viewModel.versionTagPrefix.isEmpty ? "(none)" : viewModel.versionTagPrefix)
                }
            }
        }
    }
}

struct PrefixRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct StartBranchSheet: View {
    let type: String
    let placeholder: String
    @ObservedObject var viewModel: GitFlowViewModel
    var onStart: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Start \(type)")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("\(type) name", text: $name, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)

            Text("Branch will be created: \(prefix)\(name.isEmpty ? placeholder : name)")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Start \(type)") {
                    onStart(name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350)
    }

    var prefix: String {
        switch type {
        case "Feature": return viewModel.featurePrefix
        case "Release": return viewModel.releasePrefix
        case "Hotfix": return viewModel.hotfixPrefix
        default: return ""
        }
    }
}

struct GitFlowInitSheet: View {
    @ObservedObject var viewModel: GitFlowViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Initialize Git Flow")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Section("Branch Names") {
                    TextField("Production branch", text: $viewModel.masterBranch)
                    TextField("Development branch", text: $viewModel.developBranch)
                }

                Section("Branch Prefixes") {
                    TextField("Feature prefix", text: $viewModel.featurePrefix)
                    TextField("Release prefix", text: $viewModel.releasePrefix)
                    TextField("Hotfix prefix", text: $viewModel.hotfixPrefix)
                    TextField("Support prefix", text: $viewModel.supportPrefix)
                    TextField("Version tag prefix", text: $viewModel.versionTagPrefix)
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button("Initialize") {
                    Task {
                        await viewModel.initializeGitFlow()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// #Preview {
//     GitFlowView()
//         .environmentObject(AppState())
//         .frame(width: 500, height: 600)
// }
