import SwiftUI
import Foundation

// MARK: - AWS CodeBuild Models

struct CodeBuildProject: Identifiable, Codable {
    let name: String
    let arn: String
    let description: String?
    let sourceType: String?
    let lastBuildStatus: String?

    var id: String { arn }

    @MainActor
    var statusColor: Color {
        switch lastBuildStatus {
        case "SUCCEEDED": return AppTheme.success
        case "FAILED": return AppTheme.error
        case "IN_PROGRESS": return AppTheme.info
        case "STOPPED": return AppTheme.textMuted
        default: return .secondary
        }
    }
}

struct CodeBuild: Identifiable, Codable {
    let id: String
    let arn: String
    let buildNumber: Int?
    let buildStatus: String // SUCCEEDED, FAILED, IN_PROGRESS, STOPPED
    let projectName: String
    let sourceVersion: String?
    let startTime: Date?
    let endTime: Date?
    let currentPhase: String?
    let initiator: String?

    var shortId: String {
        String(id.suffix(8))
    }

    var statusIcon: String {
        switch buildStatus {
        case "SUCCEEDED": return "checkmark.circle.fill"
        case "FAILED": return "xmark.circle.fill"
        case "IN_PROGRESS": return "arrow.triangle.2.circlepath"
        case "STOPPED": return "stop.circle.fill"
        default: return "questionmark.circle"
        }
    }

    @MainActor
    var statusColor: Color {
        switch buildStatus {
        case "SUCCEEDED": return AppTheme.success
        case "FAILED": return AppTheme.error
        case "IN_PROGRESS": return AppTheme.info
        case "STOPPED": return AppTheme.textMuted
        default: return .secondary
        }
    }

    var displayStatus: String {
        switch buildStatus {
        case "SUCCEEDED": return "Success"
        case "FAILED": return "Failed"
        case "IN_PROGRESS": return "Running"
        case "STOPPED": return "Stopped"
        default: return buildStatus
        }
    }

    var duration: String? {
        guard let start = startTime else { return nil }
        let end = endTime ?? Date()
        let elapsed = end.timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return "\(minutes)m \(seconds)s"
    }

    var timeAgo: String {
        guard let start = startTime else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: start, relativeTo: Date())
    }
}

// MARK: - AWS CodeBuild View

struct AWSCodeBuildView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AWSCodeBuildViewModel()
    @StateObject private var workspaceManager = WorkspaceSettingsManager.shared
    @State private var selectedFilter: AWSBuildFilter = .all
    @State private var selectedProject: String = ""

    // Get assigned project for current repo
    private var assignedProject: String? {
        guard let repoPath = appState.currentRepository?.path else { return nil }
        return workspaceManager.getConfig(for: repoPath).codeBuildProjectName
    }

    // Effective project filter (assigned or manual selection)
    private var effectiveProjectFilter: String {
        assignedProject ?? selectedProject
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundStyle(AppTheme.warning)
                Text("AWS CODEBUILD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if let project = assignedProject {
                    Text(project)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.success)
                        .clipShape(.rect(cornerRadius: 4))
                }

                if viewModel.isConfigured {
                    Text(viewModel.region)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.warning.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 4))
                }

                if viewModel.isPolling {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("Live")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.success)
                    }
                }

                Button {
                    Task { await viewModel.refresh(projectFilter: assignedProject) }
                } label: {
                    Image(systemName: viewModel.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary)

            if !viewModel.isConfigured {
                notConfiguredView
            } else if viewModel.error != nil {
                errorView
            } else {
                // Project filter (only show if no assigned project)
                if assignedProject == nil && !viewModel.projects.isEmpty {
                    HStack {
                        Picker("Project", selection: $selectedProject) {
                            Text("All Projects").tag("")
                            ForEach(viewModel.projects) { project in
                                Text(project.name).tag(project.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)

                        Spacer()

                        // Status filters
                        HStack(spacing: 4) {
                            ForEach(AWSBuildFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.title,
                                    isSelected: selectedFilter == filter,
                                    color: filter.color
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(AppTheme.backgroundSecondary.opacity(0.5))
                } else if assignedProject != nil {
                    // Just status filters when project is assigned
                    HStack {
                        Text("Showing builds for assigned project")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(AWSBuildFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.title,
                                    isSelected: selectedFilter == filter,
                                    color: filter.color
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(AppTheme.backgroundSecondary.opacity(0.5))
                }

                // Builds list
                if viewModel.isLoading && viewModel.builds.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background)
                } else if filteredBuilds.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredBuilds) { build in
                                AWSBuildRow(build: build)
                            }
                        }
                    }
                    .background(AppTheme.background)
                }

                // Status bar
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }

                    Text("\(viewModel.builds.count) builds")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    if let lastUpdate = viewModel.lastUpdate {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Button("Start Build") {
                        // TODO: Start build dialog
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.projects.isEmpty)
                }
                .padding(8)
                .background(AppTheme.backgroundSecondary.opacity(0.5))
            }
        }
        .task {
            // Load credentials and fetch builds
            await viewModel.loadCredentials()
            if viewModel.isConfigured {
                await viewModel.refresh(projectFilter: assignedProject)
            }
        }
        // Auto-refresh when push completes (CI/CD builds usually triggered by push)
        .onReceive(NotificationCenter.default.publisher(for: .gitPushCompleted)) { _ in
            Task {
                // Wait a few seconds for AWS to register the build
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await viewModel.refresh(projectFilter: assignedProject)
            }
        }
        // Auto-refresh when merge completes
        .onReceive(NotificationCenter.default.publisher(for: .gitMergeCompleted)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await viewModel.refresh(projectFilter: assignedProject)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshCICD)) { _ in
            Task { await viewModel.refresh(projectFilter: assignedProject) }
        }
    }

    private var filteredBuilds: [CodeBuild] {
        var builds = viewModel.builds

        // Filter by assigned project or manual selection
        if !effectiveProjectFilter.isEmpty {
            builds = builds.filter { $0.projectName == effectiveProjectFilter }
        }

        switch selectedFilter {
        case .all: break
        case .success:
            builds = builds.filter { $0.buildStatus == "SUCCEEDED" }
        case .failed:
            builds = builds.filter { $0.buildStatus == "FAILED" }
        case .running:
            builds = builds.filter { $0.buildStatus == "IN_PROGRESS" }
        }

        return builds
    }

    private var notConfiguredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.textSecondary)

            Text("AWS not configured")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Add AWS credentials in ~/.aws/credentials\nor set AWS_ACCESS_KEY_ID environment variable")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Link("AWS CLI Configuration Guide", destination: URL(string: "https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html")!)
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(AppTheme.background)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.warning)

            Text("Failed to load builds")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            Text(viewModel.error ?? "")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.refresh(projectFilter: assignedProject) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(AppTheme.background)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(AppTheme.textSecondary)
            Text("No builds found")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// MARK: - Filter

enum AWSBuildFilter: CaseIterable {
    case all, success, failed, running

    var title: String {
        switch self {
        case .all: return "All"
        case .success: return "Success"
        case .failed: return "Failed"
        case .running: return "Running"
        }
    }

    @MainActor
    var color: Color {
        switch self {
        case .all: return AppTheme.textSecondary
        case .success: return AppTheme.success
        case .failed: return AppTheme.error
        case .running: return AppTheme.info
        }
    }
}

struct FilterChip: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? color : AppTheme.backgroundSecondary)
                .foregroundStyle(isSelected ? AppTheme.background : AppTheme.textPrimary)
                .clipShape(.rect(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Build Row

struct AWSBuildRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let build: CodeBuild
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Status
            Image(systemName: build.statusIcon)
                .font(.system(size: 16))
                .foregroundStyle(build.statusColor)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(build.projectName)
                        .font(.system(size: 12, weight: .medium))

                    if let num = build.buildNumber {
                        Text("#\(num)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    if build.buildStatus == "IN_PROGRESS" {
                        ProgressView()
                            .scaleEffect(0.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textPrimary))
                    }
                }

                HStack(spacing: 6) {
                    if let phase = build.currentPhase {
                        Text(phase)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    if let source = build.sourceVersion {
                        Text(String(source.prefix(7)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    if let initiator = build.initiator {
                        Text("by \(initiator)")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }

            Spacer()

            // Status badge
            Text(build.displayStatus)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(build.statusColor.opacity(0.15))
                .foregroundStyle(build.statusColor)
                .clipShape(.rect(cornerRadius: 4))

            // Time and Duration
            VStack(alignment: .trailing, spacing: 2) {
                // Execution start time (e.g., "10:30 AM")
                if let startTime = build.startTime {
                    Text(formatStartTime(startTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                
                // Relative time and duration
                HStack(spacing: 4) {
                    Text(build.timeAgo)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    if let duration = build.duration {
                        Text("•")
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(duration)
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
            
            // View Details button (on hover)
            if isHovered {
                Button {
                    openInAWSConsole()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.borderless)
                .help("View in AWS Console")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? AppTheme.backgroundSecondary : Color.clear)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                openInAWSConsole()
            } label: {
                Label("View in AWS Console", systemImage: "safari")
            }
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(build.id, forType: .string)
            } label: {
                Label("Copy Build ID", systemImage: "doc.on.doc")
            }
            
            if build.buildStatus == "IN_PROGRESS" {
                Divider()
                Button(role: .destructive) {
                    // Stop build would be here
                } label: {
                    Label("Stop Build", systemImage: "stop.circle")
                }
            }
        }
    }
    
    private func formatStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Show date if not today, otherwise just time
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: date)
    }
    
    private func openInAWSConsole() {
        // Extract region from ARN or use default
        let region = build.arn.components(separatedBy: ":").dropFirst(3).first ?? "us-east-1"
        let encodedId = build.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? build.id
        let url = URL(string: "https://\(region).console.aws.amazon.com/codesuite/codebuild/projects/\(build.projectName)/build/\(encodedId)")
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - View Model

@MainActor
class AWSCodeBuildViewModel: ObservableObject {
    @Published var projects: [CodeBuildProject] = []
    @Published var builds: [CodeBuild] = []
    @Published var isLoading = false
    @Published var isConfigured = false
    @Published var error: String?
    @Published var region = "us-east-1"
    @Published var isPolling = false
    @Published var lastUpdate: Date?

    private var accessKeyId: String = ""
    private var secretAccessKey: String = ""
    private var pollingTask: Task<Void, Never>?

    /// Check if any builds are in progress
    var hasInProgressBuilds: Bool {
        builds.contains { $0.buildStatus == "IN_PROGRESS" }
    }

    /// Start polling for in-progress builds
    func startPollingIfNeeded(projectFilter: String?) {
        guard hasInProgressBuilds, pollingTask == nil else { return }

        isPolling = true
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                guard let self = self, self.hasInProgressBuilds else {
                    break
                }
                await self.refresh(projectFilter: projectFilter)
            }
            await MainActor.run { [weak self] in
                self?.isPolling = false
                self?.pollingTask = nil
            }
        }
    }

    /// Stop polling
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    func loadCredentials() async {
        // Try environment variables first
        if let keyId = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
           let secret = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] {
            accessKeyId = keyId
            secretAccessKey = secret
            region = ProcessInfo.processInfo.environment["AWS_DEFAULT_REGION"] ?? "us-east-1"
            isConfigured = true
            return
        }

        // Try credentials file
        let credentialsPath = NSHomeDirectory() + "/.aws/credentials"
        guard let content = try? String(contentsOfFile: credentialsPath) else {
            isConfigured = false
            return
        }

        // Parse [default] profile
        var inDefaultProfile = false
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "[default]" {
                inDefaultProfile = true
                continue
            } else if trimmed.hasPrefix("[") {
                inDefaultProfile = false
                continue
            }

            if inDefaultProfile {
                if trimmed.hasPrefix("aws_access_key_id") {
                    accessKeyId = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
                } else if trimmed.hasPrefix("aws_secret_access_key") {
                    secretAccessKey = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
                }
            }
        }

        // Try config file for region
        let configPath = NSHomeDirectory() + "/.aws/config"
        if let configContent = try? String(contentsOfFile: configPath) {
            var inDefaultProfile = false
            for line in configContent.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "[default]" || trimmed == "[profile default]" {
                    inDefaultProfile = true
                    continue
                } else if trimmed.hasPrefix("[") {
                    inDefaultProfile = false
                }
                if inDefaultProfile && trimmed.hasPrefix("region") {
                    region = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "us-east-1"
                }
            }
        }

        isConfigured = !accessKeyId.isEmpty && !secretAccessKey.isEmpty
    }

    /// Run AWS command directly (fast, no retry)
    private func runAWSCommand(_ arguments: [String], timeout: TimeInterval = 30) async -> (success: Bool, output: String) {
        await runAWSCommandAsync(arguments, timeout: timeout)
    }

    func refresh(projectFilter: String? = nil) async {
        guard isConfigured else { return }

        await MainActor.run { isLoading = true; error = nil }

        let currentRegion = region // Capture region for use in async calls

        // Load builds first (priority) - filter by project if specified (much faster!)
        var buildIds: [String] = []

        if let filter = projectFilter, !filter.isEmpty {
            // Fast path: only get builds for the assigned project (limit to 10)
            let buildsResult = await runAWSCommand(["codebuild", "list-builds-for-project", "--project-name", filter, "--max-items", "10", "--region", currentRegion, "--output", "json"])
            if buildsResult.success {
                if let data = buildsResult.output.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ids = json["ids"] as? [String] {
                    buildIds = ids
                }
            } else {
                await MainActor.run { error = buildsResult.output; isLoading = false }
                return
            }
        } else {
            // Get only recent builds (limit to 5 for speed)
            let buildsResult = await runAWSCommand(["codebuild", "list-builds", "--max-items", "5", "--region", currentRegion, "--output", "json"])
            if buildsResult.success {
                if let data = buildsResult.output.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ids = json["ids"] as? [String] {
                    buildIds = ids
                }
            } else {
                await MainActor.run { error = buildsResult.output; isLoading = false }
                return
            }
        }

        if !buildIds.isEmpty {
            // Get build details (only fetch what we have)
            let idsToFetch = Array(buildIds.prefix(10))
            let detailsResult = await runAWSCommand(["codebuild", "batch-get-builds", "--ids"] + idsToFetch + ["--region", currentRegion, "--output", "json"])

            if detailsResult.success {
                if let detailsData = detailsResult.output.data(using: .utf8),
                   let detailsJson = try? JSONSerialization.jsonObject(with: detailsData) as? [String: Any],
                   let buildsArray = detailsJson["builds"] as? [[String: Any]] {

                    var loadedBuilds: [CodeBuild] = []

                    for buildDict in buildsArray {
                        let id = buildDict["id"] as? String ?? ""
                        let arn = buildDict["arn"] as? String ?? ""
                        let buildNumber = buildDict["buildNumber"] as? Int
                        let buildStatus = buildDict["buildStatus"] as? String ?? "UNKNOWN"
                        let projectName = buildDict["projectName"] as? String ?? ""
                        let sourceVersion = buildDict["sourceVersion"] as? String
                        let currentPhase = buildDict["currentPhase"] as? String
                        let initiator = buildDict["initiator"] as? String

                        var startTime: Date?
                        var endTime: Date?

                        // AWS returns ISO8601 date strings with timezone offset
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

                        if let startTimeStr = buildDict["startTime"] as? String {
                            startTime = dateFormatter.date(from: startTimeStr)
                            if startTime == nil {
                                // Try ISO8601 as fallback
                                let iso = ISO8601DateFormatter()
                                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                startTime = iso.date(from: startTimeStr)
                            }
                        }
                        if let endTimeStr = buildDict["endTime"] as? String {
                            endTime = dateFormatter.date(from: endTimeStr)
                            if endTime == nil {
                                let iso = ISO8601DateFormatter()
                                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                endTime = iso.date(from: endTimeStr)
                            }
                        }

                        loadedBuilds.append(CodeBuild(
                            id: id,
                            arn: arn,
                            buildNumber: buildNumber,
                            buildStatus: buildStatus,
                            projectName: projectName,
                            sourceVersion: sourceVersion,
                            startTime: startTime,
                            endTime: endTime,
                            currentPhase: currentPhase,
                            initiator: initiator
                        ))
                    }
                    await MainActor.run {
                        builds = loadedBuilds
                        lastUpdate = Date()
                    }
                }
            } else {
                await MainActor.run { error = detailsResult.output }
            }
        } else {
            // No builds found - clear the list
            await MainActor.run {
                builds = []
                lastUpdate = Date()
            }
        }

        // Load projects (for picker, after builds are loaded)
        let projectsResult = await runAWSCommand(["codebuild", "list-projects", "--region", currentRegion, "--output", "json"])
        if projectsResult.success {
            if let data = projectsResult.output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let projectNames = json["projects"] as? [String] {
                var loadedProjects: [CodeBuildProject] = []
                for name in projectNames {
                    loadedProjects.append(CodeBuildProject(
                        name: name,
                        arn: "arn:aws:codebuild:\(currentRegion):project/\(name)",
                        description: nil,
                        sourceType: nil,
                        lastBuildStatus: nil
                    ))
                }
                await MainActor.run { projects = loadedProjects }
            }
        }

        await MainActor.run { isLoading = false; error = nil }

        // Start polling if there are in-progress builds
        startPollingIfNeeded(projectFilter: projectFilter)
    }

    // MARK: - AWS Command Execution (runs off main thread)
    
    nonisolated private func runAWSCommandAsync(_ arguments: [String], timeout: TimeInterval = 30) async -> (success: Bool, output: String) {
        await Task.detached(priority: .userInitiated) {
            let process = Process()

            // Find AWS CLI
            let awsPaths = ["/opt/homebrew/bin/aws", "/usr/local/bin/aws", "/usr/bin/aws"]
            guard let foundPath = awsPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                return (false, "AWS CLI not found")
            }

            process.executableURL = URL(fileURLWithPath: foundPath)
            process.arguments = arguments

            // Environment for GUI apps
            var env = ProcessInfo.processInfo.environment
            env["HOME"] = NSHomeDirectory()
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            env["AWS_CONFIG_FILE"] = NSHomeDirectory() + "/.aws/config"
            env["AWS_SHARED_CREDENTIALS_FILE"] = NSHomeDirectory() + "/.aws/credentials"
            process.environment = env

            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                return (false, error.localizedDescription)
            }

            // Read output BEFORE waitUntilExit to avoid deadlock
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return (true, output)
            } else {
                return (false, errorOutput.isEmpty ? output : errorOutput)
            }
        }.value
    }

    func startBuild(projectName: String) async {
        guard isConfigured else { return }

        await MainActor.run { isLoading = true }

        let result = await runAWSCommandAsync(["codebuild", "start-build", "--project-name", projectName])
        if !result.success {
            await MainActor.run { error = result.output }
        }

        await refresh()
    }

    func stopBuild(buildId: String) async {
        guard isConfigured else { return }

        await MainActor.run { isLoading = true }

        let result = await runAWSCommandAsync(["codebuild", "stop-build", "--id", buildId])
        if !result.success {
            await MainActor.run { error = result.output }
        }

        await refresh()
    }
}

// MARK: - AWS Panel for sidebar

struct AWSCodeBuildPanel: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Native macOS toolbar style header
            HStack {
                Text("AWS CodeBuild")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.backgroundSecondary)

            Divider()

            AWSCodeBuildView()
                .background(AppTheme.background)
        }
        .frame(width: 700, height: 500)
        .background(AppTheme.background)
    }
}
