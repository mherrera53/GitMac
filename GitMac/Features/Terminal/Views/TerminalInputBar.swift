//
//  TerminalInputBar.swift
//  GitMac
//
//  Smart terminal input bar with AI-powered suggestions
//

import SwiftUI
import AppKit

// MARK: - AI Input Bar (Full Inline Autocomplete)

struct AIInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let workingDirectory: String
    let onSubmit: (String) -> Void

    @StateObject private var suggestions = TerminalSuggestionController()
    @State private var hidesSuggestions = false
    @State private var contextTask: Task<Void, Never>?
    @State private var contextGeneration = UUID()
    @State private var cachedContextPath = ""
    @State private var selectedIndex: Int = 0

    @State private var cachedBranches: [String] = []
    @State private var cachedFiles: [String] = []
    @State private var cachedDirs: [String] = []
    @State private var cachedStagedFiles: [String] = []
    @State private var cachedModifiedFiles: [String] = []
    @State private var lastCacheUpdate: Date = .distantPast

    private static let completions: [String: String] = [
        "gi": "git", "git": "git status", "git s": "git status", "git st": "git status",
        "git a": "git add .", "git ad": "git add .", "git add": "git add .",
        "git aa": "git add --all", "git ap": "git add -p",
        "git c": "git commit -m \"\"", "git co": "git commit -m \"\"",
        "git cm": "git commit -m \"\"", "git ca": "git commit --amend",
        "git can": "git commit --amend --no-edit",
        "git p": "git push", "git pu": "git push", "git pus": "git push",
        "git pf": "git push --force-with-lease",
        "git po": "git push origin", "git pom": "git push origin main",
        "git pl": "git pull", "git pul": "git pull", "git plr": "git pull --rebase",
        "git ch": "git checkout ", "git che": "git checkout ",
        "git chb": "git checkout -b ", "git cb": "git checkout -b ",
        "git sw": "git switch ", "git swc": "git switch -c ",
        "git b": "git branch", "git br": "git branch",
        "git bd": "git branch -d ", "git bD": "git branch -D ",
        "git ba": "git branch -a", "git bv": "git branch -v",
        "git d": "git diff", "git di": "git diff", "git ds": "git diff --staged",
        "git dc": "git diff --cached", "git dh": "git diff HEAD",
        "git l": "git log --oneline", "git lo": "git log --oneline",
        "git lg": "git log --oneline --graph --all", "git ll": "git log --oneline -10",
        "git lp": "git log -p", "git ls": "git log --stat",
        "git f": "git fetch", "git fe": "git fetch", "git fa": "git fetch --all",
        "git m": "git merge ", "git me": "git merge ",
        "git r": "git rebase ", "git re": "git rebase ",
        "git ri": "git rebase -i ", "git rc": "git rebase --continue", "git ra": "git rebase --abort",
        "git sta": "git stash", "git stas": "git stash",
        "git stl": "git stash list", "git stp": "git stash pop",
        "git std": "git stash drop", "git sts": "git stash show -p",
        "git res": "git restore ", "git rss": "git restore --staged ",
        "git rh": "git reset HEAD", "git rhh": "git reset --hard HEAD",
        "git rsh": "git reset --soft HEAD~1",
        "git rem": "git remote -v", "git rema": "git remote add origin ",
        "git cl": "git clean -fd", "git cln": "git clean -fdn",
        "git t": "git tag", "git ta": "git tag -a ",
        "gh": "gh ", "gh p": "gh pr ", "gh pr": "gh pr list",
        "gh prc": "gh pr create", "gh prv": "gh pr view",
        "gh prm": "gh pr merge", "gh prd": "gh pr diff",
        "gh i": "gh issue ", "gh is": "gh issue list",
        "gh ic": "gh issue create", "gh iv": "gh issue view",
        "gh r": "gh repo ", "gh rv": "gh repo view",
        "gh rc": "gh repo clone ", "gh rf": "gh repo fork",
        "ls": "ls -la", "ll": "ls -la", "la": "ls -la", "lh": "ls -lah", "lt": "ls -lt",
        "cd": "cd ", "cd.": "cd ..", "cd..": "cd ..",
        "mk": "mkdir ", "mkd": "mkdir ", "mkp": "mkdir -p ",
        "rm": "rm -rf ", "cp": "cp -r ", "mv": "mv ",
        "cat": "cat ", "vim": "vim ", "nano": "nano ", "code": "code ",
        "touch": "touch ", "chmod": "chmod ",
        "find": "find . -name \"\"", "grep": "grep -r \"\" .",
        "rg": "rg \"\"", "fd": "fd \"\"", "ag": "ag \"\"",
        "npm": "npm install", "npm i": "npm install",
        "npm r": "npm run ", "npm t": "npm test", "npm s": "npm start", "npm b": "npm run build",
        "yarn": "yarn install", "yarn a": "yarn add ", "yarn d": "yarn dev", "yarn b": "yarn build",
        "pnpm": "pnpm install", "pnpm a": "pnpm add ",
        "pip": "pip install ", "pip3": "pip3 install ",
        "cargo": "cargo ", "cargo b": "cargo build", "cargo r": "cargo run", "cargo t": "cargo test",
        "docker": "docker ", "docker p": "docker ps", "docker pa": "docker ps -a",
        "docker i": "docker images", "docker b": "docker build -t ", "docker r": "docker run ",
        "docker c": "docker-compose ", "docker cu": "docker-compose up", "docker cd": "docker-compose down",
        "ps": "ps aux", "kill": "kill -9 ", "top": "htop", "df": "df -h", "du": "du -sh ",
        "which": "which ", "whe": "where ",
        "xc": "xcodebuild ", "xcb": "xcodebuild build", "xct": "xcodebuild test", "xcr": "xcodebuild clean",
        "swift": "swift ", "swiftb": "swift build", "swiftt": "swift test", "swiftr": "swift run",
        "pod": "pod install", "podu": "pod update",
        "make": "make ", "cmake": "cmake .",
        "python": "python3 ", "node": "node ",
        "curl": "curl -X GET ", "wget": "wget ", "ssh": "ssh ", "scp": "scp ",
    ]

    var body: some View { inputArea }

    private var allSuggestions: [String] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !hidesSuggestions, !trimmed.isEmpty, !trimmed.contains("\n") else { return [] }
        var suggestions: [String] = []
        let trimmedLower = trimmed.lowercased()
        for s in self.suggestions.results {
            suggestions.append(s)
        }
        for s in findDynamicCompletions(trimmed) where !suggestions.contains(s) {
            suggestions.append(s)
        }
        if let s = Self.completions[trimmedLower], s.count > trimmed.count, !suggestions.contains(s) {
            suggestions.append(s)
        }
        for key in Self.completions.keys.sorted() where key.hasPrefix(trimmedLower) {
            if let value = Self.completions[key], value.count > trimmed.count, !suggestions.contains(value) { suggestions.append(value) }
        }
        return Array(suggestions.uniqued().prefix(5))
    }

    private var bestSuggestion: String? {
        let s = allSuggestions
        guard !s.isEmpty else { return nil }
        return s[safe: min(selectedIndex, s.count - 1)]
    }

    private var ghostText: String {
        guard let suggestion = bestSuggestion else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return suggestion.lowercased().hasPrefix(trimmed.lowercased()) ? String(suggestion.dropFirst(trimmed.count)) : ""
    }

    private var isMultiline: Bool { text.contains("\n") || text.count > 80 }
    private var lineCount: Int { max(1, text.components(separatedBy: "\n").count) }
    private var dynamicHeight: CGFloat { min(120, 28 + CGFloat(max(0, lineCount - 1)) * 18) }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text((workingDirectory as NSString).lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.bottom, 8)
            Text("$")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.accent)
                .padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if !ghostText.isEmpty {
                        HStack(spacing: 0) {
                            Text(text).font(.system(size: 13, design: .monospaced)).opacity(0)
                            Text(ghostText).font(.system(size: 13, design: .monospaced)).foregroundStyle(AppTheme.accent.opacity(0.5))
                            Text(" ⇥").font(.system(size: 9)).foregroundStyle(AppTheme.textMuted.opacity(0.4))
                        }.padding(.top, 6)
                    }
                    if suggestions.isLoading && ghostText.isEmpty {
                        HStack(spacing: 0) {
                            Text(text).font(.system(size: 13, design: .monospaced)).opacity(0)
                            Text("...").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppTheme.textMuted.opacity(0.3))
                        }.padding(.top, 6)
                    }
                    if text.isEmpty {
                        Text("Enter command...").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppTheme.textMuted.opacity(0.4)).padding(.top, 6)
                    }
                    AITextEditor(text: $text, isFocused: isFocused, onSubmit: { suggestions.cancel(); onSubmit(text) }, onTab: applyInlineSuggestion, onArrowUp: { navigateSuggestion(up: true) }, onArrowDown: { navigateSuggestion(up: false) }, onEscape: clearSuggestions).frame(height: dynamicHeight)
                }
                if allSuggestions.count > 1 || !suggestions.results.isEmpty { suggestionsDropdown }
                if let error = suggestions.error {
                    Text(error).font(.caption).foregroundStyle(AppTheme.error).textSelection(.enabled)
                }
            }
            Button {
                hidesSuggestions = false
                suggestions.request(input: text, directory: workingDirectory)
            } label: {
                Label(suggestions.isLoading ? "Generating…" : "Suggest command", systemImage: "sparkles")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(suggestions.isLoading || text.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            .help("Request an AI suggestion. Review it before running the command.")
            .accessibilityIdentifier("terminal-request-suggestion")
            .padding(.bottom, 6)
            if isMultiline {
                Button { suggestions.cancel(); onSubmit(text) } label: {
                    Image(systemName: "paperplane.fill").font(.system(size: 12)).foregroundStyle(AppTheme.accent)
                }.buttonStyle(.plain).padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(AppTheme.backgroundSecondary)
        .overlay(Rectangle().fill(AppTheme.border.opacity(0.3)).frame(height: 1), alignment: .top)
        .onChange(of: text) { _, value in
            hidesSuggestions = false
            selectedIndex = 0
            suggestions.update(input: value, directory: workingDirectory)
        }
        .onAppear { loadContextCache() }
        .onChange(of: workingDirectory) { _, value in
            suggestions.update(input: text, directory: value)
            clearContextCache()
            loadContextCache()
        }
        .onDisappear { clearContextCache() }
    }

    /// Clear caches to free memory when view disappears
    private func clearContextCache() {
        cachedBranches.removeAll()
        cachedFiles.removeAll()
        cachedDirs.removeAll()
        cachedStagedFiles.removeAll()
        cachedModifiedFiles.removeAll()
        suggestions.cancel()
        contextTask?.cancel()
        contextTask = nil
        contextGeneration = UUID()
        cachedContextPath = ""
    }

    private var suggestionsDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(allSuggestions.enumerated()), id: \.offset) { idx, sug in
                Button { selectedIndex = idx; applyInlineSuggestion() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(AppTheme.accent).opacity(idx == selectedIndex ? 1 : 0).frame(width: 10)
                        Text(sug).font(.system(size: 12, design: .monospaced)).foregroundStyle(idx == selectedIndex ? AppTheme.accent : AppTheme.textSecondary).lineLimit(1)
                        Spacer()
                        if idx == selectedIndex { Text("⇥ Tab").font(.system(size: 9)).foregroundStyle(AppTheme.textMuted.opacity(0.5)) }
                    }.padding(.horizontal, 8).padding(.vertical, 4).background(idx == selectedIndex ? AppTheme.accent.opacity(0.1) : Color.clear)
                }.buttonStyle(.plain)
            }
        }.padding(.vertical, 4).background(AppTheme.backgroundTertiary.opacity(0.95)).clipShape(.rect(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border.opacity(0.3), lineWidth: 1)).padding(.top, 4)
    }

    private func navigateSuggestion(up: Bool) {
        let c = allSuggestions.count; guard c > 0 else { return }
        selectedIndex = up ? (selectedIndex > 0 ? selectedIndex - 1 : c - 1) : (selectedIndex + 1) % c
    }
    private func clearSuggestions() { suggestions.cancel(); selectedIndex = 0; hidesSuggestions = true }
    private func applyInlineSuggestion() { if let value = bestSuggestion { text = value; clearSuggestions() } }

    private func loadContextCache() {
        let path = (workingDirectory as NSString).expandingTildeInPath
        guard path != cachedContextPath || Date().timeIntervalSince(lastCacheUpdate) > 5 else { return }
        contextTask?.cancel()
        let generation = UUID()
        contextGeneration = generation
        contextTask = Task { @MainActor in
            let engine = GitEngine()
            async let status = try? engine.getStatus(at: path)
            async let branchResult = ShellExecutor.shared.execute("git",
                arguments: ["for-each-ref", "--format=%(refname:short)", "refs/heads/"], workingDirectory: path)
            let entries = await Task.detached(priority: .utility) {
                let root = URL(fileURLWithPath: path, isDirectory: true)
                let names = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
                var files: [String] = [], directories: [String] = []
                var inspected = 0
                while let url = names?.nextObject() as? URL, inspected < 200 {
                    guard !Task.isCancelled else { break }
                    inspected += 1
                    files.append(url.lastPathComponent)
                    if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        directories.append(url.lastPathComponent)
                    }
                }
                return (Array(files.sorted().prefix(50)), Array(directories.sorted().prefix(30)))
            }.value
            let (loadedStatus, branches) = await (status, branchResult)
            guard !Task.isCancelled, generation == contextGeneration else { return }
            cachedFiles = entries.0
            cachedDirs = entries.1
            cachedBranches = branches.isSuccess ? Array(branches.stdout.split(separator: "\n").prefix(200).map(String.init)) : []
            cachedStagedFiles = Array((loadedStatus?.staged.map(\.path) ?? []).prefix(200))
            cachedModifiedFiles = Array((loadedStatus?.unstaged.map(\.path) ?? []).prefix(200))
            cachedContextPath = path
            lastCacheUpdate = Date()
        }
    }

    private func findDynamicCompletions(_ input: String) -> [String] {
        let lower = input.lowercased(); var results: [String] = []
        if ["git checkout ", "git switch ", "git merge ", "git rebase "].contains(where: { lower.hasPrefix($0) }) {
            let pre = input.components(separatedBy: " ").dropLast().joined(separator: " ") + " "
            let partial = String(input.dropFirst(pre.count))
            for b in cachedBranches.filter({ $0.lowercased().hasPrefix(partial.lowercased()) }).prefix(3) { results.append(pre + TerminalShell.quoteArgument(b)) }
        }
        if lower.hasPrefix("git checkout -b ") || lower.hasPrefix("git switch -c ") {
            let pre = input.components(separatedBy: " ").dropLast().joined(separator: " ") + " "
            let partial = String(input.dropFirst(pre.count)).lowercased()
            for bp in ["feature/", "fix/", "hotfix/", "bugfix/", "chore/", "refactor/", "docs/", "test/"] where bp.hasPrefix(partial) { results.append(pre + bp); if results.count >= 3 { break } }
        }
        if lower.hasPrefix("cd ") { for d in cachedDirs.filter({ $0.lowercased().hasPrefix(String(input.dropFirst(3)).lowercased()) }).prefix(3) { results.append("cd -- " + TerminalShell.quoteArgument(d)) } }
        for cmd in ["cat ", "vim ", "nano ", "code ", "less ", "head ", "tail ", "open "] where lower.hasPrefix(cmd) {
            for f in cachedFiles.filter({ $0.lowercased().hasPrefix(String(input.dropFirst(cmd.count)).lowercased()) }).prefix(3) { results.append(cmd + TerminalShell.quoteArgument(f)) }
        }
        if lower.hasPrefix("git add ") && !lower.hasSuffix(".") && !lower.hasSuffix("--all") {
            let partial = String(input.dropFirst(8))
            if !partial.isEmpty && partial != "." { for f in cachedFiles.filter({ $0.lowercased().hasPrefix(partial.lowercased()) }).prefix(3) { results.append("git add -- " + TerminalShell.quoteArgument(f)) } }
        }
        if lower.hasPrefix("git commit -m \"") && !input.hasSuffix("\"\"") {
            let after = String(input.dropFirst("git commit -m \"".count)); let sType = inferCommitType()
            var types = ["feat: ", "fix: ", "docs: ", "style: ", "refactor: ", "test: ", "chore: "]
            if let i = types.firstIndex(of: sType + ": ") { types.remove(at: i); types.insert(sType + ": ", at: 0) }
            if after.isEmpty || after == "\"" {
                if !cachedStagedFiles.isEmpty { results.append("git commit -m " + TerminalShell.quoteArgument("\(sType): update \(cachedStagedFiles.prefix(3).map { ($0 as NSString).lastPathComponent }.joined(separator: ", "))")) }
                for t in types.prefix(3) { results.append("git commit -m \"\(t)\"") }
            } else { for t in types where t.hasPrefix(after.lowercased()) { results.append("git commit -m \"\(t)\"") } }
        }
        return results
    }

    private func inferCommitType() -> String {
        let f = cachedStagedFiles.joined(separator: " ").lowercased()
        if f.contains("test") || f.contains("spec") { return "test" }
        if f.contains("readme") || f.contains(".md") || f.contains("doc") { return "docs" }
        if f.contains("package.json") || f.contains("podfile") || f.contains(".yml") || f.contains("config") { return "chore" }
        if f.contains(".css") || f.contains(".scss") || f.contains("theme") { return "style" }
        if f.contains("fix") || f.contains("bug") { return "fix" }
        if f.contains("refactor") || f.contains("clean") { return "refactor" }
        return "feat"
    }

}

// MARK: - Terminal command contracts

/// AI is requested explicitly; typing, switching repositories and dismissal only invalidate it.
@MainActor final class TerminalSuggestionController: ObservableObject {
    typealias Provider = (String, String) async throws -> [String]
    @Published private(set) var results: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    private let provider: Provider
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var input = ""
    private var directory = ""

    init(provider: @escaping Provider) { self.provider = provider }

    convenience init() {
        self.init(provider: { input, directory in
            let values = try await AIService.shared.suggestTerminalCommands(input: input, repoPath: directory)
            return values.map(\.command)
        })
    }

    func update(input: String, directory: String) {
        guard self.input != input || self.directory != directory else { return }
        cancel()
        self.input = input
        self.directory = directory
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        results = []
        isLoading = false
        error = nil
    }

    func request(input: String, directory: String) {
        update(input: input, directory: directory)
        guard !isLoading else { return }
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.count >= 2 else { return }
        guard prompt.utf8.count <= 4096, !prompt.contains("\0"), !prompt.contains("\n") else {
            error = "Use a single command or question up to 4 KB for a suggestion."
            return
        }
        let request = UUID()
        generation = request
        isLoading = true
        error = nil
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation == request { isLoading = false; task = nil }
            }
            do {
                let values = try await provider(prompt, (directory as NSString).expandingTildeInPath)
                guard !Task.isCancelled, generation == request else { return }
                results = Array(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.contains("\n") && !$0.contains("\0") && $0.utf8.count <= 4096 }
                    .prefix(3))
                if results.isEmpty { error = "No command suggestion was returned. Try a more specific request." }
            } catch {
                guard !Task.isCancelled, generation == request else { return }
                self.error = error.localizedDescription
            }
        }
    }
}

enum TerminalShell {
    static func quoteArgument(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func changeDirectoryCommand(_ path: String) -> String? {
        guard path.hasPrefix("/"), !path.contains("\0") else { return nil }
        return "cd -- " + quoteArgument(path) + "\n"
    }
}

enum TerminalViewport {
    static func pixelSize(_ size: CGSize, scale: CGFloat) -> (width: UInt32, height: UInt32)? {
        guard size.width.isFinite, size.height.isFinite, scale.isFinite, scale > 0,
              size.width > 0, size.height > 0 else { return nil }
        let width = (size.width * scale).rounded(.up), height = (size.height * scale).rounded(.up)
        guard width.isFinite, height.isFinite, width <= CGFloat(UInt32.max), height <= CGFloat(UInt32.max) else { return nil }
        return (UInt32(width), UInt32(height))
    }
}
