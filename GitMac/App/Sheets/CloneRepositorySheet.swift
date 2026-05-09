//
//  CloneRepositorySheet.swift
//  GitMac
//
//  Sheet for cloning a remote repository
//

import SwiftUI

struct CloneRepositorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState
    @State private var repoURL = ""
    @State private var destinationPath = ""
    @State private var isCloning = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Clone Repository")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                    DSTextField(placeholder: "https://github.com/user/repo.git", text: $repoURL)
                        .padding(10)
                        .background(AppTheme.backgroundTertiary)
                        .clipShape(.rect(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Destination")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                    HStack {
                        DSTextField(placeholder: "Select destination folder", text: $destinationPath)
                            .padding(10)
                            .background(AppTheme.backgroundTertiary)
                            .clipShape(.rect(cornerRadius: 6))

                        Button("Browse") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true

                            panel.begin { response in
                                if response == .OK {
                                    Task { @MainActor in
                                        destinationPath = panel.url?.path ?? ""
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Clone") {
                    Task {
                        isCloning = true
                        await appState.cloneRepository(from: repoURL, to: destinationPath)
                        isCloning = false
                        if appState.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(repoURL.isEmpty || destinationPath.isEmpty || isCloning)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(AppTheme.backgroundSecondary)
    }
}
