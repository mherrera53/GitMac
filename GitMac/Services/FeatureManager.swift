import Foundation
import SwiftUI

// MARK: - Feature Definitions

enum ProFeature: String, CaseIterable {
    // AI Features
    case aiCommitMessages = "AI Commit Messages"
    case aiConflictResolution = "AI Conflict Resolution"
    case aiCodeSuggestions = "AI Code Suggestions"
    case localLLM = "Local LLM Support"
    case multipleAIProviders = "Multiple AI Providers"

    // Integrations
    case jiraIntegration = "Jira Integration"
    case linearIntegration = "Linear Integration"
    case notionIntegration = "Notion Integration"
    case microsoftPlannerIntegration = "Microsoft Planner Integration"
    case taigaIntegration = "Taiga Integration"

    // Advanced Features
    case customThemes = "Custom Themes"
    case advancedDiff = "Advanced Diff Features"
    case customWorkflows = "Custom Workflows"
    case gitHooks = "Git Hooks Management"

    var icon: String {
        switch self {
        case .aiCommitMessages, .aiConflictResolution, .aiCodeSuggestions:
            return "sparkles"
        case .localLLM:
            return "cpu"
        case .multipleAIProviders:
            return "brain"
        case .jiraIntegration, .linearIntegration, .notionIntegration,
             .microsoftPlannerIntegration, .taigaIntegration:
            return "link"
        case .customThemes:
            return "paintbrush"
        case .advancedDiff:
            return "doc.text.magnifyingglass"
        case .customWorkflows, .gitHooks:
            return "gearshape.2"
        }
    }

    var description: String {
        switch self {
        case .aiCommitMessages:
            return "Generate intelligent commit messages with AI"
        case .aiConflictResolution:
            return "Resolve merge conflicts automatically with AI assistance"
        case .aiCodeSuggestions:
            return "Get AI-powered code review and suggestions"
        case .localLLM:
            return "Use local LLMs (Ollama, LM Studio) for complete privacy"
        case .multipleAIProviders:
            return "Access OpenAI, Claude, Gemini, Mistral, Cohere, and more"
        case .jiraIntegration:
            return "Link commits to Jira issues automatically"
        case .linearIntegration:
            return "Sync with Linear for seamless workflow"
        case .notionIntegration:
            return "Document your work directly in Notion"
        case .microsoftPlannerIntegration:
            return "Track tasks in Microsoft Planner"
        case .taigaIntegration:
            return "Connect with Taiga agile boards"
        case .customThemes:
            return "Personalize GitMac with custom color schemes"
        case .advancedDiff:
            return "Word-level diffs, minimap, and more"
        case .customWorkflows:
            return "Create and automate custom Git workflows"
        case .gitHooks:
            return "Manage pre-commit, post-commit, and other hooks"
        }
    }
}

// MARK: - Feature Manager

class FeatureManager: ObservableObject {
    static let shared = FeatureManager()

    @Published var licenseValidator: GitMacLicenseValidator

    private init() {
        self.licenseValidator = GitMacLicenseValidator.shared
    }

    /// Check if a Pro feature is available
    func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        return licenseValidator.hasProFeatures
    }

    /// Get all locked features
    func getLockedFeatures() -> [ProFeature] {
        if licenseValidator.hasProFeatures {
            return []
        }
        return ProFeature.allCases
    }

    /// Get all unlocked features
    func getUnlockedFeatures() -> [ProFeature] {
        if licenseValidator.hasProFeatures {
            return ProFeature.allCases
        }
        return []
    }
}

// MARK: - View Modifier for Feature Blocking

struct ProFeatureModifier: ViewModifier {
    let feature: ProFeature
    @StateObject private var featureManager = FeatureManager.shared
    @State private var showUpgradePrompt = false

    func body(content: Content) -> some View {
        if featureManager.isFeatureAvailable(feature) {
            content
        } else {
            Button {
                showUpgradePrompt = true
            } label: {
                HStack {
                    content
                        .opacity(0.5)

                    Spacer()

                    Image(systemName: "lock.fill")
                        .foregroundColor(AppTheme.warning)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showUpgradePrompt) {
                UpgradePromptView(feature: feature)
            }
        }
    }
}

extension View {
    /// Block this view for non-Pro users
    func requiresProFeature(_ feature: ProFeature) -> some View {
        modifier(ProFeatureModifier(feature: feature))
    }
}

// MARK: - Upgrade Prompt View

struct UpgradePromptView: View {
    let feature: ProFeature?
    @Environment(\.dismiss) var dismiss
    @StateObject private var licenseValidator = GitMacLicenseValidator.shared
    @State private var licenseKey = ""
    @State private var isValidating = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [AppTheme.info.opacity(0.2), AppTheme.accentCyan.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)

                    Image(systemName: feature?.icon ?? "star.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.info, AppTheme.accentCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Unlock Pro Features")
                    .font(.title.bold())

                if let feature = feature {
                    Text(feature.description)
                        .font(.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }

            Divider()

            // Features List
            VStack(alignment: .leading, spacing: 12) {
                Text("GitMac Pro includes:")
                    .font(.headline)

                ForEach([
                    ("AI-powered features (commit, conflict resolution, suggestions)", "sparkles"),
                    ("Local LLM support (Ollama, LM Studio)", "cpu"),
                    ("Multiple AI providers (OpenAI, Claude, Gemini, Mistral, Cohere)", "brain"),
                    ("All integrations (Jira, Linear, Notion, etc.)", "link"),
                    ("Custom themes", "paintbrush"),
                    ("Advanced diff features", "doc.text.magnifyingglass"),
                    ("Priority support", "person.fill.checkmark")
                ], id: \.0) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.1)
                            .foregroundColor(AppTheme.info)
                            .frame(width: 20)

                        Text(item.0)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(AppTheme.textSecondary.opacity(0.1))
            .cornerRadius(12)

            // Pricing
            VStack(spacing: 8) {
                Text("$12/year")
                    .font(.system(size: 36, weight: .bold))

                Text("That's just $1/month")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [AppTheme.info.opacity(0.1), AppTheme.accentCyan.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)

            Divider()

            // License Activation
            VStack(spacing: 16) {
                Text("Already have a license?")
                    .font(.headline)

                DSTextField(placeholder: "Enter license key", text: $licenseKey)
                    .font(.system(.body, design: .monospaced))

                if let error = licenseValidator.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.error)
                }

                Button {
                    Task {
                        isValidating = true
                        let isValid = await licenseValidator.validateLicense(licenseKey)
                        isValidating = false
                        if isValid {
                            dismiss()
                        }
                    }
                } label: {
                    if isValidating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Activate License")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.isEmpty || isValidating)
            }

            // Purchase Button
            Link(destination: URL(string: "https://gitmac.app/buy")!) {
                Text("Purchase GitMac Pro")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [AppTheme.info, AppTheme.accentCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(AppTheme.buttonTextOnColor)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button("Not now") {
                dismiss()
            }
            .foregroundColor(AppTheme.textPrimary)
        }
        .padding(32)
        .frame(width: 500)
    }
}

// MARK: - Feature Gate Button

struct FeatureGateButton<Label: View>: View {
    let feature: ProFeature
    let action: () -> Void
    @ViewBuilder let label: Label

    @StateObject private var featureManager = FeatureManager.shared
    @State private var showUpgradePrompt = false

    var body: some View {
        Button {
            if featureManager.isFeatureAvailable(feature) {
                action()
            } else {
                showUpgradePrompt = true
            }
        } label: {
            HStack {
                label

                if !featureManager.isFeatureAvailable(feature) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(AppTheme.warning)
                }
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptView(feature: feature)
        }
    }
}

// MARK: - Usage Examples

/*
// Example 1: Block entire view
struct AICommitView: View {
    var body: some View {
        VStack {
            Text("AI Commit Features")
        }
        .requiresProFeature(.aiCommitMessages)
    }
}

// Example 2: Gate a button
FeatureGateButton(feature: .aiCommitMessages) {
    // Generate AI commit message
    generateAICommit()
} label: {
    Label("Generate with AI", systemImage: "sparkles")
}

// Example 3: Conditional content
struct SomeView: View {
    @StateObject private var featureManager = FeatureManager.shared

    var body: some View {
        VStack {
            if featureManager.isFeatureAvailable(.customThemes) {
                ThemePickerView()
            } else {
                Button("Unlock Custom Themes") {
                    // Show upgrade prompt
                }
            }
        }
    }
}

// Example 4: Show upgrade prompt directly
Button("Upgrade to Pro") {
    showUpgradePrompt = true
}
.sheet(isPresented: $showUpgradePrompt) {
    UpgradePromptView(feature: nil)
}
*/
