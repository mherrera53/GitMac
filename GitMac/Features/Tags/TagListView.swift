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
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                DSButton(variant: .primary, size: .sm) {
                    showCreateTagSheet = true
                } label: {
                    Label("New Tag", systemImage: "plus")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            // Search using DS component
            DSSearchField(
                placeholder: "Search tags...",
                text: $searchText
            )
            .padding(DesignTokens.Spacing.sm)
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
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Tag icon
            Image(systemName: tag.isAnnotated ? "tag.fill" : "tag")
                .foregroundColor(tag.isVersionTag ? AppTheme.warning : AppTheme.accent)

            // Tag info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack {
                    Text(tag.name)
                        .fontWeight(.medium)

                    if tag.isVersionTag {
                        Text("release")
                            .font(DesignTokens.Typography.caption2)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxs / 2)
                            .background(AppTheme.warning.opacity(0.2))
                            .foregroundColor(AppTheme.warning)
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(tag.shortSHA)
                        .font(DesignTokens.Typography.caption.monospacedDigit())
                        .foregroundColor(AppTheme.textPrimary)

                    if let date = tag.relativeDate {
                        Text("•")
                            .foregroundColor(AppTheme.textPrimary)
                        Text(date)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if let tagger = tag.tagger {
                        Text("•")
                            .foregroundColor(AppTheme.textPrimary)
                        Text(tagger)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }

            Spacer()

            // Actions on hover
            if isHovered {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    DSIconButton(iconName: "arrow.right.circle", variant: .ghost, size: .sm) {
                        onCheckout()
                    }
                    .help("Checkout")

                    DSIconButton(iconName: "arrow.up.circle", variant: .ghost, size: .sm) {
                        onPush()
                    }
                    .help("Push to remote")
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .background(isSelected ? AppTheme.accent.opacity(0.1) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .cornerRadius(DesignTokens.CornerRadius.sm)
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
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "tag")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textPrimary)

            if hasSearch {
                Text("No matching tags")
                    .font(.headline)
            } else {
                Text("No tags")
                    .font(.headline)

                Text("Create a tag to mark a specific point in history")
                    .foregroundColor(AppTheme.textPrimary)
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
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Create Tag")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                DSTextField(placeholder: "Tag name", text: $tagName)

                Picker("At", selection: $targetRef) {
                    Text("Current HEAD").tag("HEAD")
                    ForEach(appState.currentRepository?.branches ?? [], id: \.id) { branch in
                        Text(branch.name).tag(branch.name)
                    }
                }

                Toggle("Annotated tag", isOn: $isAnnotated)

                if isAnnotated {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Message")
                        TextEditor(text: $message)
                            .font(.system(.body))
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                    .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }

            // Version tag helper
            if !tagName.isEmpty {
                HStack {
                    if tagName.first != "v" {
                        DSButton(variant: .link, size: .sm) {
                            tagName = "v" + tagName
                        } label: {
                            Text("Add 'v' prefix")
                        }
                    }

                    Spacer()

                    if let version = SemanticVersion(from: tagName) {
                        Text("Version: \(version.string)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }

            HStack {
                DSButton(variant: .secondary, size: .md) {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                DSButton(variant: .primary, size: .md, isDisabled: tagName.isEmpty) {
                    await viewModel.createTag(
                        name: tagName,
                        message: isAnnotated && !message.isEmpty ? message : nil,
                        ref: targetRef
                    )
                    dismiss()
                } label: {
                    Text("Create Tag")
                }
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
