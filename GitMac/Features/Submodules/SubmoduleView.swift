import SwiftUI

struct SubmoduleView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SubmoduleViewModel()
    @StateObject private var modalCoordinator = ModalCoordinator<SubmoduleModal>()
    @State private var selectedSubmodule: GitSubmodule?
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Separator.horizontal()
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.submodules.isEmpty {
                emptyStateView
            } else {
                submodulesList
            }
        }
        .background(AppTheme.background)
        .task {
            await loadSubmodules()
        }
        .modalSheet(coordinator: modalCoordinator, for: .add) {
            AddSubmoduleSheet(
                onAdd: { url, path, branch in
                    await addSubmodule(url: url, path: path, branch: branch)
                },
                onDismiss: { modalCoordinator.dismiss() }
            )
        }
        .modalAlert(
            coordinator: modalCoordinator,
            for: .removeConfirm,
            title: "Remove Submodule"
        ) {
            Button("Remove", role: .destructive) {
                if let submodule = selectedSubmodule {
                    Task { await removeSubmodule(submodule) }
                }
                modalCoordinator.dismiss()
                selectedSubmodule = nil
            }
            Button("Cancel", role: .cancel) {
                modalCoordinator.dismiss()
                selectedSubmodule = nil
            }
        } message: {
            if let submodule = selectedSubmodule {
                Text("Are you sure you want to remove '\(submodule.displayName)'? This will deinitialize and remove the submodule.")
            }
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Submodules")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("\(viewModel.submodules.count) submodules")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { Task { await syncSubmodules() } }) {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
                
                Button(action: { modalCoordinator.show(.add) }) {
                    Label("Add Submodule", systemImage: "plus")
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
                
                Button(action: { Task { await loadSubmodules() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
    
    private var submodulesList: some View {
        List {
            ForEach(viewModel.submodules) { submodule in
                SubmoduleRow(
                    submodule: submodule,
                    onInitialize: { await initializeSubmodule(submodule) },
                    onUpdate: { await updateSubmodule(submodule) },
                    onRemove: {
                        selectedSubmodule = submodule
                        modalCoordinator.show(.removeConfirm)
                    }
                )
            }
        }
        .listStyle(.inset)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading submodules...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Submodules")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Add submodules to include external repositories")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: { modalCoordinator.show(.add) }) {
                Text("Add Submodule")
                    .foregroundColor(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadSubmodules() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.loadSubmodules(at: repoPath)
    }
    
    private func initializeSubmodule(_ submodule: GitSubmodule) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.initializeSubmodule(submodule, at: repoPath)
    }
    
    private func updateSubmodule(_ submodule: GitSubmodule) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.updateSubmodule(submodule, at: repoPath)
    }
    
    private func addSubmodule(url: String, path: String, branch: String?) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.addSubmodule(url: url, path: path, branch: branch, at: repoPath)
        modalCoordinator.dismiss()
    }
    
    private func removeSubmodule(_ submodule: GitSubmodule) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.removeSubmodule(submodule, at: repoPath)
    }
    
    private func syncSubmodules() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.syncSubmodules(at: repoPath)
    }
}

// MARK: - Submodule Row

struct SubmoduleRow: View {
    let submodule: GitSubmodule
    let onInitialize: () async -> Void
    let onUpdate: () async -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            
            VStack(alignment: .leading, spacing: 4) {
                Text(submodule.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(submodule.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let branch = submodule.branch {
                    Text("Branch: \(branch)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            actionButtons
        }
        .padding(.vertical, 4)
    }
    
    private var statusIndicator: some View {
        Image(systemName: submodule.status.icon)
            .foregroundColor(statusColor)
            .font(.system(size: 16))
    }
    
    private var statusColor: Color {
        switch submodule.status {
        case .initialized, .upToDate: return .green
        case .modified: return .orange
        case .uninitialized, .unknown: return .gray
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if submodule.status == .uninitialized {
                Button(action: { Task { await onInitialize() } }) {
                    Text("Initialize")
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Initialize submodule")
            } else {
                Button(action: { Task { await onUpdate() } }) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Update submodule")
            }
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Remove submodule")
        }
    }
}

// MARK: - Add Submodule Sheet

struct AddSubmoduleSheet: View {
    let onAdd: (String, String, String?) async -> Void
    let onDismiss: () -> Void
    
    @State private var url = ""
    @State private var path = ""
    @State private var branch = ""
    @State private var isAdding = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Separator.horizontal()
            
            formSection
            
            Separator.horizontal()
            footerSection
        }
        .frame(width: 500, height: 300)
        .background(AppTheme.background)
    }
    
    private var headerSection: some View {
        HStack {
            Text("Add Submodule")
                .font(.title3)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("Cancel") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }
    
    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Repository URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("https://github.com/user/repo.git", text: $url)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("path/to/submodule", text: $path)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Branch (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("main", text: $branch)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
    }
    
    private var footerSection: some View {
        HStack {
            Spacer()
            
            Button("Add Submodule") {
                Task {
                    isAdding = true
                    await onAdd(url, path, branch.isEmpty ? nil : branch)
                    isAdding = false
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(url.isEmpty || path.isEmpty || isAdding)
        }
        .padding()
    }
}

// MARK: - Supporting Types

enum SubmoduleModal: Hashable {
    case add
    case removeConfirm
}

// MARK: - ViewModel

@MainActor
class SubmoduleViewModel: ObservableObject {
    @Published var submodules: [GitSubmodule] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service = GitSubmoduleService()
    
    func loadSubmodules(at repoPath: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            submodules = try await service.getSubmodules(at: repoPath)
        } catch {
            errorMessage = "Failed to load submodules: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func initializeSubmodule(_ submodule: GitSubmodule, at repoPath: String) async {
        do {
            try await service.initializeSubmodule(submodule, at: repoPath)
            submodules = try await service.getSubmodules(at: repoPath)
        } catch {
            errorMessage = "Failed to initialize submodule: \(error.localizedDescription)"
        }
    }
    
    func updateSubmodule(_ submodule: GitSubmodule, at repoPath: String) async {
        do {
            try await service.updateSubmodule(submodule, at: repoPath)
            submodules = try await service.getSubmodules(at: repoPath)
        } catch {
            errorMessage = "Failed to update submodule: \(error.localizedDescription)"
        }
    }
    
    func addSubmodule(url: String, path: String, branch: String?, at repoPath: String) async {
        do {
            try await service.addSubmodule(url: url, path: path, branch: branch, at: repoPath)
            submodules = try await service.getSubmodules(at: repoPath)
        } catch {
            errorMessage = "Failed to add submodule: \(error.localizedDescription)"
        }
    }
    
    func removeSubmodule(_ submodule: GitSubmodule, at repoPath: String) async {
        do {
            try await service.removeSubmodule(submodule, at: repoPath)
            submodules = try await service.getSubmodules(at: repoPath)
        } catch {
            errorMessage = "Failed to remove submodule: \(error.localizedDescription)"
        }
    }
    
    func syncSubmodules(at repoPath: String) async {
        do {
            try await service.syncSubmodules(at: repoPath)
            submodules = try await service.getSubmodules(at: repoPath)
        } catch {
            errorMessage = "Failed to sync submodules: \(error.localizedDescription)"
        }
    }
}
