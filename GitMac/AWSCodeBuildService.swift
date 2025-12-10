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

    var statusColor: Color {
        switch lastBuildStatus {
        case "SUCCEEDED": return .green
        case "FAILED": return .red
        case "IN_PROGRESS": return .blue
        case "STOPPED": return .gray
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

    var statusColor: Color {
        switch buildStatus {
        case "SUCCEEDED": return .green
        case "FAILED": return .red
        case "IN_PROGRESS": return .blue
        case "STOPPED": return .gray
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
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AWSCodeBuildViewModel()
    @State private var selectedFilter: AWSBuildFilter = .all
    @State private var selectedProject: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.orange)
                Text("AWS CODEBUILD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isConfigured {
                    Text(viewModel.region)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            if !viewModel.isConfigured {
                notConfiguredView
            } else if viewModel.error != nil {
                errorView
            } else {
                // Project filter
                if !viewModel.projects.isEmpty {
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
                }

                // Builds list
                if viewModel.isLoading && viewModel.builds.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                }

                // Status bar
                HStack {
                    Text("\(viewModel.builds.count) builds")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Start Build") {
                        // TODO: Start build dialog
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.projects.isEmpty)
                }
                .padding(8)
                .background(Color.gray.opacity(0.05))
            }
        }
        .task {
            await viewModel.loadCredentials()
            await viewModel.refresh()
        }
    }

    private var filteredBuilds: [CodeBuild] {
        var builds = viewModel.builds

        if !selectedProject.isEmpty {
            builds = builds.filter { $0.projectName == selectedProject }
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
                .foregroundColor(.secondary)

            Text("AWS not configured")
                .font(.system(size: 13, weight: .medium))

            Text("Add AWS credentials in ~/.aws/credentials\nor set AWS_ACCESS_KEY_ID environment variable")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Link("AWS CLI Configuration Guide", destination: URL(string: "https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html")!)
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            Text("Failed to load builds")
                .font(.system(size: 13, weight: .medium))

            Text(viewModel.error ?? "")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No builds found")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var color: Color {
        switch self {
        case .all: return .secondary
        case .success: return .green
        case .failed: return .red
        case .running: return .blue
        }
    }
}

struct FilterChip: View {
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
                .background(isSelected ? color : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Build Row

struct AWSBuildRow: View {
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
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                    }

                    if let source = build.sourceVersion {
                        Text(String(source.prefix(7)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if let initiator = build.initiator {
                        Text("by \(initiator)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
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

            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(build.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                if let duration = build.duration {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(duration)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .onHover { isHovered = $0 }
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

    func refresh() async {
        guard isConfigured else { return }

        isLoading = true
        error = nil

        // Note: Full AWS SDK integration would require the AWS SDK for Swift
        // For now, we use a simplified approach with direct API calls

        // In production, you would use:
        // import AWSSDKForSwift
        // let client = try CodeBuildClient(region: region)
        // let response = try await client.listBuilds(input: ListBuildsInput())

        // Simulated data for demonstration
        // Replace with actual AWS SDK calls
        await simulateAWSFetch()

        isLoading = false
    }

    private func simulateAWSFetch() async {
        // This is a placeholder - in production use AWS SDK
        // The real implementation would make authenticated API calls

        // For now, show a message that AWS SDK is needed
        if builds.isEmpty {
            error = "AWS SDK integration required. Install aws-sdk-swift package for full functionality."
        }
    }

    func startBuild(projectName: String) async {
        guard isConfigured else { return }

        isLoading = true

        // AWS SDK call would go here:
        // let input = StartBuildInput(projectName: projectName)
        // let response = try await client.startBuild(input: input)

        await refresh()
    }

    func stopBuild(buildId: String) async {
        guard isConfigured else { return }

        isLoading = true

        // AWS SDK call would go here:
        // let input = StopBuildInput(id: buildId)
        // try await client.stopBuild(input: input)

        await refresh()
    }
}

// MARK: - AWS Panel for sidebar

struct AWSCodeBuildPanel: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AWS CodeBuild")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            AWSCodeBuildView()
        }
        .frame(width: 700, height: 500)
    }
}
