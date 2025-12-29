import SwiftUI

// MARK: - Planner Tasks Panel (Bottom Panel)

struct PlannerTasksPanel: View {
    @StateObject private var themeManager = ThemeManager.shared

    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = PlannerTasksViewModel()
    @State private var selectedTab: PlannerTab = .board

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            UniversalResizer(
                dimension: $height,
                minDimension: 150,
                maxDimension: 500,
                orientation: .vertical
            )

            // Use the new DSIntegrationPanel-style layout
            VStack(spacing: 0) {
                // Header
                HStack(spacing: DesignTokens.Spacing.md) {
                    DSIcon("checklist", size: .md, color: Color(hex: "0078D4"))

                    Text("Planner")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    // Plan selector
                    if !viewModel.plans.isEmpty {
                        Picker("", selection: $viewModel.selectedPlanId) {
                            Text("Select plan...").tag(nil as String?)
                            ForEach(viewModel.plans) { plan in
                                Text(plan.title).tag(plan.id as String?)
                            }
                        }
                        .frame(maxWidth: 200)
                        .labelsHidden()
                    }

                    Spacer()

                    // Refresh button
                    DSIconButton(
                        iconName: "arrow.clockwise",
                        variant: .ghost,
                        size: .sm
                    ) {
                        try? await viewModel.refresh()
                    }
                    .disabled(viewModel.isLoading)

                    // Settings button
                    DSIconButton(
                        iconName: "gear",
                        variant: .ghost,
                        size: .sm
                    ) {
                        viewModel.showSettings = true
                    }

                    // Close button
                    DSCloseButton {
                        onClose()
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                DSDivider()

                // Content
                if viewModel.isLoading && !viewModel.isAuthenticated {
                    DSLoadingState(message: "Loading...")
                } else if let error = viewModel.error {
                    DSErrorState(
                        message: error,
                        onRetry: {
                            try? await viewModel.refresh()
                        }
                    )
                } else if !viewModel.isAuthenticated {
                    DSLoginPrompt(viewModel: viewModel)
                } else {
                    if viewModel.selectedPlanId != nil {
                        PlannerBoardView(buckets: viewModel.buckets, tasks: viewModel.tasks)
                    } else {
                        PlannerEmptyView(type: "Select a plan to view tasks")
                    }
                }
            }
        }
        .frame(height: height)
        .background(AppTheme.background)
        .sheet(isPresented: $viewModel.showSettings) {
            PlannerSettingsSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedPlanId) { [weak viewModel] _, newId in
            if let id = newId {
                Task { [weak viewModel] in
                    await viewModel?.loadPlanData(planId: id)
                }
            }
        }
    }
}

// MARK: - Tabs

enum PlannerTab: String, CaseIterable {
    case board = "Board"
    case list = "List"
}

// MARK: - View Model

@MainActor
class PlannerTasksViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    @Published var plans: [PlannerPlan] = []
    @Published var selectedPlanId: String? {
        didSet {
            if let id = selectedPlanId {
                UserDefaults.standard.set(id, forKey: "planner_selected_plan_id")
            }
        }
    }

    @Published var buckets: [PlannerBucket] = []
    @Published var tasks: [PlannerTask] = []

    private let service = MicrosoftPlannerService.shared
    private let oauth = MicrosoftOAuth.shared

    nonisolated init() {
        Task { [weak self] in
            guard let self = self else { return }
            if let token = try? await KeychainManager.shared.getPlannerToken() {
                await service.setAccessToken(token)
                await MainActor.run { [weak self] in
                    self?.isAuthenticated = true
                }
                await self.loadPlans()

                // Restore selected plan
                if let savedPlanId = UserDefaults.standard.string(forKey: "planner_selected_plan_id") {
                    await MainActor.run { [weak self] in
                        self?.selectedPlanId = savedPlanId
                    }
                    await self.loadPlanData(planId: savedPlanId)
                }
            }
        }
    }

    // MARK: - IntegrationViewModel Protocol

    func authenticate() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Trigger Microsoft OAuth authentication
            let token = try await oauth.authenticate()
            try await KeychainManager.shared.savePlannerToken(token)
            await service.setAccessToken(token)
            isAuthenticated = true
            await loadPlans()
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func refresh() async throws {
        if isAuthenticated {
            await loadPlans()
            if let planId = selectedPlanId {
                await loadPlanData(planId: planId)
            }
        }
    }

    // MARK: - Planner Specific Methods

    func loadPlans() async {
        do {
            plans = try await service.listPlans()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPlanData(planId: String) async {
        isLoading = true
        do {
            async let bucketsTask = service.listBuckets(planId: planId)
            async let tasksTask = service.listTasks(planId: planId)

            buckets = try await bucketsTask
            tasks = try await tasksTask
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        Task { @MainActor in
            try? await KeychainManager.shared.deletePlannerToken()
        }
        isAuthenticated = false
        plans = []
        selectedPlanId = nil
        buckets = []
        tasks = []
    }
}

// MARK: - Login Prompt

struct PlannerLoginPrompt: View {
    @ObservedObject var viewModel: PlannerTasksViewModel
    
    var body: some View {
        PlannerLoginView(isLoading: viewModel.isLoading, error: viewModel.error) {
            viewModel.isAuthenticated = true
            Task { [weak viewModel] in
                await viewModel?.loadPlans()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Board View

struct PlannerBoardView: View {
    let buckets: [PlannerBucket]
    let tasks: [PlannerTask]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                ForEach(buckets) { bucket in
                    PlannerKanbanColumn(
                        bucket: bucket,
                        tasks: tasks.filter { $0.bucketId == bucket.id }
                    )
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }
}

// MARK: - Kanban Column

struct PlannerKanbanColumn: View {
    let bucket: PlannerBucket
    let tasks: [PlannerTask]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Column header
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(bucket.name)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(tasks.count)")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                    ForEach(tasks) { task in
                        PlannerTaskCard(task: task)
                    }
                }
            }
        }
        .frame(width: 280)
    }
}

// MARK: - Task Card

struct PlannerTaskCard: View {
    let task: PlannerTask
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                // Checkbox status
                Image(systemName: task.percentComplete == 100 ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.percentComplete == 100 ? AppTheme.success : AppTheme.textSecondary)
                    .font(DesignTokens.Typography.callout)

                Text(task.title)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(3)
                    .strikethrough(task.percentComplete == 100)

                Spacer()
            }

            // Footer
            HStack {
                // Priority
                if let priority = task.priority, priority <= 3 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppTheme.error)
                        .font(DesignTokens.Typography.caption2)
                }

                Spacer()

                // Insert to commit button
                Button {
                    NotificationCenter.default.post(
                        name: .insertPlannerRef,
                        object: nil,
                        userInfo: ["title": task.title]
                    )
                } label: {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert into commit message")
            }
        }
        .cardStyle(isHovered: $isHovered, accentColor: AppTheme.accent)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let insertPlannerRef = Notification.Name("insertPlannerRef")
}

// MARK: - Empty View

struct PlannerEmptyView: View {
    let type: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "tray")
                .font(DesignTokens.Typography.largeTitle) // Was: .system(size: 32)
                .foregroundColor(AppTheme.textMuted)

            Text(type)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings Sheet

struct PlannerSettingsSheet: View {
    @ObservedObject var viewModel: PlannerTasksViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Planner Settings")
                    .font(DesignTokens.Typography.headline) // Was: .system(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.callout) // Was: .system(size: 12, weight: .medium)
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(AppTheme.backgroundSecondary)

            Rectangle().fill(AppTheme.border).frame(height: 1)

            // Content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                        Text("Connected to Microsoft Planner")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.error)
                } else {
                    Text("Not connected to Planner")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(AppTheme.backgroundSecondary)
    }
}

