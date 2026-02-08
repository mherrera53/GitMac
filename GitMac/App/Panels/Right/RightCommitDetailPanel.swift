import SwiftUI
import AppKit

// MARK: - Right Panel Commit Detail (when commit is selected in staging)
struct RightCommitDetailPanel: View {
    let commit: Commit
    @ObservedObject var viewModel: CommitDetailViewModel
    @Binding var selectedFileDiff: FileDiff?
    let onClose: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var fileFilterText = ""
    @State private var filterByStatus: CommitFile.CommitFileStatus?
    @State private var showFilterBar = false

    private var filteredFiles: [CommitFile] {
        var files = viewModel.changedFiles

        // Text filter (path or extension)
        if !fileFilterText.isEmpty {
            let query = fileFilterText.lowercased()
            files = files.filter { file in
                file.path.lowercased().contains(query)
            }
        }

        // Status filter
        if let status = filterByStatus {
            files = files.filter { $0.status == status }
        }

        return files
    }

    /// Unique file extensions present in the changed files
    private var availableExtensions: [String] {
        let exts = Set(viewModel.changedFiles.compactMap { file -> String? in
            let ext = URL(fileURLWithPath: file.path).pathExtension
            return ext.isEmpty ? nil : ext
        })
        return exts.sorted()
    }

    /// Unique statuses present in the changed files
    private var availableStatuses: [CommitFile.CommitFileStatus] {
        Array(Set(viewModel.changedFiles.map(\.status)))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Commit header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Commit Details")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 24, height: 24)
                    .help("Close")
                }

                // Commit message
                Text(commit.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(3)

                // Author and date
                HStack(spacing: 8) {
                    AuthorAvatar(name: commit.author, size: 20)
                    Text(commit.author)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text(commit.relativeDate)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }

                // SHA
                HStack {
                    Text(String(commit.sha.prefix(8)))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.accent)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commit.sha, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(12)
            .background(.thinMaterial)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Changed files header with filter
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Changed Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()

                    // Filter toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFilterBar.toggle()
                            if !showFilterBar {
                                fileFilterText = ""
                                filterByStatus = nil
                            }
                        }
                    } label: {
                        Image(systemName: showFilterBar ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(showFilterBar ? AppTheme.accent : AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Filter files")

                    Text("\(filteredFiles.count)\(filteredFiles.count != viewModel.changedFiles.count ? "/\(viewModel.changedFiles.count)" : "")")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial)

                // Filter bar
                if showFilterBar {
                    fileFilterBar
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredFiles) { file in
                                CommitFileRow(
                                    file: file,
                                    repositoryPath: appState.currentRepository?.path ?? "",
                                    onSelect: { loadCommitFileDiff(file) }
                                )
                            }
                            if filteredFiles.isEmpty && !viewModel.changedFiles.isEmpty {
                                VStack(spacing: 4) {
                                    Text("No files match filter")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                    Button("Clear filter") {
                                        fileFilterText = ""
                                        filterByStatus = nil
                                    }
                                    .font(.system(size: 11))
                                    .buttonStyle(.borderless)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            } else if viewModel.changedFiles.isEmpty {
                                Text("No files changed")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .task(id: commit.sha) {
            guard let path = appState.currentRepository?.path else { return }
            await viewModel.loadCommitFiles(sha: commit.sha, at: path)
        }
    }

    // MARK: - Filter Bar

    private var fileFilterBar: some View {
        VStack(spacing: 6) {
            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
                TextField("Filter by name or path...", text: $fileFilterText)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                if !fileFilterText.isEmpty {
                    Button {
                        fileFilterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(AppTheme.backgroundTertiary)
            .cornerRadius(4)

            // Status filter chips
            if availableStatuses.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        fileFilterChip(label: "All", isActive: filterByStatus == nil) {
                            filterByStatus = nil
                        }
                        ForEach(availableStatuses, id: \.self) { status in
                            fileFilterChip(
                                label: status.icon,
                                color: status.color,
                                isActive: filterByStatus == status
                            ) {
                                filterByStatus = filterByStatus == status ? nil : status
                            }
                        }
                    }
                }
            }

            // Extension filter chips
            if availableExtensions.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(availableExtensions, id: \.self) { ext in
                            fileFilterChip(
                                label: ".\(ext)",
                                isActive: fileFilterText == ".\(ext)"
                            ) {
                                fileFilterText = fileFilterText == ".\(ext)" ? "" : ".\(ext)"
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.backgroundSecondary.opacity(0.5))
    }

    @ViewBuilder
    private func fileFilterChip(label: String, color: Color? = nil, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isActive ? AppTheme.accent.opacity(0.2) : AppTheme.backgroundTertiary)
            .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textSecondary)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func loadCommitFileDiff(_ file: CommitFile) {
        guard let path = appState.currentRepository?.path else { return }
        Task {
            if let diff = await viewModel.getDiff(for: file, commit: commit, at: path) {
                selectedFileDiff = diff
            }
        }
    }
}
