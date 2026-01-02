//
//  TerminalWorkflowsView.swift
//  GitMac
//
//  Warp-style workflows - parameterized command templates
//

import SwiftUI

// MARK: - Workflow Execution View

struct TerminalWorkflowsView: View {
    @ObservedObject var viewModel: GhosttyEnhancedViewModel
    @State private var showCreateWorkflow = false
    @State private var selectedWorkflow: TerminalWorkflow?
    @State private var searchText = ""

    var filteredWorkflows: [TerminalWorkflow] {
        if searchText.isEmpty {
            return viewModel.workflows
        }
        return viewModel.workflows.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Workflows")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button(action: { showCreateWorkflow = true }) {
                    Label("New Workflow", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.accent)
            }
            .padding(16)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textMuted)
                TextField("Search workflows...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            // Workflows List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredWorkflows) { workflow in
                        WorkflowCard(workflow: workflow) {
                            selectedWorkflow = workflow
                        }
                    }

                    if filteredWorkflows.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.textMuted)

                            Text(searchText.isEmpty ? "No workflows yet" : "No workflows found")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)

                            if searchText.isEmpty {
                                Button("Create Your First Workflow") {
                                    showCreateWorkflow = true
                                }
                                .foregroundColor(AppTheme.accent)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showCreateWorkflow) {
            CreateWorkflowSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedWorkflow) { workflow in
            ExecuteWorkflowSheet(workflow: workflow, viewModel: viewModel)
        }
    }
}

// MARK: - Workflow Card

struct WorkflowCard: View {
    let workflow: TerminalWorkflow
    let onExecute: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 18))
                        .foregroundColor(categoryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(workflow.description)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isHovered {
                    Button(action: onExecute) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Tags
            if !workflow.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(workflow.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.backgroundTertiary)
                            .cornerRadius(4)
                    }
                }
            }

            // Command preview
            Text(workflow.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textMuted)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(6)
        }
        .padding(16)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? AppTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onExecute()
        }
    }

    private var categoryColor: Color {
        switch workflow.category.lowercased() {
        case "git": return AppTheme.accent
        case "deploy": return AppTheme.error
        case "test": return AppTheme.success
        case "build": return AppTheme.warning
        default: return AppTheme.info
        }
    }

    private var categoryIcon: String {
        switch workflow.category.lowercased() {
        case "git": return "arrow.triangle.branch"
        case "deploy": return "arrow.up.doc"
        case "test": return "checkmark.circle"
        case "build": return "hammer"
        default: return "terminal"
        }
    }
}

// MARK: - Create Workflow Sheet

struct CreateWorkflowSheet: View {
    @ObservedObject var viewModel: GhosttyEnhancedViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var command = ""
    @State private var category = "General"
    @State private var tags: [String] = []
    @State private var newTag = ""

    let categories = ["General", "Git", "Deploy", "Test", "Build", "Database"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Workflow")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppTheme.textSecondary)

                Button("Create") {
                    createWorkflow()
                }
                .disabled(name.isEmpty || command.isEmpty)
                .foregroundColor(name.isEmpty || command.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                .fontWeight(.semibold)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)

                        TextField("Deploy to Staging", text: $name)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(AppTheme.backgroundSecondary)
                            .cornerRadius(8)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)

                        TextField("Deploy the current branch to staging environment", text: $description)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(AppTheme.backgroundSecondary)
                            .cornerRadius(8)
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)

                        Picker("", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .labelsHidden()
                    }

                    // Command
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Command Template")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)

                        Text("Use {{param}} for parameters")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)

                        TextEditor(text: $command)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 120)
                            .padding(8)
                            .background(AppTheme.backgroundSecondary)
                            .cornerRadius(8)
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)

                        HStack {
                            TextField("Add tag...", text: $newTag)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(AppTheme.backgroundSecondary)
                                .cornerRadius(6)
                                .onSubmit {
                                    if !newTag.isEmpty {
                                        tags.append(newTag)
                                        newTag = ""
                                    }
                                }

                            Button("Add") {
                                if !newTag.isEmpty {
                                    tags.append(newTag)
                                    newTag = ""
                                }
                            }
                            .disabled(newTag.isEmpty)
                        }

                        if !tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.system(size: 11))
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.backgroundTertiary)
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 600)
        .background(AppTheme.background)
    }

    private func createWorkflow() {
        let workflow = TerminalWorkflow(
            name: name,
            description: description,
            command: command,
            parameters: [],  // TODO: Parse parameters from command
            category: category,
            tags: tags
        )
        viewModel.addWorkflow(workflow)
        dismiss()
    }
}

// MARK: - Execute Workflow Sheet

struct ExecuteWorkflowSheet: View {
    let workflow: TerminalWorkflow
    @ObservedObject var viewModel: GhosttyEnhancedViewModel
    @Environment(\.dismiss) var dismiss

    @State private var paramValues: [String: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.name)
                        .font(.system(size: 18, weight: .semibold))
                    Text(workflow.description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppTheme.textSecondary)

                Button("Execute") {
                    executeWorkflow()
                }
                .foregroundColor(AppTheme.accent)
                .fontWeight(.semibold)
            }
            .padding()

            Divider()

            // Parameters
            if !workflow.parameters.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(workflow.parameters, id: \.name) { param in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(param.name)
                                        .font(.system(size: 13, weight: .medium))
                                    if param.required {
                                        Text("*")
                                            .foregroundColor(AppTheme.error)
                                    }
                                }
                                .foregroundColor(AppTheme.textSecondary)

                                Text(param.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)

                                TextField(param.placeholder, text: bindingFor(param.name))
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(AppTheme.backgroundSecondary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                Text("No parameters required")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxHeight: .infinity)
            }

            Divider()

            // Command Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Command Preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                Text(resolvedCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.backgroundTertiary)
                    .cornerRadius(8)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .background(AppTheme.background)
    }

    private func bindingFor(_ paramName: String) -> Binding<String> {
        Binding(
            get: { paramValues[paramName] ?? "" },
            set: { paramValues[paramName] = $0 }
        )
    }

    private var resolvedCommand: String {
        var cmd = workflow.command
        for (key, value) in paramValues {
            cmd = cmd.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return cmd
    }

    private func executeWorkflow() {
        // TODO: Execute the resolved command in the terminal
        viewModel.trackCommand(resolvedCommand)
        dismiss()
    }
}

// MARK: - ViewModel Extension

extension GhosttyEnhancedViewModel {
    func addWorkflow(_ workflow: TerminalWorkflow) {
        workflows.append(workflow)
        saveWorkflows()
    }

    func removeWorkflow(_ id: UUID) {
        workflows.removeAll { $0.id == id }
        saveWorkflows()
    }

    private func saveWorkflows() {
        // TODO: Persist workflows to UserDefaults or file
    }
}
