import Foundation
import os.signpost

// MARK: - Performance Logging

private let searchLog = OSLog(subsystem: "com.gitmac", category: "diff.search")

// MARK: - Diff Search Engine

/// Incremental search engine for diffs with on-demand materialization
actor DiffSearchEngine {
    private let diffEngine: DiffEngine
    
    init(diffEngine: DiffEngine = DiffEngine()) {
        self.diffEngine = diffEngine
    }
    
    /// Search for a term in hunks with incremental materialization
    func search(
        term: String,
        in hunks: [DiffHunk],
        options: SearchOptions
    ) -> AsyncStream<SearchResult> {
        AsyncStream { continuation in
            Task {
                let signpostID = OSSignpostID(log: searchLog)
                os_signpost(.begin, log: searchLog, name: "diff.search", signpostID: signpostID, "term=%{public}s", term)
                
                defer {
                    os_signpost(.end, log: searchLog, name: "diff.search", signpostID: signpostID)
                    continuation.finish()
                }
                
                var matchCount = 0
                let matcher = SearchMatcher(term: term, options: options)
                
                for (hunkIndex, hunk) in hunks.enumerated() {
                    // Check for cancellation
                    if Task.isCancelled {
                        os_signpost(.event, log: searchLog, name: "diff.search.cancelled", "matches=%d", matchCount)
                        return
                    }
                    
                    // Materialize hunk if needed
                    let lines: [DiffLine]
                    if let byteOffsets = hunk.byteOffsets {
                        // Hunk not materialized yet - skip or materialize if needed
                        // For now, skip unmaterialized hunks in LFM
                        os_signpost(.event, log: searchLog, name: "diff.search.skip_unmaterialized", "hunk=%d", hunkIndex)
                        continue
                    } else {
                        lines = hunk.lines
                    }
                    
                    // Search in lines
                    for (lineIndex, line) in lines.enumerated() {
                        if let ranges = matcher.match(line.content) {
                            matchCount += 1
                            
                            let result = SearchResult(
                                hunkIndex: hunkIndex,
                                lineIndex: lineIndex,
                                line: line,
                                matchRanges: ranges,
                                hunkHeader: hunk.header
                            )
                            
                            continuation.yield(result)
                            
                            // Yield control periodically for responsiveness
                            if matchCount % 10 == 0 {
                                await Task.yield()
                            }
                        }
                    }
                }
                
                os_signpost(.event, log: searchLog, name: "diff.search.complete", "matches=%d", matchCount)
            }
        }
    }
}

// MARK: - Search Options

struct SearchOptions: Sendable {
    var caseSensitive: Bool
    var wholeWord: Bool
    var regex: Bool
    var includeContext: Bool
    var includeAdditions: Bool
    var includeDeletions: Bool
    
    init(
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        regex: Bool = false,
        includeContext: Bool = true,
        includeAdditions: Bool = true,
        includeDeletions: Bool = true
    ) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.regex = regex
        self.includeContext = includeContext
        self.includeAdditions = includeAdditions
        self.includeDeletions = includeDeletions
    }
    
    static var `default`: SearchOptions {
        SearchOptions()
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable, Sendable {
    let id = UUID()
    let hunkIndex: Int
    let lineIndex: Int
    let line: DiffLine
    let matchRanges: [NSRange]
    let hunkHeader: String
    
    var lineNumber: Int? {
        line.newLineNumber ?? line.oldLineNumber
    }
}

// MARK: - Search Matcher

/// Helper for matching search terms with various options
struct SearchMatcher {
    let term: String
    let options: SearchOptions
    private let regex: NSRegularExpression?
    
    init(term: String, options: SearchOptions) {
        self.term = term
        self.options = options
        
        if options.regex {
            // Try to compile regex
            let regexOptions: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            self.regex = try? NSRegularExpression(pattern: term, options: regexOptions)
        } else if options.wholeWord {
            // Whole word matching
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
            let regexOptions: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            self.regex = try? NSRegularExpression(pattern: pattern, options: regexOptions)
        } else {
            self.regex = nil
        }
    }
    
    /// Match the term in a line and return match ranges if found
    func match(_ content: String) -> [NSRange]? {
        if let regex = regex {
            // Regex or whole word matching
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            return matches.isEmpty ? nil : matches.map { $0.range }
        } else {
            // Simple substring search
            let searchString = options.caseSensitive ? content : content.lowercased()
            let searchTerm = options.caseSensitive ? term : term.lowercased()
            
            var ranges: [NSRange] = []
            var searchRange = searchString.startIndex..<searchString.endIndex
            
            while let range = searchString.range(of: searchTerm, range: searchRange) {
                let nsRange = NSRange(range, in: content)
                ranges.append(nsRange)
                
                // Continue searching after this match
                searchRange = range.upperBound..<searchString.endIndex
                
                // Limit to avoid excessive matches in very long lines
                if ranges.count >= 100 {
                    break
                }
            }
            
            return ranges.isEmpty ? nil : ranges
        }
    }
}

// MARK: - Search View Model

/// View model for managing search state
@MainActor
class DiffSearchViewModel: ObservableObject {
    @Published var searchTerm: String = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var currentResultIndex: Int = 0
    @Published var options: SearchOptions = .default
    
    private var searchTask: Task<Void, Never>?
    private let searchEngine: DiffSearchEngine
    
    init(searchEngine: DiffSearchEngine = DiffSearchEngine()) {
        self.searchEngine = searchEngine
    }
    
    /// Start a new search
    func search(in hunks: [DiffHunk]) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !searchTerm.isEmpty else {
            results = []
            return
        }
        
        isSearching = true
        results = []
        currentResultIndex = 0
        
        searchTask = Task {
            var newResults: [SearchResult] = []
            
            for await result in await searchEngine.search(term: searchTerm, in: hunks, options: options) {
                // Check for cancellation
                guard !Task.isCancelled else {
                    break
                }
                
                newResults.append(result)
                
                // Update UI periodically (every 10 results)
                if newResults.count % 10 == 0 {
                    await MainActor.run {
                        self.results = newResults
                    }
                }
            }
            
            // Final update
            await MainActor.run {
                self.results = newResults
                self.isSearching = false
            }
        }
    }
    
    /// Navigate to next result
    func nextResult() {
        guard !results.isEmpty else { return }
        currentResultIndex = (currentResultIndex + 1) % results.count
    }
    
    /// Navigate to previous result
    func previousResult() {
        guard !results.isEmpty else { return }
        currentResultIndex = (currentResultIndex - 1 + results.count) % results.count
    }
    
    /// Get current result
    var currentResult: SearchResult? {
        guard currentResultIndex < results.count else { return nil }
        return results[currentResultIndex]
    }
    
    /// Clear search
    func clear() {
        searchTask?.cancel()
        searchTerm = ""
        results = []
        currentResultIndex = 0
        isSearching = false
    }
}
