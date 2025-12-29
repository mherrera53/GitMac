import SwiftUI
import Combine

// MARK: - Launchpad View

/// Unified view of Pull Requests and Issues across all repositories
struct LaunchpadView: View {
    @StateObject private var viewModel = LaunchpadViewModel()
    @State private var selectedTab: LaunchpadTab = .pullRequests
    @State private var selectedFilter: LaunchpadFilter = .all
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView
            tabBar
            filterBar

            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingView
            } else if filteredItems.isEmpty {
                emptyView
            } else {
                contentList
            }

            statusBar
        }
        .task {
            await viewModel.refresh()
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "rocket.fill")
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(AppTheme.accent)

            Text("Launchpad")
                .font(DesignTokens.Typography.subheadline)

            Spacer()

            Menu {
                Button("My Pull Requests") {
                    selectedFilter = .mine
                    selectedTab = .pullRequests
                }
                Button("Needs Review") {
                    selectedFilter = .needsReview
                    selectedTab = .pullRequests
                }
                Button("Assigned Issues") {
                    selectedFilter = .assigned
                    selectedTab = .issues
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "bookmark")
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Views")
                }
                .font(DesignTokens.Typography.caption)
            }
            .menuStyle(.borderlessButton)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LaunchpadTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation { selectedTab = tab }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                        Image(systemName: tab.icon)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(tab.title)
                        if let count = viewModel.count(for: tab) {
                            Text("\(count)")
                                .font(DesignTokens.Typography.caption2)
                                .padding(.horizontal, DesignTokens.Spacing.xs + 1)
                                .padding(.vertical, 1)  // Precise 1px for tight badge padding
                                .background(selectedTab == tab ? AppTheme.textPrimary.opacity(0.3) : AppTheme.textMuted.opacity(0.2))
                                .cornerRadius(DesignTokens.CornerRadius.sm)
                        }
                    }
                    .font(DesignTokens.Typography.callout)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(selectedTab == tab ? tab.color : Color.clear)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .background(AppTheme.textMuted.opacity(0.1))
    }

    private var filterBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textPrimary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            .background(AppTheme.textMuted.opacity(0.1))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .frame(maxWidth: 200)

            ForEach(LaunchpadFilter.allCases, id: \.self) { filter in
                LaunchpadFilterChip(title: filter.title, isSelected: selectedFilter == filter) {
                    selectedFilter = filter
                }
            }

            Spacer()

            Menu {
                Button("All Repositories") { viewModel.selectedRepo = nil }
                Divider()
                ForEach(viewModel.repositories, id: \.self) { repo in
                    Button(repo) { viewModel.selectedRepo = repo }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "folder")
                        .foregroundColor(AppTheme.textSecondary)
                    Text(viewModel.selectedRepo ?? "All Repos")
                    Image(systemName: "chevron.down")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.chevronColor)
                }
                .font(DesignTokens.Typography.caption)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(AppTheme.textMuted.opacity(0.1))
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(DesignTokens.Spacing.md)
    }

    private var filteredItems: [LaunchpadItem] {
        var items = viewModel.items

        switch selectedTab {
        case .pullRequests: items = items.filter { $0.type == .pullRequest }
        case .issues: items = items.filter { $0.type == .issue }
        case .actions: items = items.filter { $0.type == .action }
        }

        switch selectedFilter {
        case .all: break
        case .mine: items = items.filter { $0.isAuthoredByMe }
        case .needsReview: items = items.filter { $0.needsMyReview }
        case .assigned: items = items.filter { $0.isAssignedToMe }
        case .mentioned: items = items.filter { $0.mentionsMe }
        }

        if let repo = viewModel.selectedRepo {
            items = items.filter { $0.repository == repo }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.repository.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    private var contentList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    LaunchpadItemRow(item: item)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
            Text("Loading...").font(DesignTokens.Typography.callout).foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: selectedTab.icon)
                .font(DesignTokens.Typography.title3)
                .foregroundColor(AppTheme.textPrimary)
            Text("No \(selectedTab.title.lowercased()) found")
                .font(DesignTokens.Typography.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack {
            if viewModel.isLoading { ProgressView().scaleEffect(0.6) }
            Text("\(filteredItems.count) items").font(DesignTokens.Typography.caption2).foregroundColor(AppTheme.textPrimary)
            Spacer()
            if let lastUpdate = viewModel.lastUpdate {
                Text("Updated \(lastUpdate, style: .relative) ago").font(DesignTokens.Typography.caption2).foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
        .background(AppTheme.textMuted.opacity(0.05))
    }
}

// MARK: - Types

enum LaunchpadTab: CaseIterable {
    case pullRequests, issues, actions

    var title: String {
        switch self {
        case .pullRequests: return "Pull Requests"
        case .issues: return "Issues"
        case .actions: return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .pullRequests: return "arrow.triangle.pull"
        case .issues: return "exclamationmark.circle"
        case .actions: return "bolt.circle"
        }
    }

    @MainActor
    var color: Color {
        switch self {
        case .pullRequests: return AppTheme.gitModified
        case .issues: return AppTheme.success
        case .actions: return AppTheme.warning
        }
    }
}

enum LaunchpadFilter: CaseIterable {
    case all, mine, needsReview, assigned, mentioned

    var title: String {
        switch self {
        case .all: return "All"
        case .mine: return "Created by me"
        case .needsReview: return "Needs review"
        case .assigned: return "Assigned"
        case .mentioned: return "Mentioned"
        }
    }
}

struct LaunchpadItem: Identifiable {
    let id: String
    let type: ItemType
    let title: String
    let number: Int
    let repository: String
    let author: String
    let authorAvatarURL: String?
    let status: Status
    let labels: [Label]
    let createdAt: Date
    let updatedAt: Date
    let url: String

    var isAuthoredByMe: Bool = false
    var needsMyReview: Bool = false
    var isAssignedToMe: Bool = false
    var mentionsMe: Bool = false

    enum ItemType { case pullRequest, issue, action }

    enum Status {
        case open, closed, merged, draft, inProgress, success, failure

        var icon: String {
            switch self {
            case .open: return "circle"
            case .closed: return "checkmark.circle.fill"
            case .merged: return "arrow.triangle.merge"
            case .draft: return "doc.text"
            case .inProgress: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            }
        }

        @MainActor
        var color: Color {
            switch self {
            case .open: return AppTheme.success
            case .closed: return AppTheme.error
            case .merged: return AppTheme.gitModified
            case .draft: return AppTheme.textMuted
            case .inProgress: return AppTheme.info
            case .success: return AppTheme.success
            case .failure: return AppTheme.error
            }
        }
    }

    struct Label: Identifiable {
        let id: String
        let name: String
        let color: String
    }
}

struct LaunchpadItemRow: View {
    let item: LaunchpadItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: item.status.icon)
                .font(.system(size: DesignTokens.Size.iconSM, weight: .regular))
                .foregroundColor(item.status.color)
                .frame(width: DesignTokens.Size.iconXL)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                    Text(item.title).font(DesignTokens.Typography.callout).lineLimit(1)
                    Text("#\(item.number)").font(DesignTokens.Typography.caption).foregroundColor(AppTheme.textPrimary)
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(item.repository).font(DesignTokens.Typography.caption2).foregroundColor(AppTheme.textPrimary)

                    ForEach(item.labels.prefix(3)) { label in
                        Text(label.name)
                            .font(DesignTokens.Typography.caption2)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 1)  // Precise 1px for tight label padding
                            .background(AppTheme.textMuted.opacity(0.2))
                            .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                }
            }

            Spacer()
            Text(item.updatedAt, style: .relative).font(DesignTokens.Typography.caption2).foregroundColor(AppTheme.textPrimary)

            if isHovered {
                Button {
                    if let url = URL(string: item.url) { NSWorkspace.shared.open(url) }
                } label: {
                    Image(systemName: "arrow.up.forward.square").font(DesignTokens.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isHovered ? AppTheme.textMuted.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            if let url = URL(string: item.url) { NSWorkspace.shared.open(url) }
        }

        Divider()
    }
}

struct LaunchpadFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelected ? AppTheme.info : AppTheme.textMuted.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@MainActor
class LaunchpadViewModel: ObservableObject {
    @Published var items: [LaunchpadItem] = []
    @Published var repositories: [String] = []
    @Published var selectedRepo: String?
    @Published var isLoading = false
    @Published var lastUpdate: Date?

    private var currentUsername: String?

    func refresh() async {
        isLoading = true

        do {
            guard let token = try await KeychainManager.shared.getGitHubToken() else {
                isLoading = false
                return
            }

            let user = try await fetchCurrentUser(token: token)
            currentUsername = user

            async let prs = fetchPullRequests(token: token, username: user)
            async let issues = fetchIssues(token: token, username: user)

            let (prItems, issueItems) = await (try? prs, try? issues)
            items = (prItems ?? []) + (issueItems ?? [])
            repositories = Array(Set(items.map { $0.repository })).sorted()
            lastUpdate = Date()
        } catch {
            print("Launchpad error: \(error)")
        }

        isLoading = false
    }

    func count(for tab: LaunchpadTab) -> Int? {
        let count: Int
        switch tab {
        case .pullRequests: count = items.filter { $0.type == .pullRequest }.count
        case .issues: count = items.filter { $0.type == .issue }.count
        case .actions: count = items.filter { $0.type == .action }.count
        }
        return count > 0 ? count : nil
    }

    private func fetchCurrentUser(token: String) async throws -> String {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let login = json["login"] as? String else {
            throw URLError(.badServerResponse)
        }
        return login
    }

    private func fetchPullRequests(token: String, username: String) async throws -> [LaunchpadItem] {
        let query = "is:pr is:open author:\(username) OR assignee:\(username) OR review-requested:\(username)"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://api.github.com/search/issues?q=\(encodedQuery)&per_page=50")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item -> LaunchpadItem? in
            guard let id = item["id"] as? Int,
                  let title = item["title"] as? String,
                  let number = item["number"] as? Int,
                  let repoURL = item["repository_url"] as? String,
                  let user = item["user"] as? [String: Any],
                  let author = user["login"] as? String,
                  let htmlURL = item["html_url"] as? String else { return nil }

            let repo = repoURL.components(separatedBy: "/").suffix(2).joined(separator: "/")
            let avatarURL = user["avatar_url"] as? String
            let isDraft = item["draft"] as? Bool ?? false
            let state = item["state"] as? String ?? "open"

            let status: LaunchpadItem.Status = isDraft ? .draft : (state == "closed" ? .closed : .open)

            let labels = (item["labels"] as? [[String: Any]] ?? []).compactMap { label -> LaunchpadItem.Label? in
                guard let id = label["id"] as? Int,
                      let name = label["name"] as? String,
                      let color = label["color"] as? String else { return nil }
                return LaunchpadItem.Label(id: "\(id)", name: name, color: color)
            }

            let createdAt = ISO8601DateFormatter().date(from: item["created_at"] as? String ?? "") ?? Date()
            let updatedAt = ISO8601DateFormatter().date(from: item["updated_at"] as? String ?? "") ?? Date()

            var launchpadItem = LaunchpadItem(
                id: "\(id)", type: .pullRequest, title: title, number: number, repository: repo,
                author: author, authorAvatarURL: avatarURL, status: status, labels: labels,
                createdAt: createdAt, updatedAt: updatedAt, url: htmlURL
            )

            launchpadItem.isAuthoredByMe = author == username
            if let reviewers = item["requested_reviewers"] as? [[String: Any]] {
                launchpadItem.needsMyReview = reviewers.contains { ($0["login"] as? String) == username }
            }
            if let assignees = item["assignees"] as? [[String: Any]] {
                launchpadItem.isAssignedToMe = assignees.contains { ($0["login"] as? String) == username }
            }

            return launchpadItem
        }
    }

    private func fetchIssues(token: String, username: String) async throws -> [LaunchpadItem] {
        let query = "is:issue is:open assignee:\(username)"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://api.github.com/search/issues?q=\(encodedQuery)&per_page=50")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item -> LaunchpadItem? in
            guard let id = item["id"] as? Int,
                  let title = item["title"] as? String,
                  let number = item["number"] as? Int,
                  let repoURL = item["repository_url"] as? String,
                  let user = item["user"] as? [String: Any],
                  let author = user["login"] as? String,
                  let htmlURL = item["html_url"] as? String else { return nil }

            if item["pull_request"] != nil { return nil }

            let repo = repoURL.components(separatedBy: "/").suffix(2).joined(separator: "/")
            let avatarURL = user["avatar_url"] as? String
            let state = item["state"] as? String ?? "open"

            let labels = (item["labels"] as? [[String: Any]] ?? []).compactMap { label -> LaunchpadItem.Label? in
                guard let id = label["id"] as? Int,
                      let name = label["name"] as? String,
                      let color = label["color"] as? String else { return nil }
                return LaunchpadItem.Label(id: "\(id)", name: name, color: color)
            }

            let createdAt = ISO8601DateFormatter().date(from: item["created_at"] as? String ?? "") ?? Date()
            let updatedAt = ISO8601DateFormatter().date(from: item["updated_at"] as? String ?? "") ?? Date()

            var launchpadItem = LaunchpadItem(
                id: "\(id)", type: .issue, title: title, number: number, repository: repo,
                author: author, authorAvatarURL: avatarURL, status: state == "open" ? .open : .closed,
                labels: labels, createdAt: createdAt, updatedAt: updatedAt, url: htmlURL
            )

            launchpadItem.isAuthoredByMe = author == username
            launchpadItem.isAssignedToMe = true

            return launchpadItem
        }
    }
}
