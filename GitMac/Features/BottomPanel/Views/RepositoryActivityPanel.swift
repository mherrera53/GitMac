//
//  RepositoryActivityPanel.swift
//  GitMac
//
//  Repository-based activity panel showing contributors, commits, and contribution graph
//

import SwiftUI

struct RepositoryActivityPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RepositoryActivityViewModel()
    @State private var selectedContributor: Contributor?
    @State private var selectedTab: ActivityTab = .overview
    
    enum ActivityTab: String, CaseIterable {
        case overview = "Overview"
        case commits = "Commits"
        case contributors = "Contributors"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            activityHeader
            
            Divider()
            
            // Content based on repository state
            if appState.currentRepository == nil {
                noRepositoryView
            } else if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                activityContent
            }
        }
        .background(AppTheme.background)
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                Task {
                    await viewModel.loadActivity(for: path)
                }
            }
        }
        .onAppear {
            if let path = appState.currentRepository?.path {
                Task {
                    await viewModel.loadActivity(for: path)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var activityHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Repository Activity")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                if let repo = appState.currentRepository {
                    Text(repo.name)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    Text("No repository selected")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            
            Spacer()
            
            // Stats
            if !viewModel.isLoading {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ActivityStatBadge(
                        icon: "person.2.fill",
                        value: "\(viewModel.contributors.count)",
                        label: "contributors"
                    )
                    
                    ActivityStatBadge(
                        icon: "arrow.triangle.branch",
                        value: "\(viewModel.recentCommits.count)",
                        label: "commits"
                    )
                }
            }
            
            // Refresh button
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ActivityTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? AppTheme.accent : AppTheme.textSecondary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(
                            selectedTab == tab ? AppTheme.accent.opacity(0.1) : Color.clear
                        )
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.backgroundSecondary.opacity(0.5))
    }
    
    // MARK: - Content
    
    private var activityContent: some View {
        VStack(spacing: 0) {
            tabBar
            
            Divider()
            
            switch selectedTab {
            case .overview:
                overviewTab
            case .commits:
                commitsTab
            case .contributors:
                contributorsTab
            }
        }
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Contribution Graph
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Contribution Activity")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    if !viewModel.contributionDays.isEmpty {
                        ContributionGraphView(
                            contributionDays: viewModel.contributionDays,
                            weeks: 26 // Last 6 months
                        )
                    } else {
                        Text("No contribution data available")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                            .frame(height: 100)
                    }
                }
                .padding()
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                
                // Top Contributors
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Top Contributors")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    ForEach(viewModel.contributors.prefix(5)) { contributor in
                        ContributorRow(
                            contributor: contributor,
                            isSelected: selectedContributor?.id == contributor.id
                        ) {
                            selectedContributor = contributor
                            selectedTab = .contributors
                        }
                    }
                }
                .padding()
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                
                // Recent Commits
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Recent Commits")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    ForEach(viewModel.recentCommits.prefix(5)) { commit in
                        CommitActivityRow(commit: commit)
                    }
                }
                .padding()
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .padding()
        }
    }
    
    // MARK: - Commits Tab
    
    private var commitsTab: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(viewModel.recentCommits) { commit in
                    CommitActivityRow(commit: commit)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Contributors Tab
    
    private var contributorsTab: some View {
        HStack(spacing: 0) {
            // Contributors list
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(viewModel.contributors) { contributor in
                        ContributorRow(
                            contributor: contributor,
                            isSelected: selectedContributor?.id == contributor.id
                        ) {
                            selectedContributor = contributor
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .frame(width: 280)
            .background(AppTheme.backgroundSecondary.opacity(0.3))
            
            Divider()
            
            // Contributor detail
            if let contributor = selectedContributor {
                contributorDetail(contributor)
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textMuted)
                    
                    Text("Select a Contributor")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Choose a contributor from the list to view their activity")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func contributorDetail(_ contributor: Contributor) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Header
                HStack(spacing: DesignTokens.Spacing.md) {
                    AsyncImage(url: contributor.gravatarURL) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contributor.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text(contributor.email)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Label("\(contributor.commitCount) commits", systemImage: "arrow.triangle.branch")
                                .font(.caption)
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                
                // Commits by this contributor
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Commits by \(contributor.name)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    let contributorCommits = viewModel.recentCommits.filter {
                        $0.authorEmail.lowercased() == contributor.email.lowercased()
                    }
                    
                    if contributorCommits.isEmpty {
                        Text("No recent commits found")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                    } else {
                        ForEach(contributorCommits) { commit in
                            CommitActivityRow(commit: commit)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty States
    
    private var noRepositoryView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)
            
            Text("No Repository Selected")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Select a repository to view its activity")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading repository activity...")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.warning)
            
            Text("Error Loading Activity")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(error)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct ActivityStatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(AppTheme.accent)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.backgroundTertiary)
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

struct ContributorRow: View {
    let contributor: Contributor
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            AsyncImage(url: contributor.gravatarURL) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contributor.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text("\(contributor.commitCount) commits")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            // Commit bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.accent.opacity(0.3))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.accent)
                            .frame(width: geo.size.width * contributionRatio)
                    }
            }
            .frame(width: 50, height: 6)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(isSelected ? AppTheme.accent.opacity(0.15) : Color.clear)
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
    
    private var contributionRatio: CGFloat {
        CGFloat(min(contributor.commitCount, 100)) / 100.0
    }
}

struct CommitActivityRow: View {
    let commit: CommitActivity
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            // Commit indicator
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(commit.message)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(String(commit.id.prefix(7)))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.accent)
                    
                    Text(commit.author)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(formatRelativeDate(commit.date))
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundSecondary.opacity(0.5))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
