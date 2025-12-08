import SwiftUI

/// Stash list and management view
struct StashListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = StashListViewModel()
    @State private var selectedStash: Stash?
    @State private var showStashSheet = false
    @State private var showDeleteAlert = false
    @State private var stashToDelete: Stash?

    var body: some View {
        HSplitView {
            // Left: Stash list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Stashes")
                        .font(.headline)

                    Text("(\(viewModel.stashes.count))")
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        showStashSheet = true
                    } label: {
                        Label("Stash", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.hasChanges)
                    .help("Stash current changes")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // List
                if viewModel.stashes.isEmpty {
                    EmptyStashView()
                } else {
                    List(viewModel.stashes, selection: $selectedStash) { stash in
                        StashRow(
                            stash: stash,
                            isSelected: selectedStash?.id == stash.id,
                            onApply: { Task { await viewModel.applyStash(stash) } },
                            onPop: { Task { await viewModel.popStash(stash) } },
                            onDrop: {
                                stashToDelete = stash
                                showDeleteAlert = true
                            }
                        )
                        .tag(stash)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 280)

            // Right: Stash detail
            if let stash = selectedStash {
                StashDetailView(stash: stash, viewModel: viewModel)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "archivebox")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a stash to view details")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showStashSheet) {
            CreateStashSheet(viewModel: viewModel)
        }
        .alert("Drop Stash", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let stash = stashToDelete {
                    Task { await viewModel.dropStash(stash) }
                }
            }
        } message: {
            Text("Are you sure you want to drop '\(stashToDelete?.displayMessage ?? "")'? This cannot be undone.")
        }
        .task {
            if let repo = appState.currentRepository {
                viewModel.loadStashes(from: repo)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class StashListViewModel: ObservableObject {
    @Published var stashes: [Stash] = []
    @Published var hasChanges = false
    @Published var isLoading = false
    @Published var error: String?

    private let gitService = GitService()

    func loadStashes(from repo: Repository) {
        stashes = repo.stashes
        hasChanges = repo.status.hasChanges
    }

    func createStash(message: String?, includeUntracked: Bool) async {
        isLoading = true
        do {
            _ = try await gitService.stash(message: message, includeUntracked: includeUntracked)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func applyStash(_ stash: Stash) async {
        isLoading = true
        do {
            try await gitService.stashApply(index: stash.index)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func popStash(_ stash: Stash) async {
        isLoading = true
        do {
            try await gitService.stashPop(index: stash.index)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func dropStash(_ stash: Stash) async {
        isLoading = true
        do {
            try await gitService.stashDrop(index: stash.index)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func getStashDiff(_ stash: Stash) async -> String {
        // Get stash diff using git stash show -p
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["stash", "show", "-p", stash.reference]
        )
        return result.stdout
    }
}

// MARK: - Subviews

struct StashRow: View {
    let stash: Stash
    let isSelected: Bool
    var onApply: () -> Void = {}
    var onPop: () -> Void = {}
    var onDrop: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundColor(.orange)

                Text(stash.reference)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)

                Spacer()

                if isHovered {
                    HStack(spacing: 4) {
                        Button { onApply() } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.borderless)
                        .help("Apply")

                        Button { onPop() } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Pop")

                        Button { onDrop() } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Drop")
                    }
                }
            }

            Text(stash.displayMessage)
                .lineLimit(2)

            HStack {
                if let branch = stash.branchName {
                    Text("on \(branch)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(stash.relativeDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Apply") { onApply() }
            Button("Pop") { onPop() }
            Divider()
            Button("Create Branch from Stash...") { }
            Divider()
            Button("Drop", role: .destructive) { onDrop() }
        }
    }
}

struct StashDetailView: View {
    let stash: Stash
    @ObservedObject var viewModel: StashListViewModel
    @State private var diff = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stash.reference)
                        .font(.headline)
                    Text(stash.message)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.applyStash(stash) }
                    } label: {
                        Label("Apply", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await viewModel.popStash(stash) }
                    } label: {
                        Label("Pop", systemImage: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Diff content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: stash.id) {
            isLoading = true
            diff = await viewModel.getStashDiff(stash)
            isLoading = false
        }
    }
}

struct EmptyStashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No stashes")
                .font(.headline)

            Text("Stash your changes to save them temporarily")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Use ⌥⌘S to stash changes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreateStashSheet: View {
    @ObservedObject var viewModel: StashListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var includeUntracked = true
    @State private var keepIndex = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Stash Changes")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Message (optional)", text: $message)
                    .textFieldStyle(.roundedBorder)

                Toggle("Include untracked files", isOn: $includeUntracked)
                Toggle("Keep staged changes", isOn: $keepIndex)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Stash") {
                    Task {
                        await viewModel.createStash(
                            message: message.isEmpty ? nil : message,
                            includeUntracked: includeUntracked
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// #Preview {
//     StashListView()
//         .environmentObject(AppState())
//         .frame(width: 700, height: 500)
// }
