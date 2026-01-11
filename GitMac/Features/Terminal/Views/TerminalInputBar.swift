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

    @State private var inlineSuggestions: [String] = []
    @State private var selectedIndex: Int = 0
    @State private var isLoadingAI = false
    private let aiDebouncer = Debouncer(delay: 0.25)

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
        guard !trimmed.isEmpty, !trimmed.contains("\n") else { return [] }
        var suggestions: [String] = []
        let trimmedLower = trimmed.lowercased()
        for s in inlineSuggestions where s.lowercased().hasPrefix(trimmedLower) && s.count > trimmed.count {
            suggestions.append(s)
        }
        for s in findDynamicCompletions(trimmed) where !suggestions.contains(s) {
            suggestions.append(s)
        }
        if let s = Self.completions[trimmedLower], s.count > trimmed.count, !suggestions.contains(s) {
            suggestions.append(s)
        }
        for (k, v) in Self.completions where k.hasPrefix(trimmedLower) && v.count > trimmed.count && !suggestions.contains(v) {
            suggestions.append(v)
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
                .foregroundColor(AppTheme.textMuted)
                .padding(.bottom, 8)
            Text("$")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(AppTheme.accent)
                .padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if !ghostText.isEmpty {
                        HStack(spacing: 0) {
                            Text(text).font(.system(size: 13, design: .monospaced)).opacity(0)
                            Text(ghostText).font(.system(size: 13, design: .monospaced)).foregroundColor(AppTheme.accent.opacity(0.5))
                            Text(" ⇥").font(.system(size: 9)).foregroundColor(AppTheme.textMuted.opacity(0.4))
                        }.padding(.top, 6)
                    }
                    if isLoadingAI && ghostText.isEmpty {
                        HStack(spacing: 0) {
                            Text(text).font(.system(size: 13, design: .monospaced)).opacity(0)
                            Text("...").font(.system(size: 13, design: .monospaced)).foregroundColor(AppTheme.textMuted.opacity(0.3))
                        }.padding(.top, 6)
                    }
                    if text.isEmpty {
                        Text("Enter command...").font(.system(size: 13, design: .monospaced)).foregroundColor(AppTheme.textMuted.opacity(0.4)).padding(.top, 6)
                    }
                    AITextEditor(text: $text, isFocused: isFocused, onSubmit: { onSubmit(text) }, onTab: applyInlineSuggestion, onArrowUp: { navigateSuggestion(up: true) }, onArrowDown: { navigateSuggestion(up: false) }, onEscape: clearSuggestions).frame(height: dynamicHeight)
                }
                if allSuggestions.count > 1 { suggestionsDropdown }
            }
            if isMultiline {
                Button { onSubmit(text) } label: {
                    Image(systemName: "paperplane.fill").font(.system(size: 12)).foregroundColor(AppTheme.accent)
                }.buttonStyle(.plain).padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(AppTheme.backgroundSecondary)
        .overlay(Rectangle().fill(AppTheme.border.opacity(0.3)).frame(height: 1), alignment: .top)
        .onChange(of: text) { _, v in fetchInlineSuggestion(v) }
        .onAppear { loadContextCache() }
        .onChange(of: workingDirectory) { _, _ in loadContextCache() }
        .onDisappear { clearContextCache() }
    }

    /// Clear caches to free memory when view disappears
    private func clearContextCache() {
        cachedBranches.removeAll()
        cachedFiles.removeAll()
        cachedDirs.removeAll()
        cachedStagedFiles.removeAll()
        cachedModifiedFiles.removeAll()
        inlineSuggestions.removeAll()
    }

    private var suggestionsDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(allSuggestions.enumerated()), id: \.offset) { idx, sug in
                Button { selectedIndex = idx; applyInlineSuggestion() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: idx == selectedIndex ? "chevron.right" : "").font(.system(size: 8, weight: .bold)).foregroundColor(AppTheme.accent).frame(width: 10)
                        Text(sug).font(.system(size: 12, design: .monospaced)).foregroundColor(idx == selectedIndex ? AppTheme.accent : AppTheme.textSecondary).lineLimit(1)
                        Spacer()
                        if idx == selectedIndex { Text("⇥ Tab").font(.system(size: 9)).foregroundColor(AppTheme.textMuted.opacity(0.5)) }
                    }.padding(.horizontal, 8).padding(.vertical, 4).background(idx == selectedIndex ? AppTheme.accent.opacity(0.1) : Color.clear)
                }.buttonStyle(.plain)
            }
        }.padding(.vertical, 4).background(AppTheme.backgroundTertiary.opacity(0.95)).cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border.opacity(0.3), lineWidth: 1)).padding(.top, 4)
    }

    private func navigateSuggestion(up: Bool) {
        let c = allSuggestions.count; guard c > 0 else { return }
        selectedIndex = up ? (selectedIndex > 0 ? selectedIndex - 1 : c - 1) : (selectedIndex + 1) % c
    }
    private func clearSuggestions() { inlineSuggestions = []; selectedIndex = 0 }
    private func applyInlineSuggestion() { if let s = bestSuggestion, !ghostText.isEmpty { text = s; clearSuggestions() } }

    private func loadContextCache() {
        guard Date().timeIntervalSince(lastCacheUpdate) > 5 else { return }
        Task {
            async let b = loadGitBranches(); async let f = loadFiles(); async let d = loadDirectories(); async let st = loadGitStatus()
            let (br, fi, di, status) = await (b, f, d, st)
            await MainActor.run { cachedBranches = br; cachedFiles = fi; cachedDirs = di; cachedStagedFiles = status.staged; cachedModifiedFiles = status.modified; lastCacheUpdate = Date() }
        }
    }

    private func loadGitStatus() async -> (staged: [String], modified: [String]) {
        guard !workingDirectory.isEmpty else { return ([], []) }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git"); p.arguments = ["status", "--porcelain"]; p.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do {
            try p.run(); p.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            var staged: [String] = [], modified: [String] = []
            for line in output.components(separatedBy: .newlines) where line.count > 3 {
                let idx = line.prefix(1), wt = String(line.dropFirst(1).prefix(1)), fn = String(line.dropFirst(3))
                if ["A","M","R","D"].contains(String(idx)) { staged.append(fn) }
                if wt == "M" || wt == "?" { modified.append(fn) }
            }
            return (staged, modified)
        } catch { return ([], []) }
    }

    private func loadGitBranches() async -> [String] {
        guard !workingDirectory.isEmpty else { return [] }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git"); p.arguments = ["branch", "--format=%(refname:short)"]; p.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.components(separatedBy: .newlines).filter { !$0.isEmpty } ?? [] } catch { return [] }
    }

    private func loadFiles() async -> [String] {
        guard !workingDirectory.isEmpty else { return [] }
        return (try? FileManager.default.contentsOfDirectory(atPath: workingDirectory).filter { !$0.hasPrefix(".") }.prefix(50).sorted().map { String($0) }) ?? []
    }

    private func loadDirectories() async -> [String] {
        guard !workingDirectory.isEmpty else { return [] }
        let fm = FileManager.default
        var dirs: [String] = []
        for item in (try? fm.contentsOfDirectory(atPath: workingDirectory)) ?? [] where !item.hasPrefix(".") {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: (workingDirectory as NSString).appendingPathComponent(item), isDirectory: &isDir), isDir.boolValue { dirs.append(item) }
        }
        return Array(dirs.sorted().prefix(30))
    }

    private func findDynamicCompletions(_ input: String) -> [String] {
        let lower = input.lowercased(); var results: [String] = []
        if ["git checkout ", "git switch ", "git merge ", "git rebase "].contains(where: { lower.hasPrefix($0) }) {
            let pre = input.components(separatedBy: " ").dropLast().joined(separator: " ") + " "
            let partial = String(input.dropFirst(pre.count))
            for b in cachedBranches.filter({ $0.lowercased().hasPrefix(partial.lowercased()) }).prefix(3) { results.append(pre + b) }
        }
        if lower.hasPrefix("git checkout -b ") || lower.hasPrefix("git switch -c ") {
            let pre = input.components(separatedBy: " ").dropLast().joined(separator: " ") + " "
            let partial = String(input.dropFirst(pre.count)).lowercased()
            for bp in ["feature/", "fix/", "hotfix/", "bugfix/", "chore/", "refactor/", "docs/", "test/"] where bp.hasPrefix(partial) { results.append(pre + bp); if results.count >= 3 { break } }
        }
        if lower.hasPrefix("cd ") { for d in cachedDirs.filter({ $0.lowercased().hasPrefix(String(input.dropFirst(3)).lowercased()) }).prefix(3) { results.append("cd " + d) } }
        for cmd in ["cat ", "vim ", "nano ", "code ", "less ", "head ", "tail ", "open "] where lower.hasPrefix(cmd) {
            for f in cachedFiles.filter({ $0.lowercased().hasPrefix(String(input.dropFirst(cmd.count)).lowercased()) }).prefix(3) { results.append(cmd + f) }
        }
        if lower.hasPrefix("git add ") && !lower.hasSuffix(".") && !lower.hasSuffix("--all") {
            let partial = String(input.dropFirst(8))
            if !partial.isEmpty && partial != "." { for f in cachedFiles.filter({ $0.lowercased().hasPrefix(partial.lowercased()) }).prefix(3) { results.append("git add " + f) } }
        }
        if lower.hasPrefix("git commit -m \"") && !input.hasSuffix("\"\"") {
            let after = String(input.dropFirst("git commit -m \"".count)); let sType = inferCommitType()
            var types = ["feat: ", "fix: ", "docs: ", "style: ", "refactor: ", "test: ", "chore: "]
            if let i = types.firstIndex(of: sType + ": ") { types.remove(at: i); types.insert(sType + ": ", at: 0) }
            if after.isEmpty || after == "\"" {
                if !cachedStagedFiles.isEmpty { results.append("git commit -m \"\(sType): update \(cachedStagedFiles.prefix(3).map { ($0 as NSString).lastPathComponent }.joined(separator: ", "))\"") }
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

    private func fetchInlineSuggestion(_ input: String) {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines); selectedIndex = 0
        guard t.count >= 2, !t.contains("\n") else { inlineSuggestions = []; return }
        if allSuggestions.count >= 2 { return }
        aiDebouncer.debounce { [t] in
            Task { @MainActor in
                isLoadingAI = true
                let s = await fetchFromAI(input: t)
                if !s.isEmpty { inlineSuggestions = s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0.lowercased().hasPrefix(t.lowercased()) }.prefix(3).map { String($0) } }
                isLoadingAI = false
            }
        }
    }

    private func fetchFromAI(input: String) async -> String {
        if await AIService.shared.hasAPIKey(for: .ollama), let r = try? await fetchOllamaSuggestion(input: input), !r.isEmpty { return r }
        if let s = try? await AIService.shared.suggestTerminalCommands(input: input, repoPath: workingDirectory).first { return s.command }
        return ""
    }

    private func fetchOllamaSuggestion(input: String) async throws -> String {
        guard let url = URL(string: "\(AIService.ollamaBaseURL)/api/generate") else { return "" }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.timeoutInterval = 3
        let model = await AIService.shared.getCurrentModel().isEmpty ? "llama3.2" : await AIService.shared.getCurrentModel()
        req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "prompt": buildSmartPrompt(for: input), "stream": false, "options": ["num_predict": 60, "temperature": 0.1]])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let hr = resp as? HTTPURLResponse, hr.statusCode == 200, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txt = j["response"] as? String else { return "" }
        let c = txt.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").first?.replacingOccurrences(of: "`", with: "").trimmingCharacters(in: .whitespaces) ?? ""
        return c.lowercased().hasPrefix(input.lowercased()) ? c : ""
    }

    private func buildSmartPrompt(for input: String) -> String {
        let lower = input.lowercased(); var ctx = ""
        if ["checkout", "switch", "merge", "rebase", "branch"].contains(where: { lower.contains($0) }) && !cachedBranches.isEmpty { ctx += "Branches: \(cachedBranches.prefix(10).joined(separator: ", "))\n" }
        if ["cat ", "vim ", "nano ", "code ", "open ", "git add ", "less "].contains(where: { lower.hasPrefix($0) }) && !cachedFiles.isEmpty { ctx += "Files: \(cachedFiles.prefix(15).joined(separator: ", "))\n" }
        if lower.hasPrefix("cd ") && !cachedDirs.isEmpty { ctx += "Dirs: \(cachedDirs.prefix(10).joined(separator: ", "))\n" }
        if lower.contains("commit") && lower.contains("-m") { ctx += "Conventional: feat:, fix:, docs:, style:, refactor:, test:, chore:\n"; if !cachedStagedFiles.isEmpty { ctx += "Staged: \(cachedStagedFiles.prefix(10).joined(separator: ", "))\n" } }
        return ctx.isEmpty ? "Complete terminal command (ONLY command):\n\(input)" : "Complete using context:\n\(ctx)Input: \(input)"
    }
}

// Shared types (AITextEditor, Debouncer, extensions) are in TerminalSharedTypes.swift
