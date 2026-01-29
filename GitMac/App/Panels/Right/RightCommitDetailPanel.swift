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
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 24, height: 24)
                    .help("Close")
                }

                // Commit message
                Text(commit.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(3)

                // Author and date
                HStack(spacing: 8) {
                    AuthorAvatar(name: commit.author, size: 20)
                    Text(commit.author)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(commit.relativeDate)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                }

                // SHA
                HStack {
                    Text(String(commit.sha.prefix(8)))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commit.sha, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textMuted)
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
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                    Text("\(viewModel.changedFiles.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.backgroundTertiary)
                        .clipShape(.rect(cornerRadius: 4))
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
                            if viewModel.changedFiles.isEmpty && viewModel.errorMessage == nil {
                                Text("No files changed")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            if let error = viewModel.errorMessage {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(AppTheme.warning)
                                    Text(error)
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.textMuted)
                                        .multilineTextAlignment(.center)
                                    Button("Retry") {
                                        guard let path = appState.currentRepository?.path else { return }
                                        Task { await viewModel.loadCommitFiles(sha: commit.sha, at: path) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
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
