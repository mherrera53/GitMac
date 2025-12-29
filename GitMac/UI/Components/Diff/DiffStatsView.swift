import SwiftUI

// MARK: - Diff Stats View

/// Displays diff statistics showing additions and deletions
/// Used in file lists, rows, and toolbars
struct DiffStatsView: View {
    let additions: Int
    let deletions: Int
    var size: StatsSize = .medium
    var style: StatsStyle = .compact

    enum StatsSize {
        case small, medium, large

        var fontSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 10
            case .large: return 11
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 4
            case .large: return 6
            }
        }
    }

    enum StatsStyle {
        case compact    // +15 -3
        case badges     // Colored badges like in toolbar
        case detailed   // "+15 additions" "-3 deletions"
    }

    var body: some View {
        switch style {
        case .compact:
            compactView
        case .badges:
            badgesView
        case .detailed:
            detailedView
        }
    }

    // MARK: - Compact Style

    @ViewBuilder
    private var compactView: some View {
        HStack(spacing: size.spacing) {
            if additions > 0 {
                HStack(spacing: 1) {
                    Text("+")
                        .foregroundColor(AppTheme.diffAddition)
                    Text("\(additions)")
                        .foregroundColor(AppTheme.diffAddition)
                }
                .font(.system(size: size.fontSize, weight: .medium, design: .monospaced))
            }

            if deletions > 0 {
                HStack(spacing: 1) {
                    Text("−")
                        .foregroundColor(AppTheme.diffDeletion)
                    Text("\(deletions)")
                        .foregroundColor(AppTheme.diffDeletion)
                }
                .font(.system(size: size.fontSize, weight: .medium, design: .monospaced))
            }
        }
    }

    // MARK: - Badges Style

    @ViewBuilder
    private var badgesView: some View {
        HStack(spacing: size.spacing * 2) {
            if additions > 0 {
                HStack(spacing: size.spacing) {
                    Image(systemName: "plus")
                        .font(.system(size: size.fontSize - 1, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(additions)")
                        .font(.system(size: size.fontSize, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, size.fontSize * 0.8)
                .padding(.vertical, size.fontSize * 0.4)
                .background(AppTheme.diffAddition)
                .cornerRadius(4)
            }

            if deletions > 0 {
                HStack(spacing: size.spacing) {
                    Image(systemName: "minus")
                        .font(.system(size: size.fontSize - 1, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(deletions)")
                        .font(.system(size: size.fontSize, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, size.fontSize * 0.8)
                .padding(.vertical, size.fontSize * 0.4)
                .background(AppTheme.diffDeletion)
                .cornerRadius(4)
            }
        }
    }

    // MARK: - Detailed Style

    @ViewBuilder
    private var detailedView: some View {
        HStack(spacing: size.spacing * 2) {
            if additions > 0 {
                HStack(spacing: size.spacing) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: size.fontSize))
                        .foregroundColor(AppTheme.diffAddition)
                    Text("\(additions) addition\(additions == 1 ? "" : "s")")
                        .font(.system(size: size.fontSize, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            if deletions > 0 {
                HStack(spacing: size.spacing) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: size.fontSize))
                        .foregroundColor(AppTheme.diffDeletion)
                    Text("\(deletions) deletion\(deletions == 1 ? "" : "s")")
                        .font(.system(size: size.fontSize, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension DiffStatsView {
    /// Creates compact stats view (default)
    static func compact(additions: Int, deletions: Int, size: StatsSize = .medium) -> DiffStatsView {
        DiffStatsView(additions: additions, deletions: deletions, size: size, style: .compact)
    }

    /// Creates badge-style stats view (for toolbars)
    static func badges(additions: Int, deletions: Int, size: StatsSize = .medium) -> DiffStatsView {
        DiffStatsView(additions: additions, deletions: deletions, size: size, style: .badges)
    }

    /// Creates detailed stats view with text labels
    static func detailed(additions: Int, deletions: Int, size: StatsSize = .medium) -> DiffStatsView {
        DiffStatsView(additions: additions, deletions: deletions, size: size, style: .detailed)
    }
}

// MARK: - Preview

#if DEBUG
struct DiffStatsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Compact style (default)
            VStack(alignment: .leading, spacing: 8) {
                Text("Compact Style").font(.headline)
                DiffStatsView(additions: 15, deletions: 3)
                DiffStatsView(additions: 150, deletions: 0)
                DiffStatsView(additions: 0, deletions: 42)
                DiffStatsView(additions: 5, deletions: 5, size: .small)
                DiffStatsView(additions: 100, deletions: 50, size: .large)
            }

            Divider()

            // Badges style
            VStack(alignment: .leading, spacing: 8) {
                Text("Badges Style").font(.headline)
                DiffStatsView.badges(additions: 15, deletions: 3)
                DiffStatsView.badges(additions: 150, deletions: 0)
                DiffStatsView.badges(additions: 0, deletions: 42)
            }

            Divider()

            // Detailed style
            VStack(alignment: .leading, spacing: 8) {
                Text("Detailed Style").font(.headline)
                DiffStatsView.detailed(additions: 15, deletions: 3)
                DiffStatsView.detailed(additions: 1, deletions: 1)
                DiffStatsView.detailed(additions: 150, deletions: 0)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
