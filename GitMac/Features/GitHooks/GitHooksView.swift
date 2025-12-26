import SwiftUI

struct GitHooksView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GitHooksViewModel()
    @StateObject private var modalCoordinator = ModalCoordinator<GitHookModal>()
    @State private var selectedHook: GitHook?

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Separator.horizontal()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.hooks.isEmpty {
                emptyStateView
            } else {
                hooksList
            }
        }
        .background(AppTheme.background)
        .task {
            await loadHooks()
        }
        .modalSheet(coordinator: modalCoordinator, for: .editor) {
            if let hook = selectedHook {
                GitHookEditorSheet(
                    hook: hook,
                    onSave: { updatedHook, content in
                        await saveHook(updatedHook, content: content)
                    },
                    onDismiss: {
                        modalCoordinator.dismiss()
                        selectedHook = nil
                    }
                )
            }
        }
        .modalAlert(
            coordinator: modalCoordinator,
            for: .deleteConfirm,
            title: "Delete Hook"
        ) {
            Button("Delete", role: .destructive) {
                if let hook = selectedHook {
                    Task { await deleteHook(hook) }
                }
                modalCoordinator.dismiss()
                selectedHook = nil
            }
            Button("Cancel", role: .cancel) {
                modalCoordinator.dismiss()
                selectedHook = nil
            }
        } message: {
            if let hook = selectedHook {
                Text("Are you sure you want to delete the \(hook.displayName) hook? This action cannot be undone.")
            }
        }
    }

    // MARK: - Components

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Git Hooks")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(viewModel.enabledCount) of \(viewModel.hooks.count) hooks enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { Task { await loadHooks() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .foregroundColor(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var hooksList: some View {
        List {
            ForEach(GitHookCategory.allCases, id: \.self) { category in
                if !viewModel.hooks(for: category).isEmpty {
                    Section(header: Text(category.rawValue)) {
                        ForEach(viewModel.hooks(for: category)) { hook in
                            GitHookRow(
                                hook: hook,
                                onToggle: { await toggleHook(hook) },
                                onEdit: {
                                    selectedHook = hook
                                    modalCoordinator.show(.editor)
                                },
                                onDelete: {
                                    selectedHook = hook
                                    modalCoordinator.show(.deleteConfirm)
                                }
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading hooks...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Git Hooks")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Create hooks to automate workflows")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadHooks() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.loadHooks(at: repoPath)
    }

    private func toggleHook(_ hook: GitHook) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.toggleHook(hook, at: repoPath)
    }

    private func saveHook(_ hook: GitHook, content: String) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.updateHook(hook, content: content, at: repoPath)
        modalCoordinator.dismiss()
        selectedHook = nil
    }

    private func deleteHook(_ hook: GitHook) async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.deleteHook(hook, at: repoPath)
    }
}

// MARK: - Git Hook Row

struct GitHookRow: View {
    let hook: GitHook
    let onToggle: () async -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { hook.isEnabled },
                set: { _ in Task { await onToggle() } }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                Text(hook.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                Text(hook.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Edit hook")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete hook")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Git Hook Editor Sheet

struct GitHookEditorSheet: View {
    let hook: GitHook
    let onSave: (GitHook, String) async -> Void
    let onDismiss: () -> Void

    @State private var content: String
    @State private var isSaving = false

    init(hook: GitHook, onSave: @escaping (GitHook, String) async -> Void, onDismiss: @escaping () -> Void) {
        self.hook = hook
        self.onSave = onSave
        self.onDismiss = onDismiss
        self._content = State(initialValue: hook.content ?? GitHookType(rawValue: hook.name)?.templateContent ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Separator.horizontal()

            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .padding()

            Separator.horizontal()
            footerSection
        }
        .frame(width: 600, height: 500)
        .background(AppTheme.background)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Edit \(hook.displayName)")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(hook.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var footerSection: some View {
        HStack {
            Spacer()

            Button("Save") {
                Task {
                    isSaving = true
                    await onSave(hook, content)
                    isSaving = false
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || content.isEmpty)
        }
        .padding()
    }
}

// MARK: - Supporting Types

enum GitHookModal: Hashable {
    case editor
    case deleteConfirm
}

enum GitHookCategory: String, CaseIterable {
    case commit = "Commit Hooks"
    case push = "Push/Receive Hooks"
    case email = "Email Hooks"
    case other = "Other Hooks"

    func contains(_ hookName: String) -> Bool {
        switch self {
        case .commit:
            return hookName.contains("commit") || hookName.contains("rebase") || hookName.contains("merge")
        case .push:
            return hookName.contains("push") || hookName.contains("receive") || hookName.contains("update")
        case .email:
            return hookName.contains("email") || hookName.contains("applypatch")
        case .other:
            return true
        }
    }
}

// MARK: - ViewModel

@MainActor
class GitHooksViewModel: ObservableObject {
    @Published var hooks: [GitHook] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = GitHooksService()

    var enabledCount: Int {
        hooks.filter { $0.isEnabled }.count
    }

    func hooks(for category: GitHookCategory) -> [GitHook] {
        hooks.filter { category.contains($0.name) }
    }

    func loadHooks(at repoPath: String) async {
        isLoading = true
        errorMessage = nil

        do {
            hooks = try service.getHooks(at: repoPath)
        } catch {
            errorMessage = "Failed to load hooks: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func toggleHook(_ hook: GitHook, at repoPath: String) async {
        do {
            if hook.isEnabled {
                try service.disableHook(hook)
            } else {
                try service.enableHook(hook)
            }

            hooks = try service.getHooks(at: repoPath)
        } catch {
            errorMessage = "Failed to toggle hook: \(error.localizedDescription)"
        }
    }

    func updateHook(_ hook: GitHook, content: String, at repoPath: String) async {
        do {
            try service.updateHook(hook, content: content)
            if !hook.isEnabled {
                try service.enableHook(hook, content: content)
            }

            hooks = try service.getHooks(at: repoPath)
        } catch {
            errorMessage = "Failed to update hook: \(error.localizedDescription)"
        }
    }

    func deleteHook(_ hook: GitHook, at repoPath: String) async {
        do {
            try service.deleteHook(hook)
            hooks = try service.getHooks(at: repoPath)
        } catch {
            errorMessage = "Failed to delete hook: \(error.localizedDescription)"
        }
    }
}
