//
//  TerminalCompletions.swift
//  GitMac
//
//  Static command completions - easily extensible by community
//

import Foundation

/// Static command completions for instant suggestions
/// Add new completions by extending the dictionaries below
enum TerminalCompletions {

    // MARK: - Git Commands

    static let git: [String: String] = [
        // Status & Info
        "git": "git status",
        "git s": "git status",
        "git st": "git status",

        // Add
        "git a": "git add .",
        "git ad": "git add .",
        "git add": "git add .",
        "git aa": "git add --all",
        "git ap": "git add -p",

        // Commit
        "git c": "git commit -m \"\"",
        "git co": "git commit -m \"\"",
        "git cm": "git commit -m \"\"",
        "git ca": "git commit --amend",
        "git can": "git commit --amend --no-edit",

        // Push
        "git p": "git push",
        "git pu": "git push",
        "git pus": "git push",
        "git pf": "git push --force-with-lease",
        "git po": "git push origin",
        "git pom": "git push origin main",

        // Pull
        "git pl": "git pull",
        "git pul": "git pull",
        "git plr": "git pull --rebase",

        // Branches
        "git ch": "git checkout ",
        "git che": "git checkout ",
        "git chb": "git checkout -b ",
        "git cb": "git checkout -b ",
        "git sw": "git switch ",
        "git swc": "git switch -c ",
        "git b": "git branch",
        "git br": "git branch",
        "git bd": "git branch -d ",
        "git bD": "git branch -D ",
        "git ba": "git branch -a",
        "git bv": "git branch -v",

        // Diff
        "git d": "git diff",
        "git di": "git diff",
        "git ds": "git diff --staged",
        "git dc": "git diff --cached",
        "git dh": "git diff HEAD",

        // Log
        "git l": "git log --oneline",
        "git lo": "git log --oneline",
        "git lg": "git log --oneline --graph --all",
        "git ll": "git log --oneline -10",
        "git lp": "git log -p",
        "git ls": "git log --stat",

        // Fetch & Remote
        "git f": "git fetch",
        "git fe": "git fetch",
        "git fa": "git fetch --all",
        "git rem": "git remote -v",
        "git rema": "git remote add origin ",

        // Merge & Rebase
        "git m": "git merge ",
        "git me": "git merge ",
        "git r": "git rebase ",
        "git re": "git rebase ",
        "git ri": "git rebase -i ",
        "git rc": "git rebase --continue",
        "git ra": "git rebase --abort",

        // Stash
        "git sta": "git stash",
        "git stas": "git stash",
        "git stl": "git stash list",
        "git stp": "git stash pop",
        "git std": "git stash drop",
        "git sts": "git stash show -p",

        // Reset & Restore
        "git res": "git restore ",
        "git rss": "git restore --staged ",
        "git rh": "git reset HEAD",
        "git rhh": "git reset --hard HEAD",
        "git rsh": "git reset --soft HEAD~1",

        // Clean & Tags
        "git cl": "git clean -fd",
        "git cln": "git clean -fdn",
        "git t": "git tag",
        "git ta": "git tag -a ",
    ]

    // MARK: - GitHub CLI

    static let github: [String: String] = [
        "gh": "gh ",
        "gh p": "gh pr ",
        "gh pr": "gh pr list",
        "gh prc": "gh pr create",
        "gh prv": "gh pr view",
        "gh prm": "gh pr merge",
        "gh prd": "gh pr diff",
        "gh i": "gh issue ",
        "gh is": "gh issue list",
        "gh ic": "gh issue create",
        "gh iv": "gh issue view",
        "gh r": "gh repo ",
        "gh rv": "gh repo view",
        "gh rc": "gh repo clone ",
        "gh rf": "gh repo fork",
    ]

    // MARK: - Shell Commands

    static let shell: [String: String] = [
        "ls": "ls -la",
        "ll": "ls -la",
        "la": "ls -la",
        "lh": "ls -lah",
        "lt": "ls -lt",
        "cd": "cd ",
        "cd.": "cd ..",
        "cd..": "cd ..",
        "mk": "mkdir ",
        "mkd": "mkdir ",
        "mkp": "mkdir -p ",
        "rm": "rm -rf ",
        "cp": "cp -r ",
        "mv": "mv ",
        "cat": "cat ",
        "vim": "vim ",
        "nano": "nano ",
        "code": "code ",
        "touch": "touch ",
        "chmod": "chmod ",
        "find": "find . -name \"\"",
        "grep": "grep -r \"\" .",
        "rg": "rg \"\"",
        "fd": "fd \"\"",
        "ag": "ag \"\"",
        "ps": "ps aux",
        "kill": "kill -9 ",
        "top": "htop",
        "df": "df -h",
        "du": "du -sh ",
        "which": "which ",
    ]

    // MARK: - Package Managers

    static let packageManagers: [String: String] = [
        // npm
        "npm": "npm install",
        "npm i": "npm install",
        "npm r": "npm run ",
        "npm t": "npm test",
        "npm s": "npm start",
        "npm b": "npm run build",

        // yarn
        "yarn": "yarn install",
        "yarn a": "yarn add ",
        "yarn d": "yarn dev",
        "yarn b": "yarn build",

        // pnpm
        "pnpm": "pnpm install",
        "pnpm a": "pnpm add ",

        // pip
        "pip": "pip install ",
        "pip3": "pip3 install ",

        // cargo
        "cargo": "cargo ",
        "cargo b": "cargo build",
        "cargo r": "cargo run",
        "cargo t": "cargo test",

        // CocoaPods
        "pod": "pod install",
        "podu": "pod update",
    ]

    // MARK: - Docker

    static let docker: [String: String] = [
        "docker": "docker ",
        "docker p": "docker ps",
        "docker pa": "docker ps -a",
        "docker i": "docker images",
        "docker b": "docker build -t ",
        "docker r": "docker run ",
        "docker c": "docker-compose ",
        "docker cu": "docker-compose up",
        "docker cd": "docker-compose down",
    ]

    // MARK: - Xcode & Swift

    static let xcode: [String: String] = [
        "xc": "xcodebuild ",
        "xcb": "xcodebuild build",
        "xct": "xcodebuild test",
        "xcr": "xcodebuild clean",
        "swift": "swift ",
        "swiftb": "swift build",
        "swiftt": "swift test",
        "swiftr": "swift run",
    ]

    // MARK: - Network

    static let network: [String: String] = [
        "curl": "curl -X GET ",
        "wget": "wget ",
        "ssh": "ssh ",
        "scp": "scp ",
    ]

    // MARK: - Build Tools

    static let build: [String: String] = [
        "make": "make ",
        "cmake": "cmake .",
        "python": "python3 ",
        "node": "node ",
    ]

    // MARK: - Conventional Commit Types

    static let commitTypes = [
        "feat",
        "fix",
        "docs",
        "style",
        "refactor",
        "test",
        "chore",
        "perf",
        "ci",
        "build",
        "revert"
    ]

    // MARK: - Branch Prefixes

    static let branchPrefixes = [
        "feature/",
        "fix/",
        "hotfix/",
        "bugfix/",
        "chore/",
        "refactor/",
        "docs/",
        "test/",
        "release/",
        "dependabot/"
    ]

    // MARK: - All Completions (Combined)

    static var all: [String: String] {
        var combined: [String: String] = [:]
        combined.merge(git) { _, new in new }
        combined.merge(github) { _, new in new }
        combined.merge(shell) { _, new in new }
        combined.merge(packageManagers) { _, new in new }
        combined.merge(docker) { _, new in new }
        combined.merge(xcode) { _, new in new }
        combined.merge(network) { _, new in new }
        combined.merge(build) { _, new in new }
        return combined
    }

    /// Get completion for input
    static func completion(for input: String) -> String? {
        all[input.lowercased()]
    }

    /// Get all completions matching prefix
    static func completions(matchingPrefix prefix: String) -> [String] {
        let lower = prefix.lowercased()
        return all.filter { $0.key.hasPrefix(lower) }.map { $0.value }
    }
}
