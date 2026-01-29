import SwiftUI
import AppKit

// Note: CommitFile model is defined in App/Models/CommitFile.swift

// MARK: - Commit File Row
struct CommitFileRow: View {
    let file: CommitFile
    var repositoryPath: String = ""
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var showPreview = false

    private var filename: String {
        (file.path as NSString).lastPathComponent
    }

    private var canPreview: Bool {
        FilePreviewHelper.canPreview(filename: file.path)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: file.status.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(file.status.color)
                .frame(width: 16)

            // File icon
            Image(systemName: "doc.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.accent)

            // Filename
            Text(filename)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Additions/Deletions
            if file.additions > 0 {
                Text("+\(file.additions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.success)
            }
            if file.deletions > 0 {
                Text("-\(file.deletions)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.error)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            // Preview and Copy Content (for text files)
            if canPreview {
                Button {
                    showPreview = true
                } label: {
                    Label("Preview File", systemImage: "eye")
                }

                Button {
                    copyFileContent()
                } label: {
                    Label("Copy Content", systemImage: "doc.on.clipboard")
                }

                Divider()
            }

            // Copy path options
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filename, forType: .string)
            } label: {
                Label("Copy Filename", systemImage: "doc.text")
            }

            Divider()

            // Open/Reveal options
            Button {
                let fullPath = (repositoryPath as NSString).appendingPathComponent(file.path)
                NSWorkspace.shared.selectFile(fullPath, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                let fullPath = (repositoryPath as NSString).appendingPathComponent(file.path)
                NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
            } label: {
                Label("Open with Default App", systemImage: "arrow.up.forward.app")
            }
        }
        .sheet(isPresented: $showPreview) {
            FilePreviewView(filePath: file.path, repositoryPath: repositoryPath)
        }
    }

    private func copyFileContent() {
        let fullPath = (repositoryPath as NSString).appendingPathComponent(file.path)
        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        }
    }
}

// MARK: - Author Avatar
struct AuthorAvatar: View {
    let name: String
    let size: CGFloat

    var color: Color {
        let colors = AppTheme.laneColors
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Commit Section
struct CommitSection: View {
    @Binding var commitMessage: String
    let canCommit: Bool
    let repositoryPath: String?
    let onCommit: () -> Void
    var onCommitPushPR: (() -> Void)? = nil  // Optional: Commit + Push + Create PR

    @State private var linkedTaigaRef: String?
    @State private var linkedTaigaSubject: String?
    @State private var showStatusPicker = false
    @State private var isGeneratingAI = false
    @State private var aiError: String?

    var body: some View {
        VStack(spacing: 8) {
            // Linked Taiga ticket indicator
            if let ref = linkedTaigaRef {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.success)

                    Text(ref)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.success)

                    if let subject = linkedTaigaSubject {
                        Text(subject)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status picker
                    Menu {
                        Button("No status change") {
                            updateCommitWithTaiga(ref: ref, status: nil)
                        }
                        Divider()
                        Button("#new") { updateCommitWithTaiga(ref: ref, status: "new") }
                        Button("#in-progress") { updateCommitWithTaiga(ref: ref, status: "in-progress") }
                        Button("#ready-for-test") { updateCommitWithTaiga(ref: ref, status: "ready-for-test") }
                        Button("#closed") { updateCommitWithTaiga(ref: ref, status: "closed") }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                    .help("Change status with commit")

                    // Remove link
                    Button {
                        removeTaigaLink()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Remove Taiga link")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(AppTheme.success.opacity(0.1))
                .clipShape(.rect(cornerRadius: 4))
            }

            ZStack(alignment: .topLeading) {
                if commitMessage.isEmpty {
                    Text("Commit message...")
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $commitMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 60, maxHeight: 100)

                // AI Generation Button
                HStack {
                    if let error = aiError {
                        Text(error)
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.error)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        generateAICommitMessage()
                    } label: {
                        if isGeneratingAI {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.accent)
                                .padding(6)
                                .background(AppTheme.background.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .disabled(isGeneratingAI)
                    .help("Generate commit message with AI")
                }
            }
            .padding(4)
            .background(AppTheme.backgroundTertiary)
            .clipShape(.rect(cornerRadius: 6))

            // Commit buttons row
            HStack(spacing: 8) {
                // Standard Commit button
                Button(action: onCommit) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Commit")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canCommit && !commitMessage.isEmpty ? AppTheme.success : AppTheme.backgroundTertiary)
                    .foregroundStyle(canCommit && !commitMessage.isEmpty ? AppTheme.textPrimary : AppTheme.textMuted)
                    .clipShape(.rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!canCommit || commitMessage.isEmpty)

                // Commit + Push + PR button
                if let onCommitPushPR = onCommitPushPR {
                    Button(action: onCommitPushPR) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Commit & PR")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(canCommit && !commitMessage.isEmpty ? AppTheme.accent : AppTheme.backgroundTertiary)
                        .foregroundStyle(canCommit && !commitMessage.isEmpty ? .white : AppTheme.textMuted)
                        .clipShape(.rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCommit || commitMessage.isEmpty)
                    .help("Commit, Push, and Create Pull Request")
                }
            }
        }
        .padding(12)
        .background(AppTheme.backgroundSecondary)
        .onReceive(NotificationCenter.default.publisher(for: .insertTaigaRef)) { notification in
            if let userInfo = notification.userInfo,
               let ref = userInfo["ref"] as? String {
                linkedTaigaRef = ref
                linkedTaigaSubject = userInfo["subject"] as? String

                // Insert at the end of commit message
                if !commitMessage.contains(ref) {
                    if commitMessage.isEmpty {
                        commitMessage = "\(ref) "
                    } else {
                        commitMessage += " \(ref)"
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .insertPlannerRef)) { notification in
            if let userInfo = notification.userInfo,
               let title = userInfo["title"] as? String {

                // Insert title at the end of commit message
                if commitMessage.isEmpty {
                    commitMessage = title
                } else {
                    commitMessage += "\n\n" + title
                }
            }
        }
    }

    private func updateCommitWithTaiga(ref: String, status: String?) {
        // Remove any existing TG reference with status
        let pattern = "\(ref)(\\s+#[a-z-]+)?"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(commitMessage.startIndex..., in: commitMessage)
            commitMessage = regex.stringByReplacingMatches(in: commitMessage, range: range, withTemplate: "")
            commitMessage = commitMessage.trimmingCharacters(in: .whitespaces)
        }

        // Add new reference with status
        let newRef = status != nil ? "\(ref) #\(status!)" : ref
        if commitMessage.isEmpty {
            commitMessage = "\(newRef) "
        } else {
            commitMessage += " \(newRef)"
        }
    }

    private func removeTaigaLink() {
        if let ref = linkedTaigaRef {
            // Remove TG reference from message
            let pattern = "\(ref)(\\s+#[a-z-]+)?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(commitMessage.startIndex..., in: commitMessage)
                commitMessage = regex.stringByReplacingMatches(in: commitMessage, range: range, withTemplate: "")
                commitMessage = commitMessage.trimmingCharacters(in: .whitespaces)
            }
        }
        linkedTaigaRef = nil
        linkedTaigaSubject = nil
    }

    private func generateAICommitMessage() {
        Task {
            await MainActor.run {
                isGeneratingAI = true
                aiError = nil
            }

            guard let path = repositoryPath else {
                await MainActor.run {
                    isGeneratingAI = false
                    aiError = "No repository selected"
                }
                return
            }

            do {
                // First check if there are staged changes using git diff --cached --stat
                let shell = ShellExecutor()
                let statResult = await shell.execute("git", arguments: ["diff", "--cached", "--stat"], workingDirectory: path)

                if statResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await MainActor.run {
                        isGeneratingAI = false
                        aiError = "No staged changes"
                    }
                    return
                }

                // Get staged diff with limited output for AI
                let diffResult = await shell.execute(
                    "git",
                    arguments: ["diff", "--cached", "-U2", "--no-color"],  // -U2 = less context
                    workingDirectory: path
                )

                let diff = diffResult.stdout
                if diff.isEmpty {
                    await MainActor.run {
                        isGeneratingAI = false
                        aiError = "No staged changes"
                    }
                    return
                }

                // Generate message using shared instance
                let message = try await AIService.shared.generateCommitMessage(diff: diff)

                await MainActor.run {
                    isGeneratingAI = false
                    if commitMessage.isEmpty {
                        commitMessage = message
                    } else {
                        commitMessage = message + "\n\n" + commitMessage
                    }
                }
            } catch {
                await MainActor.run {
                    isGeneratingAI = false
                    if let err = error as? AIError {
                        switch err {
                        case .noAPIKey:
                            self.aiError = "No API key configured"
                        case .invalidProvider:
                            self.aiError = "Invalid AI provider"
                        case .requestFailed(let msg):
                            self.aiError = msg
                        case .invalidResponse:
                            self.aiError = "Invalid AI response"
                        case .connectionError(let msg):
                            self.aiError = msg
                        }
                    } else {
                        self.aiError = error.localizedDescription
                    }
                }
                print("Error generating AI commit message: \(error)")
            }
        }
    }
}
