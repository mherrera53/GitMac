import Foundation

/// Service for managing Git hooks
@MainActor
class GitHooksService {
    private let fileManager = FileManager.default

    /// Get all git hooks for a repository
    func getHooks(at repoPath: String) throws -> [GitHook] {
        let hooksPath = "\(repoPath)/.git/hooks"

        var hooks: [GitHook] = []

        for hookType in GitHookType.allCases {
            let hookPath = "\(hooksPath)/\(hookType.rawValue)"
            let samplePath = "\(hookPath).sample"

            var isEnabled = false
            var content: String? = nil

            if fileManager.fileExists(atPath: hookPath) {
                isEnabled = true
                content = try? String(contentsOfFile: hookPath, encoding: .utf8)
            } else if fileManager.fileExists(atPath: samplePath) {
                content = try? String(contentsOfFile: samplePath, encoding: .utf8)
            }

            let hook = GitHook(
                id: hookType.rawValue,
                name: hookType.rawValue,
                description: hookType.description,
                isEnabled: isEnabled,
                content: content,
                path: hookPath
            )

            hooks.append(hook)
        }

        return hooks
    }

    /// Enable a hook by creating/activating the hook file
    func enableHook(_ hook: GitHook, content: String? = nil) throws {
        let finalContent = content ?? hook.content ?? GitHookType(rawValue: hook.name)?.templateContent ?? ""

        try finalContent.write(toFile: hook.path, atomically: true, encoding: .utf8)

        try setExecutable(hook.path)
    }

    /// Disable a hook by renaming it to .sample
    func disableHook(_ hook: GitHook) throws {
        let samplePath = "\(hook.path).sample"

        guard fileManager.fileExists(atPath: hook.path) else {
            return
        }

        if fileManager.fileExists(atPath: samplePath) {
            try fileManager.removeItem(atPath: samplePath)
        }

        try fileManager.moveItem(atPath: hook.path, toPath: samplePath)
    }

    /// Update hook content
    func updateHook(_ hook: GitHook, content: String) throws {
        try content.write(toFile: hook.path, atomically: true, encoding: .utf8)

        if hook.isEnabled {
            try setExecutable(hook.path)
        }
    }

    /// Delete a hook
    func deleteHook(_ hook: GitHook) throws {
        if fileManager.fileExists(atPath: hook.path) {
            try fileManager.removeItem(atPath: hook.path)
        }

        let samplePath = "\(hook.path).sample"
        if fileManager.fileExists(atPath: samplePath) {
            try fileManager.removeItem(atPath: samplePath)
        }
    }

    /// Set file as executable
    private func setExecutable(_ path: String) throws {
        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: 0o755
        ]
        try fileManager.setAttributes(attributes, ofItemAtPath: path)
    }

    /// Get content of a hook
    func getHookContent(_ hook: GitHook) -> String? {
        if let content = hook.content {
            return content
        }

        if fileManager.fileExists(atPath: hook.path) {
            return try? String(contentsOfFile: hook.path, encoding: .utf8)
        }

        let samplePath = "\(hook.path).sample"
        if fileManager.fileExists(atPath: samplePath) {
            return try? String(contentsOfFile: samplePath, encoding: .utf8)
        }

        return GitHookType(rawValue: hook.name)?.templateContent
    }

    /// Create new hook from template
    func createHookFromTemplate(type: GitHookType, at repoPath: String) throws -> GitHook {
        let hooksPath = "\(repoPath)/.git/hooks"
        let hookPath = "\(hooksPath)/\(type.rawValue)"

        if !fileManager.fileExists(atPath: hooksPath) {
            try fileManager.createDirectory(atPath: hooksPath, withIntermediateDirectories: true)
        }

        let content = type.templateContent
        try content.write(toFile: hookPath, atomically: true, encoding: .utf8)
        try setExecutable(hookPath)

        return GitHook(
            id: type.rawValue,
            name: type.rawValue,
            description: type.description,
            isEnabled: true,
            content: content,
            path: hookPath
        )
    }
}
