import SwiftUI

// MARK: - LFS Models

struct LFSFile: Identifiable, Hashable {
    let id: UUID
    let path: String
    let size: Int64
    let oid: String // LFS object ID (SHA-256)
    let isPointer: Bool // Is it a pointer file (not yet downloaded)?

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var shortOID: String {
        String(oid.prefix(12))
    }

    init(id: UUID = UUID(), path: String, size: Int64, oid: String, isPointer: Bool = false) {
        self.id = id
        self.path = path
        self.size = size
        self.oid = oid
        self.isPointer = isPointer
    }
}

struct LFSTrackPattern: Identifiable, Hashable {
    let id: UUID
    let pattern: String

    init(id: UUID = UUID(), pattern: String) {
        self.id = id
        self.pattern = pattern
    }
}

struct LFSStorageInfo {
    let localSize: Int64
    let remoteSize: Int64
    let fileCount: Int

    var formattedLocalSize: String {
        ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)
    }

    var formattedRemoteSize: String {
        ByteCountFormatter.string(fromByteCount: remoteSize, countStyle: .file)
    }
}

// MARK: - LFS View

struct LFSManagerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LFSViewModel()
    @State private var selectedTab = 0
    @State private var showTrackSheet = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GIT LFS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isInstalled {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Installed")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("Not installed")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            if !viewModel.isInstalled {
                // LFS not installed
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.xmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("Git LFS is not installed")
                        .font(.system(size: 13, weight: .medium))

                    Text("Install Git LFS to track large files")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button("Install LFS") {
                        Task { await viewModel.install(at: appState.currentRepository?.path) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Tabs
                Picker("", selection: $selectedTab) {
                    Text("Tracked Files").tag(0)
                    Text("Patterns").tag(1)
                    Text("Storage").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(8)

                switch selectedTab {
                case 0:
                    trackedFilesView
                case 1:
                    patternsView
                case 2:
                    storageView
                default:
                    EmptyView()
                }
            }
        }
        .task {
            await viewModel.checkInstallation()
            await viewModel.refresh(at: appState.currentRepository?.path)
        }
        .onChange(of: appState.currentRepository?.path) { _, newPath in
            Task { await viewModel.refresh(at: newPath) }
        }
        .sheet(isPresented: $showTrackSheet) {
            TrackPatternSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Tracked Files Tab

    private var trackedFilesView: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .padding(8)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.ellipsis")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No LFS files tracked")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFiles) { file in
                            LFSFileRow(file: file)
                        }
                    }
                }
            }

            // Actions
            HStack {
                Button("Pull LFS") {
                    Task { await viewModel.pull(at: appState.currentRepository?.path) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Push LFS") {
                    Task { await viewModel.push(at: appState.currentRepository?.path) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Fetch") {
                    Task { await viewModel.fetch(at: appState.currentRepository?.path) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
        }
    }

    private var filteredFiles: [LFSFile] {
        if searchText.isEmpty {
            return viewModel.trackedFiles
        }
        return viewModel.trackedFiles.filter { $0.path.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Patterns Tab

    private var patternsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.patterns) { pattern in
                        HStack {
                            Image(systemName: "doc.badge.gearshape")
                                .foregroundColor(.blue)

                            Text(pattern.pattern)
                                .font(.system(size: 12, design: .monospaced))

                            Spacer()

                            Button {
                                Task { await viewModel.untrack(pattern: pattern.pattern, at: appState.currentRepository?.path) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                    }
                }
            }

            HStack {
                Button("Add Pattern") {
                    showTrackSheet = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
        }
    }

    // MARK: - Storage Tab

    private var storageView: some View {
        VStack(spacing: 16) {
            if let info = viewModel.storageInfo {
                VStack(spacing: 20) {
                    // Local storage
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "internaldrive")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Local Storage")
                                    .font(.system(size: 12, weight: .medium))
                                Text(info.formattedLocalSize)
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    // File count
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.secondary)
                        Text("\(info.fileCount) files tracked")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    Spacer()

                    // Actions
                    VStack(spacing: 8) {
                        Button("Prune Old Objects") {
                            Task { await viewModel.prune(at: appState.currentRepository?.path) }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Text("Remove local copies of old LFS objects")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - LFS File Row

struct LFSFileRow: View {
    let file: LFSFile
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.isPointer ? "arrow.down.circle" : "checkmark.circle.fill")
                .foregroundColor(file.isPointer ? .orange : .green)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.path)
                        .font(.system(size: 10))
                    Text(file.formattedSize)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            if isHovered {
                Text(file.shortOID)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Track Pattern Sheet

struct TrackPatternSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: LFSViewModel

    @State private var pattern = ""
    @State private var selectedPreset: String?

    let presets = [
        "*.psd": "Photoshop files",
        "*.ai": "Illustrator files",
        "*.sketch": "Sketch files",
        "*.zip": "ZIP archives",
        "*.mp4": "MP4 videos",
        "*.mov": "MOV videos",
        "*.mp3": "MP3 audio",
        "*.wav": "WAV audio",
        "*.pdf": "PDF documents",
        "*.docx": "Word documents",
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Track Pattern with LFS")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pattern")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("*.psd, assets/**/*.png", text: $pattern)
                        .textFieldStyle(.roundedBorder)
                }

                Text("Common patterns:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(Array(presets.keys.sorted()), id: \.self) { key in
                        Button {
                            pattern = key
                        } label: {
                            Text(key)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(pattern == key ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(pattern == key ? .white : .primary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Track") {
                    Task {
                        await viewModel.track(pattern: pattern, at: appState.currentRepository?.path)
                        if viewModel.error == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pattern.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

// MARK: - View Model

@MainActor
class LFSViewModel: ObservableObject {
    @Published var isInstalled = false
    @Published var trackedFiles: [LFSFile] = []
    @Published var patterns: [LFSTrackPattern] = []
    @Published var storageInfo: LFSStorageInfo?
    @Published var isLoading = false
    @Published var error: String?

    private let shell = ShellExecutor()

    func checkInstallation() async {
        let result = await shell.execute("git", arguments: ["lfs", "version"], workingDirectory: nil)
        isInstalled = result.isSuccess
    }

    func install(at path: String?) async {
        guard let path = path else { return }

        let result = await shell.execute("git", arguments: ["lfs", "install"], workingDirectory: path)
        if result.isSuccess {
            isInstalled = true
            await refresh(at: path)
        } else {
            error = "Failed to install Git LFS. Make sure it's installed via Homebrew: brew install git-lfs"
        }
    }

    func refresh(at path: String?) async {
        guard let path = path, isInstalled else { return }

        isLoading = true

        // Load tracked patterns
        await loadPatterns(at: path)

        // Load tracked files
        await loadTrackedFiles(at: path)

        // Load storage info
        await loadStorageInfo(at: path)

        isLoading = false
    }

    private func loadPatterns(at path: String) async {
        let result = await shell.execute("git", arguments: ["lfs", "track"], workingDirectory: path)

        if result.isSuccess {
            let lines = result.stdout.components(separatedBy: .newlines)
            patterns = lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, trimmed.contains("(") else { return nil }
                let pattern = trimmed.components(separatedBy: " ").first ?? ""
                return LFSTrackPattern(pattern: pattern)
            }
        }
    }

    private func loadTrackedFiles(at path: String) async {
        let result = await shell.execute("git", arguments: ["lfs", "ls-files", "-l"], workingDirectory: path)

        if result.isSuccess {
            let lines = result.stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
            trackedFiles = lines.compactMap { line in
                // Format: oid - filename (size) or oid * filename (pointer)
                let parts = line.components(separatedBy: " ")
                guard parts.count >= 3 else { return nil }

                let oid = parts[0]
                let isPointer = parts[1] == "*"
                let filename = parts.dropFirst(2).joined(separator: " ")

                return LFSFile(
                    path: filename,
                    size: 0, // Size not available in this format
                    oid: oid,
                    isPointer: isPointer
                )
            }
        }
    }

    private func loadStorageInfo(at path: String) async {
        // Get local LFS object size
        let lfsPath = "\(path)/.git/lfs/objects"
        var localSize: Int64 = 0
        var fileCount = 0

        if let enumerator = FileManager.default.enumerator(atPath: lfsPath) {
            while let file = enumerator.nextObject() as? String {
                let fullPath = "\(lfsPath)/\(file)"
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? Int64 {
                    localSize += size
                    fileCount += 1
                }
            }
        }

        storageInfo = LFSStorageInfo(
            localSize: localSize,
            remoteSize: 0, // Would need API call
            fileCount: trackedFiles.count
        )
    }

    func track(pattern: String, at path: String?) async {
        guard let path = path else { return }

        let result = await shell.execute("git", arguments: ["lfs", "track", pattern], workingDirectory: path)

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to track pattern" : result.stderr
        } else {
            await refresh(at: path)
        }
    }

    func untrack(pattern: String, at path: String?) async {
        guard let path = path else { return }

        let result = await shell.execute("git", arguments: ["lfs", "untrack", pattern], workingDirectory: path)

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to untrack pattern" : result.stderr
        } else {
            await refresh(at: path)
        }
    }

    func pull(at path: String?) async {
        guard let path = path else { return }

        isLoading = true
        let result = await shell.execute("git", arguments: ["lfs", "pull"], workingDirectory: path)

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to pull LFS objects" : result.stderr
        }

        await refresh(at: path)
        isLoading = false
    }

    func push(at path: String?) async {
        guard let path = path else { return }

        isLoading = true
        let result = await shell.execute("git", arguments: ["lfs", "push", "--all", "origin"], workingDirectory: path)

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to push LFS objects" : result.stderr
        }

        isLoading = false
    }

    func fetch(at path: String?) async {
        guard let path = path else { return }

        isLoading = true
        let result = await shell.execute("git", arguments: ["lfs", "fetch"], workingDirectory: path)

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to fetch LFS objects" : result.stderr
        }

        await refresh(at: path)
        isLoading = false
    }

    func prune(at path: String?) async {
        guard let path = path else { return }

        isLoading = true
        let result = await shell.execute("git", arguments: ["lfs", "prune"], workingDirectory: path)

        if !result.isSuccess {
            error = result.stderr.isEmpty ? "Failed to prune LFS objects" : result.stderr
        }

        await refresh(at: path)
        isLoading = false
    }
}
