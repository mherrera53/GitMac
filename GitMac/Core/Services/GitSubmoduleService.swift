import Foundation

/// Service for managing Git submodules
@MainActor
class GitSubmoduleService {
    private let shell = ShellExecutor()
    
    /// Get all submodules in the repository
    func getSubmodules(at repoPath: String) async throws -> [GitSubmodule] {
        let result = await shell.execute(
            "git",
            arguments: ["config", "--file", ".gitmodules", "--get-regexp", "path"],
            workingDirectory: repoPath
        )
        
        guard result.exitCode == 0 else {
            if result.stderr.contains("--file .gitmodules") {
                return []
            }
            throw SubmoduleError.commandFailed(result.stderr)
        }
        
        var submodules: [GitSubmodule] = []
        let lines = result.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let components = line.components(separatedBy: " ")
            guard components.count >= 2 else { continue }
            
            let nameKey = components[0]
            let path = components[1...].joined(separator: " ")
            let name = nameKey.replacingOccurrences(of: "submodule.", with: "")
                .replacingOccurrences(of: ".path", with: "")
            
            if let submodule = try? await getSubmoduleDetails(name: name, path: path, at: repoPath) {
                submodules.append(submodule)
            }
        }
        
        return submodules
    }
    
    /// Get details for a specific submodule
    private func getSubmoduleDetails(name: String, path: String, at repoPath: String) async throws -> GitSubmodule {
        let urlResult = await shell.execute(
            "git",
            arguments: ["config", "--file", ".gitmodules", "--get", "submodule.\(name).url"],
            workingDirectory: repoPath
        )
        
        let branchResult = await shell.execute(
            "git",
            arguments: ["config", "--file", ".gitmodules", "--get", "submodule.\(name).branch"],
            workingDirectory: repoPath
        )
        
        let statusResult = await shell.execute(
            "git",
            arguments: ["submodule", "status", path],
            workingDirectory: repoPath
        )
        
        let url = urlResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = branchResult.exitCode == 0 ? branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        
        let statusLine = statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = parseSubmoduleStatus(statusLine)
        let commitSHA = extractCommitSHA(from: statusLine)
        
        return GitSubmodule(
            id: name,
            name: name,
            path: path,
            url: url,
            branch: branch,
            status: status,
            commitSHA: commitSHA
        )
    }
    
    /// Initialize a submodule
    func initializeSubmodule(_ submodule: GitSubmodule, at repoPath: String) async throws {
        let result = await shell.execute(
            "git",
            arguments: ["submodule", "init", submodule.path],
            workingDirectory: repoPath
        )
        
        guard result.exitCode == 0 else {
            throw SubmoduleError.commandFailed(result.stderr)
        }
    }
    
    /// Update a submodule
    func updateSubmodule(_ submodule: GitSubmodule, at repoPath: String) async throws {
        let result = await shell.execute(
            "git",
            arguments: ["submodule", "update", "--remote", submodule.path],
            workingDirectory: repoPath
        )
        
        guard result.exitCode == 0 else {
            throw SubmoduleError.commandFailed(result.stderr)
        }
    }
    
    /// Add a new submodule
    func addSubmodule(url: String, path: String, branch: String?, at repoPath: String) async throws {
        var args = ["submodule", "add"]
        if let branch = branch {
            args.append(contentsOf: ["-b", branch])
        }
        args.append(contentsOf: [url, path])
        
        let result = await shell.execute(
            "git",
            arguments: args,
            workingDirectory: repoPath
        )
        
        guard result.exitCode == 0 else {
            throw SubmoduleError.commandFailed(result.stderr)
        }
    }
    
    /// Remove a submodule
    func removeSubmodule(_ submodule: GitSubmodule, at repoPath: String) async throws {
        let deinitResult = await shell.execute(
            "git",
            arguments: ["submodule", "deinit", "-f", submodule.path],
            workingDirectory: repoPath
        )
        
        guard deinitResult.exitCode == 0 else {
            throw SubmoduleError.commandFailed(deinitResult.stderr)
        }
        
        let rmResult = await shell.execute(
            "git",
            arguments: ["rm", "-f", submodule.path],
            workingDirectory: repoPath
        )
        
        guard rmResult.exitCode == 0 else {
            throw SubmoduleError.commandFailed(rmResult.stderr)
        }
        
        let gitDirPath = "\(repoPath)/.git/modules/\(submodule.name)"
        try? FileManager.default.removeItem(atPath: gitDirPath)
    }
    
    /// Sync submodule URLs
    func syncSubmodules(at repoPath: String) async throws {
        let result = await shell.execute(
            "git",
            arguments: ["submodule", "sync"],
            workingDirectory: repoPath
        )
        
        guard result.exitCode == 0 else {
            throw SubmoduleError.commandFailed(result.stderr)
        }
    }
    
    // MARK: - Private Helpers
    
    private func parseSubmoduleStatus(_ statusLine: String) -> SubmoduleStatus {
        if statusLine.isEmpty {
            return .unknown
        }
        
        let firstChar = statusLine.first
        switch firstChar {
        case "-":
            return .uninitialized
        case "+":
            return .modified
        case " ":
            return .initialized
        default:
            return .upToDate
        }
    }
    
    private func extractCommitSHA(from statusLine: String) -> String? {
        let components = statusLine.components(separatedBy: " ")
        guard components.count > 0 else { return nil }
        
        let shaComponent = components[0]
        let sha = shaComponent.trimmingCharacters(in: CharacterSet(charactersIn: "-+ "))
        return sha.isEmpty ? nil : sha
    }
}

enum SubmoduleError: LocalizedError {
    case commandFailed(String)
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .invalidConfiguration:
            return "Invalid submodule configuration"
        }
    }
}
