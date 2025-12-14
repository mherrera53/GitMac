import SwiftUI

// MARK: - Complete Integration Example

/// Example of a complete diff view with all performance optimizations
struct PerformantDiffView: View {
    let filePath: String
    let repoPath: String
    let isStaged: Bool
    
    @State private var fileDiff: FileDiff?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isLFMActive = false
    @State private var degradations: [DiffDegradation] = []
    @State private var preflightStats: DiffPreflightStats?
    @State private var performanceStats: DiffPerformanceStats?
    
    @StateObject private var searchVM = DiffSearchViewModel()
    @StateObject private var profiler = FrameTimeProfiler()
    
    private let diffEngine = DiffEngine()
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            Divider()
            
            // Status bar
            if let stats = performanceStats {
                DiffStatusBar(
                    isLFMActive: isLFMActive,
                    degradations: degradations,
                    stats: stats,
                    searchResults: searchVM.results.count > 0 ? searchVM.results.count : nil
                )
                
                Divider()
            }
            
            // Content
            content
        }
        .task {
            await loadDiff()
        }
        .onChange(of: searchVM.searchTerm) { _, newValue in
            if !newValue.isEmpty, let diff = fileDiff {
                searchVM.search(in: diff.hunks)
            }
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // File info
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text(filePath)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Search
            searchField
            
            // Actions
            Button("Refresh") {
                Task { await loadDiff() }
            }
            .disabled(isLoading)
            
            Button("Clear Cache") {
                Task { await clearCache() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            
            TextField("Search in diff...", text: $searchVM.searchTerm)
                .textFieldStyle(.plain)
                .frame(width: 200)
            
            if searchVM.isSearching {
                ProgressView()
                    .scaleEffect(0.6)
            }
            
            if !searchVM.results.isEmpty {
                HStack(spacing: 4) {
                    Text("\(searchVM.currentResultIndex + 1)/\(searchVM.results.count)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Button(action: searchVM.previousResult) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: searchVM.nextResult) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if !searchVM.searchTerm.isEmpty {
                Button(action: searchVM.clear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading diff...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = error {
            errorView(error)
        } else if let diff = fileDiff {
            diffView(diff)
        } else {
            Text("No changes")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to load diff")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await loadDiff() }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func diffView(_ diff: FileDiff) -> some View {
        AdaptiveTiledDiffView(
            fileDiff: diff,
            options: diffOptions
        )
    }
    
    // MARK: - Logic
    
    private var diffOptions: DiffOptions {
        if isLFMActive {
            return .largeFile
        } else {
            var opts = DiffOptions.default
            
            // Apply user preferences
            let prefs = UserDefaults.standard.diffPreferences
            opts.contextLines = prefs.defaultContextLines
            opts.enableWordDiff = prefs.enableWordDiffOnDemand
            opts.enableSyntaxHighlight = prefs.enableSyntaxHighlightOnDemand
            
            return opts
        }
    }
    
    private func loadDiff() async {
        isLoading = true
        error = nil
        
        let startTime = Date()
        
        do {
            // 1. Preflight check
            let stats = try await diffEngine.stats(
                file: filePath,
                at: repoPath,
                staged: isStaged
            )
            
            preflightStats = stats
            
            // 2. Determine if LFM is needed
            let prefs = UserDefaults.standard.diffPreferences
            
            // Check manual override first
            if let manualOverride = prefs.lfmOverride(for: filePath) {
                isLFMActive = manualOverride
            } else {
                // Auto-detect
                isLFMActive = prefs.lfmThresholds.shouldActivateLFM(stats: stats)
            }
            
            // 3. Build degradations list
            degradations = buildDegradations(stats: stats, isLFM: isLFMActive)
            
            // 4. Stream hunks
            let options = diffOptions
            let hunkStream = try await diffEngine.diff(
                file: filePath,
                at: repoPath,
                options: options
            )
            
            var hunks: [DiffHunk] = []
            
            for try await hunk in hunkStream {
                hunks.append(hunk)
                
                // Update UI incrementally every 25 hunks
                if hunks.count % 25 == 0 {
                    updateFileDiff(hunks: hunks, stats: stats)
                }
            }
            
            // 5. Final update
            updateFileDiff(hunks: hunks, stats: stats)
            
            // 6. Record parse time
            let parseTime = Date().timeIntervalSince(startTime)
            profiler.setParseTime(parseTime)
            
            // 7. Get cache stats for memory usage
            let cacheStats = await diffEngine.cacheStats()
            profiler.setMemoryUsage(cacheStats.totalBytes)
            
            updatePerformanceStats()
            
            isLoading = false
            
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    private func updateFileDiff(hunks: [DiffHunk], stats: DiffPreflightStats) {
        fileDiff = FileDiff(
            oldPath: filePath,
            newPath: filePath,
            status: .modified,
            hunks: hunks,
            isBinary: stats.isBinary,
            additions: stats.additions,
            deletions: stats.deletions
        )
    }
    
    private func buildDegradations(stats: DiffPreflightStats, isLFM: Bool) -> [DiffDegradation] {
        var result: [DiffDegradation] = []
        
        if isLFM {
            result.append(.largeFileModeActive)
            result.append(.wordDiffDisabled)
            result.append(.syntaxHighlightDisabled)
            result.append(.sideBySideDisabled)
            result.append(.softWrapDisabled)
            result.append(.hunksCollapsedByDefault)
        }
        
        return result
    }
    
    private func updatePerformanceStats() {
        performanceStats = profiler.stats
    }
    
    private func clearCache() async {
        await GlobalDiffCache.shared.removeFile(filePath, staged: isStaged)
    }
}

// MARK: - Simple Usage Example

/// Minimal example for basic usage
struct SimpleDiffView: View {
    let filePath: String
    let repoPath: String
    
    @State private var hunks: [DiffHunk] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(hunks) { hunk in
                    VStack(alignment: .leading, spacing: 0) {
                        // Hunk header
                        Text(hunk.header)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                        
                        // Lines
                        ForEach(hunk.lines) { line in
                            HStack(spacing: 8) {
                                Text(linePrefix(line))
                                    .foregroundColor(lineColor(line))
                                
                                Text(line.content)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(lineBackground(line))
                        }
                    }
                }
            }
        }
        .task {
            await loadDiff()
        }
    }
    
    private func loadDiff() async {
        let engine = DiffEngine()
        
        do {
            let hunkStream = try await engine.diff(
                file: filePath,
                at: repoPath,
                options: .default
            )
            
            var result: [DiffHunk] = []
            for try await hunk in hunkStream {
                result.append(hunk)
            }
            
            hunks = result
        } catch {
            print("Failed to load diff: \(error)")
        }
    }
    
    private func linePrefix(_ line: DiffLine) -> String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .hunkHeader: return "@"
        }
    }
    
    private func lineColor(_ line: DiffLine) -> Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .primary
        case .hunkHeader: return .blue
        }
    }
    
    private func lineBackground(_ line: DiffLine) -> Color {
        switch line.type {
        case .addition: return .green.opacity(0.1)
        case .deletion: return .red.opacity(0.1)
        case .context, .hunkHeader: return .clear
        }
    }
}

// MARK: - Preferences View Example

struct DiffPreferencesView: View {
    @State private var preferences = UserDefaults.standard.diffPreferences
    
    var body: some View {
        Form {
            Section("Large File Mode Thresholds") {
                HStack {
                    Text("File Size (MB):")
                    Spacer()
                    TextField("", value: $preferences.lfmThresholds.fileSizeMB, format: .number)
                        .frame(width: 80)
                }
                
                HStack {
                    Text("Estimated Lines:")
                    Spacer()
                    TextField("", value: $preferences.lfmThresholds.estimatedLines, format: .number)
                        .frame(width: 80)
                }
                
                HStack {
                    Text("Max Line Length:")
                    Spacer()
                    TextField("", value: $preferences.lfmThresholds.maxLineLength, format: .number)
                        .frame(width: 80)
                }
                
                HStack {
                    Text("Max Hunks:")
                    Spacer()
                    TextField("", value: $preferences.lfmThresholds.maxHunks, format: .number)
                        .frame(width: 80)
                }
                
                HStack(spacing: 8) {
                    Button("Conservative") {
                        preferences.lfmThresholds = .conservative
                    }
                    Button("Default") {
                        preferences.lfmThresholds = .default
                    }
                    Button("Aggressive") {
                        preferences.lfmThresholds = .aggressive
                    }
                }
            }
            
            Section("Default Options") {
                HStack {
                    Text("Context Lines:")
                    Spacer()
                    Stepper("\(preferences.defaultContextLines)", value: $preferences.defaultContextLines, in: 0...10)
                }
                
                Toggle("Enable Word Diff on Demand", isOn: $preferences.enableWordDiffOnDemand)
                Toggle("Enable Syntax Highlighting on Demand", isOn: $preferences.enableSyntaxHighlightOnDemand)
                Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)
                Toggle("Show Whitespace", isOn: $preferences.showWhitespace)
            }
            
            Section("Manual Overrides") {
                if preferences.lfmManualOverrides.isEmpty {
                    Text("No manual overrides")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(preferences.lfmManualOverrides.keys.sorted()), id: \.self) { file in
                        HStack {
                            Text(file)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(preferences.lfmManualOverrides[file] == true ? "LFM On" : "LFM Off")
                                .foregroundColor(.secondary)
                            
                            Button("Remove") {
                                preferences.clearLfmOverride(for: file)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            
            HStack {
                Button("Reset to Defaults") {
                    preferences = .default
                }
                
                Spacer()
                
                Button("Save") {
                    UserDefaults.standard.diffPreferences = preferences
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 600)
    }
}

// MARK: - Cache Stats View Example

struct CacheStatsView: View {
    @State private var stats: CacheStats?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diff Cache Statistics")
                .font(.headline)
            
            if let stats = stats {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Entries:")
                        Text("\(stats.entries)")
                            .fontWeight(.semibold)
                    }
                    
                    GridRow {
                        Text("Memory Usage:")
                        HStack(spacing: 4) {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(stats.totalBytes), countStyle: .memory))
                                .fontWeight(.semibold)
                            Text("/ \(ByteCountFormatter.string(fromByteCount: Int64(stats.maxBytes), countStyle: .memory))")
                                .foregroundColor(.secondary)
                            Text("(\(String(format: "%.1f", stats.usagePercent))%)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    GridRow {
                        Text("Hits:")
                        Text("\(stats.hits)")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    GridRow {
                        Text("Misses:")
                        Text("\(stats.misses)")
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    
                    GridRow {
                        Text("Hit Rate:")
                        Text("\(String(format: "%.1f", stats.hitRate * 100))%")
                            .fontWeight(.semibold)
                            .foregroundColor(stats.hitRate > 0.8 ? .green : .orange)
                    }
                    
                    GridRow {
                        Text("Evictions:")
                        Text("\(stats.evictions)")
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
            } else {
                ProgressView("Loading stats...")
            }
            
            HStack(spacing: 8) {
                Button("Refresh") {
                    Task { await loadStats() }
                }
                
                Button("Clear Cache") {
                    Task { await clearCache() }
                }
                .tint(.red)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 400)
        .task {
            await loadStats()
        }
    }
    
    private func loadStats() async {
        stats = await GlobalDiffCache.shared.stats()
    }
    
    private func clearCache() async {
        await GlobalDiffCache.shared.clear()
        await loadStats()
    }
}
