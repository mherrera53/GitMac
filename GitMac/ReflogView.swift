import SwiftUI

/// Reflog viewer - Git's safety net
struct ReflogView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ReflogViewModel()
    @State private var selectedEntry: ReflogEntry?
    @State private var searchText = ""
    @State private var filterRef: String?
    
    var body: some View {
        HSplitView {
            // Left: Reflog entries list
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    // Search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textPrimary)
                        
                        TextField("Search reflog...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    
                    // Filter by ref
                    Menu {
                        Button("All References") {
                            filterRef = nil
                        }
                        
                        Divider()
                        
                        ForEach(viewModel.availableRefs, id: \.self) { ref in
                            Button(ref) {
                                filterRef = ref
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(AppTheme.textSecondary)
                            Text(filterRef ?? "All")
                                .lineLimit(1)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 120)
                    
                    // Refresh
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh")
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Reflog entries
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredEntries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .frame(minWidth: 400)
            
            // Right: Entry details
            if let entry = selectedEntry {
                ReflogEntryDetailView(entry: entry)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Select an entry to view details")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.load()
        }
    }
    
    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        ForEach(groupedEntries[date] ?? []) { entry in
                            ReflogEntryRow(
                                entry: entry,
                                isSelected: selectedEntry?.id == entry.id
                            )
                            .onTapGesture {
                                selectedEntry = entry
                            }
                        }
                    } header: {
                        HStack {
                            Text(formatDateHeader(date))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("No reflog entries found")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private var filteredEntries: [ReflogEntry] {
        var entries = viewModel.entries
        
        // Filter by ref
        if let ref = filterRef {
            entries = entries.filter { $0.ref == ref }
        }
        
        // Search
        if !searchText.isEmpty {
            entries = entries.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.sha.localizedCaseInsensitiveContains(searchText) ||
                $0.ref.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return entries
    }
    
    private var groupedEntries: [String: [ReflogEntry]] {
        Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.date).ISO8601Format()
        }
    }
    
    private func formatDateHeader(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Reflog Entry Row

struct ReflogEntryRow: View {
    let entry: ReflogEntry
    let isSelected: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Operation icon
            Image(systemName: entry.operationType.icon)
                .font(.system(size: 16))
                .foregroundColor(entry.operationType.color)
                .frame(width: 24, height: 24)
                .background(entry.operationType.color.opacity(0.15))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                // Message
                Text(entry.message)
                    .font(.body)
                    .lineLimit(1)
                
                // Metadata
                HStack(spacing: 8) {
                    // SHA
                    Text(entry.shortSHA)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // Ref
                    Text(entry.ref)
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                    
                    Text("•")
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // Time
                    Text(entry.date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            
            Spacer()
            
            // Quick actions on hover
            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        // TODO: Checkout
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Checkout")
                    
                    Button {
                        // TODO: Reset here
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to here")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : (isHovered ? AppTheme.textSecondary.opacity(0.05) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.sha, forType: .string)
            } label: {
                Label("Copy SHA", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button {
                // TODO: Checkout
            } label: {
                Label("Checkout \(entry.shortSHA)", systemImage: "arrow.right.circle")
            }
            
            Button {
                // TODO: Reset
            } label: {
                Label("Reset Branch Here", systemImage: "arrow.uturn.backward.circle")
            }
            
            Button {
                // TODO: Create branch
            } label: {
                Label("Create Branch from Here", systemImage: "arrow.branch")
            }
        }
    }
}

// MARK: - Entry Detail View

struct ReflogEntryDetailView: View {
    let entry: ReflogEntry
    @StateObject private var diffLoader = DiffLoader()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: entry.operationType.icon)
                        .font(.system(size: 24))
                        .foregroundColor(entry.operationType.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.message)
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            Text(entry.shortSHA)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("•")
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text(entry.ref)
                                .font(.caption)
                                .foregroundColor(AppTheme.accent)
                            
                            Text("•")
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Actions
                HStack(spacing: 8) {
                    Button {
                        // TODO: Checkout
                    } label: {
                        Label("Checkout", systemImage: "arrow.right.circle")
                    }
                    
                    Button {
                        // TODO: Reset
                    } label: {
                        Label("Reset Branch", systemImage: "arrow.uturn.backward.circle")
                    }
                    
                    Button {
                        // TODO: Create branch
                    } label: {
                        Label("Create Branch", systemImage: "arrow.branch")
                    }
                    
                    Spacer()
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.sha, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .help("Copy SHA")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Diff preview (if applicable)
            if diffLoader.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !diffLoader.diff.isEmpty {
                ScrollView {
                    Text(diffLoader.diff)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("No diff available")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await diffLoader.loadDiff(sha: entry.sha)
        }
    }
}

// MARK: - Models

struct ReflogEntry: Identifiable {
    let id: UUID
    let sha: String
    let ref: String
    let message: String
    let date: Date
    
    var shortSHA: String {
        String(sha.prefix(7))
    }
    
    var operationType: ReflogOperationType {
        if message.contains("commit") {
            return .commit
        } else if message.contains("checkout") {
            return .checkout
        } else if message.contains("merge") {
            return .merge
        } else if message.contains("rebase") {
            return .rebase
        } else if message.contains("reset") {
            return .reset
        } else if message.contains("pull") {
            return .pull
        } else if message.contains("cherry-pick") {
            return .cherryPick
        } else {
            return .other
        }
    }
    
    init(sha: String, ref: String, message: String, date: Date) {
        self.id = UUID()
        self.sha = sha
        self.ref = ref
        self.message = message
        self.date = date
    }
}

enum ReflogOperationType {
    case commit
    case checkout
    case merge
    case rebase
    case reset
    case pull
    case cherryPick
    case other
    
    var icon: String {
        switch self {
        case .commit: return "checkmark.circle.fill"
        case .checkout: return "arrow.right.circle.fill"
        case .merge: return "arrow.triangle.merge"
        case .rebase: return "arrow.up.arrow.down.circle.fill"
        case .reset: return "arrow.uturn.backward.circle.fill"
        case .pull: return "arrow.down.circle.fill"
        case .cherryPick: return "cherry"
        case .other: return "circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .commit: return .green
        case .checkout: return .blue
        case .merge: return .purple
        case .rebase: return .orange
        case .reset: return .red
        case .pull: return .cyan
        case .cherryPick: return .pink
        case .other: return .gray
        }
    }
}

// MARK: - View Model

@MainActor
class ReflogViewModel: ObservableObject {
    @Published var entries: [ReflogEntry] = []
    @Published var availableRefs: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var appState: AppState?
    
    func configure(appState: AppState) {
        self.appState = appState
    }
    
    func load() async {
        guard let repoPath = appState?.currentRepository?.path else { return }
        
        isLoading = true
        errorMessage = nil
        
        let shell = ShellExecutor()
        let result = await shell.execute(
            "git",
            arguments: ["reflog", "--all", "--date=iso"],
            workingDirectory: repoPath
        )
        
        if result.exitCode == 0 {
            entries = parseReflog(result.stdout)
            availableRefs = Array(Set(entries.map { $0.ref })).sorted()
        } else {
            errorMessage = result.stderr
        }
        
        isLoading = false
    }
    
    private func parseReflog(_ output: String) -> [ReflogEntry] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        return lines.compactMap { line in
            // Format: SHA ref@{num}: message
            // Example: abc123 HEAD@{0}: commit: Add feature
            let components = line.components(separatedBy: " ")
            guard components.count >= 3 else { return nil }
            
            let sha = components[0]
            let refPart = components[1] // HEAD@{0}:
            let ref = refPart.components(separatedBy: "@").first ?? "HEAD"
            
            // Extract message (everything after the first two components)
            let message = components[2...].joined(separator: " ")
            
            // Parse date if available (git reflog --date=iso includes it)
            let date = Date() // Simplified - would need proper parsing
            
            return ReflogEntry(sha: sha, ref: ref, message: message, date: date)
        }
    }
}

// MARK: - Diff Loader

@MainActor
class DiffLoader: ObservableObject {
    @Published var diff = ""
    @Published var isLoading = false
    
    func loadDiff(sha: String) async {
        isLoading = true
        
        // Simulate loading - would use actual git service
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        diff = "// Diff would be loaded here"
        isLoading = false
    }
}
