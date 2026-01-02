//
//  AnalyticsDashboard.swift
//  GitMac
//
//  Repository analytics and performance metrics dashboard
//

import SwiftUI
import Charts

// MARK: - Analytics Dashboard

struct AnalyticsDashboard: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AnalyticsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Header
                dashboardHeader
                
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    // Metrics Grid
                    metricsGrid
                    
                    // Charts Row
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        commitActivityChart
                        languageBreakdownChart
                    }
                    
                    // Contributors and Activity
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        topContributorsCard
                        recentActivityCard
                    }
                    
                    // Repository Health
                    repositoryHealthCard
                }
            }
            .padding()
        }
        .background(AppTheme.background)
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            if let path = newPath {
                Task { await viewModel.loadAnalytics(for: path) }
            }
        }
        .onAppear {
            if let path = appState.currentRepository?.path {
                Task { await viewModel.loadAnalytics(for: path) }
            }
        }
    }
    
    // MARK: - Header
    
    private var dashboardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Repository Analytics")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)
                
                if let repo = appState.currentRepository {
                    Text(repo.name)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Time range picker
            Picker("Time Range", selection: $viewModel.timeRange) {
                ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.borderless)
        }
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignTokens.Spacing.md) {
            MetricCard(
                title: "Total Commits",
                value: "\(viewModel.metrics.totalCommits)",
                icon: "arrow.triangle.branch",
                trend: viewModel.metrics.commitsTrend
            )
            
            MetricCard(
                title: "Contributors",
                value: "\(viewModel.metrics.totalContributors)",
                icon: "person.2.fill",
                trend: nil
            )
            
            MetricCard(
                title: "Files",
                value: formatNumber(viewModel.metrics.totalFiles),
                icon: "doc.fill",
                trend: nil
            )
            
            MetricCard(
                title: "Lines of Code",
                value: formatNumber(viewModel.metrics.totalLines),
                icon: "text.alignleft",
                trend: viewModel.metrics.linesTrend
            )
            
            MetricCard(
                title: "Active Branches",
                value: "\(viewModel.metrics.activeBranches)",
                icon: "arrow.triangle.branch",
                trend: nil
            )
        }
    }
    
    // MARK: - Commit Activity Chart
    
    private var commitActivityChart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Commit Activity")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            if #available(macOS 14.0, *) {
                Chart(viewModel.commitActivity) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Commits", item.count)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            } else {
                // Fallback for older macOS
                Text("Charts require macOS 14+")
                    .foregroundColor(AppTheme.textMuted)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
    
    // MARK: - Language Breakdown
    
    private var languageBreakdownChart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Language Breakdown")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            if #available(macOS 14.0, *) {
                Chart(viewModel.languageBreakdown) { item in
                    SectorMark(
                        angle: .value("Lines", item.lines),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Language", item.language))
                    .cornerRadius(4)
                }
                .chartLegend(position: .trailing)
                .frame(height: 200)
            } else {
                // Fallback bar representation
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(viewModel.languageBreakdown.prefix(5)) { lang in
                        HStack {
                            Text(lang.language)
                                .font(.caption)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(lang.color)
                                    .frame(width: geo.size.width * lang.percentage)
                            }
                            .frame(height: 12)
                            
                            Text("\(Int(lang.percentage * 100))%")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
    
    // MARK: - Top Contributors
    
    private var topContributorsCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Top Contributors")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            ForEach(viewModel.topContributors.prefix(5)) { contributor in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Rank
                    Text("#\(contributor.rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(contributor.rank <= 3 ? AppTheme.accent : AppTheme.textMuted)
                        .frame(width: 24)
                    
                    // Avatar
                    AsyncImage(url: contributor.avatarURL) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    
                    // Name and stats
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contributor.name)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("\(contributor.commits) commits")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Contribution bar
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.accent.opacity(0.3))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.accent)
                                    .frame(width: geo.size.width * contributor.percentage)
                            }
                    }
                    .frame(width: 60, height: 6)
                }
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
    
    // MARK: - Recent Activity
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            ForEach(viewModel.recentActivity.prefix(5)) { activity in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: activity.icon)
                        .font(.caption)
                        .foregroundColor(activity.color)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.description)
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(activity.relativeTime)
                            .font(.caption2)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
    
    // MARK: - Repository Health
    
    private var repositoryHealthCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Repository Health")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                // Health score
                HStack(spacing: 4) {
                    Image(systemName: viewModel.healthScore >= 80 ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.healthScore >= 80 ? AppTheme.success : AppTheme.warning)
                    
                    Text("\(viewModel.healthScore)%")
                        .font(.headline)
                        .foregroundColor(viewModel.healthScore >= 80 ? AppTheme.success : AppTheme.warning)
                }
            }
            
            // Health indicators
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignTokens.Spacing.sm) {
                HealthIndicator(
                    title: "Last Commit",
                    value: viewModel.metrics.daysSinceLastCommit == 0 ? "Today" : "\(viewModel.metrics.daysSinceLastCommit)d ago",
                    status: viewModel.metrics.daysSinceLastCommit < 7 ? .good : (viewModel.metrics.daysSinceLastCommit < 30 ? .warning : .bad)
                )
                
                HealthIndicator(
                    title: "Active Branches",
                    value: "\(viewModel.metrics.activeBranches)",
                    status: viewModel.metrics.activeBranches > 0 ? .good : .warning
                )
                
                HealthIndicator(
                    title: "Stale Branches",
                    value: "\(viewModel.metrics.staleBranches)",
                    status: viewModel.metrics.staleBranches < 5 ? .good : (viewModel.metrics.staleBranches < 10 ? .warning : .bad)
                )
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
    
    // MARK: - Loading/Error States
    
    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing repository...")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.warning)
            
            Text("Error Loading Analytics")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(error)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppTheme.accent)
                
                Spacer()
                
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(abs(Int(trend * 100)))%")
                    }
                    .font(.caption2)
                    .foregroundColor(trend >= 0 ? AppTheme.success : AppTheme.error)
                }
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}

struct HealthIndicator: View {
    let title: String
    let value: String
    let status: HealthStatus
    
    enum HealthStatus {
        case good, warning, bad
        
        @MainActor var color: Color {
            switch self {
            case .good: return AppTheme.success
            case .warning: return AppTheme.warning
            case .bad: return AppTheme.error
            }
        }
        
        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .bad: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textMuted)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(status.color.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}
