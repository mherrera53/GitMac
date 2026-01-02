//
//  CodeReviewService.swift
//  GitMac
//
//  Advanced code review tools with inline comments and review sessions
//

import SwiftUI
import Combine

// MARK: - Review Comment Model

struct ReviewComment: Identifiable, Codable, Equatable {
    let id: UUID
    let author: String
    let authorEmail: String
    let lineNumber: Int
    let lineNumberEnd: Int?  // For multi-line comments
    let filePath: String
    var content: String
    let timestamp: Date
    var replies: [ReviewComment]
    var isResolved: Bool
    var suggestedCode: String?
    var diffSide: DiffSide  // left (deletion) or right (addition)
    
    enum DiffSide: String, Codable {
        case left
        case right
    }
    
    init(
        author: String,
        authorEmail: String,
        lineNumber: Int,
        lineNumberEnd: Int? = nil,
        filePath: String,
        content: String,
        suggestedCode: String? = nil,
        diffSide: DiffSide = .right
    ) {
        self.id = UUID()
        self.author = author
        self.authorEmail = authorEmail
        self.lineNumber = lineNumber
        self.lineNumberEnd = lineNumberEnd
        self.filePath = filePath
        self.content = content
        self.timestamp = Date()
        self.replies = []
        self.isResolved = false
        self.suggestedCode = suggestedCode
        self.diffSide = diffSide
    }
    
    var gravatarURL: URL? {
        let hash = authorEmail.lowercased().trimmingCharacters(in: .whitespaces).md5Hash
        return URL(string: "https://www.gravatar.com/avatar/\(hash)?d=identicon&s=32")
    }
    
    var lineRange: String {
        if let end = lineNumberEnd, end != lineNumber {
            return "L\(lineNumber)-\(end)"
        }
        return "L\(lineNumber)"
    }
}

// MARK: - Review Session Model

struct ReviewSession: Identifiable, Codable {
    let id: UUID
    let repositoryPath: String
    let baseBranch: String  // Target branch (e.g., "main")
    let headBranch: String  // Source branch (e.g., "feature/new-feature")
    let baseCommit: String
    let headCommit: String
    var title: String
    var description: String
    var status: ReviewStatus
    var comments: [ReviewComment]
    let createdBy: String
    let createdAt: Date
    var reviewers: [Reviewer]
    var labels: [String]
    
    enum ReviewStatus: String, Codable, CaseIterable {
        case draft = "draft"
        case pending = "pending"
        case approved = "approved"
        case changesRequested = "changes_requested"
        case merged = "merged"
        case closed = "closed"
        
        var displayName: String {
            switch self {
            case .draft: return "Draft"
            case .pending: return "Pending Review"
            case .approved: return "Approved"
            case .changesRequested: return "Changes Requested"
            case .merged: return "Merged"
            case .closed: return "Closed"
            }
        }
        
        var icon: String {
            switch self {
            case .draft: return "doc.text"
            case .pending: return "clock"
            case .approved: return "checkmark.circle.fill"
            case .changesRequested: return "exclamationmark.circle.fill"
            case .merged: return "arrow.triangle.merge"
            case .closed: return "xmark.circle"
            }
        }
        
        @MainActor var color: Color {
            switch self {
            case .draft: return AppTheme.textMuted
            case .pending: return AppTheme.warning
            case .approved: return AppTheme.success
            case .changesRequested: return AppTheme.error
            case .merged: return Color.purple
            case .closed: return AppTheme.textSecondary
            }
        }
    }
    
    struct Reviewer: Identifiable, Codable, Equatable {
        var id: String { email }
        let name: String
        let email: String
        var status: ReviewerStatus
        var reviewedAt: Date?
        
        enum ReviewerStatus: String, Codable {
            case pending = "pending"
            case approved = "approved"
            case changesRequested = "changes_requested"
            case commented = "commented"
        }
    }
    
    init(
        repositoryPath: String,
        baseBranch: String,
        headBranch: String,
        baseCommit: String,
        headCommit: String,
        title: String,
        createdBy: String
    ) {
        self.id = UUID()
        self.repositoryPath = repositoryPath
        self.baseBranch = baseBranch
        self.headBranch = headBranch
        self.baseCommit = baseCommit
        self.headCommit = headCommit
        self.title = title
        self.description = ""
        self.status = .draft
        self.comments = []
        self.createdBy = createdBy
        self.createdAt = Date()
        self.reviewers = []
        self.labels = []
    }
    
    var unresolvedComments: [ReviewComment] {
        comments.filter { !$0.isResolved }
    }
    
    var fileComments: [String: [ReviewComment]] {
        Dictionary(grouping: comments, by: { $0.filePath })
    }
}

// MARK: - Code Review Service

@MainActor
class CodeReviewService: ObservableObject {
    static let shared = CodeReviewService()
    
    // MARK: - Published Properties
    
    @Published var sessions: [ReviewSession] = []
    @Published var activeSession: ReviewSession?
    @Published var isLoading = false
    
    private let storageKey = "com.gitmac.codeReviewSessions"
    
    private init() {
        loadSessions()
    }
    
    // MARK: - Session Management
    
    func createSession(
        repositoryPath: String,
        baseBranch: String,
        headBranch: String,
        title: String,
        createdBy: String
    ) async throws -> ReviewSession {
        isLoading = true
        defer { isLoading = false }
        
        // Get commit hashes for branches
        let baseCommit = try await getCommitHash(for: baseBranch, in: repositoryPath)
        let headCommit = try await getCommitHash(for: headBranch, in: repositoryPath)
        
        var session = ReviewSession(
            repositoryPath: repositoryPath,
            baseBranch: baseBranch,
            headBranch: headBranch,
            baseCommit: baseCommit,
            headCommit: headCommit,
            title: title,
            createdBy: createdBy
        )
        
        // Generate description using AI if available
        if let description = try? await generateSessionDescription(session) {
            session.description = description
        }
        
        sessions.append(session)
        saveSessions()
        
        return session
    }
    
    func getSession(id: UUID) -> ReviewSession? {
        sessions.first { $0.id == id }
    }
    
    func updateSession(_ session: ReviewSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions()
        }
    }
    
    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSession?.id == id {
            activeSession = nil
        }
        saveSessions()
    }
    
    // MARK: - Comment Operations
    
    func addComment(
        to sessionId: UUID,
        filePath: String,
        lineNumber: Int,
        content: String,
        author: String,
        authorEmail: String,
        suggestedCode: String? = nil,
        diffSide: ReviewComment.DiffSide = .right
    ) {
        guard var session = getSession(id: sessionId) else { return }
        
        let comment = ReviewComment(
            author: author,
            authorEmail: authorEmail,
            lineNumber: lineNumber,
            filePath: filePath,
            content: content,
            suggestedCode: suggestedCode,
            diffSide: diffSide
        )
        
        session.comments.append(comment)
        updateSession(session)
    }
    
    func addReply(
        to commentId: UUID,
        in sessionId: UUID,
        content: String,
        author: String,
        authorEmail: String
    ) {
        guard var session = getSession(id: sessionId) else { return }
        
        if let index = session.comments.firstIndex(where: { $0.id == commentId }) {
            let reply = ReviewComment(
                author: author,
                authorEmail: authorEmail,
                lineNumber: session.comments[index].lineNumber,
                filePath: session.comments[index].filePath,
                content: content,
                diffSide: session.comments[index].diffSide
            )
            session.comments[index].replies.append(reply)
            updateSession(session)
        }
    }
    
    func resolveComment(commentId: UUID, in sessionId: UUID) {
        guard var session = getSession(id: sessionId) else { return }
        
        if let index = session.comments.firstIndex(where: { $0.id == commentId }) {
            session.comments[index].isResolved = true
            updateSession(session)
        }
    }
    
    func unresolveComment(commentId: UUID, in sessionId: UUID) {
        guard var session = getSession(id: sessionId) else { return }
        
        if let index = session.comments.firstIndex(where: { $0.id == commentId }) {
            session.comments[index].isResolved = false
            updateSession(session)
        }
    }
    
    func deleteComment(commentId: UUID, from sessionId: UUID) {
        guard var session = getSession(id: sessionId) else { return }
        session.comments.removeAll { $0.id == commentId }
        updateSession(session)
    }
    
    // MARK: - Review Status
    
    func approveReview(sessionId: UUID, reviewer: String, reviewerEmail: String) {
        guard var session = getSession(id: sessionId) else { return }
        
        if let index = session.reviewers.firstIndex(where: { $0.email == reviewerEmail }) {
            session.reviewers[index].status = .approved
            session.reviewers[index].reviewedAt = Date()
        } else {
            session.reviewers.append(ReviewSession.Reviewer(
                name: reviewer,
                email: reviewerEmail,
                status: .approved,
                reviewedAt: Date()
            ))
        }
        
        // Update session status if all reviewers approved
        let allApproved = session.reviewers.allSatisfy { $0.status == .approved }
        if allApproved && !session.reviewers.isEmpty {
            session.status = .approved
        }
        
        updateSession(session)
    }
    
    func requestChanges(sessionId: UUID, reviewer: String, reviewerEmail: String) {
        guard var session = getSession(id: sessionId) else { return }
        
        if let index = session.reviewers.firstIndex(where: { $0.email == reviewerEmail }) {
            session.reviewers[index].status = .changesRequested
            session.reviewers[index].reviewedAt = Date()
        } else {
            session.reviewers.append(ReviewSession.Reviewer(
                name: reviewer,
                email: reviewerEmail,
                status: .changesRequested,
                reviewedAt: Date()
            ))
        }
        
        session.status = .changesRequested
        updateSession(session)
    }
    
    // MARK: - Git Operations
    
    private let shell = ShellExecutor()
    
    private func getCommitHash(for branch: String, in repoPath: String) async throws -> String {
        let result = await shell.execute(
            "git", arguments: ["rev-parse", branch],
            workingDirectory: repoPath
        )
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    func getDiff(for session: ReviewSession) async throws -> String {
        let result = await shell.execute(
            "git", arguments: ["diff", "\(session.baseCommit)...\(session.headCommit)"],
            workingDirectory: session.repositoryPath
        )
        return result.output
    }
    
    func getCommits(for session: ReviewSession) async throws -> [String] {
        let result = await shell.execute(
            "git", arguments: ["log", "--oneline", "\(session.baseCommit)..\(session.headCommit)"],
            workingDirectory: session.repositoryPath
        )
        return result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    func getChangedFiles(for session: ReviewSession) async throws -> [String] {
        let result = await shell.execute(
            "git", arguments: ["diff", "--name-only", "\(session.baseCommit)...\(session.headCommit)"],
            workingDirectory: session.repositoryPath
        )
        return result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    // MARK: - AI Integration
    
    private func generateSessionDescription(_ session: ReviewSession) async throws -> String {
        let commits = try await getCommits(for: session)
        let diff = try await getDiff(for: session)
        
        let prSummary = try await AIService.shared.generatePRSummary(
            commits: commits,
            diff: diff,
            template: .default
        )
        
        return prSummary.markdownDescription
    }
    
    // MARK: - Persistence
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ReviewSession].self, from: data) else {
            return
        }
        sessions = decoded
    }
    
    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Code Review Panel Component

struct CodeReviewPanel: View {
    let session: ReviewSession
    @StateObject private var service = CodeReviewService.shared
    @State private var newCommentText = ""
    @State private var showingAddReviewer = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Label(session.headBranch, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(AppTheme.accent)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textMuted)
                        
                        Label(session.baseBranch, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: session.status.icon)
                    Text(session.status.displayName)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(session.status.color)
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
            
            Divider()
            
            // Comments list
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(session.comments) { comment in
                        ReviewCommentView(
                            comment: comment,
                            sessionId: session.id
                        )
                    }
                    
                    if session.comments.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textMuted)
                            
                            Text("No comments yet")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xxl)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Review actions
            HStack {
                Button {
                    service.requestChanges(
                        sessionId: session.id,
                        reviewer: "You",
                        reviewerEmail: "you@example.com"
                    )
                } label: {
                    Label("Request Changes", systemImage: "exclamationmark.circle")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    service.approveReview(
                        sessionId: session.id,
                        reviewer: "You",
                        reviewerEmail: "you@example.com"
                    )
                } label: {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
        }
    }
}

// MARK: - Review Comment View

struct ReviewCommentView: View {
    let comment: ReviewComment
    let sessionId: UUID
    @StateObject private var service = CodeReviewService.shared
    @State private var isReplying = false
    @State private var replyText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Comment header
            HStack {
                AsyncImage(url: comment.gravatarURL) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                Text(comment.author)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(comment.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
                
                Spacer()
                
                // File and line info
                Text("\(comment.filePath.components(separatedBy: "/").last ?? ""):\(comment.lineRange)")
                    .font(.caption.monospaced())
                    .foregroundColor(AppTheme.accent)
                
                if comment.isResolved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                }
            }
            
            // Comment content
            Text(comment.content)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
            
            // Suggested code
            if let suggestion = comment.suggestedCode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested change:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(suggestion)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(8)
                        .background(AppTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
            }
            
            // Replies
            if !comment.replies.isEmpty {
                ForEach(comment.replies) { reply in
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(width: 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(reply.author)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Text(reply.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            
                            Text(reply.content)
                                .font(.caption)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                    .padding(.leading, DesignTokens.Spacing.md)
                }
            }
            
            // Actions
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("Reply") {
                    isReplying.toggle()
                }
                .font(.caption)
                
                Button(comment.isResolved ? "Unresolve" : "Resolve") {
                    if comment.isResolved {
                        service.unresolveComment(commentId: comment.id, in: sessionId)
                    } else {
                        service.resolveComment(commentId: comment.id, in: sessionId)
                    }
                }
                .font(.caption)
            }
            .foregroundColor(AppTheme.accent)
            
            // Reply input
            if isReplying {
                HStack {
                    TextField("Write a reply...", text: $replyText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Send") {
                        service.addReply(
                            to: comment.id,
                            in: sessionId,
                            content: replyText,
                            author: "You",
                            authorEmail: "you@example.com"
                        )
                        replyText = ""
                        isReplying = false
                    }
                    .disabled(replyText.isEmpty)
                }
            }
        }
        .padding()
        .background(comment.isResolved ? AppTheme.success.opacity(0.05) : AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(comment.isResolved ? AppTheme.success.opacity(0.3) : AppTheme.border, lineWidth: 1)
        )
    }
}
