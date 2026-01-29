import SwiftUI
import AppKit

// MARK: - Stash Detail Panel
struct StashDetailPanel: View {
    let stash: Stash
    @ObservedObject var viewModel: StashDetailViewModel
    @Binding var selectedFileDiff: FileDiff?
    let onClose: () -> Void
    @EnvironmentObject var appState: AppState

    private var stashColor: Color { AppTheme.info }

    var body: some View {
        VStack(spacing: 0) {
            // Stash header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(stashColor)
                        Text("Stash Details")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                // Stash message
                Text(stash.displayMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(3)

                // Branch and date
                HStack(spacing: 8) {
                    if let branch = stash.branchName {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                            Text(branch)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(stash.relativeDate)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                }

                // Reference
                HStack {
                    Text(stash.reference)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(stashColor)
                    Spacer()
                }
            }
            .padding(12)
            .background(.thinMaterial)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Stash files
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Stashed Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                    Text("\(viewModel.stashFiles.count)")
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
                            ForEach(viewModel.stashFiles) { file in
                                StashDetailFileRow(
                                    file: file,
                                    onSelect: { loadStashFileDiff(file) },
                                    onApply: {
                                        if let path = appState.currentRepository?.path {
                                            Task { await viewModel.applyStashFile(stash: stash, file: file, at: path) }
                                        }
                                    }
                                )
                            }
                            if viewModel.stashFiles.isEmpty {
                                Text("No files in stash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    NotificationCenter.default.post(name: .applyStash, object: stash.index)
                    onClose()
                } label: {
                    Label("Apply", systemImage: "arrow.down.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)

                Button {
                    NotificationCenter.default.post(name: .popStashAtIndex, object: stash.index)
                    onClose()
                } label: {
                    Label("Pop", systemImage: "arrow.up.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    NotificationCenter.default.post(name: .dropStash, object: stash.index)
                    onClose()
                } label: {
                    Label("Drop", systemImage: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(AppTheme.backgroundSecondary)
        }
        .task {
            // Load files when panel appears
            if let path = appState.currentRepository?.path {
                await viewModel.loadStashFiles(stashRef: stash.reference, at: path)
            }
        }
    }

    private func loadStashFileDiff(_ file: StashFile) {
        guard let path = appState.currentRepository?.path else { return }
        Task {
            if let diff = await viewModel.getDiff(for: file, stash: stash, at: path) {
                selectedFileDiff = diff
            }
        }
    }
}
