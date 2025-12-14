import SwiftUI

// MARK: - Conflict Prevention View

/// Main view for analyzing potential merge conflicts before they happen
struct ConflictPreventionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ConflictPreventionViewModel()
    @State private var selectedSourceBranch: String = ""
    @State private var selectedTargetBranch: String = "main"
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            if isExpanded {
                // Branch Selection
                branchSelectionView

                Divider()

                // Results
                if viewModel.isAnalyzing {
                    analysisProgressView
                } else if let analysis = viewModel.analysis {
                    analysisResultsView(analysis)
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    emptyStateView
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .task {
            await loadBranches()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 12))
                .foregroundColor(.orange)

            Text("CONFLICT PREVENTION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()

            if let analysis = viewModel.analysis {
                conflictBadge(analysis)
            }

            Button {
                Task { await analyze() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(viewModel.isAnalyzing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private func conflictBadge(_ analysis: ConflictPreventionService.ConflictAnalysis) -> some View {
        if analysis.hasConflicts {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                Text("\(analysis.potentialConflicts.count)")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .cornerRadius(4)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                Text("Safe")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.2))
            .foregroundColor(.green)
            .cornerRadius(4)
        }
    }

    // MARK: - Branch Selection

    private var branchSelectionView: some View {
        HStack(spacing: 12) {
            // Source branch
            VStack(alignment: .leading, spacing: 4) {
                Text("From")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedSourceBranch) {
                    ForEach(viewModel.branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Target branch
            VStack(alignment: .leading, spacing: 4) {
                Text("Into")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedTargetBranch) {
                    ForEach(viewModel.branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            // Analyze button
            Button("Analyze") {
                Task { await analyze() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedSourceBranch.isEmpty || selectedTargetBranch.isEmpty || viewModel.isAnalyzing)
        }
        .padding(12)
    }

    // MARK: - Progress View

    private var analysisProgressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Analyzing potential conflicts...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // MARK: - Results View

    @ViewBuilder
    private func analysisResultsView(_ analysis: ConflictPreventionService.ConflictAnalysis) -> some View {
        VStack(spacing: 0) {
            // Summary
            HStack {
                if analysis.hasConflicts {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Text(analysis.summary)
                    .font(.system(size: 12))

                Spacer()

                Text("Analyzed \(analysis.analyzedAt, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(analysis.hasConflicts ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))

            if analysis.hasConflicts {
                // Conflict list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(analysis.potentialConflicts) { conflict in
                            ConflictRowView(conflict: conflict)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            Text("Analysis Failed")
                .font(.system(size: 12, weight: .medium))

            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("Select branches to analyze")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Detect potential merge conflicts before they happen")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // MARK: - Actions

    private func loadBranches() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.loadBranches(at: repoPath)

        // Set current branch as source
        if let currentBranch = appState.currentRepository?.head?.name {
            selectedSourceBranch = currentBranch
        }

        // Set main/master as target
        if viewModel.branches.contains("main") {
            selectedTargetBranch = "main"
        } else if viewModel.branches.contains("master") {
            selectedTargetBranch = "master"
        }
    }

    private func analyze() async {
        guard let repoPath = appState.currentRepository?.path else { return }
        await viewModel.analyze(
            source: selectedSourceBranch,
            target: selectedTargetBranch,
            at: repoPath
        )
    }
}

// MARK: - Conflict Row View

struct ConflictRowView: View {
    let conflict: ConflictPreventionService.PotentialConflict
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 10) {
                // Severity icon
                Image(systemName: conflict.severity.icon)
                    .font(.system(size: 14))
                    .foregroundColor(severityColor)
                    .frame(width: 20)

                // File info
                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.file)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Line range
                        Text("Lines \(conflict.sourceLines.lowerBound)-\(conflict.sourceLines.upperBound)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)

                        // Authors
                        if let sourceAuthor = conflict.sourceAuthor {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Text(String(sourceAuthor.prefix(1)).uppercased())
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(.blue)
                                    )
                                Text(sourceAuthor)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if conflict.sourceAuthor != conflict.targetAuthor,
                           let targetAuthor = conflict.targetAuthor {
                            Text("vs")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)

                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color.purple.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Text(String(targetAuthor.prefix(1)).uppercased())
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(.purple)
                                    )
                                Text(targetAuthor)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // Severity badge
                Text(conflict.severity.rawValue.capitalized)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.2))
                    .foregroundColor(severityColor)
                    .cornerRadius(4)

                // Expand button
                if conflict.overlappingContent != nil {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if conflict.overlappingContent != nil {
                    withAnimation { isExpanded.toggle() }
                }
            }

            // Expanded content
            if isExpanded, let content = conflict.overlappingContent {
                HStack(spacing: 1) {
                    // Source content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conflict.sourceBranch)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)

                        Text(content.sourceContent)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(10)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))

                    // Target content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conflict.targetBranch)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.purple)

                        Text(content.targetContent)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(10)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.05))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var severityColor: Color {
        switch conflict.severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}

// MARK: - View Model

@MainActor
class ConflictPreventionViewModel: ObservableObject {
    @Published var branches: [String] = []
    @Published var analysis: ConflictPreventionService.ConflictAnalysis?
    @Published var isAnalyzing = false
    @Published var error: String?

    private let service = ConflictPreventionService.shared
    private let engine = GitEngine()

    func loadBranches(at repoPath: String) async {
        do {
            let branchList = try await engine.getBranches(at: repoPath)
            branches = branchList.map { $0.name }
        } catch {
            branches = []
        }
    }

    func analyze(source: String, target: String, at repoPath: String) async {
        isAnalyzing = true
        error = nil

        do {
            analysis = try await service.analyzeConflicts(
                source: source,
                target: target,
                at: repoPath
            )
        } catch {
            self.error = error.localizedDescription
        }

        isAnalyzing = false
    }
}

// MARK: - Compact Badge for Branch List

/// A small badge to show conflict status in branch lists
struct ConflictPreventionBadge: View {
    let branchName: String
    let targetBranch: String
    let repoPath: String

    @State private var hasConflicts: Bool?
    @State private var isChecking = false

    var body: some View {
        Group {
            if isChecking {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else if let hasConflicts = hasConflicts {
                Image(systemName: hasConflicts ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(hasConflicts ? .orange : .green)
            }
        }
        .task {
            await checkConflicts()
        }
    }

    private func checkConflicts() async {
        guard branchName != targetBranch else {
            hasConflicts = false
            return
        }

        isChecking = true
        do {
            hasConflicts = try await ConflictPreventionService.shared.hasConflicts(
                source: branchName,
                target: targetBranch,
                at: repoPath
            )
        } catch {
            hasConflicts = nil
        }
        isChecking = false
    }
}
