import SwiftUI
import AppKit

// MARK: - Right Panel Commit Detail (when commit is selected in staging)
struct RightCommitDetailPanel: View {
    let commit: Commit
    @ObservedObject var viewModel: CommitDetailViewModel
    @Binding var selectedFileDiff: FileDiff?
    let onClose: () -> Void
    @EnvironmentObject var appState: AppState

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

            // Changed files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Changed Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Text("\(viewModel.changedFiles.count)")
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
                            ForEach(viewModel.changedFiles) { file in
                                CommitFileRow(
                                    file: file,
                                    repositoryPath: appState.currentRepository?.path ?? "",
                                    onSelect: { loadCommitFileDiff(file) }
                                )
                            }
                            if viewModel.changedFiles.isEmpty {
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
            // Load files when commit changes or panel appears
            guard let path = appState.currentRepository?.path else { return }
            await viewModel.loadCommitFiles(sha: commit.sha, at: path)
        }
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
