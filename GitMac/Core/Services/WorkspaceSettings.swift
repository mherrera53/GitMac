import Foundation

// MARK: - Workspace Settings Manager

/// Manages per-repository settings for integrations like Taiga and Microsoft Planner
@MainActor
class WorkspaceSettingsManager: ObservableObject {
    static let shared = WorkspaceSettingsManager()

    @Published var workspaces: [String: WorkspaceConfig] = [:]

    private let userDefaultsKey = "workspace_settings"

    private init() {
        load()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: WorkspaceConfig].self, from: data) {
            workspaces = decoded
        }
    }

    // MARK: - Access

    func getConfig(for repoPath: String) -> WorkspaceConfig {
        workspaces[repoPath] ?? WorkspaceConfig()
    }

    func setConfig(for repoPath: String, config: WorkspaceConfig) {
        workspaces[repoPath] = config
        save()
    }

    func setTaigaProject(for repoPath: String, projectId: Int?, projectName: String?) {
        var config = getConfig(for: repoPath)
        config.taigaProjectId = projectId
        config.taigaProjectName = projectName
        setConfig(for: repoPath, config: config)
    }

    func setPlannerPlan(for repoPath: String, planId: String?, planName: String?) {
        var config = getConfig(for: repoPath)
        config.plannerPlanId = planId
        config.plannerPlanName = planName
        setConfig(for: repoPath, config: config)
    }

    func setCodeBuildProject(for repoPath: String, projectName: String?) {
        var config = getConfig(for: repoPath)
        config.codeBuildProjectName = projectName
        setConfig(for: repoPath, config: config)
    }

    func setMainBranch(for repoPath: String, branchName: String?) {
        var config = getConfig(for: repoPath)
        config.mainBranchName = branchName
        setConfig(for: repoPath, config: config)
    }

    func getMainBranch(for repoPath: String) -> String {
        // Get configured main branch, fallback to "main"
        getConfig(for: repoPath).mainBranchName ?? "main"
    }
}

// MARK: - Workspace Configuration

struct WorkspaceConfig: Codable {
    // Git Configuration
    var mainBranchName: String?  // Per-repository main branch (e.g., "main", "master", "develop")

    // Taiga Integration
    var taigaProjectId: Int?
    var taigaProjectName: String?

    // Microsoft Planner Integration
    var plannerPlanId: String?
    var plannerPlanName: String?
    var plannerGroupId: String?

    // Future integrations
    var jiraProjectKey: String?
    var linearTeamId: String?
    var asanaProjectId: String?

    // AWS CodeBuild
    var codeBuildProjectName: String?

    init() {}
}

// MARK: - Integration Type

enum IntegrationType: String, CaseIterable, Identifiable {
    case taiga = "Taiga"
    case planner = "Microsoft Planner"
    case github = "GitHub Issues"
    case jira = "Jira"
    case linear = "Linear"
    case notion = "Notion"
    case asana = "Asana"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .taiga: return "ticket.fill"
        case .planner: return "calendar.badge.checkmark"
        case .github: return "circle.dashed"
        case .jira: return "square.stack.3d.up.fill"
        case .linear: return "lineweight"
        case .notion: return "doc.text.fill"
        case .asana: return "checklist"
        }
    }

    var color: String {
        switch self {
        case .taiga: return "4DC8A8"
        case .planner: return "0078D4"
        case .github: return "238636"
        case .jira: return "0052CC"
        case .linear: return "5E6AD2"
        case .notion: return "000000"
        case .asana: return "F06A6A"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .taiga, .planner, .github, .jira, .linear, .notion:
            return true
        default:
            return false
        }
    }
}
