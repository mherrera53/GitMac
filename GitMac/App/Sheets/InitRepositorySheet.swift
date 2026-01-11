//
//  InitRepositorySheet.swift
//  GitMac
//
//  Sheet for initializing a new git repository
//

import SwiftUI

struct InitRepositorySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var localPath: String = NSHomeDirectory() + "/Documents"
    @State private var repositoryName: String = ""
    @State private var initialBranch: String = "main"
    @State private var createReadme: Bool = true
    @State private var createGitignore: Bool = true
    @State private var gitignoreTemplate: String = "macOS"
    @State private var isCreating: Bool = false
    @State private var error: String?

    private let gitignoreTemplates = ["None", "macOS", "Swift", "Python", "Node", "Java", "Go"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(DesignTokens.Typography.iconXL)
                    .foregroundColor(AppTheme.success)
                Text("Initialize Repository")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Repository Name")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        DSTextField(placeholder: "my-project", text: $repositoryName)
                            .disabled(isCreating)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Location")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            DSTextField(placeholder: "/path/to/parent/directory", text: $localPath)
                                .disabled(isCreating)
                            Button("Browse") { selectLocalPath() }
                                .disabled(isCreating)
                        }
                        if !repositoryName.isEmpty {
                            Text("Will create: \(localPath)/\(repositoryName)")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Initial Branch")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        DSTextField(placeholder: "main", text: $initialBranch)
                            .disabled(isCreating)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Initial Files")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textSecondary)
                        Toggle("Create README.md", isOn: $createReadme)
                            .disabled(isCreating)
                        Toggle("Create .gitignore", isOn: $createGitignore)
                            .disabled(isCreating)
                        if createGitignore {
                            Picker("Template", selection: $gitignoreTemplate) {
                                ForEach(gitignoreTemplates, id: \.self) { template in
                                    Text(template).tag(template)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(isCreating)
                        }
                    }

                    if let error = error {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.error)
                            Text(error)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.error)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(AppTheme.error.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.md)
                    }

                    if isCreating {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView().scaleEffect(0.8)
                            Text("Creating repository...")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                    .disabled(isCreating)
                Spacer()
                Button("Initialize") { initRepository() }
                    .keyboardShortcut(.return)
                    .disabled(repositoryName.isEmpty || localPath.isEmpty || isCreating)
                    .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 500, height: 550)
        .background(AppTheme.background)
    }

    private func selectLocalPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "Select parent directory"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            localPath = url.path
        }
    }

    private func initRepository() {
        guard !repositoryName.isEmpty else { return }
        isCreating = true
        error = nil
        Task {
            do {
                let repoPath = "\(localPath)/\(repositoryName)"
                try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
                let initProcess = Process()
                initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                initProcess.arguments = ["init", "-b", initialBranch]
                initProcess.currentDirectoryURL = URL(fileURLWithPath: repoPath)
                try initProcess.run()
                initProcess.waitUntilExit()
                if createReadme {
                    try "# \(repositoryName)\n\nA new repository.\n".write(toFile: "\(repoPath)/README.md", atomically: true, encoding: .utf8)
                }
                if createGitignore && gitignoreTemplate != "None" {
                    try getGitignoreContent(for: gitignoreTemplate).write(toFile: "\(repoPath)/.gitignore", atomically: true, encoding: .utf8)
                }
                if createReadme || createGitignore {
                    let addProcess = Process()
                    addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    addProcess.arguments = ["add", "."]
                    addProcess.currentDirectoryURL = URL(fileURLWithPath: repoPath)
                    try addProcess.run()
                    addProcess.waitUntilExit()
                    let commitProcess = Process()
                    commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    commitProcess.arguments = ["commit", "-m", "Initial commit"]
                    commitProcess.currentDirectoryURL = URL(fileURLWithPath: repoPath)
                    try commitProcess.run()
                    commitProcess.waitUntilExit()
                }
                await appState.openRepository(at: repoPath)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }

    private func getGitignoreContent(for template: String) -> String {
        switch template {
        case "macOS": return ".DS_Store\n.AppleDouble\n.LSOverride\n._*\n"
        case "Swift": return ".DS_Store\n*.xcodeproj\nxcuserdata/\nDerivedData/\n.build/\n"
        case "Python": return "__pycache__/\n*.py[cod]\n.Python\nvenv/\n.env\n"
        case "Node": return "node_modules/\nnpm-debug.log\n.env\ndist/\n"
        case "Java": return "*.class\n*.jar\ntarget/\nbuild/\n"
        case "Go": return "*.exe\n*.test\n*.out\nvendor/\n"
        default: return ""
        }
    }
}
