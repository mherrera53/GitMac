import SwiftUI

/// Reset operations view - powerful Git reset with safety
struct ResetView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ResetViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let targetCommit: Commit
    
    @State private var resetMode: ResetMode = .mixed
    @State private var showConfirmation = false
    @State private var isResetting = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reset Branch")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Move current branch to a different commit")
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()
            }
            
            Divider()
            
            // Target commit info
            VStack(alignment: .leading, spacing: 8) {
                Text("Reset to:")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    // Commit indicator
                    Circle()
                        .fill(AppTheme.info)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(targetCommit.message)
                            .font(.body)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(targetCommit.shortSHA)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AppTheme.textPrimary)

                            Text("•")
                                .foregroundColor(AppTheme.textPrimary)

                            Text(targetCommit.author)
                                .font(.caption)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("•")
                                .foregroundColor(AppTheme.textPrimary)

                            Text(targetCommit.date.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                }
                .padding()
                .background(AppTheme.info.opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Reset mode picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Reset Mode:")
                    .font(.headline)
                
                // Soft
                ResetModeOption(
                    mode: .soft,
                    isSelected: resetMode == .soft,
                    icon: "doc.text.fill",
                    color: AppTheme.success,
                    title: "Soft",
                    description: "Keep all changes as staged. Safe for uncommitted work.",
                    details: "• Moves HEAD to target commit\n• Keeps all changes staged\n• Working directory unchanged"
                ) {
                    resetMode = .soft
                }

                // Mixed (default)
                ResetModeOption(
                    mode: .mixed,
                    isSelected: resetMode == .mixed,
                    icon: "rectangle.stack.fill",
                    color: AppTheme.warning,
                    title: "Mixed (Default)",
                    description: "Keep changes as unstaged. Useful for re-committing.",
                    details: "• Moves HEAD to target commit\n• Unstages all changes\n• Working directory unchanged"
                ) {
                    resetMode = .mixed
                }

                // Hard
                ResetModeOption(
                    mode: .hard,
                    isSelected: resetMode == .hard,
                    icon: "trash.fill",
                    color: AppTheme.error,
                    title: "Hard",
                    description: "⚠️ DESTRUCTIVE: Discard all changes permanently.",
                    details: "• Moves HEAD to target commit\n• Resets staging area\n• ⚠️ DELETES all working changes"
                ) {
                    resetMode = .hard
                }
            }
            
            Spacer()
            
            // Warning for hard reset
            if resetMode == .hard {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.error)

                    Text("Hard reset will permanently delete all uncommitted changes!")
                        .font(.caption)
                        .foregroundColor(AppTheme.error)

                    Spacer()
                }
                .padding()
                .background(AppTheme.error.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    if resetMode == .hard {
                        showConfirmation = true
                    } else {
                        Task { await performReset() }
                    }
                } label: {
                    if isResetting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Reset Branch")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(resetMode == .hard ? AppTheme.error : .accentColor)
                .disabled(isResetting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 600, height: 700)
        .alert("Confirm Hard Reset", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset and Delete Changes", role: .destructive) {
                Task { await performReset() }
            }
        } message: {
            Text("This will permanently delete all uncommitted changes. This action cannot be undone.\n\nAre you absolutely sure?")
        }
        .task {
            viewModel.configure(appState: appState)
        }
    }
    
    private func performReset() async {
        isResetting = true
        let success = await viewModel.reset(to: targetCommit.sha, mode: resetMode)
        isResetting = false
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Reset Mode

enum ResetMode: String, CaseIterable {
    case soft = "soft"
    case mixed = "mixed"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .soft: return "Soft"
        case .mixed: return "Mixed"
        case .hard: return "Hard"
        }
    }
}

// MARK: - Reset Mode Option

struct ResetModeOption: View {
    let mode: ResetMode
    let isSelected: Bool
    let icon: String
    let color: Color
    let title: String
    let description: String
    let details: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if isSelected || isHovered {
                        Text(details)
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.1) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - View Model

@MainActor
class ResetViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var appState: AppState?
    
    func configure(appState: AppState) {
        self.appState = appState
    }
    
    func reset(to commitSHA: String, mode: ResetMode) async -> Bool {
        guard let appState = appState else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await appState.gitService.reset(to: commitSHA, mode: mode)
            
            // Show success notification
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationMessage(
                    type: .success,
                    message: "Reset completed successfully",
                    detail: "Branch reset to \(commitSHA.prefix(7)) (\(mode.displayName) mode)"
                )
            )
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationMessage(
                    type: .error,
                    message: "Reset failed",
                    detail: error.localizedDescription
                )
            )
            
            return false
        }
    }
}

// MARK: - Quick Reset Actions

struct QuickResetMenu: View {
    let commit: Commit
    @State private var showResetSheet = false
    
    var body: some View {
        Menu {
            Button {
                showResetSheet = true
            } label: {
                Label("Reset Branch to Here...", systemImage: "arrow.uturn.backward.circle")
            }
            
            Divider()
            
            Button {
                Task {
                    await quickReset(mode: .soft)
                }
            } label: {
                Label("Soft Reset (keep changes staged)", systemImage: "doc.text.fill")
            }
            
            Button {
                Task {
                    await quickReset(mode: .mixed)
                }
            } label: {
                Label("Mixed Reset (keep changes unstaged)", systemImage: "rectangle.stack.fill")
            }
            
            Button(role: .destructive) {
                Task {
                    await quickReset(mode: .hard)
                }
            } label: {
                Label("Hard Reset (discard all changes)", systemImage: "trash.fill")
            }
        } label: {
            Image(systemName: "arrow.uturn.backward.circle")
                .foregroundColor(AppTheme.warning)
        }
        .menuStyle(.borderlessButton)
        .help("Reset branch")
        .sheet(isPresented: $showResetSheet) {
            ResetView(targetCommit: commit)
        }
    }
    
    private func quickReset(mode: ResetMode) async {
        // TODO: Implement quick reset without showing sheet
    }
}
