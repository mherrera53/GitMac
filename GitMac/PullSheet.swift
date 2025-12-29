import SwiftUI

struct PullSheet: View {
    @EnvironmentObject var appState: AppState

    @State private var useRebase = false
    @State private var isRunning = false
    @State private var result: AutoStashResult?
    @State private var error: String?

    @State private var showResolver = false
    @State private var conflictToResolve: FileStatus?

    private var conflictedFiles: [FileStatus] {
        appState.currentRepository?.status.conflicted ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pull").font(.title2).bold()

            Toggle("Rebase en lugar de merge", isOn: $useRebase)

            if isRunning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Ejecutando pull…")
                }
                .padding(.top, 4)
            }

            if let result {
                PullResultView(result: result)
            }

            if let error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppTheme.warning)
                    Text(error).foregroundColor(AppTheme.textPrimary)
                }
                .padding(8)
                .background(AppTheme.warning.opacity(0.1))
                .cornerRadius(6)
            }

            if !conflictedFiles.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Conflictos detectados (\(conflictedFiles.count))")
                    .font(.headline)
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(conflictedFiles) { file in
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(AppTheme.warning)
                                Text(file.path)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    conflictToResolve = file
                                    showResolver = true
                                } label: {
                                    Label("Resolver", systemImage: "wand.and.stars")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.warning)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 180)
            }

            HStack {
                Spacer()
                Button("Cerrar") {
                    NSApp.keyWindow?.close()
                }
                Button("Pull") {
                    Task { await doPull() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
            }
            .padding(.top, 6)
        }
        .padding(16)
        .frame(width: 480)
        .sheet(isPresented: $showResolver) {
            if let file = conflictToResolve, let repoPath = appState.currentRepository?.path {
                InlineConflictResolver(
                    filePath: file.path,
                    repositoryPath: repoPath,
                    onResolved: {
                        Task { try? await appState.gitService.refresh() }
                        showResolver = false
                    }
                )
            }
        }
    }

    private func doPull() async {
        guard let repo = appState.currentRepository else { return }
        isRunning = true
        error = nil
        result = nil

        let branchName = repo.currentBranch?.name ?? "unknown"

        do {
            let r = try await appState.gitService.pullWithAutoStash(rebase: useRebase)
            result = r
            
            // Track successful pull
            RemoteOperationTracker.shared.recordPull(
                success: true,
                branch: branchName,
                remote: "origin",
                error: nil,
                commitCount: 0 // TODO: Get actual commit count from result
            )
            
            // Show success notification
            NotificationManager.shared.success(
                "Pull completed",
                detail: r.message
            )
            
        } catch let gitError as GitError {
            self.error = gitError.localizedDescription
            
            // Track failed pull
            RemoteOperationTracker.shared.recordPull(
                success: false,
                branch: branchName,
                remote: "origin",
                error: gitError.localizedDescription
            )
            
            // Show error notification with suggested fix if available
            if let fix = gitError.suggestedFix {
                NotificationManager.shared.errorWithFix(
                    "Pull failed",
                    detail: gitError.localizedDescription,
                    fixTitle: fix.title,
                    fixHint: fix.hint
                ) { [weak appState] in
                    // Execute the suggested fix
                    Task {
                        if let command = fix.command {
                            // Run the suggested command
                            if command == "git stash" {
                                _ = try? await appState?.gitService.stash(message: "Auto-stash before pull")
                                NotificationManager.shared.success("Changes stashed", detail: "Now try pulling again")
                            } else if command == "git pull --rebase" {
                                // Already doing this, just close
                            }
                        }
                    }
                }
            } else {
                NotificationManager.shared.error(
                    "Pull failed",
                    detail: gitError.localizedDescription
                )
            }
        } catch {
            self.error = error.localizedDescription
            
            // Track failed pull
            RemoteOperationTracker.shared.recordPull(
                success: false,
                branch: branchName,
                remote: "origin",
                error: error.localizedDescription
            )
            
            NotificationManager.shared.error(
                "Pull failed",
                detail: error.localizedDescription
            )
        }

        isRunning = false
    }
}

struct PullResultView: View {
    let result: AutoStashResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.isFullySuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(result.isFullySuccessful ? AppTheme.success : AppTheme.warning)
            Text(result.message)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(8)
        .background((result.isFullySuccessful ? AppTheme.success : AppTheme.warning).opacity(0.08))
        .cornerRadius(6)
    }
}
