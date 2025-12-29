import SwiftUI

/// Revert commit view - create inverse commit
struct RevertView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RevertViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let targetCommits: [Commit]
    
    @State private var noCommit = false
    @State private var isReverting = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Revert Commit")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create a new commit that undoes the changes")
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Target commits info
            VStack(alignment: .leading, spacing: 8) {
                Text(targetCommits.count > 1 ? "Revert changes from \(targetCommits.count) commits:" : "Revert changes from:")
                    .font(.headline)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(targetCommits) { commit in
                            CommitInfoCard(commit: commit)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            
            Divider()
            
            // Options
            VStack(alignment: .leading, spacing: 12) {
                Text("Options:")
                    .font(.headline)
                
                Toggle(isOn: $noCommit) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stage changes without committing")
                            .font(.body)
                        
                        Text("Apply the revert to staging area, allowing you to modify or amend before committing")
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            
            // Info box
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppTheme.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("How revert works:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Revert creates a new commit that undoes the changes from the selected commit. This is safe for public branches because it doesn't rewrite history.")
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(AppTheme.accent.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    Task { await performRevert() }
                } label: {
                    if isReverting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Text(noCommit ? (targetCommits.count > 1 ? "Revert All to Staging" : "Revert to Staging") : (targetCommits.count > 1 ? "Revert All Commits" : "Revert Commit"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isReverting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 550, height: 500)
        .task {
            viewModel.configure(appState: appState)
        }
    }
    
    private func performRevert() async {
        isReverting = true
        let success = await viewModel.revert(commits: targetCommits, noCommit: noCommit)
        isReverting = false
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Commit Info Card

struct CommitInfoCard: View {
    let commit: Commit
    
    var body: some View {
        HStack(spacing: 12) {
            // Commit indicator
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(commit.message)
                    .font(.body)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(commit.shortSHA)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(commit.author)
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(commit.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.accent.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - View Model

@MainActor
class RevertViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var appState: AppState?
    
    func configure(appState: AppState) {
        self.appState = appState
    }
    
    func revert(commits: [Commit], noCommit: Bool) async -> Bool {
        guard let appState = appState else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await appState.gitService.revert(
                commitSHAs: commits.map { $0.sha },
                noCommit: noCommit
            )

            // Show success notification
            let message = noCommit ? "Changes reverted to staging area" : "Commit reverted successfully"
            let detail = noCommit ? "Review and commit when ready" : "New revert commit created"
            
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationMessage(
                    type: .success,
                    message: message,
                    detail: detail
                )
            )
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationMessage(
                    type: .error,
                    message: "Revert failed",
                    detail: error.localizedDescription
                )
            )
            
            return false
        }
    }
}
