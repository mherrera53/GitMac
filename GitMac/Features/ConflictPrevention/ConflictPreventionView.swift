import SwiftUI

// MARK: - Conflict Prevention View

/// Main view for analyzing potential merge conflicts before they happen
struct ConflictPreventionView: View {
    @StateObject private var themeManager = ThemeManager.shared

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
        .cornerRadius(DesignTokens.CornerRadius.lg)
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
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            Image(systemName: "exclamationmark.shield")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.warning)

            Text("CONFLICT PREVENTION")
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            if let analysis = viewModel.analysis {
                conflictBadge(analysis)
            }

            Button {
                Task { await analyze() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(DesignTokens.Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.textPrimary)
            .disabled(viewModel.isAnalyzing)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(AppTheme.textMuted.opacity(0.1))
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
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.warning)
                Text("\(analysis.potentialConflicts.count)")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs + 2)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(AppTheme.error.opacity(0.2))
            .foregroundColor(AppTheme.error)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        } else {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.success)
                Text("Safe")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs + 2)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(AppTheme.success.opacity(0.2))
            .foregroundColor(AppTheme.success)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
    }

    // MARK: - Branch Selection

    private var branchSelectionView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Source branch
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("From")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textPrimary)

                DSPicker(selection: $selectedSourceBranch) {
                    ForEach(viewModel.branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Image(systemName: "arrow.right")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)

            // Target branch
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Into")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textPrimary)

                DSPicker(selection: $selectedTargetBranch) {
                    ForEach(viewModel.branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
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
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - Progress View

    private var analysisProgressView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Analyzing potential conflicts...")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }

    // MARK: - Results View

    @ViewBuilder
    private func analysisResultsView(_ analysis: ConflictPreventionService.ConflictAnalysis) -> some View {
        VStack(spacing: 0) {
            // Summary
            HStack {
                if analysis.hasConflicts {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.warning)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                }

                Text(analysis.summary)
                    .font(DesignTokens.Typography.callout)

                Spacer()

                Text("Analyzed \(analysis.analyzedAt, style: .relative) ago")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(analysis.hasConflicts ? AppTheme.warning.opacity(0.1) : AppTheme.success.opacity(0.1))

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
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                // TODO: Replace with appropriate Typography token when available for large icons
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(AppTheme.warning)

            Text("Analysis Failed")
                .font(DesignTokens.Typography.callout)
                .fontWeight(.medium)

            Text(error)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "shield.checkered")
                // TODO: Replace with appropriate Typography token when available for large icons
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(AppTheme.textPrimary)

            Text("Select branches to analyze")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)

            Text("Detect potential merge conflicts before they happen")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
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
            HStack(spacing: DesignTokens.Spacing.sm + 2) {
                // Severity icon
                Image(systemName: conflict.severity.icon)
                    .font(.system(size: DesignTokens.Size.iconSM))
                    .fontDesign(.default)
                    .foregroundColor(severityColor)
                    .frame(width: 20)

                // File info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(conflict.file)
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        // Line range
                        Text("Lines \(conflict.sourceLines.lowerBound)-\(conflict.sourceLines.upperBound)")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textPrimary)

                        // Authors
                        if let sourceAuthor = conflict.sourceAuthor {
                            HStack(spacing: DesignTokens.Spacing.xxs) {
                                Circle()
                                    .fill(AppTheme.info.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Text(String(sourceAuthor.prefix(1)).uppercased())
                                            .font(DesignTokens.Typography.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppTheme.info)
                                    )
                                Text(sourceAuthor)
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        if conflict.sourceAuthor != conflict.targetAuthor,
                           let targetAuthor = conflict.targetAuthor {
                            Text("vs")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(AppTheme.textPrimary)

                            HStack(spacing: DesignTokens.Spacing.xxs) {
                                Circle()
                                    .fill(AppTheme.accentPurple.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Text(String(targetAuthor.prefix(1)).uppercased())
                                            .font(DesignTokens.Typography.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppTheme.accentPurple)
                                    )
                                Text(targetAuthor)
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                }

                Spacer()

                // Severity badge
                Text(conflict.severity.rawValue.capitalized)
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, DesignTokens.Spacing.xs + 2)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(severityColor.opacity(0.2))
                    .foregroundColor(severityColor)
                    .cornerRadius(DesignTokens.CornerRadius.sm)

                // Expand button
                if conflict.overlappingContent != nil {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
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
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(conflict.sourceBranch)
                            .font(DesignTokens.Typography.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.info)

                        Text(content.sourceContent)
                            .font(DesignTokens.Typography.caption)
                            .lineLimit(10)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.info.opacity(0.05))

                    // Target content
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(conflict.targetBranch)
                            .font(DesignTokens.Typography.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentPurple)

                        Text(content.targetContent)
                            .font(DesignTokens.Typography.caption)
                            .lineLimit(10)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.accentPurple.opacity(0.05))
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }

            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var severityColor: Color {
        switch conflict.severity {
        case .high: return AppTheme.error
        case .medium: return AppTheme.warning
        case .low: return AppTheme.warning
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
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(hasConflicts ? AppTheme.warning : AppTheme.success)
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
