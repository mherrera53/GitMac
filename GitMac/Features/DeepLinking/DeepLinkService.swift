import Foundation
import AppKit

// MARK: - Deep Link Service

/// Service for creating and handling deep links to specific commits, branches, and files
class DeepLinkService {
    static let shared = DeepLinkService()
    
    private let scheme = "gitmac"
    
    private init() {}
    
    // MARK: - Link Generation
    
    /// Generate a deep link to a specific commit
    func linkToCommit(sha: String, repoPath: String) -> URL? {
        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
        return URL(string: "\(scheme)://commit/\(repoName)/\(sha)")
    }
    
    /// Generate a deep link to a branch
    func linkToBranch(name: String, repoPath: String) -> URL? {
        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
        let encodedBranch = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return URL(string: "\(scheme)://branch/\(repoName)/\(encodedBranch)")
    }
    
    /// Generate a deep link to a file at a specific commit
    func linkToFile(path: String, at commit: String?, repoPath: String) -> URL? {
        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        var link = "\(scheme)://file/\(repoName)/\(encodedPath)"
        if let commit = commit {
            link += "?ref=\(commit)"
        }
        return URL(string: link)
    }
    
    /// Generate a deep link to a specific line in a file
    func linkToLine(file: String, line: Int, at commit: String?, repoPath: String) -> URL? {
        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
        let encodedPath = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file
        var link = "\(scheme)://file/\(repoName)/\(encodedPath)?line=\(line)"
        if let commit = commit {
            link += "&ref=\(commit)"
        }
        return URL(string: link)
    }
    
    /// Generate a deep link to open a repository
    func linkToRepository(path: String) -> URL? {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: "\(scheme)://open?path=\(encodedPath)")
    }
    
    /// Generate a GitHub-compatible web link to a commit
    func webLinkToCommit(sha: String, owner: String, repo: String) -> URL? {
        URL(string: "https://github.com/\(owner)/\(repo)/commit/\(sha)")
    }
    
    /// Generate a GitHub-compatible web link to a branch
    func webLinkToBranch(name: String, owner: String, repo: String) -> URL? {
        let encodedBranch = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return URL(string: "https://github.com/\(owner)/\(repo)/tree/\(encodedBranch)")
    }
    
    // MARK: - Link Parsing
    
    struct DeepLink {
        enum LinkType {
            case commit(repoName: String, sha: String)
            case branch(repoName: String, name: String)
            case file(repoName: String, path: String, ref: String?, line: Int?)
            case open(path: String)
        }
        
        let type: LinkType
        let url: URL
    }
    
    /// Parse a deep link URL
    func parseLink(_ url: URL) -> DeepLink? {
        guard url.scheme == scheme else { return nil }
        
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch host {
        case "commit":
            guard pathComponents.count >= 2 else { return nil }
            return DeepLink(
                type: .commit(repoName: pathComponents[0], sha: pathComponents[1]),
                url: url
            )
            
        case "branch":
            guard pathComponents.count >= 2 else { return nil }
            let branchName = pathComponents.dropFirst().joined(separator: "/")
            return DeepLink(
                type: .branch(repoName: pathComponents[0], name: branchName),
                url: url
            )
            
        case "file":
            guard pathComponents.count >= 2 else { return nil }
            let filePath = pathComponents.dropFirst().joined(separator: "/")
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let ref = queryItems?.first(where: { $0.name == "ref" })?.value
            let line = queryItems?.first(where: { $0.name == "line" })?.value.flatMap { Int($0) }
            return DeepLink(
                type: .file(repoName: pathComponents[0], path: filePath, ref: ref, line: line),
                url: url
            )
            
        case "open":
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            guard let path = queryItems?.first(where: { $0.name == "path" })?.value else { return nil }
            return DeepLink(
                type: .open(path: path),
                url: url
            )
            
        default:
            return nil
        }
    }
    
    // MARK: - Clipboard
    
    /// Copy a deep link to the clipboard
    func copyLinkToClipboard(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }
    
    /// Copy a formatted link (markdown) to clipboard
    func copyMarkdownLink(title: String, url: URL) {
        let markdown = "[\(title)](\(url.absoluteString))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }
}

// MARK: - Notification for handling deep links

extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
}
