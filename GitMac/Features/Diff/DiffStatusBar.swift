import SwiftUI

// MARK: - Diff Status Bar

/// Status bar showing performance metrics and active degradations
struct DiffStatusBar: View {
    let isLFMActive: Bool
    let degradations: [DiffDegradation]
    let stats: DiffPerformanceStats?
    let searchResults: Int?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // LFM indicator
            if isLFMActive {
                lfmIndicator

                Divider()
                    .frame(height: DesignTokens.Sizing.Icon.md)
            }
            
            // Active degradations
            if !degradations.isEmpty {
                ForEach(degradations) { degradation in
                    degradationBadge(degradation)
                }

                Divider()
                    .frame(height: DesignTokens.Sizing.Icon.md)
            }

            // Search results
            if let count = searchResults, count > 0 {
                searchIndicator(count: count)

                Divider()
                    .frame(height: DesignTokens.Sizing.Icon.md)
            }
            
            Spacer()
            
            // Performance stats
            if let stats = stats {
                performanceStats(stats)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md / 2)
        .background(statusBarBackground)
        .font(DesignTokens.Typography.caption)
    }
    
    // MARK: - Components
    
    private var lfmIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "bolt.fill")
                .foregroundColor(AppTheme.warning)
            Text("Large File Mode")
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.warning)
        }
    }
    
    private func degradationBadge(_ degradation: DiffDegradation) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: degradation.icon)
                .font(DesignTokens.Typography.caption2)
            Text(degradation.description)
        }
        .foregroundColor(colorForSeverity(degradation.severity))
        .help(degradation.description)
    }
    
    private func searchIndicator(count: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "magnifyingglass")
            Text("\(count) match\(count == 1 ? "" : "es")")
        }
        .foregroundColor(AppTheme.accent)
    }
    
    private func performanceStats(_ stats: DiffPerformanceStats) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if let parseTime = stats.parseTime {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(DesignTokens.Typography.caption2)
                    Text("Parse: \(parseTime, format: .number.precision(.fractionLength(2)))s")
                }
                .foregroundColor(AppTheme.textPrimary)
            }

            if let memoryUsage = stats.memoryUsage {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "memorychip")
                        .font(DesignTokens.Typography.caption2)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory))
                }
                .foregroundColor(AppTheme.textPrimary)
            }

            if let frameTime = stats.averageFrameTime {
                let color: Color = frameTime < 16 ? AppTheme.success : (frameTime < 33 ? AppTheme.warning : AppTheme.error)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "gauge")
                        .font(DesignTokens.Typography.caption2)
                    Text("\(frameTime, format: .number.precision(.fractionLength(1))) ms/frame")
                }
                .foregroundColor(color)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func colorForSeverity(_ severity: DegradationSeverity) -> Color {
        switch severity {
        case .info: return AppTheme.info
        case .warning: return AppTheme.warning
        case .error: return AppTheme.error
        }
    }
    
    private var statusBarBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(nsColor: .controlBackgroundColor)
            } else {
                Color(nsColor: .controlBackgroundColor).opacity(0.9)
            }
        }
    }
}

// MARK: - Performance Stats

/// Performance statistics for diff rendering
struct DiffPerformanceStats: Sendable {
    let parseTime: TimeInterval?
    let memoryUsage: Int?
    let averageFrameTime: Double?  // in milliseconds
    let p95FrameTime: Double?
    let p99FrameTime: Double?
    
    init(
        parseTime: TimeInterval? = nil,
        memoryUsage: Int? = nil,
        averageFrameTime: Double? = nil,
        p95FrameTime: Double? = nil,
        p99FrameTime: Double? = nil
    ) {
        self.parseTime = parseTime
        self.memoryUsage = memoryUsage
        self.averageFrameTime = averageFrameTime
        self.p95FrameTime = p95FrameTime
        self.p99FrameTime = p99FrameTime
    }
}

// MARK: - Frame Time Profiler

/// Profiler for measuring frame rendering times
@MainActor
class FrameTimeProfiler: ObservableObject {
    @Published var stats: DiffPerformanceStats = DiffPerformanceStats()
    
    private var frameTimes: [Double] = []
    private let maxSamples = 100
    
    /// Record a frame time
    func recordFrameTime(_ milliseconds: Double) {
        frameTimes.append(milliseconds)
        
        // Keep only recent samples
        if frameTimes.count > maxSamples {
            frameTimes.removeFirst(frameTimes.count - maxSamples)
        }
        
        // Update stats
        updateStats()
    }
    
    /// Reset profiler
    func reset() {
        frameTimes.removeAll()
        updateStats()
    }
    
    private func updateStats() {
        guard !frameTimes.isEmpty else {
            stats = DiffPerformanceStats()
            return
        }
        
        let avg = frameTimes.reduce(0, +) / Double(frameTimes.count)
        
        let sorted = frameTimes.sorted()
        let p95Index = Int(Double(sorted.count) * 0.95)
        let p99Index = Int(Double(sorted.count) * 0.99)
        
        let p95 = sorted[min(p95Index, sorted.count - 1)]
        let p99 = sorted[min(p99Index, sorted.count - 1)]
        
        stats = DiffPerformanceStats(
            parseTime: stats.parseTime,
            memoryUsage: stats.memoryUsage,
            averageFrameTime: avg,
            p95FrameTime: p95,
            p99FrameTime: p99
        )
    }
    
    /// Set parse time
    func setParseTime(_ time: TimeInterval) {
        stats = DiffPerformanceStats(
            parseTime: time,
            memoryUsage: stats.memoryUsage,
            averageFrameTime: stats.averageFrameTime,
            p95FrameTime: stats.p95FrameTime,
            p99FrameTime: stats.p99FrameTime
        )
    }
    
    /// Set memory usage
    func setMemoryUsage(_ bytes: Int) {
        stats = DiffPerformanceStats(
            parseTime: stats.parseTime,
            memoryUsage: bytes,
            averageFrameTime: stats.averageFrameTime,
            p95FrameTime: stats.p95FrameTime,
            p99FrameTime: stats.p99FrameTime
        )
    }
}

// MARK: - Preview

#if DEBUG
struct DiffStatusBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // With LFM active
            DiffStatusBar(
                isLFMActive: true,
                degradations: [
                    .wordDiffDisabled,
                    .syntaxHighlightDisabled,
                    .sideBySideDisabled
                ],
                stats: DiffPerformanceStats(
                    parseTime: 0.45,
                    memoryUsage: 45_000_000,
                    averageFrameTime: 12.5
                ),
                searchResults: 42
            )
            
            Divider()
            
            // Normal mode
            DiffStatusBar(
                isLFMActive: false,
                degradations: [],
                stats: DiffPerformanceStats(
                    parseTime: 0.08,
                    memoryUsage: 8_000_000,
                    averageFrameTime: 6.2
                ),
                searchResults: nil
            )
            
            Divider()
            
            // Warning state (slow frames)
            DiffStatusBar(
                isLFMActive: false,
                degradations: [],
                stats: DiffPerformanceStats(
                    parseTime: 0.15,
                    memoryUsage: 25_000_000,
                    averageFrameTime: 22.8
                ),
                searchResults: nil
            )
        }
        .frame(width: 800)
    }
}
#endif
