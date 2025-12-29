import SwiftUI
import Charts

// MARK: - Git Insights View

/// Analytics dashboard showing repository metrics like cycle time, throughput, merge rate
struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedTimeRange: TimeRange = .week

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Header
                headerView

                // Time range picker
                timeRangePicker

                if viewModel.isLoading {
                    loadingView
                } else if let metrics = viewModel.metrics {
                    // Summary cards
                    summaryCards(metrics)

                    // Charts
                    chartsSection(metrics)

                    // Top contributors
                    topContributorsSection(metrics)
                } else {
                    emptyView
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .task {
            if let path = appState.currentRepository?.path {
                await viewModel.loadMetrics(at: path, timeRange: selectedTimeRange)
            }
        }
        .onChange(of: selectedTimeRange) { _, newValue in
            if let path = appState.currentRepository?.path {
                Task { await viewModel.loadMetrics(at: path, timeRange: newValue) }
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Repository Insights")
                    .font(DesignTokens.Typography.title2)

                if let repo = appState.currentRepository {
                    Text(repo.name)
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            Spacer()

            Button {
                if let path = appState.currentRepository?.path {
                    Task { await viewModel.loadMetrics(at: path, timeRange: selectedTimeRange) }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
    }

    private var timeRangePicker: some View {
        HStack {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    selectedTimeRange = range
                } label: {
                    Text(range.title)
                        .font(DesignTokens.Typography.caption)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm - 2)
                        .background(selectedTimeRange == range ? AppTheme.info : AppTheme.textMuted.opacity(0.1))
                        .foregroundColor(selectedTimeRange == range ? .white : .primary)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func summaryCards(_ metrics: RepositoryMetrics) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignTokens.Spacing.md) {
            MetricCard(
                title: "Total Commits",
                value: "\(metrics.totalCommits)",
                icon: "number.circle.fill",
                color: AppTheme.accent,
                trend: metrics.commitsTrend
            )

            MetricCard(
                title: "Avg Cycle Time",
                value: formatDuration(metrics.averageCycleTime),
                icon: "clock.fill",
                color: AppTheme.warning,
                trend: metrics.cycleTimeTrend
            )

            MetricCard(
                title: "Merge Rate",
                value: "\(Int(metrics.mergeRate * 100))%",
                icon: "arrow.triangle.merge",
                color: AppTheme.accentPurple,
                trend: metrics.mergeRateTrend
            )

            MetricCard(
                title: "Active Contributors",
                value: "\(metrics.activeContributors)",
                icon: "person.2.fill",
                color: AppTheme.success,
                trend: nil
            )
        }
    }

    @ViewBuilder
    private func chartsSection(_ metrics: RepositoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Commit Activity")
                .font(DesignTokens.Typography.headline)

            if #available(macOS 14.0, *) {
                Chart(metrics.dailyCommits) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Commits", item.count)
                    )
                    .foregroundStyle(AppTheme.info.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            } else {
                // Fallback for older macOS
                HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xxs) {
                    ForEach(metrics.dailyCommits) { item in
                        VStack {
                            Rectangle()
                                .fill(AppTheme.info)
                                .frame(width: 8, height: CGFloat(item.count) * 10)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)

        // PR throughput
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("PR Throughput")
                .font(DesignTokens.Typography.headline)

            HStack(spacing: DesignTokens.Spacing.xl) {
                VStack {
                    Text("\(metrics.openPRs)")
                        .font(DesignTokens.Typography.title2)
                        .foregroundColor(AppTheme.success)
                    Text("Open")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }

                VStack {
                    Text("\(metrics.mergedPRs)")
                        .font(DesignTokens.Typography.title2)
                        .foregroundColor(AppTheme.accentPurple)
                    Text("Merged")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }

                VStack {
                    Text("\(metrics.closedPRs)")
                        .font(DesignTokens.Typography.title2)
                        .foregroundColor(AppTheme.error)
                    Text("Closed")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }

    private func topContributorsSection(_ metrics: RepositoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Top Contributors")
                .font(DesignTokens.Typography.headline)

            ForEach(metrics.topContributors.prefix(5)) { contributor in
                HStack {
                    Circle()
                        .fill(AppTheme.info.opacity(0.3))
                        .frame(width: DesignTokens.Size.avatarLG, height: DesignTokens.Size.avatarLG)
                        .overlay(
                            Text(String(contributor.name.prefix(1)).uppercased())
                                .font(DesignTokens.Typography.callout.bold())
                                .foregroundColor(AppTheme.info)
                        )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text(contributor.name)
                            .font(DesignTokens.Typography.callout.weight(.medium))
                        Text("\(contributor.commits) commits")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Spacer()

                    // Progress bar
                    GeometryReader { geo in
                        let maxCommits = metrics.topContributors.first?.commits ?? 1
                        let width = (CGFloat(contributor.commits) / CGFloat(maxCommits)) * geo.size.width
                        Rectangle()
                            .fill(AppTheme.info.opacity(0.3))
                            .frame(width: width)
                    }
                    .frame(width: 100, height: DesignTokens.Spacing.sm)
                    .background(AppTheme.textMuted.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
            Text("Analyzing repository...")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxl + 8)
    }

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(AppTheme.textPrimary)

            Text("No data available")
                .font(DesignTokens.Typography.headline)

            Text("Open a repository to see insights")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xxl + 8)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))h"
        } else {
            return "\(Int(seconds / 86400))d"
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.Size.iconSM))
                    .foregroundColor(color)
                Spacer()
                if let trend = trend {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9)) // Chart label - intentionally small
                        Text("\(abs(Int(trend * 100)))%")
                            .font(.system(size: 9)) // Chart label - intentionally small
                    }
                    .foregroundColor(trend >= 0 ? AppTheme.success : AppTheme.error)
                }
            }

            Text(value)
                .font(DesignTokens.Typography.title2)

            Text(title)
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

// MARK: - Types

enum TimeRange: CaseIterable {
    case week, month, quarter, year

    var title: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        case .year: return "1 Year"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

struct RepositoryMetrics {
    let totalCommits: Int
    let averageCycleTime: TimeInterval
    let mergeRate: Double
    let activeContributors: Int
    let commitsTrend: Double?
    let cycleTimeTrend: Double?
    let mergeRateTrend: Double?
    let dailyCommits: [DailyCommit]
    let topContributors: [Contributor]
    let openPRs: Int
    let mergedPRs: Int
    let closedPRs: Int

    struct DailyCommit: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    struct Contributor: Identifiable {
        let id = UUID()
        let name: String
        let email: String
        let commits: Int
    }
}

// MARK: - View Model

@MainActor
class InsightsViewModel: ObservableObject {
    @Published var metrics: RepositoryMetrics?
    @Published var isLoading = false

    private let engine = GitEngine()

    func loadMetrics(at repoPath: String, timeRange: TimeRange) async {
        isLoading = true

        do {
            let sinceDate = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
            let dateFormatter = ISO8601DateFormatter()
            let sinceString = dateFormatter.string(from: sinceDate)

            // Get commits in time range
            let commitsResult = try await ShellExecutor.shared.execute(
                "cd '\(repoPath)' && git log --since='\(sinceString)' --format='%H|%an|%ae|%aI' --no-merges"
            )

            var commits: [(sha: String, author: String, email: String, date: Date)] = []
            for line in commitsResult.output.components(separatedBy: "\n") where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                if parts.count >= 4 {
                    if let date = dateFormatter.date(from: parts[3]) {
                        commits.append((parts[0], parts[1], parts[2], date))
                    }
                }
            }

            // Calculate daily commits
            var dailyCommits: [Date: Int] = [:]
            let calendar = Calendar.current
            for commit in commits {
                let day = calendar.startOfDay(for: commit.date)
                dailyCommits[day, default: 0] += 1
            }

            let sortedDaily = dailyCommits.map { RepositoryMetrics.DailyCommit(date: $0.key, count: $0.value) }
                .sorted { $0.date < $1.date }

            // Calculate contributors
            var contributorCounts: [String: (name: String, email: String, count: Int)] = [:]
            for commit in commits {
                if let existing = contributorCounts[commit.email] {
                    contributorCounts[commit.email] = (existing.name, existing.email, existing.count + 1)
                } else {
                    contributorCounts[commit.email] = (commit.author, commit.email, 1)
                }
            }

            let topContributors = contributorCounts.values
                .map { RepositoryMetrics.Contributor(name: $0.name, email: $0.email, commits: $0.count) }
                .sorted { $0.commits > $1.commits }

            // Calculate trends (compare first half to second half)
            let midpoint = commits.count / 2
            let firstHalf = commits.prefix(midpoint).count
            let secondHalf = commits.suffix(midpoint).count
            let commitsTrend = firstHalf > 0 ? Double(secondHalf - firstHalf) / Double(firstHalf) : 0

            metrics = RepositoryMetrics(
                totalCommits: commits.count,
                averageCycleTime: 3600 * 24 * 2, // Placeholder - would need PR data
                mergeRate: 0.85, // Placeholder
                activeContributors: contributorCounts.count,
                commitsTrend: commitsTrend,
                cycleTimeTrend: nil,
                mergeRateTrend: nil,
                dailyCommits: sortedDaily,
                topContributors: topContributors,
                openPRs: 0,
                mergedPRs: 0,
                closedPRs: 0
            )

        } catch {
            print("Error loading metrics: \(error)")
            metrics = nil
        }

        isLoading = false
    }
}
