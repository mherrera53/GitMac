import SwiftUI

/// Remote repositories management view
struct RemoteListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RemoteListViewModel()
    @State private var showAddRemoteSheet = false
    @State private var showDeleteAlert = false
    @State private var remoteToDelete: Remote?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Remotes")
                    .font(DesignTokens.Typography.headline)

                Spacer()

                Button {
                    showAddRemoteSheet = true
                } label: {
                    Label("Add Remote", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Remote list
            if viewModel.remotes.isEmpty {
                EmptyRemoteView()
            } else {
                List {
                    ForEach(viewModel.remotes) { remote in
                        RemoteRow(
                            remote: remote,
                            onFetch: { Task { await viewModel.fetch(remote: remote) } },
                            onPush: { Task { await viewModel.push(to: remote) } },
                            onDelete: {
                                remoteToDelete = remote
                                showDeleteAlert = true
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Actions
            HStack {
                Button {
                    Task { await viewModel.fetchAll() }
                } label: {
                    Label("Fetch All", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .sheet(isPresented: $showAddRemoteSheet) {
            AddRemoteSheet(viewModel: viewModel)
        }
        .alert("Remove Remote", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let remote = remoteToDelete {
                    Task { await viewModel.removeRemote(remote) }
                }
            }
        } message: {
            Text("Are you sure you want to remove '\(remoteToDelete?.name ?? "")'?")
        }
        .task {
            if let repo = appState.currentRepository {
                viewModel.loadRemotes(from: repo)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class RemoteListViewModel: ObservableObject {
    @Published var remotes: [Remote] = []
    @Published var isLoading = false
    @Published var error: String?

    private let gitService = GitService()

    func loadRemotes(from repo: Repository) {
        remotes = repo.remotes
    }

    func fetch(remote: Remote) async {
        isLoading = true
        do {
            try await gitService.fetch(remote: remote.name)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetchAll() async {
        isLoading = true
        do {
            try await gitService.fetch()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func push(to remote: Remote) async {
        isLoading = true
        do {
            try await gitService.push()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func addRemote(name: String, url: String) async {
        let shell = ShellExecutor()
        isLoading = true
        _ = await shell.execute("git", arguments: ["remote", "add", name, url])
        isLoading = false
    }

    func removeRemote(_ remote: Remote) async {
        let shell = ShellExecutor()
        isLoading = true
        _ = await shell.execute("git", arguments: ["remote", "remove", remote.name])
        remotes.removeAll { $0.id == remote.id }
        isLoading = false
    }

    func renameRemote(_ remote: Remote, to newName: String) async {
        let shell = ShellExecutor()
        isLoading = true
        _ = await shell.execute("git", arguments: ["remote", "rename", remote.name, newName])
        isLoading = false
    }
}

// MARK: - Subviews

struct RemoteRow: View {
    let remote: Remote
    var onFetch: () -> Void = {}
    var onPush: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: DesignTokens.Spacing.md) {
                // Provider icon
                RemoteProviderIcon(provider: remote.provider)

                // Info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack {
                        Text(remote.name)
                            .fontWeight(.semibold)

                        if remote.name == "origin" {
                            Text("default")
                                .font(DesignTokens.Typography.caption2)
                                .padding(.horizontal, DesignTokens.Spacing.xs)
                                .padding(.vertical, 1)
                                .background(AppTheme.info.opacity(0.2))
                                .foregroundColor(AppTheme.info)
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                    }

                    Text(remote.fetchURL)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                // Actions
                if isHovered {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Button { onFetch() } label: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(AppTheme.info)
                        }
                        .buttonStyle(.borderless)
                        .help("Fetch")

                        Button { onPush() } label: {
                            Image(systemName: "arrow.up.circle")
                                .foregroundColor(AppTheme.warning)
                        }
                        .buttonStyle(.borderless)
                        .help("Push")
                    }
                }

                // Expand button
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Divider()

                    // URLs
                    LabeledContent("Fetch URL") {
                        Text(remote.fetchURL)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .textSelection(.enabled)
                    }

                    LabeledContent("Push URL") {
                        Text(remote.pushURL)
                            .font(DesignTokens.Typography.caption.monospaced())
                            .textSelection(.enabled)
                    }

                    // Branches
                    if !remote.branches.isEmpty {
                        Divider()

                        Text("Remote Branches (\(remote.branches.count))")
                            .font(DesignTokens.Typography.caption.weight(.semibold))

                        ForEach(remote.branches.prefix(5)) { branch in
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundColor(AppTheme.textPrimary)
                                    .font(DesignTokens.Typography.caption)
                                Text(branch.displayName)
                                    .font(DesignTokens.Typography.caption)
                            }
                        }

                        if remote.branches.count > 5 {
                            Text("+ \(remote.branches.count - 5) more")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                }
                .padding(.leading, 44)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }
        }
        .contextMenu {
            Button("Fetch") { onFetch() }
            Button("Push") { onPush() }
            Divider()
            Button("Copy Fetch URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(remote.fetchURL, forType: .string)
            }
            Button("Copy Push URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(remote.pushURL, forType: .string)
            }
            Divider()
            Button("Open in Browser") {
                if let ownerRepo = remote.ownerAndRepo {
                    let url: String
                    switch remote.provider {
                    case .github:
                        url = "https://github.com/\(ownerRepo.owner)/\(ownerRepo.repo)"
                    case .gitlab:
                        url = "https://gitlab.com/\(ownerRepo.owner)/\(ownerRepo.repo)"
                    case .bitbucket:
                        url = "https://bitbucket.org/\(ownerRepo.owner)/\(ownerRepo.repo)"
                    default:
                        url = remote.fetchURL
                    }
                    NSWorkspace.shared.open(URL(string: url)!)
                }
            }
            Divider()
            Button("Remove", role: .destructive) { onDelete() }
        }
    }
}

struct RemoteProviderIcon: View {
    let provider: RemoteProvider

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: iconName)
                .font(DesignTokens.Typography.headline)
                .foregroundColor(iconColor)
        }
    }

    var iconName: String {
        switch provider {
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .gitlab: return "square.stack.3d.up"
        case .bitbucket: return "b.circle"
        case .azureDevOps: return "cloud"
        case .other: return "network"
        }
    }

    var iconColor: Color {
        switch provider {
        case .github: return .white
        case .gitlab: return .white
        case .bitbucket: return .white
        case .azureDevOps: return .white
        case .other: return .gray
        }
    }

    var backgroundColor: Color {
        switch provider {
        case .github: return Color(hex: "24292E")
        case .gitlab: return Color(hex: "FC6D26")
        case .bitbucket: return Color(hex: "0052CC")
        case .azureDevOps: return Color(hex: "0078D4")
        case .other: return AppTheme.textMuted.opacity(0.3)
        }
    }
}

struct EmptyRemoteView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "network.slash")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textPrimary)

            Text("No remotes configured")
                .font(DesignTokens.Typography.headline)

            Text("Add a remote to push and pull changes")
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AddRemoteSheet: View {
    @ObservedObject var viewModel: RemoteListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var url = ""

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Add Remote")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("URL", text: $url)
                    .textFieldStyle(.roundedBorder)

                Text("Example: https://github.com/user/repo.git")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }

            // URL suggestions
            if !url.isEmpty {
                HStack {
                    if url.contains("github") {
                        RemoteProviderIcon(provider: .github)
                            .scaleEffect(0.7)
                        Text("GitHub")
                            .font(DesignTokens.Typography.caption)
                    } else if url.contains("gitlab") {
                        RemoteProviderIcon(provider: .gitlab)
                            .scaleEffect(0.7)
                        Text("GitLab")
                            .font(DesignTokens.Typography.caption)
                    } else if url.contains("bitbucket") {
                        RemoteProviderIcon(provider: .bitbucket)
                            .scaleEffect(0.7)
                        Text("Bitbucket")
                            .font(DesignTokens.Typography.caption)
                    }
                    Spacer()
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    Task {
                        await viewModel.addRemote(name: name, url: url)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || url.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            if name.isEmpty {
                name = "origin"
            }
        }
    }
}

// #Preview {
//     RemoteListView()
//         .environmentObject(AppState())
//         .frame(width: 400, height: 500)
// }
