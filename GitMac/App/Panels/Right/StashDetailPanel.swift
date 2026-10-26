import SwiftUI
import AppKit

// MARK: - Stash Detail Panel
struct StashDetailPanel: View {
    let stash: Stash
    @ObservedObject var viewModel: StashDetailViewModel
    @Binding var selectedFileDiff: FileDiff?
    let onClose: () -> Void
    var repositoryPath: String? = nil
    @State private var showDropConfirmation = false

    private var stashColor: Color { AppTheme.info }

    var body: some View {
        // Do not export the changing intrinsic size of the loading/header/file
        // branches to the native inspector's SplitViewChildController.
        GeometryReader { geometry in
            panelContent
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .task(id: [repositoryPath ?? "", stash.sha]) {
            if let path = repositoryPath {
                await viewModel.loadStashFiles(stashRef: stash.reference, at: path)
            }
        }
        .confirmationDialog("Delete this saved stash?", isPresented: $showDropConfirmation, titleVisibility: .visible) {
            Button("Delete Saved Stash", role: .destructive) {
                NotificationCenter.default.post(name: .dropStash, object: stash.index)
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(stash.reference) from the saved stash list. Viewing a stash does not require deleting it. Do not rely on Undo to recover this entry.")
        }
    }

    private var panelContent: some View {
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
                                .lineLimit(1)
                                .truncationMode(.middle)
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
                                        if let path = repositoryPath {
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
            ViewThatFits(in: .horizontal) {
                stashActionButtons.fixedSize(horizontal: true, vertical: false)
                stashActionButtons.labelStyle(.iconOnly)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stash-actions")
            .padding(12)
            .background(AppTheme.backgroundSecondary)
        }
    }

    private var stashActionButtons: some View {
        HStack(spacing: 8) {
                Button {
                    NotificationCenter.default.post(name: .applyStash, object: stash.index)
                    onClose()
                } label: {
                    Label("Apply", systemImage: "arrow.down.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Apply changes and keep the saved stash entry")
                .accessibilityLabel("Apply stash and keep saved entry")
                .accessibilityIdentifier("stash-apply")
                .frame(minWidth: 28, minHeight: 28)

                Button {
                    NotificationCenter.default.post(name: .popStashAtIndex, object: stash.index)
                    onClose()
                } label: {
                    Label("Pop", systemImage: "arrow.up.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Apply changes, then remove the saved entry if successful")
                .accessibilityLabel("Pop stash")
                .accessibilityIdentifier("stash-pop")
                .frame(minWidth: 28, minHeight: 28)

                Spacer()

                Button(role: .destructive) {
                    showDropConfirmation = true
                } label: {
                    Label("Drop", systemImage: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Delete the saved stash entry — confirmation required")
                .accessibilityLabel("Delete saved stash")
                .accessibilityIdentifier("stash-drop")
                .frame(minWidth: 28, minHeight: 28)
            }
    }

    private func loadStashFileDiff(_ file: StashFile) {
        guard let path = repositoryPath else { return }
        Task {
            if let diff = await viewModel.getDiff(for: file, stash: stash, at: path) {
                selectedFileDiff = diff
            }
        }
    }
}
