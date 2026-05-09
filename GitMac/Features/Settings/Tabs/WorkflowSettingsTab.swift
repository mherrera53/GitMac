import SwiftUI

struct WorkflowSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    private var engine: WorkflowEngine { WorkflowEngine.shared }
    @State private var selectedWorkflow: GitWorkflow?
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text("Workflows")
                    .font(DesignTokens.Typography.title2)
                    .fontWeight(.semibold)
                Spacer()
                DSButton("Reset Defaults", variant: .ghost, size: .sm) {
                    engine.resetToDefaults()
                }
                DSButton("Add Workflow", variant: .primary, size: .sm) {
                    showAddSheet = true
                }
            }

            Text("Configure automated workflows for your git operations. Workflows are triggered based on conditions like current branch.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(engine.workflows) { workflow in
                GitWorkflowRow(
                    workflow: workflow,
                    onToggle: { enabled in
                        var updated = workflow
                        updated.isEnabled = enabled
                        engine.updateWorkflow(updated)
                    },
                    onEdit: {
                        selectedWorkflow = workflow
                    },
                    onDelete: {
                        engine.deleteWorkflow(workflow)
                    }
                )
            }
        }
        .padding()
        .background(AppTheme.background)
        .sheet(item: $selectedWorkflow) { workflow in
            WorkflowEditorSheet(workflow: workflow) { updated in
                engine.updateWorkflow(updated)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            WorkflowEditorSheet(
                workflow: GitWorkflow(
                    name: "New Workflow",
                    icon: "bolt.circle",
                    color: "#9C27B0",
                    triggerCondition: .always,
                    steps: []
                )
            ) { newWorkflow in
                engine.addWorkflow(newWorkflow)
            }
        }
    }
}

// MARK: - Workflow Row

struct GitWorkflowRow: View {
    let workflow: GitWorkflow
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isEnabled: Bool

    init(workflow: GitWorkflow, onToggle: @escaping (Bool) -> Void, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.workflow = workflow
        self.onToggle = onToggle
        self.onEdit = onEdit
        self.onDelete = onDelete
        self._isEnabled = State(initialValue: workflow.isEnabled)
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: workflow.icon)
                .font(.title3)
                .foregroundStyle(Color(hex: workflow.color) ?? AppTheme.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.name)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(triggerDescription)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Text("\(workflow.steps.count) step(s): \(stepsPreview)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    onToggle(newValue)
                }

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle")
            }
            .buttonStyle(.borderless)
            .help("Edit workflow")

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(AppTheme.error)
            }
            .buttonStyle(.borderless)
            .help("Delete workflow")
        }
        .padding()
        .background(AppTheme.backgroundSecondary.opacity(0.3))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var triggerDescription: String {
        switch workflow.triggerCondition {
        case .always: return "Always available"
        case .onBranch(let p): return "When on: \(p)"
        case .notOnBranch(let p): return "When NOT on: \(p)"
        case .hasStaged: return "When files are staged"
        case .manual: return "Manual only"
        }
    }

    private var stepsPreview: String {
        workflow.steps.map { $0.displayName }.joined(separator: " -> ")
    }
}

// MARK: - Workflow Editor Sheet

struct WorkflowEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var workflow: GitWorkflow
    let onSave: (GitWorkflow) -> Void

    @State private var showAddStep = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Edit Workflow")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            HStack(spacing: DesignTokens.Spacing.md) {
                DSTextField(placeholder: "Name", text: $workflow.name)
                DSTextField(placeholder: "SF Symbol", text: $workflow.icon)
                    .frame(width: 120)
                DSTextField(placeholder: "#color", text: $workflow.color)
                    .frame(width: 100)
            }

            HStack {
                Text("Trigger")
                    .font(DesignTokens.Typography.headline)
                Spacer()
            }

            TriggerPicker(trigger: $workflow.triggerCondition)

            HStack {
                Text("Steps")
                    .font(DesignTokens.Typography.headline)
                Spacer()
                Button {
                    showAddStep = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Step")
                    }
                    .font(DesignTokens.Typography.caption)
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(Array(workflow.steps.enumerated()), id: \.offset) { index, step in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.textMuted)
                                .frame(width: 20)

                            Image(systemName: step.icon)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 20)

                            Text(step.displayName)
                                .font(DesignTokens.Typography.callout)

                            Spacer()

                            Button {
                                workflow.steps.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(AppTheme.backgroundSecondary.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 4))
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onSave(workflow)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(workflow.name.isEmpty || workflow.steps.isEmpty)
            }
        }
        .padding()
        .frame(width: 520, height: 500)
        .sheet(isPresented: $showAddStep) {
            StepPickerSheet { step in
                workflow.steps.append(step)
            }
        }
    }
}

// MARK: - Trigger Picker

struct TriggerPicker: View {
    @Binding var trigger: WorkflowTrigger

    @State private var triggerType = 0
    @State private var pattern = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Picker("", selection: $triggerType) {
                Text("Always").tag(0)
                Text("On Branch").tag(1)
                Text("Not On Branch").tag(2)
                Text("Has Staged").tag(3)
                Text("Manual").tag(4)
            }
            .pickerStyle(.segmented)
            .onChange(of: triggerType) { _, newValue in
                updateTrigger(newValue)
            }

            if triggerType == 1 || triggerType == 2 {
                DSTextField(placeholder: "Branch pattern (e.g. main|master)", text: $pattern)
                    .onChange(of: pattern) { _, _ in
                        updateTrigger(triggerType)
                    }
            }
        }
        .onAppear {
            switch trigger {
            case .always: triggerType = 0
            case .onBranch(let p): triggerType = 1; pattern = p
            case .notOnBranch(let p): triggerType = 2; pattern = p
            case .hasStaged: triggerType = 3
            case .manual: triggerType = 4
            }
        }
    }

    private func updateTrigger(_ type: Int) {
        switch type {
        case 0: trigger = .always
        case 1: trigger = .onBranch(pattern: pattern)
        case 2: trigger = .notOnBranch(pattern: pattern)
        case 3: trigger = .hasStaged
        case 4: trigger = .manual
        default: break
        }
    }
}

// MARK: - Step Picker

struct StepPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (WorkflowStep) -> Void

    private let availableSteps: [(String, WorkflowStep)] = [
        ("Fetch origin", .fetch(remote: "origin")),
        ("Pull", .pull(rebase: false)),
        ("Pull (rebase)", .pull(rebase: true)),
        ("Checkout Main", .checkoutMain),
        ("Create Branch (AI)", .createBranch(nameStrategy: .aiGenerated)),
        ("Create Branch (from message)", .createBranch(nameStrategy: .fromCommitMessage)),
        ("Create Branch (user input)", .createBranch(nameStrategy: .userInput)),
        ("Rebase on Main", .rebaseOnMain),
        ("Stash", .stash),
        ("Stash Pop", .stashPop),
        ("Stage All", .stageAll),
        ("Commit (user message)", .commit(messageStrategy: .userProvided)),
        ("Commit (AI message)", .commit(messageStrategy: .aiGenerated)),
        ("Commit (WIP template)", .commit(messageStrategy: .template("wip: {{message}}"))),
        ("Push", .push(setUpstream: false, force: false)),
        ("Push (set upstream)", .push(setUpstream: true, force: false)),
        ("Push (force-with-lease)", .push(setUpstream: false, force: true)),
        ("Create Tag", .createTag(nameStrategy: .userInput)),
        ("Open PR", .openPR(draft: false, autoFill: true)),
        ("Open Draft PR", .openPR(draft: true, autoFill: true)),
        ("Notify", .notify(message: "Done!")),
    ]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("Add Step")
                .font(DesignTokens.Typography.title3)
                .fontWeight(.semibold)

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(availableSteps, id: \.0) { name, step in
                        Button {
                            onAdd(step)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: step.icon)
                                    .frame(width: 24)
                                Text(name)
                                Spacer()
                            }
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(AppTheme.backgroundSecondary.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 350, height: 400)
    }
}
