import SwiftUI

// MARK: - Git Hooks View

struct GitHooksView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GitHooksViewModel()
    @State private var selectedHook: GitHook?
    @State private var showCreateSheet = false
    
    var body: some View {
        HSplitView {
            // Hooks list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Git Hooks")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Spacer()
                    
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                
                // Hooks list
                if viewModel.hooks.isEmpty {
                    emptyView
                } else {
                    List(viewModel.hooks, selection: $selectedHook) { hook in
                        HookRow(hook: hook)
                            .tag(hook)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // Hook editor
            if let hook = selectedHook {
                HookEditorView(hook: hook, viewModel: viewModel)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Select a hook to edit")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if let path = appState.currentRepository?.path {
                await viewModel.loadHooks(at: path)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateHookSheet(viewModel: viewModel)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No hooks configured")
                .font(.system(size: 14, weight: .medium))
            
            Text("Git hooks run scripts at specific points in the Git workflow")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Hook") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Hook Row

struct HookRow: View {
    let hook: GitHook
    
    var body: some View {
        HStack {
            Image(systemName: hook.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(hook.isEnabled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hook.name)
                    .font(.system(size: 12, weight: .medium))
                
                Text(hook.type.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hook Editor

struct HookEditorView: View {
    let hook: GitHook
    @ObservedObject var viewModel: GitHooksViewModel
    @State private var content: String = ""
    @State private var hasChanges = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hook.name)
                        .font(.system(size: 16, weight: .semibold))
                    Text(hook.type.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("Enabled", isOn: Binding(
                    get: { hook.isEnabled },
                    set: { newValue in
                        Task { await viewModel.toggleHook(hook, enabled: newValue) }
                    }
                ))
                
                Button {
                    Task { await viewModel.saveHook(hook, content: content) }
                    hasChanges = false
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Description
            Text(hook.type.helpText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
            
            // Editor
            TextEditor(text: $content)
                .font(.system(size: 12, design: .monospaced))
                .onChange(of: content) { _, _ in
                    hasChanges = true
                }
            
            // Actions
            HStack {
                Button {
                    content = hook.type.template
                } label: {
                    Label("Insert Template", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(role: .destructive) {
                    Task { await viewModel.deleteHook(hook) }
                } label: {
                    Label("Delete Hook", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .onAppear {
            content = hook.content
            hasChanges = false
        }
        .onChange(of: hook.id) { _, _ in
            content = hook.content
            hasChanges = false
        }
    }
}

// MARK: - Create Hook Sheet

struct CreateHookSheet: View {
    @ObservedObject var viewModel: GitHooksViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: GitHookType = .preCommit
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create Git Hook")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Hook Type")
                    .font(.system(size: 12, weight: .medium))
                
                Picker("", selection: $selectedType) {
                    ForEach(GitHookType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                
                Text(selectedType.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Button("Create") {
                    Task {
                        await viewModel.createHook(type: selectedType)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

// MARK: - Models

struct GitHook: Identifiable, Hashable {
    let id: String
    let name: String
    let type: GitHookType
    var content: String
    var isEnabled: Bool
    let path: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: GitHook, rhs: GitHook) -> Bool {
        lhs.id == rhs.id
    }
}

enum GitHookType: String, CaseIterable {
    case preCommit = "pre-commit"
    case prepareCommitMsg = "prepare-commit-msg"
    case commitMsg = "commit-msg"
    case postCommit = "post-commit"
    case preRebase = "pre-rebase"
    case postCheckout = "post-checkout"
    case postMerge = "post-merge"
    case prePush = "pre-push"
    case preReceive = "pre-receive"
    case update = "update"
    case postReceive = "post-receive"
    
    var description: String {
        switch self {
        case .preCommit: return "Run before commit is created"
        case .prepareCommitMsg: return "Modify default commit message"
        case .commitMsg: return "Validate commit message"
        case .postCommit: return "Run after commit is created"
        case .preRebase: return "Run before rebase starts"
        case .postCheckout: return "Run after checkout completes"
        case .postMerge: return "Run after merge completes"
        case .prePush: return "Run before push to remote"
        case .preReceive: return "Server-side: before accepting push"
        case .update: return "Server-side: before updating ref"
        case .postReceive: return "Server-side: after push completes"
        }
    }
    
    var helpText: String {
        switch self {
        case .preCommit:
            return "This hook runs before the commit is created. Exit with non-zero to abort the commit. Common uses: run linters, tests, check for debug statements."
        case .prepareCommitMsg:
            return "This hook can modify the default commit message before the editor opens. Receives the commit message file path as argument."
        case .commitMsg:
            return "This hook validates the commit message. Exit with non-zero to abort. Receives the commit message file path as argument."
        case .postCommit:
            return "This hook runs after the commit is created. Cannot affect the commit outcome. Common uses: notifications, CI triggers."
        case .preRebase:
            return "This hook runs before rebase starts. Exit with non-zero to abort. Receives upstream and branch as arguments."
        case .postCheckout:
            return "This hook runs after checkout completes. Receives previous HEAD, new HEAD, and branch flag as arguments."
        case .postMerge:
            return "This hook runs after merge completes. Receives a flag indicating if it was a squash merge."
        case .prePush:
            return "This hook runs before push to remote. Exit with non-zero to abort. Receives remote name and URL as arguments."
        default:
            return "Server-side hook for managing push operations."
        }
    }
    
    var template: String {
        switch self {
        case .preCommit:
            return """
            #!/bin/sh
            # Pre-commit hook
            
            # Run linter
            # npm run lint
            
            # Run tests
            # npm test
            
            # Check for debug statements
            # if git diff --cached | grep -E 'console\\.log|debugger' > /dev/null; then
            #     echo "Error: Debug statements found in staged files"
            #     exit 1
            # fi
            
            exit 0
            """
        case .commitMsg:
            return """
            #!/bin/sh
            # Commit message validation hook
            
            COMMIT_MSG_FILE=$1
            COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")
            
            # Enforce conventional commits
            # if ! echo "$COMMIT_MSG" | grep -qE '^(feat|fix|docs|style|refactor|test|chore)(\\(.+\\))?: .+'; then
            #     echo "Error: Commit message must follow conventional commits format"
            #     echo "Example: feat(auth): add login functionality"
            #     exit 1
            # fi
            
            exit 0
            """
        case .prePush:
            return """
            #!/bin/sh
            # Pre-push hook
            
            REMOTE="$1"
            URL="$2"
            
            # Run tests before push
            # npm test
            # if [ $? -ne 0 ]; then
            #     echo "Tests failed. Push aborted."
            #     exit 1
            # fi
            
            exit 0
            """
        default:
            return """
            #!/bin/sh
            # \(rawValue) hook
            
            # Add your hook logic here
            
            exit 0
            """
        }
    }
}

// MARK: - View Model

@MainActor
class GitHooksViewModel: ObservableObject {
    @Published var hooks: [GitHook] = []
    @Published var repoPath: String = ""
    
    func loadHooks(at path: String) async {
        repoPath = path
        let hooksDir = (path as NSString).appendingPathComponent(".git/hooks")
        
        guard FileManager.default.fileExists(atPath: hooksDir) else {
            hooks = []
            return
        }
        
        var loadedHooks: [GitHook] = []
        
        for hookType in GitHookType.allCases {
            let hookPath = (hooksDir as NSString).appendingPathComponent(hookType.rawValue)
            let samplePath = hookPath + ".sample"
            
            if FileManager.default.fileExists(atPath: hookPath) {
                let content = (try? String(contentsOfFile: hookPath)) ?? ""
                let isExecutable = FileManager.default.isExecutableFile(atPath: hookPath)
                
                loadedHooks.append(GitHook(
                    id: hookType.rawValue,
                    name: hookType.rawValue,
                    type: hookType,
                    content: content,
                    isEnabled: isExecutable,
                    path: hookPath
                ))
            } else if FileManager.default.fileExists(atPath: samplePath) {
                let content = (try? String(contentsOfFile: samplePath)) ?? ""
                
                loadedHooks.append(GitHook(
                    id: hookType.rawValue + ".sample",
                    name: hookType.rawValue + " (sample)",
                    type: hookType,
                    content: content,
                    isEnabled: false,
                    path: samplePath
                ))
            }
        }
        
        hooks = loadedHooks
    }
    
    func createHook(type: GitHookType) async {
        let hooksDir = (repoPath as NSString).appendingPathComponent(".git/hooks")
        let hookPath = (hooksDir as NSString).appendingPathComponent(type.rawValue)
        
        // Create hooks directory if needed
        try? FileManager.default.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
        
        // Write template
        try? type.template.write(toFile: hookPath, atomically: true, encoding: .utf8)
        
        // Make executable
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
        
        await loadHooks(at: repoPath)
    }
    
    func saveHook(_ hook: GitHook, content: String) async {
        try? content.write(toFile: hook.path, atomically: true, encoding: .utf8)
        
        // Ensure it's executable
        if hook.isEnabled {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
        }
        
        await loadHooks(at: repoPath)
    }
    
    func toggleHook(_ hook: GitHook, enabled: Bool) async {
        if enabled {
            // Make executable
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
        } else {
            // Remove execute permission
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: hook.path)
        }
        
        await loadHooks(at: repoPath)
    }
    
    func deleteHook(_ hook: GitHook) async {
        try? FileManager.default.removeItem(atPath: hook.path)
        await loadHooks(at: repoPath)
    }
}
