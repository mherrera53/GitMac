import SwiftUI

// MARK: - Planner Tasks Panel (Bottom Panel)

struct PlannerTasksPanel: View {
    @Binding var height: CGFloat
    let onClose: () -> Void
    @StateObject private var viewModel = PlannerTasksViewModel()
    @State private var selectedTab: PlannerTab = .board

    var body: some View {
        VStack(spacing: 0) {
            // Resizer handle
            PlannerPanelResizer(height: $height)

            // Header
            HStack(spacing: 12) {
                // Planner logo
                Image(systemName: "checklist")
                    .foregroundColor(Color(hex: "0078D4"))

                Text("Planner")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)

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

                // Refresh
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(GitKrakenTheme.textMuted)

                // Settings
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(GitKrakenTheme.textMuted)

                // Close
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(GitKrakenTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(GitKrakenTheme.toolbar)

            Rectangle().fill(GitKrakenTheme.border).frame(height: 1)

            // Content
            if !viewModel.isAuthenticated {
                PlannerLoginPrompt(viewModel: viewModel)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let selectedPlan = viewModel.selectedPlanId {
                    PlannerBoardView(buckets: viewModel.buckets, tasks: viewModel.tasks)
                } else {
                    PlannerEmptyView(type: "Select a plan to view tasks")
                }
            }
        }
        .frame(height: height)
        .background(GitKrakenTheme.panel)
        .sheet(isPresented: $viewModel.showSettings) {
            PlannerSettingsSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedPlanId) { _, newId in
            if let id = newId {
                Task { await viewModel.loadPlanData(planId: id) }
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
class PlannerTasksViewModel: ObservableObject {
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

    init() {
        Task {
            if let token = try? await KeychainManager.shared.getPlannerToken() {
                await service.setAccessToken(token)
                await MainActor.run {
                    isAuthenticated = true
                }
                await loadPlans()

                // Restore selected plan
                if let savedPlanId = UserDefaults.standard.string(forKey: "planner_selected_plan_id") {
                    await MainActor.run {
                        selectedPlanId = savedPlanId
                    }
                    await loadPlanData(planId: savedPlanId)
                }
            }
        }
    }

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

    func refresh() async {
        if let planId = selectedPlanId {
            await loadPlanData(planId: planId)
        }
    }
    
    func logout() {
        Task {
            try? await KeychainManager.shared.deletePlannerToken()
            try? await KeychainManager.shared.deleteMicrosoftTokens()
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
            Task {
                await viewModel.loadPlans()
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
            HStack(alignment: .top, spacing: 12) {
                ForEach(buckets) { bucket in
                    PlannerKanbanColumn(
                        bucket: bucket,
                        tasks: tasks.filter { $0.bucketId == bucket.id }
                    )
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Kanban Column

struct PlannerKanbanColumn: View {
    let bucket: PlannerBucket
    let tasks: [PlannerTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column header
            HStack(spacing: 8) {
                Text(bucket.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)

                Text("\(tasks.count)")
                    .font(.system(size: 10))
                    .foregroundColor(GitKrakenTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(GitKrakenTheme.backgroundTertiary)
                    .cornerRadius(4)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(GitKrakenTheme.backgroundSecondary)
            .cornerRadius(6)

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                // Checkbox status
                Image(systemName: task.percentComplete == 100 ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.percentComplete == 100 ? .green : .secondary)
                    .font(.system(size: 12))
                
                Text(task.title)
                    .font(.system(size: 12))
                    .foregroundColor(GitKrakenTheme.textPrimary)
                    .lineLimit(3)
                    .strikethrough(task.percentComplete == 100)
                
                Spacer()
            }

            // Footer
            HStack {
                // Priority
                if let priority = task.priority, priority <= 3 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 10))
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
                        .font(.system(size: 10))
                        .foregroundColor(GitKrakenTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Insert into commit message")
            }
        }
        .padding(10)
        .background(isHovered ? GitKrakenTheme.hover : GitKrakenTheme.backgroundSecondary)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color.blue.opacity(0.5) : GitKrakenTheme.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
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
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(GitKrakenTheme.textMuted)

            Text(type)
                .font(.system(size: 13))
                .foregroundColor(GitKrakenTheme.textSecondary)
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GitKrakenTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(GitKrakenTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(GitKrakenTheme.toolbar)

            Rectangle().fill(GitKrakenTheme.border).frame(height: 1)

            // Content
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Microsoft Planner")
                            .font(.system(size: 13))
                            .foregroundColor(GitKrakenTheme.textPrimary)
                    }

                    Button("Disconnect") {
                        viewModel.logout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                } else {
                    Text("Not connected to Planner")
                        .font(.system(size: 13))
                        .foregroundColor(GitKrakenTheme.textSecondary)
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 350, height: 200)
        .background(GitKrakenTheme.panel)
    }
}

// MARK: - Panel Resizer

struct PlannerPanelResizer: View {
    @Binding var height: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(GitKrakenTheme.border)
            .frame(height: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newHeight = height - value.translation.height
                        height = min(max(newHeight, 150), 500)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
