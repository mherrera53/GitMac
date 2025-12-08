import SwiftUI

/// Tag list and management view
struct TagListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = TagListViewModel()
    @State private var selectedTag: Tag?
    @State private var showCreateTagSheet = false
    @State private var showDeleteAlert = false
    @State private var tagToDelete: Tag?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tags")
                    .font(.headline)

                Text("(\(viewModel.tags.count))")
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showCreateTagSheet = true
                } label: {
                    Label("New Tag", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tags...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Tag list
            if filteredTags.isEmpty {
                EmptyTagView(hasSearch: !searchText.isEmpty)
            } else {
                List(filteredTags, selection: $selectedTag) { tag in
                    TagRow(
                        tag: tag,
                        isSelected: selectedTag?.id == tag.id,
                        onCheckout: { Task { await viewModel.checkoutTag(tag) } },
                        onPush: { Task { await viewModel.pushTag(tag) } },
                        onDelete: {
                            tagToDelete = tag
                            showDeleteAlert = true
                        }
                    )
                    .tag(tag)
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showCreateTagSheet) {
            CreateTagSheet(viewModel: viewModel)
        }
        .alert("Delete Tag", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    Task { await viewModel.deleteTag(tag) }
                }
            }
        } message: {
            Text("Are you sure you want to delete tag '\(tagToDelete?.name ?? "")'?")
        }
        .task {
            if let repo = appState.currentRepository {
                viewModel.loadTags(from: repo)
            }
        }
    }

    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return viewModel.tags
        }
        return viewModel.tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - View Model

@MainActor
class TagListViewModel: ObservableObject {
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var error: String?

    private let gitService = GitService()

    func loadTags(from repo: Repository) {
        // Sort tags: version tags first (newest), then alphabetically
        tags = repo.tags.sorted { lhs, rhs in
            if let lhsVersion = lhs.version, let rhsVersion = rhs.version {
                return lhsVersion > rhsVersion
            }
            if lhs.isVersionTag && !rhs.isVersionTag { return true }
            if !lhs.isVersionTag && rhs.isVersionTag { return false }
            return lhs.name > rhs.name
        }
    }

    func createTag(name: String, message: String?, ref: String) async {
        isLoading = true
        do {
            _ = try await gitService.createTag(name: name, message: message, ref: ref)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteTag(_ tag: Tag) async {
        isLoading = true
        do {
            try await gitService.deleteTag(named: tag.name)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func checkoutTag(_ tag: Tag) async {
        isLoading = true
        do {
            try await gitService.checkout(tag.name)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func pushTag(_ tag: Tag) async {
        isLoading = true
        let shell = ShellExecutor()
        _ = await shell.execute("git", arguments: ["push", "origin", tag.name])
        isLoading = false
    }

    func pushAllTags() async {
        isLoading = true
        let shell = ShellExecutor()
        _ = await shell.execute("git", arguments: ["push", "--tags"])
        isLoading = false
    }
}

// MARK: - Subviews

struct TagRow: View {
    let tag: Tag
    let isSelected: Bool
    var onCheckout: () -> Void = {}
    var onPush: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Tag icon
            Image(systemName: tag.isAnnotated ? "tag.fill" : "tag")
                .foregroundColor(tag.isVersionTag ? .orange : .blue)

            // Tag info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(tag.name)
                        .fontWeight(.medium)

                    if tag.isVersionTag {
                        Text("release")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Text(tag.shortSHA)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)

                    if let date = tag.relativeDate {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let tagger = tag.tagger {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(tagger)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Actions on hover
            if isHovered {
                HStack(spacing: 4) {
                    Button { onCheckout() } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Checkout")

                    Button { onPush() } label: {
                        Image(systemName: "arrow.up.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Push to remote")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Checkout") { onCheckout() }
            Divider()
            Button("Push to Remote") { onPush() }
            Divider()
            Button("Copy Tag Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tag.name, forType: .string)
            }
            Button("Copy SHA") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tag.targetSHA, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

struct EmptyTagView: View {
    let hasSearch: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if hasSearch {
                Text("No matching tags")
                    .font(.headline)
            } else {
                Text("No tags")
                    .font(.headline)

                Text("Create a tag to mark a specific point in history")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreateTagSheet: View {
    @ObservedObject var viewModel: TagListViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var tagName = ""
    @State private var message = ""
    @State private var targetRef = "HEAD"
    @State private var isAnnotated = true

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Tag")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Tag name", text: $tagName)
                    .textFieldStyle(.roundedBorder)

                Picker("At", selection: $targetRef) {
                    Text("Current HEAD").tag("HEAD")
                    ForEach(appState.currentRepository?.branches ?? [], id: \.id) { branch in
                        Text(branch.name).tag(branch.name)
                    }
                }

                Toggle("Annotated tag", isOn: $isAnnotated)

                if isAnnotated {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Message")
                        TextEditor(text: $message)
                            .font(.system(.body))
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }

            // Version tag helper
            if !tagName.isEmpty {
                HStack {
                    if tagName.first != "v" {
                        Button("Add 'v' prefix") {
                            tagName = "v" + tagName
                        }
                        .buttonStyle(.borderless)
                    }

                    Spacer()

                    if let version = SemanticVersion(from: tagName) {
                        Text("Version: \(version.string)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Tag") {
                    Task {
                        await viewModel.createTag(
                            name: tagName,
                            message: isAnnotated && !message.isEmpty ? message : nil,
                            ref: targetRef
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(tagName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// #Preview {
//     TagListView()
//         .environmentObject(AppState())
//         .frame(width: 350, height: 500)
// }
