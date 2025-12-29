import SwiftUI

/// Fuzzy File Finder - Ultra-fast file search (Cmd+P)
/// Optimized for large repos with thousands of files
struct FuzzyFileFinder: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FuzzyFileFinderViewModel()
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
            
            Divider()
            
            // Results
            if viewModel.isLoading {
                loadingView
            } else if filteredFiles.isEmpty {
                emptyState
            } else {
                fileList
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 700, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isSearchFocused = true
            if let repo = appState.currentRepository {
                viewModel.loadFiles(repoPath: repo.path)
            }
        }
    }
    
    // MARK: - Search Field
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(AppTheme.accent)
            
            DSTextField(placeholder: "Search files...", text: $searchText)
                .font(.system(size: 16))
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    selectedIndex = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - File List
    
    private var fileList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredFiles.enumerated()), id: \.element.id) { index, file in
                        FileResultRow(
                            file: file,
                            isSelected: index == selectedIndex,
                            searchText: searchText,
                            onOpen: {
                                openFile(file)
                            }
                        )
                        .id(index)
                    }
                }
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Indexing files...")
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            
            Text(searchText.isEmpty ? "Start typing to search files" : "No files found")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            KeyboardShortcutHint(symbol: "↑↓", label: "Navigate")
            KeyboardShortcutHint(symbol: "↵", label: "Open")
            KeyboardShortcutHint(symbol: "Cmd+↵", label: "Open & Close")
            KeyboardShortcutHint(symbol: "Esc", label: "Close")
            
            Spacer()
            
            if !searchText.isEmpty {
                Text("\(filteredFiles.count) of \(viewModel.allFiles.count) files")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            } else {
                Text("\(viewModel.allFiles.count) files")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Keyboard Navigation
    
    private var keyboardHandler: some View {
        Color.clear
            .onKeyPress(.downArrow) {
                selectedIndex = min(selectedIndex + 1, filteredFiles.count - 1)
                return .handled
            }
            .onKeyPress(.upArrow) {
                selectedIndex = max(selectedIndex - 1, 0)
                return .handled
            }
            .onKeyPress(.return) {
                if !filteredFiles.isEmpty {
                    openFile(filteredFiles[selectedIndex])
                }
                return .handled
            }
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
    }
    
    // MARK: - Helpers
    
    private var filteredFiles: [FileResult] {
        if searchText.isEmpty {
            return Array(viewModel.allFiles.prefix(100)) // Show top 100 when no search
        }
        
        // Fuzzy matching with scoring
        let results = viewModel.allFiles.compactMap { file -> (file: FileResult, score: Int)? in
            guard let score = fuzzyMatch(file.path, pattern: searchText) else {
                return nil
            }
            return (file, score)
        }
        
        // Sort by score (higher = better match)
        return results
            .sorted { $0.score > $1.score }
            .prefix(100) // Limit results for performance
            .map { $0.file }
    }
    
    /// Fuzzy matching algorithm with scoring
    /// Returns nil if no match, or a score (higher = better)
    private func fuzzyMatch(_ text: String, pattern: String) -> Int? {
        let text = text.lowercased()
        let pattern = pattern.lowercased()
        
        var score = 0
        var textIndex = text.startIndex
        var patternIndex = pattern.startIndex
        var consecutiveMatches = 0
        var lastMatchIndex: String.Index?
        
        while patternIndex < pattern.endIndex && textIndex < text.endIndex {
            let patternChar = pattern[patternIndex]
            let textChar = text[textIndex]
            
            if patternChar == textChar {
                score += 1
                
                // Bonus for consecutive matches
                if let last = lastMatchIndex, text.index(after: last) == textIndex {
                    consecutiveMatches += 1
                    score += consecutiveMatches * 2 // Exponential bonus
                } else {
                    consecutiveMatches = 0
                }
                
                // Bonus for matching at word boundaries
                if textIndex == text.startIndex || text[text.index(before: textIndex)] == "/" {
                    score += 5
                }
                
                // Bonus for matching filename (after last /)
                if let lastSlash = text.lastIndex(of: "/"), textIndex > lastSlash {
                    score += 3
                }
                
                lastMatchIndex = textIndex
                patternIndex = pattern.index(after: patternIndex)
            }
            
            textIndex = text.index(after: textIndex)
        }
        
        // Return nil if pattern wasn't fully matched
        guard patternIndex == pattern.endIndex else {
            return nil
        }
        
        return score
    }
    
    private func openFile(_ file: FileResult) {
        guard let repoPath = appState.currentRepository?.path else { return }
        
        let fullPath = repoPath + "/" + file.path
        let url = URL(fileURLWithPath: fullPath)
        
        // Open with default application
        NSWorkspace.shared.open(url)
        
        dismiss()
    }
}

// MARK: - File Result Row

struct FileResultRow: View {
    let file: FileResult
    let isSelected: Bool
    let searchText: String
    let onOpen: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                // File icon
                Image(systemName: "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.info)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.info.opacity(0.15))
                    .cornerRadius(8)
                
                // File info
                VStack(alignment: .leading, spacing: 2) {
                    // Filename (highlighted)
                    Text(highlightedFilename)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    // Path
                    Text(file.directory)
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Quick actions on hover
                if isHovered {
                    HStack(spacing: 4) {
                        Button {
                            NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Image(systemName: "folder")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Reveal in Finder")
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(file.path, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy Path")
                    }
                }
                
                // File size
                if let size = file.size {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.accent.opacity(0.2) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private var highlightedFilename: AttributedString {
        var attributed = AttributedString(file.filename)
        
        if !searchText.isEmpty {
            let filename = file.filename.lowercased()
            let search = searchText.lowercased()
            
            // Highlight matching characters
            var currentIndex = filename.startIndex
            for char in search {
                if let index = filename[currentIndex...].firstIndex(of: char) {
                    let nsRange = NSRange(index...index, in: file.filename)
                    if let attrRange = Range<AttributedString.Index>(nsRange, in: attributed) {
                        attributed[attrRange].foregroundColor = .accentColor
                        attributed[attrRange].font = .body.bold()
                    }
                    currentIndex = filename.index(after: index)
                }
            }
        }
        
        return attributed
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Models

struct FileResult: Identifiable {
    let id: UUID
    let path: String
    let size: Int?
    let modifiedDate: Date?
    
    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
    
    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }
    
    var fileExtension: String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }
    
    init(path: String, size: Int? = nil, modifiedDate: Date? = nil) {
        self.id = UUID()
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
    }
}

// MARK: - View Model

@MainActor
class FuzzyFileFinderViewModel: ObservableObject {
    @Published var allFiles: [FileResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var indexTask: Task<Void, Never>?
    
    func loadFiles(repoPath: String) {
        // Cancel previous task if running
        indexTask?.cancel()
        
        indexTask = Task {
            isLoading = true
            
            // Use git ls-files for speed (only tracked files)
            let shell = ShellExecutor()
            let result = await shell.execute(
                "git",
                arguments: ["ls-files"],
                workingDirectory: repoPath
            )
            
            guard !Task.isCancelled else { return }
            
            if result.exitCode == 0 {
                let paths = result.stdout
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                
                // Get file info in parallel (but limit concurrency)
                let files = paths.map { path in
                    FileResult(path: path)
                }
                
                guard !Task.isCancelled else { return }
                
                allFiles = files
            } else {
                errorMessage = result.stderr
            }
            
            isLoading = false
        }
    }
    
    deinit {
        indexTask?.cancel()
    }
}
