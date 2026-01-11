import SwiftUI

/// File Annotation View - Blame with visual heatmap
/// Shows who changed each line and when, with color-coded age
struct FileAnnotationView: View {
    let filePath: String
    @StateObject private var viewModel = FileAnnotationViewModel()
    
    @State private var hoveredLine: Int?
    @State private var selectedCommit: String?
    @State private var showHeatmap = true
    @State private var colorScheme: HeatmapColorScheme = .age
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            annotationToolbar
            
            Divider()
            
            // Content
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                annotationContent
            }
        }
        .task {
            await viewModel.loadBlame(for: filePath)
        }
    }
    
    // MARK: - Toolbar
    
    private var annotationToolbar: some View {
        HStack {
            Text(filePath)
                .font(.headline)
            
            Spacer()
            
            // Heatmap toggle
            Toggle("Heatmap", isOn: $showHeatmap)
            
            // Color scheme
            if showHeatmap {
                Picker("Color by", selection: $colorScheme) {
                    Text("Age").tag(HeatmapColorScheme.age)
                    Text("Author").tag(HeatmapColorScheme.author)
                    Text("Activity").tag(HeatmapColorScheme.activity)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Stats
            if !viewModel.annotations.isEmpty {
                HStack(spacing: 12) {
                    Label("\(viewModel.uniqueAuthors.count)", systemImage: "person")
                    Label("\(viewModel.uniqueCommits.count)", systemImage: "number")
                }
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Content
    
    private var annotationContent: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.annotations.enumerated()), id: \.offset) { index, annotation in
                        AnnotationRow(
                            annotation: annotation,
                            lineNumber: index + 1,
                            showHeatmap: showHeatmap,
                            colorScheme: colorScheme,
                            heatmapIntensity: heatmapIntensity(for: annotation),
                            isHovered: hoveredLine == index + 1,
                            isSelected: selectedCommit == annotation.commitSHA,
                            onHover: { hoveredLine = $0 ? (index + 1) : nil },
                            onSelect: { selectedCommit = annotation.commitSHA }
                        )
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading annotations...")
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.warning)
            
            Text("Failed to load annotations")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
            
            Button("Retry") {
                Task { await viewModel.loadBlame(for: filePath) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func heatmapIntensity(for annotation: BlameLine) -> Double {
        switch colorScheme {
        case .age:
            return viewModel.ageIntensity(for: annotation)
        case .author:
            return viewModel.authorIntensity(for: annotation)
        case .activity:
            return viewModel.activityIntensity(for: annotation)
        }
    }
}

// MARK: - Annotation Row

struct AnnotationRow: View {
    let annotation: BlameLine
    let lineNumber: Int
    let showHeatmap: Bool
    let colorScheme: HeatmapColorScheme
    let heatmapIntensity: Double
    let isHovered: Bool
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void
    
    @State private var showTooltip = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Heatmap bar
            if showHeatmap {
                heatmapBar
            }
            
            // Commit info
            commitInfo
            
            // Line number
            Text("\(lineNumber)")
                .frame(width: 50, alignment: .trailing)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            // Code content
            Text(annotation.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
        }
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered in
            onHover(isHovered)
            showTooltip = isHovered
        }
        .popover(isPresented: $showTooltip, arrowEdge: .leading) {
            commitTooltip
        }
    }
    
    // MARK: - Heatmap Bar
    
    private var heatmapBar: some View {
        Rectangle()
            .fill(heatmapColor)
            .frame(width: 8)
    }
    
    private var heatmapColor: Color {
        switch colorScheme {
        case .age:
            return ageColor
        case .author:
            return authorColor
        case .activity:
            return activityColor
        }
    }
    
    private var ageColor: Color {
        // Newer = Green, Older = Red
        let intensity = heatmapIntensity
        if intensity < 0.33 {
            return AppTheme.success.opacity(0.3 + intensity)
        } else if intensity < 0.66 {
            return AppTheme.warning.opacity(0.3 + intensity)
        } else {
            return AppTheme.error.opacity(0.3 + intensity)
        }
    }
    
    private var authorColor: Color {
        // Different color per author (hashed)
        let hash = annotation.author.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
            .opacity(0.6)
    }
    
    private var activityColor: Color {
        // High activity = Hot (red), Low activity = Cool (blue)
        let intensity = heatmapIntensity
        if intensity < 0.33 {
            return AppTheme.accent.opacity(0.3 + intensity)
        } else if intensity < 0.66 {
            return Color.purple.opacity(0.3 + intensity)
        } else {
            return AppTheme.error.opacity(0.3 + intensity)
        }
    }
    
    // MARK: - Commit Info
    
    private var commitInfo: some View {
        HStack(spacing: 8) {
            // Author avatar (first letter)
            Text(annotation.author.prefix(1).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(authorColor)
                )
            
            // Author name
            Text(annotation.author)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            
            // Commit SHA
            Text(annotation.shortSHA)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 60, alignment: .leading)
            
            // Date
            Text(annotation.relativeDate)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 100, alignment: .leading)
        }
        .frame(width: 350)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Tooltip
    
    private var commitTooltip: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Commit message
            Text(annotation.message)
                .font(.headline)
                .lineLimit(2)
            
            Divider()
            
            // Metadata
            HStack {
                Label(annotation.author, systemImage: "person")
                Spacer()
            }
            
            HStack {
                Label(annotation.commitSHA, systemImage: "number")
                Spacer()
            }
            
            HStack {
                Label(annotation.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                Spacer()
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("View Commit") {
                    // TODO: Navigate to commit
                }
                .buttonStyle(.borderedProminent)
                
                Button("Copy SHA") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(annotation.commitSHA, forType: .string)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Background
    
    private var rowBackground: Color {
        if isSelected {
            return AppTheme.accent.opacity(0.2)
        } else if isHovered {
            return AppTheme.textSecondary.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Heatmap Color Scheme

enum HeatmapColorScheme: String, CaseIterable {
    case age
    case author
    case activity
}

// MARK: - Blame Line Model

struct BlameLine: Identifiable {
    let id: UUID
    let commitSHA: String
    let author: String
    let email: String
    let date: Date
    let message: String
    let lineNumber: Int
    let content: String
    
    var shortSHA: String {
        String(commitSHA.prefix(7))
    }
    
    var relativeDate: String {
        date.formatted(.relative(presentation: .named))
    }
    
    init(commitSHA: String, author: String, email: String, date: Date, message: String, lineNumber: Int, content: String) {
        self.id = UUID()
        self.commitSHA = commitSHA
        self.author = author
        self.email = email
        self.date = date
        self.message = message
        self.lineNumber = lineNumber
        self.content = content
    }
}

// MARK: - View Model

@MainActor
class FileAnnotationViewModel: ObservableObject {
    @Published var annotations: [BlameLine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var uniqueAuthors: Set<String> {
        Set(annotations.map { $0.author })
    }
    
    var uniqueCommits: Set<String> {
        Set(annotations.map { $0.commitSHA })
    }
    
    private var oldestDate: Date?
    private var newestDate: Date?
    private var authorCommitCount: [String: Int] = [:]
    
    func loadBlame(for filePath: String) async {
        isLoading = true
        errorMessage = nil
        
        // Simulated loading - replace with actual git blame
        do {
            annotations = try await executeGitBlame(filePath: filePath)
            calculateHeatmapData()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func executeGitBlame(filePath: String) async throws -> [BlameLine] {
        // TODO: Implement actual git blame execution
        // git blame --line-porcelain <file>
        
        // Simulated data for now
        return []
    }
    
    // MARK: - Heatmap Calculations
    
    private func calculateHeatmapData() {
        guard !annotations.isEmpty else { return }
        
        // Find date range
        oldestDate = annotations.map { $0.date }.min()
        newestDate = annotations.map { $0.date }.max()
        
        // Count commits per author
        authorCommitCount = Dictionary(grouping: annotations, by: { $0.author })
            .mapValues { $0.count }
    }
    
    func ageIntensity(for annotation: BlameLine) -> Double {
        guard let oldest = oldestDate,
              let newest = newestDate else {
            return 0.5
        }
        
        let totalRange = newest.timeIntervalSince(oldest)
        let lineAge = newest.timeIntervalSince(annotation.date)
        
        return totalRange > 0 ? lineAge / totalRange : 0.5
    }
    
    func authorIntensity(for annotation: BlameLine) -> Double {
        // Not really intensity, just a stable value per author
        let hash = annotation.author.hashValue
        return Double(abs(hash) % 100) / 100.0
    }
    
    func activityIntensity(for annotation: BlameLine) -> Double {
        guard let maxCommits = authorCommitCount.values.max(),
              maxCommits > 0 else {
            return 0.5
        }
        
        let authorCommits = authorCommitCount[annotation.author] ?? 0
        return Double(authorCommits) / Double(maxCommits)
    }
}

// MARK: - Annotation Legend

struct AnnotationLegendView: View {
    let colorScheme: HeatmapColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heatmap Legend")
                .font(.headline)
            
            switch colorScheme {
            case .age:
                ageLegend
            case .author:
                authorLegend
            case .activity:
                activityLegend
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(radius: 4)
        )
    }
    
    private var ageLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            LegendItem(color: .green, label: "Recent changes")
            LegendItem(color: .yellow, label: "Medium age")
            LegendItem(color: .red, label: "Old code")
        }
    }
    
    private var authorLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Each author has a unique color")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
    
    private var activityLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            LegendItem(color: .blue, label: "Low activity")
            LegendItem(color: .purple, label: "Medium activity")
            LegendItem(color: .red, label: "High activity")
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.6))
                .frame(width: 20, height: 12)
                .cornerRadius(3)
            
            Text(label)
                .font(.caption)
        }
    }
}

// MARK: - Enhanced Annotation View with Stats

struct EnhancedFileAnnotationView: View {
    let filePath: String
    @StateObject private var viewModel = FileAnnotationViewModel()
    
    @State private var showLegend = false
    @State private var showStats = false
    @State private var colorScheme: HeatmapColorScheme = .age
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            FileAnnotationView(filePath: filePath)
            
            // Floating controls
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    // Legend button
                    Button {
                        showLegend.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Show Legend")
                    .popover(isPresented: $showLegend) {
                        AnnotationLegendView(colorScheme: colorScheme)
                    }
                    
                    // Stats button
                    Button {
                        showStats.toggle()
                    } label: {
                        Image(systemName: "chart.bar")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Show Stats")
                    .sheet(isPresented: $showStats) {
                        AnnotationStatsView(annotations: viewModel.annotations)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Stats View

struct AnnotationStatsView: View {
    let annotations: [BlameLine]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("File Statistics")
                .font(.title2)
                .fontWeight(.bold)
            
            // Author breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Contributors")
                    .font(.headline)
                
                ForEach(authorStats, id: \.author) { stat in
                    HStack {
                        Text(stat.author)
                        Spacer()
                        Text("\(stat.lines) lines")
                            .foregroundColor(AppTheme.textPrimary)
                        Text("(\(stat.percentage)%)")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Age distribution
            VStack(alignment: .leading, spacing: 12) {
                Text("Code Age")
                    .font(.headline)
                
                Text("Average age: \(averageAge)")
                Text("Oldest: \(oldestLine)")
                Text("Newest: \(newestLine)")
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .padding()
    }
    
    private var authorStats: [(author: String, lines: Int, percentage: Int)] {
        let grouped = Dictionary(grouping: annotations, by: { $0.author })
        let total = annotations.count
        
        return grouped.map { author, lines in
            let count = lines.count
            let percentage = total > 0 ? (count * 100) / total : 0
            return (author, count, percentage)
        }
        .sorted { $0.lines > $1.lines }
    }
    
    private var averageAge: String {
        guard !annotations.isEmpty else { return "N/A" }
        
        let avg = annotations.reduce(0.0) { $0 + Date().timeIntervalSince($1.date) } / Double(annotations.count)
        let days = Int(avg / 86400)
        
        return "\(days) days"
    }
    
    private var oldestLine: String {
        annotations.map { $0.date }.min()?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
    }
    
    private var newestLine: String {
        annotations.map { $0.date }.max()?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
    }
}
