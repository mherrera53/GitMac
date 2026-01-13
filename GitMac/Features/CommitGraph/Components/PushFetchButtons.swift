import SwiftUI

struct PushFetchButtons: View {
    let currentBranch: Branch?
    let aheadCount: Int
    let behindCount: Int
    let lastFetchDate: Date?
    let onPush: () -> Void
    let onFetch: () -> Void
    var repoPath: String? = nil

    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var cicdStatus = CICDBadgeViewModel()

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        return HStack(spacing: DesignTokens.Spacing.xs) {
            // CI/CD Badge
            if let status = cicdStatus.lastBuildStatus {
                CICDBadge(status: status, isLoading: cicdStatus.isLoading)
            }

            // Sync button (one-click pull + push)
            if aheadCount > 0 || behindCount > 0 {
                SyncButton(currentBranch: currentBranch)
            }

            // Push button with enhanced icons
            Button(action: onPush) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: aheadCount > 0 ? "arrow.up.square.fill" : "arrow.up.circle")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(aheadCount > 0 ? AppTheme.success : theme.textMuted)
                        .symbolRenderingMode(.hierarchical)

                    Text("Push")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(aheadCount > 0 ? .semibold : .regular)
                        .foregroundColor(theme.text)

                    if aheadCount > 0 {
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.success, AppTheme.success.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AppTheme.success.opacity(0.3), radius: 2, x: 0, y: 1)

                            Text("\(aheadCount)")
                                .font(DesignTokens.Typography.caption2.monospacedDigit())
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.buttonTextOnColor)
                        }
                        .frame(height: 18)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(theme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(.plain)
            .disabled(aheadCount == 0 || currentBranch == nil)
            .help(aheadCount > 0 ? "Push \(aheadCount) commits" : "Nothing to push")

            // Fetch button with enhanced icons
            Button(action: onFetch) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: behindCount > 0 ? "arrow.down.square.fill" : "arrow.down.circle")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(behindCount > 0 ? AppTheme.warning : theme.textMuted)
                        .symbolRenderingMode(.hierarchical)

                    Text("Fetch")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(behindCount > 0 ? .semibold : .regular)
                        .foregroundColor(theme.text)

                    if let lastFetch = lastFetchDate {
                        Text("(\(relativeTime(from: lastFetch)))")
                            .font(DesignTokens.Typography.caption2.monospacedDigit())
                            .foregroundColor(theme.textMuted)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(theme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .buttonStyle(.plain)
            .help("Fetch from remote")
        }
        .task(id: repoPath) {
            await cicdStatus.loadStatus(for: repoPath)
        }
        .onReceive(NotificationCenter.default.publisher(for: .gitPushCompleted)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5s for CI to start
                await cicdStatus.loadStatus(for: repoPath)
            }
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}

// MARK: - CI/CD Toolbar Badge (standalone)

struct CICDToolbarBadge: View {
    let repoPath: String?
    @StateObject private var viewModel = CICDBadgeViewModel()

    var body: some View {
        Group {
            if let status = viewModel.lastBuildStatus {
                Button {
                    NotificationCenter.default.post(name: .showCICD, object: nil)
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        } else {
                            Circle()
                                .fill(status.color)
                                .frame(width: 6, height: 6)
                        }
                        Text(status.shortLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("CI/CD: \(status.label) - Click to view")
            }
        }
        .task(id: repoPath) {
            await viewModel.loadStatus(for: repoPath)
        }
        .onReceive(NotificationCenter.default.publisher(for: .gitPushCompleted)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await viewModel.loadStatus(for: repoPath)
            }
        }
    }
}

// MARK: - CI/CD Badge

struct CICDBadge: View {
    let status: BuildStatus
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
            }
            Text(status.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .cornerRadius(6)
        .help("Last build: \(status.label)")
    }
}

enum BuildStatus {
    case success, failed, running, unknown

    @MainActor
    var color: Color {
        switch self {
        case .success: return AppTheme.success
        case .failed: return AppTheme.error
        case .running: return AppTheme.info
        case .unknown: return AppTheme.textMuted
        }
    }

    var label: String {
        switch self {
        case .success: return "Passed"
        case .failed: return "Failed"
        case .running: return "Running"
        case .unknown: return "CI/CD"
        }
    }

    var shortLabel: String {
        switch self {
        case .success: return "✓"
        case .failed: return "✗"
        case .running: return "⋯"
        case .unknown: return "CI"
        }
    }
}

@MainActor
class CICDBadgeViewModel: ObservableObject {
    @Published var lastBuildStatus: BuildStatus?
    @Published var isLoading = false

    private var repoPath: String?

    func loadStatus(for repoPath: String?) async {
        guard let path = repoPath else { return }
        self.repoPath = path

        // Get assigned project for this repo
        let config = WorkspaceSettingsManager.shared.getConfig(for: path)
        guard let projectName = config.codeBuildProjectName, !projectName.isEmpty else {
            lastBuildStatus = nil
            return
        }

        isLoading = true

        // Quick fetch of last build status
        let status = await fetchLastBuildStatus(project: projectName)
        lastBuildStatus = status
        isLoading = false
    }

    private func fetchLastBuildStatus(project: String) async -> BuildStatus {
        // Run AWS command to get last build
        let result = await runAWSCommand([
            "codebuild", "list-builds-for-project",
            "--project-name", project,
            "--max-items", "1",
            "--region", WorkspaceSettingsManager.shared.getConfig(for: repoPath ?? "").awsRegion ?? "us-east-2",
            "--output", "json"
        ])

        guard result.success,
              let data = result.output.data(using: String.Encoding.utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = json["ids"] as? [String],
              let firstId = ids.first else {
            return .unknown
        }

        // Get build details
        let detailResult = await runAWSCommand([
            "codebuild", "batch-get-builds",
            "--ids", firstId,
            "--region", WorkspaceSettingsManager.shared.getConfig(for: repoPath ?? "").awsRegion ?? "us-east-2",
            "--output", "json"
        ])

        guard detailResult.success,
              let detailData = detailResult.output.data(using: String.Encoding.utf8),
              let detailJson = try? JSONSerialization.jsonObject(with: detailData) as? [String: Any],
              let builds = detailJson["builds"] as? [[String: Any]],
              let build = builds.first,
              let statusStr = build["buildStatus"] as? String else {
            return .unknown
        }

        switch statusStr {
        case "SUCCEEDED": return .success
        case "FAILED": return .failed
        case "IN_PROGRESS": return .running
        default: return .unknown
        }
    }

    nonisolated private func runAWSCommand(_ arguments: [String]) async -> (success: Bool, output: String) {
        await Task.detached {
            let process = Process()
            let awsPaths = ["/opt/homebrew/bin/aws", "/usr/local/bin/aws", "/usr/bin/aws"]
            guard let path = awsPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                return (false, "")
            }

            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            env["HOME"] = NSHomeDirectory()
            env["AWS_CONFIG_FILE"] = NSHomeDirectory() + "/.aws/config"
            env["AWS_SHARED_CREDENTIALS_FILE"] = NSHomeDirectory() + "/.aws/credentials"
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do { try process.run() } catch { return (false, "") }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return (process.terminationStatus == 0, String(data: data, encoding: .utf8) ?? "")
        }.value
    }
}
