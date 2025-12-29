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
    @StateObject private var themeManager = ThemeManager.shared

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
                    .foregroundColor(AppTheme.warning)
                Text("AWS CODEBUILD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                if let project = assignedProject {
                    Text(project)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.success)
                        .cornerRadius(4)
                }

                if viewModel.isConfigured {
                    Text(viewModel.region)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.warning.opacity(0.2))
                        .cornerRadius(4)
                }

                Button {
                    Task { await viewModel.refresh(projectFilter: assignedProject) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
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
                            .foregroundColor(AppTheme.textSecondary)
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
                    Text("\(viewModel.builds.count) builds")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

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
            // Only check credentials on mount - don't load builds (lazy loading)
            await viewModel.loadCredentials()
            // Skip auto-refresh to prevent hang on open
            // User can click refresh to load builds when ready
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
                .foregroundColor(AppTheme.textSecondary)

            Text("AWS not configured")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)

            Text("Add AWS credentials in ~/.aws/credentials\nor set AWS_ACCESS_KEY_ID environment variable")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
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
                .foregroundColor(AppTheme.warning)

            Text("Failed to load builds")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)

            Text(viewModel.error ?? "")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.refresh() }
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
                .foregroundColor(AppTheme.textSecondary)
            Text("No builds found")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
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
    @StateObject private var themeManager = ThemeManager.shared
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
                .foregroundColor(isSelected ? AppTheme.background : AppTheme.textPrimary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Build Row

struct AWSBuildRow: View {
    @StateObject private var themeManager = ThemeManager.shared
    let build: CodeBuild
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Status
            Image(systemName: build.statusIcon)
                .font(.system(size: 16))
                .foregroundColor(build.statusColor)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(build.projectName)
                        .font(.system(size: 12, weight: .medium))

                    if let num = build.buildNumber {
                        Text("#\(num)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if build.buildStatus == "IN_PROGRESS" {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }

                HStack(spacing: 6) {
                    if let phase = build.currentPhase {
                        Text(phase)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if let source = build.sourceVersion {
                        Text(String(source.prefix(7)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if let initiator = build.initiator {
                        Text("by \(initiator)")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textPrimary)
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
                .foregroundColor(build.statusColor)
                .cornerRadius(4)

            // Time and Duration
            VStack(alignment: .trailing, spacing: 2) {
                // Execution start time (e.g., "10:30 AM")
                if let startTime = build.startTime {
                    Text(formatStartTime(startTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                // Relative time and duration
                HStack(spacing: 4) {
                    Text(build.timeAgo)
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    if let duration = build.duration {
                        Text("•")
                            .foregroundColor(AppTheme.textPrimary)
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(duration)
                                .font(.system(size: 9))
                        }
                        .foregroundColor(AppTheme.textPrimary)
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
                        .foregroundColor(AppTheme.textSecondary)
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
        formatter.dateFormat = "h:mm a"
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

    private var accessKeyId: String = ""
    private var secretAccessKey: String = ""

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

    func refresh(projectFilter: String? = nil) async {
        guard isConfigured else { return }

        await MainActor.run { isLoading = true; error = nil }
        
        let currentRegion = region // Capture region for use in async calls

        // Load builds first (priority) - filter by project if specified (much faster!)
        var buildIds: [String] = []

        if let filter = projectFilter, !filter.isEmpty {
            // Fast path: only get builds for the assigned project (limit to 10)
            let buildsResult = await runAWSCommandAsync(["codebuild", "list-builds-for-project", "--project-name", filter, "--max-items", "10", "--region", currentRegion, "--output", "json"])
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
            let buildsResult = await runAWSCommandAsync(["codebuild", "list-builds", "--max-items", "5", "--region", currentRegion, "--output", "json"])
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
            let detailsResult = await runAWSCommandAsync(["codebuild", "batch-get-builds", "--ids"] + idsToFetch + ["--region", currentRegion, "--output", "json"])

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

                        if let startTimeNum = buildDict["startTime"] as? Double {
                            startTime = Date(timeIntervalSince1970: startTimeNum)
                        }
                        if let endTimeNum = buildDict["endTime"] as? Double {
                            endTime = Date(timeIntervalSince1970: endTimeNum)
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
                    await MainActor.run { builds = loadedBuilds }
                }
            } else {
                await MainActor.run { error = detailsResult.output }
            }
        } else {
            // No builds found - clear the list
            await MainActor.run { builds = [] }
        }

        // Load projects (for picker, after builds are loaded)
        let projectsResult = await runAWSCommandAsync(["codebuild", "list-projects", "--region", currentRegion, "--output", "json"])
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

        await MainActor.run { isLoading = false }
    }

    // MARK: - AWS Command Execution (runs off main thread)
    
    nonisolated private func runAWSCommandAsync(_ arguments: [String], timeout: TimeInterval = 15) async -> (success: Bool, output: String) {
        // Use Task.detached to ensure we're completely off the main actor
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            
            // Try multiple AWS CLI locations
            let awsPaths = ["/opt/homebrew/bin/aws", "/usr/local/bin/aws", "/usr/bin/aws"]
            var awsPath: String? = nil
            for path in awsPaths {
                if FileManager.default.fileExists(atPath: path) {
                    awsPath = path
                    break
                }
            }
            
            guard let foundPath = awsPath else {
                return (false, "AWS CLI not found")
            }
            
            process.executableURL = URL(fileURLWithPath: foundPath)
            process.arguments = arguments
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            // Set up timeout with continuation
            do {
                try process.run()

                // Run timeout in background
                Task.detached { [process] in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()

                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                // Check if process was terminated (typically SIGTERM = 15)
                if process.terminationReason == .uncaughtSignal {
                    return (false, "Timeout after \(Int(timeout))s")
                }

                if process.terminationStatus == 0 {
                    return (true, output)
                } else {
                    return (false, errorOutput.isEmpty ? output : errorOutput)
                }
            } catch {
                return (false, error.localizedDescription)
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
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Native macOS toolbar style header
            HStack {
                Text("AWS CodeBuild")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
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
