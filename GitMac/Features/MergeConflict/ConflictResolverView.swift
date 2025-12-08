import SwiftUI

/// Three-way merge conflict resolver
struct ConflictResolverView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ConflictResolverViewModel()
    @State private var selectedFile: ConflictFile?

    var body: some View {
        VStack(spacing: 0) {
            // Header with conflict count
            ConflictHeader(
                conflictCount: viewModel.conflictFiles.count,
                resolvedCount: viewModel.resolvedCount,
                onAbort: { Task { await viewModel.abortMerge() } },
                onContinue: { Task { await viewModel.continueMerge() } }
            )

            Divider()

            HSplitView {
                // Left: File list
                ConflictFileList(
                    files: viewModel.conflictFiles,
                    selectedFile: $selectedFile
                )
                .frame(minWidth: 200, maxWidth: 300)

                // Right: Three-way merge view
                if let file = selectedFile {
                    ThreeWayMergeView(
                        file: file,
                        viewModel: viewModel
                    )
                } else {
                    EmptyConflictView()
                }
            }
        }
        .task {
            if let repo = appState.currentRepository {
                await viewModel.loadConflicts(from: repo)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class ConflictResolverViewModel: ObservableObject {
    @Published var conflictFiles: [ConflictFile] = []
    @Published var isLoading = false
    @Published var error: String?

    private let gitService = GitService()
    private let aiService = AIService()
    private var repositoryPath: String = ""

    var resolvedCount: Int {
        conflictFiles.filter { $0.isResolved }.count
    }

    var allResolved: Bool {
        !conflictFiles.isEmpty && conflictFiles.allSatisfy { $0.isResolved }
    }

    func loadConflicts(from repo: Repository) async {
        repositoryPath = repo.path
        isLoading = true

        var files: [ConflictFile] = []

        for fileStatus in repo.status.conflicted {
            let content = await loadConflictContent(for: fileStatus.path)
            files.append(ConflictFile(
                path: fileStatus.path,
                oursContent: content.ours,
                theirsContent: content.theirs,
                baseContent: content.base
            ))
        }

        conflictFiles = files
        isLoading = false
    }

    func loadConflictContent(for path: String) async -> (ours: String, theirs: String, base: String?) {
        let shell = ShellExecutor()

        // Get our version
        let oursResult = await shell.execute(
            "git",
            arguments: ["show", ":2:\(path)"],
            workingDirectory: repositoryPath
        )

        // Get their version
        let theirsResult = await shell.execute(
            "git",
            arguments: ["show", ":3:\(path)"],
            workingDirectory: repositoryPath
        )

        // Get base version
        let baseResult = await shell.execute(
            "git",
            arguments: ["show", ":1:\(path)"],
            workingDirectory: repositoryPath
        )

        return (
            ours: oursResult.stdout,
            theirs: theirsResult.stdout,
            base: baseResult.exitCode == 0 ? baseResult.stdout : nil
        )
    }

    func resolveWithOurs(_ file: ConflictFile) async {
        await resolveFile(file, with: file.oursContent)
    }

    func resolveWithTheirs(_ file: ConflictFile) async {
        await resolveFile(file, with: file.theirsContent)
    }

    func resolveWithCustom(_ file: ConflictFile, content: String) async {
        await resolveFile(file, with: content)
    }

    func resolveWithAI(_ file: ConflictFile) async -> ConflictResolution? {
        do {
            return try await aiService.suggestConflictResolution(
                ours: file.oursContent,
                theirs: file.theirsContent,
                base: file.baseContent,
                filename: file.path
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private func resolveFile(_ file: ConflictFile, with content: String) async {
        // Write resolved content
        let fileURL = URL(fileURLWithPath: repositoryPath).appendingPathComponent(file.path)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            // Stage the resolved file
            try await gitService.stage(files: [file.path])

            // Update file status
            if let index = conflictFiles.firstIndex(where: { $0.id == file.id }) {
                conflictFiles[index].isResolved = true
                conflictFiles[index].resolvedContent = content
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func abortMerge() async {
        do {
            try await gitService.mergeAbort()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func continueMerge() async {
        // All conflicts must be resolved
        guard allResolved else { return }

        // Commit the merge
        do {
            _ = try await gitService.commit(message: "Merge conflict resolved")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Models

struct ConflictFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let oursContent: String
    let theirsContent: String
    let baseContent: String?
    var isResolved = false
    var resolvedContent: String?

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static func == (lhs: ConflictFile, rhs: ConflictFile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents a single conflict chunk within a file
struct ConflictChunk: Identifiable {
    let id = UUID()
    let startLine: Int
    let endLine: Int
    let oursLines: [String]
    let theirsLines: [String]
    let baseLines: [String]?
    var resolution: ChunkResolution = .unresolved

    enum ChunkResolution: Equatable {
        case unresolved
        case ours
        case theirs
        case both
        case custom(String)

        static func == (lhs: ChunkResolution, rhs: ChunkResolution) -> Bool {
            switch (lhs, rhs) {
            case (.unresolved, .unresolved): return true
            case (.ours, .ours): return true
            case (.theirs, .theirs): return true
            case (.both, .both): return true
            case (.custom(let a), .custom(let b)): return a == b
            default: return false
            }
        }
    }

    var isResolved: Bool {
        if case .unresolved = resolution { return false }
        return true
    }

    var resolvedContent: String {
        switch resolution {
        case .unresolved:
            return ""
        case .ours:
            return oursLines.joined(separator: "\n")
        case .theirs:
            return theirsLines.joined(separator: "\n")
        case .both:
            return oursLines.joined(separator: "\n") + "\n" + theirsLines.joined(separator: "\n")
        case .custom(let content):
            return content
        }
    }
}

/// Parses conflict markers from file content
struct ConflictParser {
    static func parseConflicts(from content: String) -> [ConflictChunk] {
        let lines = content.components(separatedBy: .newlines)
        var chunks: [ConflictChunk] = []

        var i = 0
        while i < lines.count {
            if lines[i].hasPrefix("<<<<<<<") {
                let startLine = i
                var oursLines: [String] = []
                var theirsLines: [String] = []
                var baseLines: [String]? = nil
                var inOurs = true
                var inBase = false

                i += 1
                while i < lines.count {
                    if lines[i].hasPrefix("|||||||") {
                        // Base marker (diff3 style)
                        inOurs = false
                        inBase = true
                        baseLines = []
                        i += 1
                        continue
                    } else if lines[i].hasPrefix("=======") {
                        inOurs = false
                        inBase = false
                        i += 1
                        continue
                    } else if lines[i].hasPrefix(">>>>>>>") {
                        chunks.append(ConflictChunk(
                            startLine: startLine,
                            endLine: i,
                            oursLines: oursLines,
                            theirsLines: theirsLines,
                            baseLines: baseLines
                        ))
                        break
                    }

                    if inOurs {
                        oursLines.append(lines[i])
                    } else if inBase {
                        baseLines?.append(lines[i])
                    } else {
                        theirsLines.append(lines[i])
                    }
                    i += 1
                }
            }
            i += 1
        }

        return chunks
    }

    /// Applies resolutions to original content
    static func applyResolutions(to content: String, chunks: [ConflictChunk]) -> String {
        var lines = content.components(separatedBy: .newlines)

        // Process chunks in reverse order to maintain line indices
        for chunk in chunks.reversed() {
            guard chunk.isResolved else { continue }

            // Remove the conflict block and insert resolved content
            let range = chunk.startLine...chunk.endLine
            let resolvedLines = chunk.resolvedContent.components(separatedBy: .newlines)
            lines.replaceSubrange(range, with: resolvedLines)
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Subviews

struct ConflictHeader: View {
    let conflictCount: Int
    let resolvedCount: Int
    var onAbort: () -> Void = {}
    var onContinue: () -> Void = {}

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text("Merge Conflicts")
                .font(.headline)

            Text("\(resolvedCount)/\(conflictCount) resolved")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(resolvedCount == conflictCount ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(resolvedCount == conflictCount ? .green : .orange)
                .cornerRadius(10)

            Spacer()

            Button("Abort Merge") {
                onAbort()
            }
            .foregroundColor(.red)

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .disabled(resolvedCount != conflictCount)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

struct ConflictFileList: View {
    let files: [ConflictFile]
    @Binding var selectedFile: ConflictFile?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conflicted Files")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            List(files, selection: $selectedFile) { file in
                ConflictFileRow(file: file, isSelected: selectedFile?.id == file.id)
                    .tag(file)
            }
            .listStyle(.plain)
        }
    }
}

struct ConflictFileRow: View {
    let file: ConflictFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.isResolved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(file.isResolved ? .green : .red)

            Image(systemName: FileTypeIcon.systemIcon(for: file.filename))
                .foregroundColor(FileTypeIcon.color(for: file.filename))

            VStack(alignment: .leading) {
                Text(file.filename)
                    .lineLimit(1)

                let dir = URL(fileURLWithPath: file.path).deletingLastPathComponent().path
                if !dir.isEmpty && dir != "." {
                    Text(dir)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if file.isResolved {
                Text("Resolved")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ThreeWayMergeView: View {
    let file: ConflictFile
    @ObservedObject var viewModel: ConflictResolverViewModel
    @State private var outputContent: String = ""
    @State private var aiResolution: ConflictResolution?
    @State private var isGeneratingAI = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(file.path)
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        isGeneratingAI = true
                        aiResolution = await viewModel.resolveWithAI(file)
                        if let resolution = aiResolution {
                            outputContent = resolution.suggestion
                        }
                        isGeneratingAI = false
                    }
                } label: {
                    if isGeneratingAI {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("AI Resolve", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingAI)

                Button("Use Ours") {
                    Task { await viewModel.resolveWithOurs(file) }
                }
                .buttonStyle(.bordered)

                Button("Use Theirs") {
                    Task { await viewModel.resolveWithTheirs(file) }
                }
                .buttonStyle(.bordered)

                Button("Save Resolution") {
                    Task { await viewModel.resolveWithCustom(file, content: outputContent) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(outputContent.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // AI resolution info
            if let resolution = aiResolution {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)

                    Text("AI Suggestion")
                        .fontWeight(.medium)

                    ConfidenceBadge(confidence: resolution.confidence)

                    Spacer()

                    Text(resolution.explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color.purple.opacity(0.1))

                Divider()
            }

            // Three panels
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Ours (left)
                    MergePanel(
                        title: "Ours (Current)",
                        content: file.oursContent,
                        color: .blue,
                        onSelect: { selected in
                            outputContent += selected + "\n"
                        }
                    )
                    .frame(width: geometry.size.width / 3)

                    Divider()

                    // Output (center)
                    OutputPanel(
                        content: $outputContent
                    )
                    .frame(width: geometry.size.width / 3)

                    Divider()

                    // Theirs (right)
                    MergePanel(
                        title: "Theirs (Incoming)",
                        content: file.theirsContent,
                        color: .green,
                        onSelect: { selected in
                            outputContent += selected + "\n"
                        }
                    )
                    .frame(width: geometry.size.width / 3)
                }
            }
        }
        .onAppear {
            // Initialize output with base content or empty
            outputContent = file.baseContent ?? ""
        }
    }
}

struct MergePanel: View {
    let title: String
    let content: String
    let color: Color
    var onSelect: (String) -> Void = { _ in }

    @State private var selectedLines: Set<Int> = []

    var lines: [String] {
        content.components(separatedBy: .newlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()

                if !selectedLines.isEmpty {
                    Button("Add Selected") {
                        let selected = selectedLines.sorted().map { lines[$0] }.joined(separator: "\n")
                        onSelect(selected)
                        selectedLines.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding(8)
            .background(color.opacity(0.1))

            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                                .padding(.trailing, 8)

                            Text(line.isEmpty ? " " : line)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 1)
                        .padding(.horizontal, 4)
                        .background(selectedLines.contains(index) ? color.opacity(0.2) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedLines.contains(index) {
                                selectedLines.remove(index)
                            } else {
                                selectedLines.insert(index)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct OutputPanel: View {
    @Binding var content: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                Text("Output")
                    .font(.caption.weight(.semibold))
                Spacer()

                Button {
                    content = ""
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))

            // Editable content
            TextEditor(text: $content)
                .font(.system(.caption, design: .monospaced))
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: ConflictResolution.Confidence

    var body: some View {
        Text(confidence.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    var color: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

struct EmptyConflictView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("No conflicts to resolve")
                .font(.headline)

            Text("Select a conflicted file from the list")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Conflict Resolution View (VS Code style)

/// View that shows conflicts inline with action buttons like VS Code
struct InlineConflictResolverView: View {
    let filePath: String
    let repositoryPath: String
    @Binding var isPresented: Bool
    var onResolved: () -> Void = {}

    @State private var fileContent: String = ""
    @State private var chunks: [ConflictChunk] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("Resolve Conflicts: \(URL(fileURLWithPath: filePath).lastPathComponent)")
                    .font(.headline)

                Spacer()

                let resolvedCount = chunks.filter(\.isResolved).count
                Text("\(resolvedCount)/\(chunks.count) resolved")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(resolvedCount == chunks.count ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(resolvedCount == chunks.count ? .green : .orange)
                    .cornerRadius(10)

                Button("Cancel") {
                    isPresented = false
                }

                Button("Save & Mark Resolved") {
                    saveResolution()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!chunks.allSatisfy(\.isResolved))
            }
            .padding()
            .background(Color.orange.opacity(0.1))

            Divider()

            if isLoading {
                ProgressView("Loading file...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Inline conflict view
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(renderContent().enumerated()), id: \.offset) { _, item in
                            switch item {
                            case .normal(let line, let lineNumber):
                                NormalLineView(line: line, lineNumber: lineNumber)

                            case .conflict(let chunkIndex):
                                if chunkIndex < chunks.count {
                                    ConflictChunkView(
                                        chunk: chunks[chunkIndex],
                                        onResolve: { resolution in
                                            chunks[chunkIndex].resolution = resolution
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .task {
            await loadFile()
        }
    }

    private func loadFile() async {
        isLoading = true
        let fullPath = URL(fileURLWithPath: repositoryPath).appendingPathComponent(filePath).path

        do {
            fileContent = try String(contentsOfFile: fullPath, encoding: .utf8)
            chunks = ConflictParser.parseConflicts(from: fileContent)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func saveResolution() {
        let resolvedContent = ConflictParser.applyResolutions(to: fileContent, chunks: chunks)
        let fullPath = URL(fileURLWithPath: repositoryPath).appendingPathComponent(filePath).path

        do {
            try resolvedContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
            onResolved()
            isPresented = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    enum RenderItem {
        case normal(line: String, lineNumber: Int)
        case conflict(chunkIndex: Int)
    }

    private func renderContent() -> [RenderItem] {
        let lines = fileContent.components(separatedBy: .newlines)
        var items: [RenderItem] = []
        var lineIndex = 0
        var chunkIndex = 0

        while lineIndex < lines.count {
            if chunkIndex < chunks.count && lineIndex == chunks[chunkIndex].startLine {
                items.append(.conflict(chunkIndex: chunkIndex))
                lineIndex = chunks[chunkIndex].endLine + 1
                chunkIndex += 1
            } else {
                items.append(.normal(line: lines[lineIndex], lineNumber: lineIndex + 1))
                lineIndex += 1
            }
        }

        return items
    }
}

struct NormalLineView: View {
    let line: String
    let lineNumber: Int

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            Text(line.isEmpty ? " " : line)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
    }
}

struct ConflictChunkView: View {
    let chunk: ConflictChunk
    var onResolve: (ConflictChunk.ChunkResolution) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ConflictActionBar(chunk: chunk, onResolve: onResolve)
            OursSection(chunk: chunk)
            SeparatorSection()
            TheirsSection(chunk: chunk)
        }
        .background(Color.orange.opacity(chunk.isResolved ? 0 : 0.05))
        .cornerRadius(4)
        .padding(.vertical, 4)
    }
}

struct ConflictActionBar: View {
    let chunk: ConflictChunk
    var onResolve: (ConflictChunk.ChunkResolution) -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button { onResolve(.ours) } label: {
                Text("Accept Current Change").font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.blue)

            Text("|").foregroundColor(.secondary)

            Button { onResolve(.theirs) } label: {
                Text("Accept Incoming Change").font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.green)

            Text("|").foregroundColor(.secondary)

            Button { onResolve(.both) } label: {
                Text("Accept Both Changes").font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.purple)

            Spacer()

            if chunk.isResolved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Resolved")
                }
                .font(.caption)
                .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
    }
}

struct OursSection: View {
    let chunk: ConflictChunk

    private var isSelected: Bool {
        chunk.resolution == .ours || chunk.resolution == .both
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("<<<<<<< Current Change (yours)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.15))

            ForEach(Array(chunk.oursLines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.blue.opacity(0.3), lineWidth: chunk.resolution == .ours ? 2 : 0)
        )
    }
}

struct SeparatorSection: View {
    var body: some View {
        HStack {
            Text("=======")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
    }
}

struct TheirsSection: View {
    let chunk: ConflictChunk

    private var isSelected: Bool {
        chunk.resolution == .theirs || chunk.resolution == .both
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chunk.theirsLines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.green.opacity(0.1) : Color.green.opacity(0.05))
            }

            HStack {
                Text(">>>>>>> Incoming Change (theirs)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green.opacity(0.3), lineWidth: chunk.resolution == .theirs ? 2 : 0)
        )
    }
}

// MARK: - Quick Conflict Resolver (for single file)

/// Quick resolver for a single conflicted file - shows as sheet
struct QuickConflictResolverSheet: View {
    let conflictedFile: FileStatus
    let repositoryPath: String
    @Binding var isPresented: Bool
    var onResolved: () -> Void = {}

    var body: some View {
        InlineConflictResolverView(
            filePath: conflictedFile.path,
            repositoryPath: repositoryPath,
            isPresented: $isPresented,
            onResolved: onResolved
        )
    }
}

// #Preview {
//     ConflictResolverView()
//         .environmentObject(AppState())
//         .frame(width: 1000, height: 600)
// }
