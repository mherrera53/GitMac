import SwiftUI
import AppKit

struct WorktreeListView: View {
    @Environment(AppState.self) var appState
    @StateObject private var manager = WorktreeManager.shared
    @State private var showAddSheet = false
    @State private var selectedPath: String?
    @State private var pendingRemoval: Worktree?
    @State private var removalRepository: String?
    @State private var operationError: String?
    @State private var query = ""

    private var visibleWorktrees: [Worktree] {
        manager.worktrees.filter { query.isEmpty || [$0.name, $0.branch ?? "", $0.path].contains { $0.localizedStandardContains(query) } }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Worktrees", systemImage: "folder.badge.gearshape").font(.headline)
                Spacer()
                GitHelpButton(topicID: "worktrees")
                Button {
                    Task { await manager.refresh(at: appState.currentRepository?.path) }
                } label: { Image(systemName: "arrow.clockwise").frame(width: 28, height: 28) }
                .help("Refresh worktrees").accessibilityLabel("Refresh worktrees")
                Button("New Worktree…", systemImage: "plus") { showAddSheet = true }
                    .disabled(appState.currentRepository == nil || manager.isLoading || manager.isPerformingOperation)
            }
            .padding(12)

            VStack(alignment: .leading, spacing: 4) {
                Text("One task, one branch, one folder.").font(.subheadline.weight(.semibold))
                Text("Open a folder to work there. Closing its tab keeps the folder; Remove deletes it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).background(AppTheme.backgroundSecondary)

            if !manager.worktrees.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textSecondary)
                    TextField("Find a worktree, branch or folder", text: $query).textFieldStyle(.plain)
                        .accessibilityIdentifier("worktree-search")
                    if !query.isEmpty { Button("Clear") { query = "" }.buttonStyle(.borderless) }
                }.padding(10)
            }
            if let error = manager.error {
                Text(error).font(.caption).foregroundStyle(AppTheme.error).textSelection(.enabled).padding(12)
            }
            if manager.worktrees.isEmpty && manager.isLoading {
                ProgressView("Loading worktrees…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.worktrees.isEmpty {
                ContentUnavailableView {
                    Label("No worktrees available", systemImage: "folder")
                } description: {
                    Text("Refresh the list or create a separate folder for your next task.")
                } actions: {
                    Button("New Worktree…") { showAddSheet = true }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if visibleWorktrees.isEmpty {
                            ContentUnavailableView.search(text: query)
                        }
                        ForEach(visibleWorktrees, id: \.path) { worktree in
                            WorktreeRow(worktree: worktree,
                                isSelected: selectedPath == worktree.path,
                                isCurrent: worktree.path == appState.currentRepository?.path,
                                onSelect: { selectedPath = worktree.path },
                                onOpen: { Task { await appState.openRepository(at: worktree.path) } },
                                onRemove: {
                                    removalRepository = appState.currentRepository?.path
                                    pendingRemoval = worktree
                                },
                                onLock: { toggleLock(worktree) },
                                onOpenTerminal: {
                                    Task {
                                        await appState.openRepository(at: worktree.path)
                                        guard appState.currentRepository?.path == worktree.path else { return }
                                        BottomPanelManager.shared.openTab(type: .terminal)
                                    }
                                })
                                .disabled(manager.isPerformingOperation)
                            Divider()
                        }
                    }
                }
            }
        }
        .background(AppTheme.background)
        .task(id: appState.currentRepository?.path) {
            selectedPath = nil
            pendingRemoval = nil
            await manager.refresh(at: appState.currentRepository?.path)
        }
        .sheet(isPresented: $showAddSheet) { AddWorktreeSheet() }
        .confirmationDialog("Remove this worktree folder?", isPresented: Binding(
            get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
            if let worktree = pendingRemoval {
                Button("Remove Folder", role: .destructive) {
                    let repository = removalRepository
                    pendingRemoval = nil
                    Task {
                        do { try await manager.removeWorktree(worktree, repositoryPath: repository) }
                        catch { operationError = error.localizedDescription }
                    }
                }
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("Folder: \(pendingRemoval?.path ?? "")\nIts branch remains. Uncommitted files block removal. This does not use the Trash.")
        }
        .alert("Worktree operation failed", isPresented: Binding(
            get: { operationError != nil }, set: { if !$0 { operationError = nil } })) {
            Button("OK") { operationError = nil }
        } message: { Text(operationError ?? "") }
    }

    private func toggleLock(_ worktree: Worktree) {
        let repository = appState.currentRepository?.path
        Task {
            do {
                if worktree.isLocked { try await manager.unlockWorktree(worktree, repositoryPath: repository) }
                else { try await manager.lockWorktree(worktree, reason: "Protected in GitMac", repositoryPath: repository) }
            } catch { operationError = error.localizedDescription }
        }
    }
}

struct WorktreeRow: View {
    let worktree: Worktree
    let isSelected: Bool
    var isCurrent: Bool = false
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void
    let onLock: () -> Void
    var onOpenTerminal: (() -> Void)? = nil

    private var canOpen: Bool { !worktree.isBare && !worktree.isPrunable && FileManager.default.fileExists(atPath: worktree.path) }
    private var canRemove: Bool { !worktree.isMain && !worktree.isLocked && !worktree.isDetached && !isCurrent && canOpen }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: worktree.isMain ? "house" : "folder").foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(worktree.name).font(.subheadline.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                    if isCurrent { Text("Current").font(.caption2).foregroundStyle(AppTheme.accent) }
                    if worktree.isMain { Text("Main folder").font(.caption2).foregroundStyle(.secondary) }
                    if worktree.isLocked { Image(systemName: "lock.fill").help(worktree.lockedReason ?? "Protected against removal") }
                }
                Text(worktree.isBare ? "Bare repository" : (worktree.branch ?? "Detached revision \(worktree.shortSHA)"))
                    .font(.caption).foregroundStyle(worktree.isDetached ? AppTheme.warning : AppTheme.textSecondary)
                    .lineLimit(1).truncationMode(.middle)
                Text(worktree.path).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle).help(worktree.path)
                if worktree.isPrunable {
                    Text("Folder missing — review stale metadata before cleanup").font(.caption).foregroundStyle(AppTheme.warning)
                }
            }
            Spacer(minLength: 0)
            Button("Open", action: onOpen).disabled(!canOpen)
                .help("Open this worktree in a repository tab")
                .accessibilityLabel("Open worktree \(worktree.name)")
            Menu { actionsMenu
            } label: { Image(systemName: "ellipsis.circle").frame(width: 28, height: 28) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .help("Worktree actions. Protected, current, main and detached folders cannot be removed here.")
            .accessibilityLabel("Actions for worktree \(worktree.name)")
        }
        .padding(12)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if canOpen { onOpen() } }
        .onTapGesture { onSelect() }
        .contextMenu { actionsMenu }
        .accessibilityElement(children: .contain)
    }
    @ViewBuilder private var actionsMenu: some View {
        Button("Open Worktree", systemImage: "arrow.up.forward.square", action: onOpen).disabled(!canOpen)
        if let onOpenTerminal {
            Button("Open Terminal Here", systemImage: "terminal", action: onOpenTerminal).disabled(!canOpen)
        }
                Button("Reveal in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: worktree.path)])
                }.disabled(!canOpen)
                Button("Copy Folder Path", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(worktree.path, forType: .string)
                }
                if !worktree.isMain {
                    Divider()
                    Button(worktree.isLocked ? "Unlock Folder" : "Protect Folder", systemImage: worktree.isLocked ? "lock.open" : "lock", action: onLock)
                        .disabled(!canOpen)
                    Button("Remove Folder…", systemImage: "trash", role: .destructive, action: onRemove)
                        .disabled(!canRemove)
                }
    }

}

struct AddWorktreeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState
    @StateObject private var manager = WorktreeManager.shared
    var startPoint: String? = nil

    private enum Mode: String, CaseIterable {
        case newBranch = "New branch"
        case existing = "Existing branch"
        case inspect = "Inspect revision"
    }

    @State private var mode: Mode = .newBranch
    @State private var worktreePath = ""
    @State private var selectedRevision = ""
    @State private var newBranchName = ""
    @State private var sourceRepository: String?
    @State private var sourceBranches: [Branch] = []
    @State private var openAfterCreation = true
    @State private var isCreating = false
    @State private var creationError: String?

    private var validationMessage: String? {
        guard let sourceRepository else { return "Open a repository first." }
        guard appState.currentRepository?.path == sourceRepository else { return "Repository changed. Close and reopen this dialog." }
        guard worktreePath.hasPrefix("/"), !worktreePath.contains("\0") else { return "Choose an absolute path for a new folder." }
        guard !FileManager.default.fileExists(atPath: worktreePath) else { return "That folder already exists. Choose a new destination." }
        let source = URL(fileURLWithPath: sourceRepository).resolvingSymlinksInPath().path
        let destination = URL(fileURLWithPath: worktreePath).standardizedFileURL.resolvingSymlinksInPath().path
        guard destination != source && !destination.hasPrefix(source + "/") else { return "Choose a separate folder outside this repository." }
        if mode == .newBranch && newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Name the new branch for this task." }
        if mode != .newBranch && selectedRevision.isEmpty { return "Choose a branch or revision." }
        if mode == .existing && manager.hasWorktree(for: selectedRevision) { return "That branch already has a folder. Open its worktree or create a new branch." }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Create Worktree", systemImage: "folder.badge.plus").font(.headline)
                Spacer()
                GitHelpButton(topicID: "worktrees")
            }.padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Keep your current work in place and start another task in a separate folder.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let sourceRepository {
                        LabeledContent("Repository", value: URL(fileURLWithPath: sourceRepository).lastPathComponent)
                            .help(sourceRepository)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Choose your task").font(.subheadline.weight(.semibold))
                        Picker("Worktree mode", selection: $mode) {
                            ForEach(Mode.allCases.filter { startPoint == nil || $0 != .existing }, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        if mode == .newBranch {
                            TextField("New branch name, e.g. feature/search", text: $newBranchName).textFieldStyle(.roundedBorder)
                            Text("Recommended for editing. Your original folder stays on its current branch.")
                                .font(.caption).foregroundStyle(.secondary)
                            TextField("Start from branch, tag or commit (HEAD by default)", text: $selectedRevision).textFieldStyle(.roundedBorder)
                        } else if mode == .existing {
                            Picker("Branch", selection: $selectedRevision) {
                                Text("Choose a branch…").tag("")
                                ForEach(sourceBranches.filter { !$0.isRemote }) { branch in
                                    Text(branch.name + (manager.hasWorktree(for: branch.name) ? " — already open" : ""))
                                        .tag(branch.name).disabled(manager.hasWorktree(for: branch.name))
                                }
                            }
                            Text("A branch already open in another worktree cannot be selected twice.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            TextField("Branch, tag or commit to inspect", text: $selectedRevision).textFieldStyle(.roundedBorder)
                            Label("Detached HEAD: create a branch before keeping new commits.", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(AppTheme.warning)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("2. Choose a new folder").font(.subheadline.weight(.semibold))
                        HStack {
                            TextField("Absolute folder path", text: $worktreePath).textFieldStyle(.roundedBorder)
                            Button("Choose…", action: chooseFolder)
                        }
                        Text("The folder will be created here. Existing folders are not overwritten.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("Open the new worktree in a tab", isOn: $openAfterCreation)
                    if let message = creationError ?? validationMessage {
                        Label(message, systemImage: creationError == nil ? "info.circle" : "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(creationError == nil ? AppTheme.textSecondary : AppTheme.error)
                            .textSelection(.enabled)
                    }
                }
                .padding(16).disabled(isCreating)
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(isCreating)
                Spacer()
                if isCreating { ProgressView().controlSize(.small) }
                Button(isCreating ? "Creating…" : "Create Worktree", action: createWorktree)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(validationMessage != nil || isCreating)
            }.padding(16)
        }
        .frame(minWidth: 420, idealWidth: 520, maxWidth: 680, minHeight: 340, idealHeight: 520, maxHeight: 700)
        .background(AppTheme.background)
        .task {
            guard sourceRepository == nil, let repository = appState.currentRepository else { return }
            sourceRepository = repository.path
            sourceBranches = repository.branches
            selectedRevision = startPoint ?? repository.currentBranch?.name ?? "HEAD"
            worktreePath = URL(fileURLWithPath: repository.path).deletingLastPathComponent()
                .appendingPathComponent(repository.name + "-worktree").path
            await manager.refresh(at: repository.path)
        }
        .onChange(of: mode) { _, mode in
            creationError = nil
            if mode == .existing { selectedRevision = sourceBranches.first { !$0.isRemote && !manager.hasWorktree(for: $0.name) }?.name ?? "" }
            else if selectedRevision.isEmpty { selectedRevision = startPoint ?? "HEAD" }
        }
    }

    private func chooseFolder() {
        let panel = NSSavePanel()
        panel.title = "Choose a new worktree folder"
        panel.prompt = "Use This Location"
        panel.canCreateDirectories = true
        if let sourceRepository { panel.directoryURL = URL(fileURLWithPath: sourceRepository).deletingLastPathComponent() }
        panel.nameFieldStringValue = URL(fileURLWithPath: worktreePath).lastPathComponent
        panel.begin { response in
            if response == .OK, let url = panel.url { worktreePath = url.path; creationError = nil }
        }
    }

    private func createWorktree() {
        guard validationMessage == nil, !isCreating, let repository = sourceRepository else { return }
        isCreating = true
        creationError = nil
        Task { @MainActor in
            defer { isCreating = false }
            do {
                let created = try await manager.addWorktree(path: worktreePath,
                    branch: selectedRevision.isEmpty ? nil : selectedRevision,
                    newBranch: mode == .newBranch ? newBranchName : nil,
                    detach: mode == .inspect, repositoryPath: repository)
                if openAfterCreation { await appState.openRepository(at: created.path) }
                dismiss()
            } catch {
                creationError = error.localizedDescription + "\nChoose another branch or destination and retry. Nothing was forced."
            }
        }
    }
}

struct CreateWorktreeFromCommitSheet: View {
    let commitSHA: String
    var body: some View { AddWorktreeSheet(startPoint: commitSHA) }
}

/// Native, keyboard-accessible contextual help. All text is bundled in code.
struct GitHelpButton: View {
    let topicID: String
    @State private var isPresented = false
    var body: some View {
        Button { isPresented = true } label: {
            Image(systemName: "questionmark.circle").frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .help("Explain this workflow — no commands will be executed")
        .accessibilityLabel("Help for \(GitHelpTopic.all.first { $0.id == topicID }?.title ?? "Git")")
        .sheet(isPresented: $isPresented) { GitHelpSheet(initialTopicID: topicID) }
    }
}

struct GitHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    var initialTopicID = "basics"
    @State private var query = ""

    private var topics: [GitHelpTopic] {
        let matching = GitHelpTopic.matching(query)
        return matching.filter { $0.id == initialTopicID } + matching.filter { $0.id != initialTopicID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Guía de Git").font(.headline)
                    Text("Qué hace cada acción, cuándo usarla y qué revisar antes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cerrar") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(16)
            TextField("Buscar: stash, ramas, deshacer, worktrees…", text: $query)
                .textFieldStyle(.roundedBorder).padding(.horizontal, 16)
                .accessibilityLabel("Buscar ayuda de Git")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if topics.isEmpty {
                        Text("No hay resultados. Prueba el nombre del comando o una palabra más corta.")
                            .foregroundStyle(.secondary).padding()
                    }
                    ForEach(topics) { topic in
                        GitHelpCard(topic: topic, initiallyExpanded: topic.id == initialTopicID)
                    }
                    Link("Catálogo completo de comandos de Git ↗", destination: URL(string: "https://git-scm.com/docs/git")!)
                        .padding(.vertical, 8)
                    Text("La ayuda funciona sin conexión. Solo los enlaces a documentación necesitan internet. Leer aquí nunca ejecuta comandos.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16)
            }
        }
        .frame(minWidth: 460, idealWidth: 640, maxWidth: 800, minHeight: 320, idealHeight: 520, maxHeight: 700)
    }
}

private struct GitHelpCard: View {
    let topic: GitHelpTopic
    @State private var isExpanded: Bool
    init(topic: GitHelpTopic, initiallyExpanded: Bool) {
        self.topic = topic
        _isExpanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text(topic.guidance).textSelection(.enabled)
                Label(topic.risk, systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
                Link("Documentación oficial ↗", destination: topic.documentationURL)
            }.padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title).font(.subheadline.weight(.semibold))
                Text(topic.summary).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}
