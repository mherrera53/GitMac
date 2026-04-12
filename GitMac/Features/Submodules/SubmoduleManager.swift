import SwiftUI

// MARK: - Submodule Model

struct ManagedSubmodule: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let url: String
    let branch: String?
    let commitSHA: String
    let status: SubmoduleStatus

    var shortSHA: String {
        String(commitSHA.prefix(7))
    }

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        url: String,
        branch: String? = nil,
        commitSHA: String,
        status: SubmoduleStatus = .clean
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.url = url
        self.branch = branch
        self.commitSHA = commitSHA
        self.status = status
    }

    static func parseFromStatus(_ output: String, gitmodulesContent: String) -> [ManagedSubmodule] {
        var submodules: [ManagedSubmodule] = []
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines {
            guard line.count > 1 else { continue }

            let statusChar = line.first!
            let rest = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            let parts = rest.components(separatedBy: " ")

            guard parts.count >= 2 else { continue }

            let sha = parts[0]
            let path = parts[1]
            let name = URL(fileURLWithPath: path).lastPathComponent

            let status: SubmoduleStatus
            switch statusChar {
            case " ": status = .clean
            case "+": status = .modified
            case "-": status = .uninitialized
            case "U": status = .mergeConflict
            default: status = .clean
            }

            // Parse URL from .gitmodules
            let url = parseSubmoduleURL(path: path, from: gitmodulesContent) ?? ""
            let branch = parseSubmoduleBranch(path: path, from: gitmodulesContent)

            submodules.append(ManagedSubmodule(
                name: name,
                path: path,
                url: url,
                branch: branch,
                commitSHA: sha,
                status: status
            ))
        }

        return submodules
    }

    private static func parseSubmoduleURL(path: String, from content: String) -> String? {
        let pattern = "\\[submodule \"[^\"]*\"\\][^\\[]*path\\s*=\\s*\(NSRegularExpression.escapedPattern(for: path))[^\\[]*url\\s*=\\s*([^\\n]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }

        let range = NSRange(content.startIndex..., in: content)
        if let match = regex.firstMatch(in: content, range: range),
           let urlRange = Range(match.range(at: 1), in: content) {
            return String(content[urlRange]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func parseSubmoduleBranch(path: String, from content: String) -> String? {
        let pattern = "\\[submodule \"[^\"]*\"\\][^\\[]*path\\s*=\\s*\(NSRegularExpression.escapedPattern(for: path))[^\\[]*branch\\s*=\\s*([^\\n]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }

        let range = NSRange(content.startIndex..., in: content)
        if let match = regex.firstMatch(in: content, range: range),
           let branchRange = Range(match.range(at: 1), in: content) {
            return String(content[branchRange]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

// MARK: - Submodule List View

struct SubmoduleListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SubmoduleListViewModel()
    @State private var showAddSheet = false
    @State private var selectedSubmodule: ManagedSubmodule?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
            actionsBar
        }
        .task {
            await viewModel.refresh(at: appState.currentRepository?.path)
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            Task { await viewModel.refresh(at: newPath) }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSubmoduleSheetFromList(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("SUBMODULES")
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    Task { await viewModel.refresh(at: appState.currentRepository?.path) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(DesignTokens.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)

                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.textMuted.opacity(0.1))
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
                .scaleEffect(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.submodules.isEmpty {
            emptyStateView
        } else {
            submodulesList
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "shippingbox")
                .font(DesignTokens.Typography.title3)
                .foregroundStyle(AppTheme.textSecondary)
            Text("No submodules")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    @ViewBuilder
    private var submodulesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.submodules) { submodule in
                    ManagedSubmoduleRow(
                        submodule: submodule,
                        isSelected: selectedSubmodule?.id == submodule.id,
                        onSelect: { selectedSubmodule = submodule },
                        onUpdate: { await viewModel.update(submodule, at: appState.currentRepository?.path) },
                        onSync: { await viewModel.sync(submodule, at: appState.currentRepository?.path) },
                        onRemove: { await viewModel.remove(submodule, at: appState.currentRepository?.path) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var actionsBar: some View {
        if !viewModel.submodules.isEmpty {
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("Update All") {
                    Task { await viewModel.updateAll(at: appState.currentRepository?.path) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Init Recursive") {
                    Task { await viewModel.initRecursive(at: appState.currentRepository?.path) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(AppTheme.textMuted.opacity(0.05))
        }
    }
}

// MARK: - Submodule Row

struct ManagedSubmoduleRow: View {
    let submodule: ManagedSubmodule
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: () async -> Void
    let onSync: () async -> Void
    let onRemove: () async -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: submodule.status.icon)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(submodule.status.color)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(submodule.name)
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if let branch = submodule.branch {
                        Text(branch)
                            .font(DesignTokens.Typography.caption2)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 1)
                            .background(AppTheme.info.opacity(0.2))
                            .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.sm))
                    }
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(submodule.path)
                        .font(DesignTokens.Typography.caption2)
                    Text("@")
                        .font(DesignTokens.Typography.caption2)
                    Text(submodule.shortSHA)
                        .font(DesignTokens.Typography.caption2)
                        .fontDesign(.monospaced)
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Button { Task { await onUpdate() } } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.info)
                    }
                    .buttonStyle(.plain)
                    .help("Update submodule")

                    Button { Task { await onSync() } } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.info)
                    }
                    .buttonStyle(.plain)
                    .help("Sync URL")

                    Button { Task { await onRemove() } } label: {
                        Image(systemName: "trash")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.error)
                    }
                    .buttonStyle(.plain)
                    .help("Remove submodule")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(isSelected ? AppTheme.info.opacity(0.2) : (isHovered ? AppTheme.textMuted.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

// MARK: - Add Submodule Sheet

struct AddSubmoduleSheetFromList: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: SubmoduleListViewModel

    @State private var url = ""
    @State private var path = ""
    @State private var branch = ""
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Add Submodule")
                .font(.headline)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Repository URL")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textSecondary)
                    DSTextField(placeholder: "https://github.com/user/repo.git", text: $url)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Path (relative to repo root)")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textSecondary)
                    DSTextField(placeholder: "libs/mylib", text: $path)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Branch (optional)")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textSecondary)
                    DSTextField(placeholder: "main", text: $branch)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Add Submodule") {
                    Task {
                        isAdding = true
                        await viewModel.add(
                            url: url,
                            path: path,
                            branch: branch.isEmpty ? nil : branch,
                            at: appState.currentRepository?.path
                        )
                        isAdding = false
                        if viewModel.error == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(url.isEmpty || path.isEmpty || isAdding)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 400)
    }
}

// MARK: - View Model

@MainActor
class SubmoduleListViewModel: ObservableObject {
    @Published var submodules: [ManagedSubmodule] = []
    @Published var isLoading = false
    @Published var error: String?

    private let shell = ShellExecutor.shared

    func refresh(at path: String?) async {
        guard let path = path else {
            submodules = []
            return
        }

        isLoading = true

        // Get submodule status
        let statusResult = await shell.execute(
            "git",
            arguments: ["submodule", "status", "--recursive"],
            workingDirectory: path
        )

        // Get .gitmodules content
        let gitmodulesPath = "\(path)/.gitmodules"
        let gitmodulesContent = (try? String(contentsOfFile: gitmodulesPath)) ?? ""

        if statusResult.isSuccess {
            submodules = ManagedSubmodule.parseFromStatus(statusResult.stdout, gitmodulesContent: gitmodulesContent)
        } else {
            submodules = []
        }

        isLoading = false
    }

    func add(url: String, path: String, branch: String?, at repoPath: String?) async {
        guard let repoPath = repoPath else { return }

        isLoading = true
        var args = ["submodule", "add"]

        if let branch = branch {
            args += ["-b", branch]
        }

        args += [url, path]

        let result = await shell.execute("git", arguments: args, workingDirectory: repoPath)

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to add submodule" : result.stderr
        } else {
            await refresh(at: repoPath)
        }

        isLoading = false
    }

    func update(_ submodule: ManagedSubmodule, at path: String?) async {
        guard let path = path else { return }

        let result = await shell.execute(
            "git",
            arguments: ["submodule", "update", "--remote", "--merge", submodule.path],
            workingDirectory: path
        )

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to update submodule" : result.stderr
        } else {
            await refresh(at: path)
        }
    }

    func updateAll(at path: String?) async {
        guard let path = path else { return }

        isLoading = true
        let result = await shell.execute(
            "git",
            arguments: ["submodule", "update", "--remote", "--merge"],
            workingDirectory: path
        )

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to update submodules" : result.stderr
        }

        await refresh(at: path)
        isLoading = false
    }

    func sync(_ submodule: ManagedSubmodule, at path: String?) async {
        guard let path = path else { return }

        let result = await shell.execute(
            "git",
            arguments: ["submodule", "sync", submodule.path],
            workingDirectory: path
        )

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to sync submodule" : result.stderr
        } else {
            await refresh(at: path)
        }
    }

    func remove(_ submodule: ManagedSubmodule, at path: String?) async {
        guard let path = path else { return }

        // 1. Deinit
        _ = await shell.execute(
            "git",
            arguments: ["submodule", "deinit", "-f", submodule.path],
            workingDirectory: path
        )

        // 2. Remove from .git/modules
        _ = await shell.execute(
            "rm",
            arguments: ["-rf", ".git/modules/\(submodule.path)"],
            workingDirectory: path
        )

        // 3. Remove from working tree
        let result = await shell.execute(
            "git",
            arguments: ["rm", "-f", submodule.path],
            workingDirectory: path
        )

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to remove submodule" : result.stderr
        } else {
            await refresh(at: path)
        }
    }

    func initRecursive(at path: String?) async {
        guard let path = path else { return }

        isLoading = true
        let result = await shell.execute(
            "git",
            arguments: ["submodule", "update", "--init", "--recursive"],
            workingDirectory: path
        )

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to init submodules" : result.stderr
        }

        await refresh(at: path)
        isLoading = false
    }
}
