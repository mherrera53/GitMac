import SwiftUI

/// Remote Management View - Add, edit, remove remotes
struct RemoteManagementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RemoteManagementViewModel()
    
    @State private var showAddRemote = false
    @State private var showEditRemote: Remote?
    @State private var selectedRemote: Remote?
    
    var body: some View {
        HSplitView {
            // Left: Remotes list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Remotes")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        showAddRemote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Add Remote")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Remotes list
                if viewModel.remotes.isEmpty {
                    emptyState
                } else {
                    remotesList
                }
            }
            .frame(minWidth: 300)
            
            // Right: Remote details
            if let remote = selectedRemote {
                RemoteDetailView(remote: remote)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Select a remote to view details")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showAddRemote) {
            AddRemoteMgmtSheet(isPresented: $showAddRemote)
                .environmentObject(appState)
        }
        .sheet(item: $showEditRemote) { remote in
            EditRemoteSheet(remote: remote)
                .environmentObject(appState)
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.loadRemotes()
        }
    }
    
    private var remotesList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.remotes) { remote in
                    RemoteMgmtRow(
                        remote: remote,
                        isSelected: selectedRemote?.id == remote.id,
                        onSelect: { selectedRemote = remote },
                        onEdit: { showEditRemote = remote },
                        onDelete: { Task { await viewModel.deleteRemote(remote) } },
                        onFetch: { Task { await viewModel.fetch(remote: remote.name) } }
                    )
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("No remotes configured")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Button {
                showAddRemote = true
            } label: {
                Label("Add Remote", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Remote Row

struct RemoteMgmtRow: View {
    let remote: Remote
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onFetch: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Remote icon
            Image(systemName: remoteIcon)
                .font(.system(size: 20))
                .foregroundColor(remoteColor)
                .frame(width: 32, height: 32)
                .background(remoteColor.opacity(0.15))
                .cornerRadius(8)
            
            // Remote info
            VStack(alignment: .leading, spacing: 2) {
                Text(remote.name)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(remote.fetchURL)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Actions on hover
            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        onFetch()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Fetch")
                    
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Edit")
                    
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.error)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
    
    private var remoteIcon: String {
        if remote.fetchURL.contains("github.com") {
            return "chevron.left.forwardslash.chevron.right"
        } else if remote.fetchURL.contains("gitlab.com") {
            return "server.rack"
        } else if remote.fetchURL.contains("bitbucket.org") {
            return "chevron.left.forwardslash.chevron.right"
        } else {
            return "network"
        }
    }
    
    private var remoteColor: Color {
        remote.name == "origin" ? .blue : .purple
    }
}

// MARK: - Remote Detail View

struct RemoteDetailView: View {
    let remote: Remote
    @StateObject private var viewModel = RemoteDetailViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "network")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.accent)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(remote.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(remote.fetchURL)
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    Spacer()
                }
                
                // Quick actions
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.fetch(remote: remote.name) }
                    } label: {
                        Label("Fetch", systemImage: "arrow.down.circle")
                    }
                    
                    Button {
                        Task { await viewModel.prune(remote: remote.name) }
                    } label: {
                        Label("Prune", systemImage: "trash")
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Remote branches
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                remoteBranchesList
            }
        }
        .task {
            await viewModel.loadBranches(for: remote)
        }
    }
    
    private var remoteBranchesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.branches) { branch in
                    RemoteMgmtBranchRow(branch: branch)
                }
            }
        }
    }
}

struct RemoteMgmtBranchRow: View {
    let branch: Branch

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.branch")
                .foregroundColor(AppTheme.success)

            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .font(.body)

                Text(branch.shortSHA)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Add Remote Sheet

struct AddRemoteMgmtSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    
    @State private var remoteName = ""
    @State private var remoteURL = ""
    @State private var isSaving = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Remote")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                DSTextField(placeholder: "Name (e.g., origin)", text: $remoteName)

                DSTextField(placeholder: "URL", text: $remoteURL)
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    Task { await addRemote() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Add")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(remoteName.isEmpty || remoteURL.isEmpty || isSaving)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func addRemote() async {
        isSaving = true
        
        do {
            try await appState.gitService.addRemote(name: remoteName, url: remoteURL)
            isPresented = false
        } catch {
            // Show error
        }
        
        isSaving = false
    }
}

// MARK: - Edit Remote Sheet

struct EditRemoteSheet: View {
    @EnvironmentObject var appState: AppState
    let remote: Remote
    @Environment(\.dismiss) private var dismiss
    
    @State private var newURL: String
    @State private var isSaving = false
    
    init(remote: Remote) {
        self.remote = remote
        self._newURL = State(initialValue: remote.fetchURL)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Remote: \(remote.name)")
                .font(.title2)
                .fontWeight(.bold)
            
            DSTextField(placeholder: "URL", text: $newURL)
                .padding()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    Task { await saveRemote() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newURL.isEmpty || isSaving)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func saveRemote() async {
        isSaving = true
        
        do {
            try await appState.gitService.setRemoteURL(name: remote.name, url: newURL)
            dismiss()
        } catch {
            // Show error
        }
        
        isSaving = false
    }
}

// MARK: - View Models

@MainActor
class RemoteManagementViewModel: ObservableObject {
    @Published var remotes: [Remote] = []
    @Published var isLoading = false
    
    private var appState: AppState?
    
    func configure(appState: AppState) {
        self.appState = appState
    }
    
    func loadRemotes() async {
        guard let repo = appState?.currentRepository else { return }
        
        isLoading = true
        remotes = repo.remotes
        isLoading = false
    }
    
    func deleteRemote(_ remote: Remote) async {
        do {
            try await appState?.gitService.removeRemote(name: remote.name)
            await loadRemotes()
        } catch {
            // Show error
        }
    }
    
    func fetch(remote: String) async {
        do {
            try await appState?.gitService.fetch(remote: remote)

            // Track successful fetch
            RemoteOperationTracker.shared.recordFetch(
                success: true,
                remote: remote
            )
        } catch {
            // Track failed fetch
            RemoteOperationTracker.shared.recordFetch(
                success: false,
                remote: remote,
                error: error.localizedDescription
            )
        }
    }
}

@MainActor
class RemoteDetailViewModel: ObservableObject {
    @Published var branches: [Branch] = []
    @Published var isLoading = false
    
    func loadBranches(for remote: Remote) async {
        isLoading = true
        
        // Load remote branches
        // TODO: Implement
        
        isLoading = false
    }
    
    func fetch(remote: String) async {
        // TODO: Implement
    }
    
    func prune(remote: String) async {
        // TODO: Implement
    }
}

// MARK: - GitService Extensions

extension GitService {
    func addRemote(name: String, url: String) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }
        
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["remote", "add", name, url],
            workingDirectory: path
        )
        
        if result.exitCode != 0 {
            throw GitError.commandFailed("git remote add", result.stderr)
        }

        try await refresh()
    }

    func removeRemote(name: String) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }
        
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["remote", "remove", name],
            workingDirectory: path
        )
        
        if result.exitCode != 0 {
            throw GitError.commandFailed("git remote remove", result.stderr)
        }

        try await refresh()
    }

    func setRemoteURL(name: String, url: String) async throws {
        guard let path = currentRepository?.path else {
            throw GitServiceError.noRepository
        }
        
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["remote", "set-url", name, url],
            workingDirectory: path
        )
        
        if result.exitCode != 0 {
            throw GitError.commandFailed("git remote set-url", result.stderr)
        }

        try await refresh()
    }
}
