import SwiftUI
import Foundation

/// GitHub Integration - Pull Requests, Issues, and OAuth
/// Provides seamless integration with GitHub API
class GitHubIntegration: ObservableObject {
    static let shared = GitHubIntegration()
    
    @Published var isAuthenticated = false
    @Published var currentUser: GitHubUser?
    @Published var pullRequests: [GitHubPullRequest] = []
    @Published var issues: [GitHubIssue] = []
    @Published var isLoading = false
    
    private let clientId = "YOUR_GITHUB_CLIENT_ID" // TODO: Replace with actual client ID
    private let clientSecret = "YOUR_GITHUB_CLIENT_SECRET" // TODO: Replace
    private let redirectUri = "gitmac://oauth-callback"
    
    private var accessToken: String? {
        get { GHIKeychainHelper.get(key: "github_access_token") }
        set {
            if let token = newValue {
                GHIKeychainHelper.set(key: "github_access_token", value: token)
            } else {
                GHIKeychainHelper.delete(key: "github_access_token")
            }
        }
    }
    
    private let baseURL = "https://api.github.com"
    
    init() {
        checkAuthentication()
    }
    
    // MARK: - Authentication
    
    func authenticate() {
        let authURL = "https://github.com/login/oauth/authorize?client_id=\(clientId)&redirect_uri=\(redirectUri)&scope=repo,user"
        
        if let url = URL(string: authURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func handleOAuthCallback(code: String) async {
        isLoading = true
        
        do {
            let token = try await exchangeCodeForToken(code: code)
            accessToken = token
            isAuthenticated = true
            
            await loadCurrentUser()
            
            NotificationManager.shared.success("GitHub authenticated successfully")
        } catch {
            NotificationManager.shared.error("GitHub authentication failed", detail: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func logout() {
        accessToken = nil
        isAuthenticated = false
        currentUser = nil
        pullRequests = []
        issues = []
        
        NotificationManager.shared.info("Logged out from GitHub")
    }
    
    private func checkAuthentication() {
        isAuthenticated = accessToken != nil
        
        if isAuthenticated {
            Task {
                await loadCurrentUser()
            }
        }
    }
    
    // MARK: - API Methods
    
    func loadCurrentUser() async {
        guard let user = try? await fetchUser() else { return }
        currentUser = user
    }
    
    func loadPullRequests(owner: String, repo: String) async {
        isLoading = true
        
        do {
            pullRequests = try await fetchPullRequests(owner: owner, repo: repo)
        } catch {
            NotificationManager.shared.error("Failed to load pull requests", detail: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func loadIssues(owner: String, repo: String) async {
        isLoading = true
        
        do {
            issues = try await fetchIssues(owner: owner, repo: repo)
        } catch {
            NotificationManager.shared.error("Failed to load issues", detail: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func createPullRequest(owner: String, repo: String, title: String, body: String, head: String, base: String) async throws -> GitHubPullRequest {
        let endpoint = "/repos/\(owner)/\(repo)/pulls"
        
        let parameters: [String: Any] = [
            "title": title,
            "body": body,
            "head": head,
            "base": base
        ]
        
        let pr: GitHubPullRequest = try await request(endpoint: endpoint, method: "POST", parameters: parameters)
        
        NotificationManager.shared.success("Pull request created", detail: "#\(pr.number): \(pr.title)")
        
        return pr
    }
    
    func createIssue(owner: String, repo: String, title: String, body: String, labels: [String] = []) async throws -> GitHubIssue {
        let endpoint = "/repos/\(owner)/\(repo)/issues"
        
        let parameters: [String: Any] = [
            "title": title,
            "body": body,
            "labels": labels
        ]
        
        let issue: GitHubIssue = try await request(endpoint: endpoint, method: "POST", parameters: parameters)
        
        NotificationManager.shared.success("Issue created", detail: "#\(issue.number): \(issue.title)")
        
        return issue
    }
    
    func commentOnPullRequest(owner: String, repo: String, number: Int, body: String) async throws {
        let endpoint = "/repos/\(owner)/\(repo)/issues/\(number)/comments"
        
        let parameters: [String: Any] = [
            "body": body
        ]
        
        let _: GitHubComment = try await request(endpoint: endpoint, method: "POST", parameters: parameters)
        
        NotificationManager.shared.success("Comment added to PR #\(number)")
    }
    
    // MARK: - Private API Helpers
    
    private func exchangeCodeForToken(code: String) async throws -> String {
        let tokenURL = "https://github.com/login/oauth/access_token"
        
        let parameters: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": redirectUri
        ]
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["access_token"] as? String {
            return token
        }
        
        throw GitHubError.authenticationFailed
    }
    
    private func fetchUser() async throws -> GitHubUser {
        return try await request(endpoint: "/user")
    }
    
    private func fetchPullRequests(owner: String, repo: String) async throws -> [GitHubPullRequest] {
        return try await request(endpoint: "/repos/\(owner)/\(repo)/pulls")
    }
    
    private func fetchIssues(owner: String, repo: String) async throws -> [GitHubIssue] {
        return try await request(endpoint: "/repos/\(owner)/\(repo)/issues")
    }
    
    private func request<T: Decodable>(endpoint: String, method: String = "GET", parameters: [String: Any]? = nil) async throws -> T {
        guard let token = accessToken else {
            throw GitHubError.notAuthenticated
        }
        
        var urlComponents = URLComponents(string: baseURL + endpoint)!
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        if let parameters = parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.apiError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Models (Using types from GitHubService.swift)
// Types GitHubUser, GitHubPullRequest, GitHubIssue, GitHubLabel are defined in GitHubService.swift

// Local types needed for this integration
fileprivate struct GHIBranch: Codable {
    let ref: String
    let sha: String
    let label: String
}

fileprivate struct GHIComment: Codable, Identifiable {
    let id: Int
    let body: String
    let user: GHIUser
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case createdAt = "created_at"
    }
}

fileprivate struct GHIUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let avatarUrl: String
    let bio: String?
    let publicRepos: Int

    enum CodingKeys: String, CodingKey {
        case id, login, name, bio
        case avatarUrl = "avatar_url"
        case publicRepos = "public_repos"
    }
}

fileprivate struct GHIPullRequest: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let user: GHIUser
    let createdAt: Date
    let updatedAt: Date
    let head: GHIBranch
    let base: GHIBranch
    let mergeable: Bool?
    let merged: Bool

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, head, base, mergeable, merged
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

fileprivate struct GHIIssue: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let user: GHIUser
    let labels: [GHILabel]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

fileprivate struct GHILabel: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}

// MARK: - Errors

fileprivate enum GHIError: LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case invalidResponse
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with GitHub"
        case .authenticationFailed:
            return "GitHub authentication failed"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .apiError(let statusCode, let message):
            return "GitHub API error (\(statusCode)): \(message ?? "Unknown error")"
        }
    }
}

// MARK: - Keychain Helper (uses existing KeychainManager from Core/Utils)

fileprivate struct GHIKeychainHelper {
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.gitmac.github",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func set(key: String, value: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.gitmac.github",
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.gitmac.github",
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - GitHub View

struct GitHubIntegrationView: View {
    @StateObject private var github = GitHubIntegration.shared
    @State private var selectedTab = 0
    @State private var showCreatePR = false
    @State private var showCreateIssue = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !github.isAuthenticated {
                loginView
            } else {
                authenticatedView
            }
        }
    }
    
    // MARK: - Login View
    
    private var loginView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.accent)
            
            Text("Connect to GitHub")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Access pull requests, issues, and more")
                .foregroundColor(AppTheme.textPrimary)
            
            Button {
                github.authenticate()
            } label: {
                Label("Sign in with GitHub", systemImage: "person.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Authenticated View
    
    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let user = github.currentUser {
                    AsyncImage(url: URL(string: user.avatarUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        AppTheme.textMuted
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name ?? user.login)
                            .font(.headline)
                        Text("@\(user.login)")
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                
                Spacer()
                
                Button("Logout") {
                    github.logout()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Tabs
            TabView(selection: $selectedTab) {
                pullRequestsTab
                    .tabItem {
                        Label("Pull Requests", systemImage: "arrow.triangle.pull")
                    }
                    .tag(0)
                
                issuesTab
                    .tabItem {
                        Label("Issues", systemImage: "exclamationmark.circle")
                    }
                    .tag(1)
            }
        }
    }
    
    // MARK: - Pull Requests Tab
    
    private var pullRequestsTab: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(github.pullRequests.count) pull requests")
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Button {
                    showCreatePR = true
                } label: {
                    Label("New PR", systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // List
            if github.pullRequests.isEmpty {
                emptyState(icon: "arrow.triangle.pull", message: "No pull requests")
            } else {
                List(github.pullRequests) { pr in
                    PullRequestRow(pr: pr)
                }
            }
        }
        .sheet(isPresented: $showCreatePR) {
            CreatePullRequestSheet()
        }
    }
    
    // MARK: - Issues Tab
    
    private var issuesTab: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(github.issues.count) issues")
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Button {
                    showCreateIssue = true
                } label: {
                    Label("New Issue", systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // List
            if github.issues.isEmpty {
                emptyState(icon: "exclamationmark.circle", message: "No issues")
            } else {
                List(github.issues) { issue in
                    IssueRow(issue: issue)
                }
            }
        }
        .sheet(isPresented: $showCreateIssue) {
            CreateIssueSheet()
        }
    }
    
    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            Text(message)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct PullRequestRow: View {
    let pr: GitHubPullRequest
    
    var body: some View {
        HStack {
            Image(systemName: pr.state == "open" ? "circle.fill" : "checkmark.circle.fill")
                .foregroundColor(pr.state == "open" ? .green : .purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pr.title)
                    .font(.headline)
                
                Text("#\(pr.number) by @\(pr.user.login)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct IssueRow: View {
    let issue: GitHubIssue
    
    var body: some View {
        HStack {
            Image(systemName: issue.state == "open" ? "circle.fill" : "checkmark.circle.fill")
                .foregroundColor(issue.state == "open" ? .green : .purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.headline)
                
                HStack {
                    Text("#\(issue.number)")
                    ForEach(issue.labels.prefix(3)) { label in
                        Text(label.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: label.color).opacity(0.3))
                            .cornerRadius(4)
                    }
                }
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CreatePullRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var body = ""
    @State private var base = "main"
    @State private var head = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Pull Request")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                TextField("Title", text: $title)
                TextField("Head branch", text: $head)
                TextField("Base branch", text: $base)
                TextEditor(text: $body)
                    .frame(height: 150)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    // TODO: Create PR
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct CreateIssueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var body = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Issue")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                TextField("Title", text: $title)
                TextEditor(text: $body)
                    .frame(height: 200)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    // TODO: Create issue
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
