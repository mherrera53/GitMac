import Foundation
import CryptoKit

// MARK: - Cloud Patch Service

/// Service for creating and sharing code patches without committing
/// Advanced feature's Cloud Patches feature
actor CloudPatchService {
    static let shared = CloudPatchService()
    
    private let baseURL = "https://api.github.com/gists" // Using GitHub Gists as backend
    private var token: String?
    
    // MARK: - Models
    
    struct CloudPatch: Identifiable, Codable {
        let id: String
        let title: String
        let description: String?
        let files: [PatchFile]
        let createdAt: Date
        let expiresAt: Date?
        let shareURL: String
        let isPublic: Bool
        let author: String
        
        struct PatchFile: Codable {
            let filename: String
            let content: String
            let language: String?
        }
    }
    
    struct CreatePatchRequest {
        let title: String
        let description: String?
        let diff: String
        let files: [String]
        let isPublic: Bool
        let expiresIn: TimeInterval? // nil = never expires
    }
    
    // MARK: - Configuration
    
    func configure(token: String) {
        self.token = token
    }
    
    // MARK: - Create Patch
    
    /// Create a cloud patch from staged changes
    func createPatch(from request: CreatePatchRequest) async throws -> CloudPatch {
        guard let token = token else {
            throw CloudPatchError.notAuthenticated
        }
        
        // Create gist payload
        var gistFiles: [String: [String: String]] = [:]
        
        // Add the patch file
        gistFiles["patch.diff"] = [
            "content": request.diff
        ]
        
        // Add metadata
        let metadata: [String: Any] = [
            "title": request.title,
            "description": request.description ?? "",
            "files": request.files,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": request.expiresIn.map { ISO8601DateFormatter().string(from: Date().addingTimeInterval($0)) } as Any
        ]
        
        if let metadataJSON = try? JSONSerialization.data(withJSONObject: metadata),
           let metadataString = String(data: metadataJSON, encoding: .utf8) {
            gistFiles["metadata.json"] = ["content": metadataString]
        }
        
        let payload: [String: Any] = [
            "description": "GitMac Cloud Patch: \(request.title)",
            "public": request.isPublic,
            "files": gistFiles
        ]
        
        // Create the gist
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw CloudPatchError.createFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gistId = json["id"] as? String,
              let htmlURL = json["html_url"] as? String,
              let owner = json["owner"] as? [String: Any],
              let ownerLogin = owner["login"] as? String else {
            throw CloudPatchError.invalidResponse
        }
        
        return CloudPatch(
            id: gistId,
            title: request.title,
            description: request.description,
            files: request.files.map { CloudPatch.PatchFile(filename: $0, content: "", language: nil) },
            createdAt: Date(),
            expiresAt: request.expiresIn.map { Date().addingTimeInterval($0) },
            shareURL: htmlURL,
            isPublic: request.isPublic,
            author: ownerLogin
        )
    }
    
    /// Generate a short shareable link
    func generateShareLink(for patch: CloudPatch) -> String {
        // Create a short link format: gitmac://patch/{id}
        return "gitmac://patch/\(patch.id)"
    }
    
    // MARK: - Retrieve Patch
    
    /// Fetch a cloud patch by ID
    func getPatch(id: String) async throws -> CloudPatch {
        guard let token = token else {
            throw CloudPatchError.notAuthenticated
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/\(id)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudPatchError.notFound
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let htmlURL = json["html_url"] as? String,
              let owner = json["owner"] as? [String: Any],
              let ownerLogin = owner["login"] as? String,
              let files = json["files"] as? [String: [String: Any]],
              let createdAtStr = json["created_at"] as? String,
              let createdAt = ISO8601DateFormatter().date(from: createdAtStr) else {
            throw CloudPatchError.invalidResponse
        }
        
        // Parse metadata if available
        var title = "Untitled Patch"
        var description: String?
        var fileList: [String] = []
        
        if let metadataFile = files["metadata.json"],
           let content = metadataFile["content"] as? String,
           let metadataData = content.data(using: .utf8),
           let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
            title = metadata["title"] as? String ?? title
            description = metadata["description"] as? String
            fileList = metadata["files"] as? [String] ?? []
        }
        
        let isPublic = json["public"] as? Bool ?? true
        
        let patchFiles = files.compactMap { (filename, fileData) -> CloudPatch.PatchFile? in
            guard let content = fileData["content"] as? String else { return nil }
            let language = fileData["language"] as? String
            return CloudPatch.PatchFile(filename: filename, content: content, language: language)
        }
        
        return CloudPatch(
            id: id,
            title: title,
            description: description,
            files: patchFiles,
            createdAt: createdAt,
            expiresAt: nil,
            shareURL: htmlURL,
            isPublic: isPublic,
            author: ownerLogin
        )
    }
    
    // MARK: - Apply Patch
    
    /// Apply a cloud patch to a repository
    func applyPatch(_ patch: CloudPatch, to repoPath: String) async throws {
        guard let patchFile = patch.files.first(where: { $0.filename == "patch.diff" }) else {
            throw CloudPatchError.noPatchContent
        }
        
        // Write patch to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloudpatch-\(patch.id).diff")
        try patchFile.content.write(to: tempURL, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Apply the patch
        let result = try await ShellExecutor.shared.execute(
            "cd '\(repoPath)' && git apply '\(tempURL.path)'"
        )
        
        if !result.output.isEmpty && result.output.contains("error") {
            throw CloudPatchError.applyFailed(result.output)
        }
    }
    
    // MARK: - List My Patches
    
    /// List all cloud patches created by the user
    func listMyPatches() async throws -> [CloudPatch] {
        guard let token = token else {
            throw CloudPatchError.notAuthenticated
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)?per_page=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let gists = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw CloudPatchError.invalidResponse
        }
        
        return gists.compactMap { gist -> CloudPatch? in
            guard let id = gist["id"] as? String,
                  let description = gist["description"] as? String,
                  description.hasPrefix("GitMac Cloud Patch:"),
                  let htmlURL = gist["html_url"] as? String,
                  let owner = gist["owner"] as? [String: Any],
                  let ownerLogin = owner["login"] as? String,
                  let createdAtStr = gist["created_at"] as? String,
                  let createdAt = ISO8601DateFormatter().date(from: createdAtStr) else {
                return nil
            }
            
            let title = description.replacingOccurrences(of: "GitMac Cloud Patch: ", with: "")
            let isPublic = gist["public"] as? Bool ?? true
            
            return CloudPatch(
                id: id,
                title: title,
                description: nil,
                files: [],
                createdAt: createdAt,
                expiresAt: nil,
                shareURL: htmlURL,
                isPublic: isPublic,
                author: ownerLogin
            )
        }
    }
    
    // MARK: - Delete Patch
    
    func deletePatch(id: String) async throws {
        guard let token = token else {
            throw CloudPatchError.notAuthenticated
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/\(id)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw CloudPatchError.deleteFailed
        }
    }
}

// MARK: - Errors

enum CloudPatchError: LocalizedError {
    case notAuthenticated
    case createFailed
    case notFound
    case invalidResponse
    case noPatchContent
    case applyFailed(String)
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please configure GitHub token."
        case .createFailed: return "Failed to create cloud patch"
        case .notFound: return "Cloud patch not found"
        case .invalidResponse: return "Invalid response from server"
        case .noPatchContent: return "No patch content found"
        case .applyFailed(let msg): return "Failed to apply patch: \(msg)"
        case .deleteFailed: return "Failed to delete cloud patch"
        }
    }
}
