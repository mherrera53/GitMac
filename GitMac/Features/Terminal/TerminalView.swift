import SwiftUI
import AppKit

/// Integrated terminal emulator
struct TerminalView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = TerminalViewModel()
    @State private var commandInput = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.green)

                Text("Terminal")
                    .fontWeight(.medium)

                if let path = appState.currentRepository?.path {
                    Text("- \(path)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear terminal")

                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.circle")
                }
                .buttonStyle(.borderless)
                .help("Stop current process")
                .disabled(!viewModel.isRunning)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.lines) { line in
                            TerminalLineView(line: line)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(Color(hex: "1E1E1E"))
                .onChange(of: viewModel.lines.count) { _, _ in
                    if let lastLine = viewModel.lines.last {
                        withAnimation {
                            proxy.scrollTo(lastLine.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Command input
            HStack(spacing: 8) {
                Text(viewModel.prompt)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)

                TextField("", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }
                    .onKeyPress(.upArrow) {
                        commandInput = viewModel.previousCommand()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        commandInput = viewModel.nextCommand()
                        return .handled
                    }

                if viewModel.isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "1E1E1E"))
        }
        .onAppear {
            if let path = appState.currentRepository?.path {
                viewModel.setWorkingDirectory(path)
            }
            isInputFocused = true
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                viewModel.setWorkingDirectory(path)
            }
        }
    }

    private func executeCommand() {
        guard !commandInput.isEmpty else { return }

        Task {
            await viewModel.execute(commandInput)
            commandInput = ""
        }
    }
}

// MARK: - View Model

@MainActor
class TerminalViewModel: ObservableObject {
    @Published var lines: [TerminalLine] = []
    @Published var isRunning = false
    @Published var prompt = "$ "

    private var workingDirectory: String = ""
    private var commandHistory: [String] = []
    private var historyIndex: Int = -1
    private var currentProcess: Process?
    private let shellExecutor = ShellExecutor()

    init() {
        // Welcome message
        addLine("Welcome to GitMac Terminal", type: .system)
        addLine("Type 'help' for available commands", type: .system)
        addLine("", type: .output)
    }

    func setWorkingDirectory(_ path: String) {
        workingDirectory = path
        updatePrompt()
        addLine("Changed directory to: \(path)", type: .system)
    }

    func execute(_ command: String) async {
        // Add to history
        commandHistory.append(command)
        historyIndex = commandHistory.count

        // Show command in output
        addLine("\(prompt)\(command)", type: .command)

        // Handle built-in commands
        if handleBuiltInCommand(command) {
            return
        }

        isRunning = true

        // Execute command
        let result = await shellExecutor.execute(
            "bash",
            arguments: ["-c", command],
            workingDirectory: workingDirectory
        )

        // Process output
        if !result.stdout.isEmpty {
            for line in result.stdout.components(separatedBy: .newlines) {
                if !line.isEmpty {
                    addLine(line, type: .output)
                }
            }
        }

        if !result.stderr.isEmpty {
            for line in result.stderr.components(separatedBy: .newlines) {
                if !line.isEmpty {
                    addLine(line, type: .error)
                }
            }
        }

        if result.exitCode != 0 && result.stdout.isEmpty && result.stderr.isEmpty {
            addLine("Command exited with code \(result.exitCode)", type: .error)
        }

        isRunning = false
    }

    func clear() {
        lines.removeAll()
    }

    func stop() {
        currentProcess?.terminate()
        isRunning = false
        addLine("^C", type: .system)
    }

    func previousCommand() -> String {
        guard !commandHistory.isEmpty else { return "" }

        if historyIndex > 0 {
            historyIndex -= 1
        }
        return commandHistory[historyIndex]
    }

    func nextCommand() -> String {
        guard !commandHistory.isEmpty else { return "" }

        if historyIndex < commandHistory.count - 1 {
            historyIndex += 1
            return commandHistory[historyIndex]
        } else {
            historyIndex = commandHistory.count
            return ""
        }
    }

    // Git shortcuts mapping
    private let gitShortcuts: [String: String] = [
        "gs": "git status",
        "ga": "git add",
        "gc": "git commit",
        "gp": "git push",
        "gl": "git pull",
        "gco": "git checkout",
        "gb": "git branch",
        "gd": "git diff",
        "gf": "git fetch",
        "gm": "git merge",
        "gr": "git rebase",
        "gst": "git stash",
        "glog": "git log --oneline --graph",
    ]

    // GitHub CLI (gh) shortcuts mapping
    private let ghShortcuts: [String: String] = [
        // Pull Requests
        "ghpr": "gh pr list",
        "ghprc": "gh pr create",
        "ghprv": "gh pr view",
        "ghprm": "gh pr merge",
        "ghprd": "gh pr diff",
        "ghprs": "gh pr status",
        "ghprco": "gh pr checkout",
        "ghpre": "gh pr edit",
        "ghprr": "gh pr review",

        // Issues
        "ghis": "gh issue list",
        "ghisc": "gh issue create",
        "ghisv": "gh issue view",
        "ghiss": "gh issue status",
        "ghise": "gh issue edit",
        "ghiscl": "gh issue close",

        // Repository
        "ghrepo": "gh repo view",
        "ghrepoc": "gh repo clone",
        "ghrepof": "gh repo fork",
        "ghrepos": "gh repo sync",

        // Workflow / Actions
        "ghrun": "gh run list",
        "ghrunv": "gh run view",
        "ghrunw": "gh run watch",
        "ghwf": "gh workflow list",
        "ghwfr": "gh workflow run",

        // Other
        "ghauth": "gh auth status",
        "ghhelp": "gh help",
        "ghapi": "gh api",
        "ghgist": "gh gist list",
    ]

    private func handleBuiltInCommand(_ command: String) -> Bool {
        let parts = command.split(separator: " ")
        guard let cmd = parts.first else { return false }
        let cmdString = String(cmd)
        let args = parts.dropFirst().joined(separator: " ")

        switch cmdString {
        case "clear", "cls":
            clear()
            return true

        case "cd":
            if parts.count > 1 {
                let path = parts.dropFirst().joined(separator: " ")
                let newPath: String
                if path.hasPrefix("/") {
                    newPath = path
                } else if path == "~" {
                    newPath = NSHomeDirectory()
                } else {
                    newPath = (workingDirectory as NSString).appendingPathComponent(path)
                }

                if FileManager.default.fileExists(atPath: newPath) {
                    workingDirectory = newPath
                    updatePrompt()
                    addLine("", type: .output)
                } else {
                    addLine("cd: no such file or directory: \(path)", type: .error)
                }
            } else {
                workingDirectory = NSHomeDirectory()
                updatePrompt()
            }
            return true

        case "help":
            showHelp()
            return true

        case "history":
            for (index, cmd) in commandHistory.enumerated() {
                addLine("  \(index + 1)  \(cmd)", type: .output)
            }
            return true

        default:
            // Check for git shortcuts
            if let expanded = gitShortcuts[cmdString] {
                let fullCommand = args.isEmpty ? expanded : "\(expanded) \(args)"
                Task { await execute(fullCommand) }
                return true
            }

            // Check for gh shortcuts
            if let expanded = ghShortcuts[cmdString] {
                let fullCommand = args.isEmpty ? expanded : "\(expanded) \(args)"
                Task { await execute(fullCommand) }
                return true
            }

            return false
        }
    }

    private func showHelp() {
        let helpText = """
        GitMac Terminal - Available Commands:

        Built-in:
          clear, cls    Clear the terminal
          cd <path>     Change directory
          history       Show command history
          help          Show this help

        Git shortcuts:
          gs            git status
          ga            git add
          gc            git commit
          gp            git push
          gl            git pull
          gco           git checkout
          gb            git branch
          gd            git diff
          gf            git fetch
          gm            git merge
          gr            git rebase
          gst           git stash
          glog          git log --oneline --graph

        GitHub CLI (gh) shortcuts:
          Pull Requests:
            ghpr        gh pr list
            ghprc       gh pr create
            ghprv       gh pr view
            ghprm       gh pr merge
            ghprd       gh pr diff
            ghprs       gh pr status
            ghprco      gh pr checkout

          Issues:
            ghis        gh issue list
            ghisc       gh issue create
            ghisv       gh issue view
            ghiss       gh issue status

          Repository:
            ghrepo      gh repo view
            ghrepoc     gh repo clone
            ghrepof     gh repo fork

          Workflows:
            ghrun       gh run list
            ghrunv      gh run view
            ghwf        gh workflow list

          Other:
            ghauth      gh auth status
            ghhelp      gh help

        Use arrow keys to navigate command history.
        Tip: Install GitHub CLI with 'brew install gh'
        """

        for line in helpText.components(separatedBy: .newlines) {
            addLine(line, type: .output)
        }
    }

    private func updatePrompt() {
        let dirName = (workingDirectory as NSString).lastPathComponent
        prompt = "\(dirName) $ "
    }

    private func addLine(_ text: String, type: TerminalLineType) {
        lines.append(TerminalLine(text: text, type: type))
    }
}

// MARK: - Terminal Line

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let type: TerminalLineType
    let timestamp = Date()
}

enum TerminalLineType {
    case command
    case output
    case error
    case system
}

struct TerminalLineView: View {
    let line: TerminalLine

    var body: some View {
        Text(attributedText)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
    }

    var attributedText: AttributedString {
        var text = AttributedString(line.text)

        switch line.type {
        case .command:
            text.foregroundColor = .white
        case .output:
            text.foregroundColor = Color(hex: "CCCCCC")
        case .error:
            text.foregroundColor = .red
        case .system:
            text.foregroundColor = Color(hex: "6A9955")
        }

        return text
    }
}

// Alternative simpler terminal line view
struct TerminalLine_View: View {
    let line: TerminalLine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(parseANSI(line.text))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var textColor: Color {
        switch line.type {
        case .command: return .white
        case .output: return Color(hex: "CCCCCC")
        case .error: return Color(hex: "F14C4C")
        case .system: return Color(hex: "6A9955")
        }
    }

    // Basic ANSI color parsing
    func parseANSI(_ text: String) -> AttributedString {
        // For now, just strip ANSI codes
        let pattern = #"\x1B\[[0-9;]*m"#
        let stripped = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return AttributedString(stripped)
    }
}

// MARK: - Git & GitHub CLI Command Autocomplete

struct GitCommandSuggestions {
    static let commands: [String: [String]] = [
        // Git commands
        "git": ["status", "add", "commit", "push", "pull", "fetch", "branch", "checkout", "merge", "rebase", "stash", "log", "diff", "reset", "revert", "tag", "remote", "clone", "init", "worktree"],
        "git add": ["-A", "-p", "--all", "."],
        "git commit": ["-m", "-a", "--amend", "--no-edit"],
        "git push": ["-u", "--force", "--force-with-lease", "origin"],
        "git pull": ["--rebase", "origin"],
        "git checkout": ["-b"],
        "git branch": ["-d", "-D", "-m", "-a"],
        "git stash": ["push", "pop", "apply", "list", "drop", "clear"],
        "git reset": ["--soft", "--hard", "--mixed", "HEAD~1"],
        "git log": ["--oneline", "--graph", "--all", "-n"],
        "git worktree": ["add", "list", "remove", "prune", "lock", "unlock"],

        // GitHub CLI commands
        "gh": ["pr", "issue", "repo", "run", "workflow", "auth", "config", "api", "gist", "release", "ssh-key", "secret", "codespace", "extension"],
        "gh pr": ["list", "create", "view", "merge", "diff", "status", "checkout", "edit", "review", "close", "reopen", "ready", "comment"],
        "gh issue": ["list", "create", "view", "status", "edit", "close", "reopen", "comment", "delete", "transfer"],
        "gh repo": ["view", "clone", "fork", "create", "sync", "archive", "delete", "edit", "rename"],
        "gh run": ["list", "view", "watch", "download", "cancel", "rerun"],
        "gh workflow": ["list", "view", "run", "enable", "disable"],
        "gh auth": ["status", "login", "logout", "refresh", "token"],
        "gh gist": ["list", "create", "view", "edit", "delete", "clone"],
        "gh release": ["list", "create", "view", "edit", "delete", "download", "upload"],
    ]

    static func suggestions(for input: String) -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Find matching command prefix
        for (prefix, suggestions) in commands {
            if trimmed == prefix || trimmed.hasPrefix(prefix + " ") {
                let remaining = trimmed.replacingOccurrences(of: prefix + " ", with: "")
                return suggestions.filter { $0.hasPrefix(remaining) }
            }
        }

        // Top-level git commands
        if trimmed.hasPrefix("git ") {
            let subcommand = trimmed.replacingOccurrences(of: "git ", with: "")
            return commands["git"]?.filter { $0.hasPrefix(subcommand) } ?? []
        }

        // Top-level gh commands
        if trimmed.hasPrefix("gh ") {
            let subcommand = trimmed.replacingOccurrences(of: "gh ", with: "")
            return commands["gh"]?.filter { $0.hasPrefix(subcommand) } ?? []
        }

        return []
    }
}

// #Preview {
//     TerminalView()
//         .environmentObject(AppState())
//         .frame(width: 600, height: 400)
// }
