//
//  WorkspaceManagerTab.swift
//  GitMac
//
//  Centralized workspace management for multiple repositories
//

import SwiftUI

struct WorkspaceManagerTab: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @StateObject private var workspaceSettings = WorkspaceSettingsManager.shared
    @State private var selectedView: WorkspaceManagerView = .overview
    @State private var showingImportSheet = false
    @State private var showingExportSheet = false
    @State private var showingTemplateEditor = false
    @State private var showingGroupEditor = false
    @State private var selectedTemplate: WorkspaceTemplate?
    @State private var selectedGroup: WorkspaceGroup?
    @State private var exportMessage: String?

    enum WorkspaceManagerView: String, CaseIterable {
        case overview = "Overview"
        case templates = "Templates"
        case groups = "Groups"
        case repositories = "Repositories"
        case bulk = "Bulk Operations"

        var icon: String {
            switch self {
            case .overview: return "chart.bar.doc.horizontal"
            case .templates: return "doc.text.image"
            case .groups: return "folder.badge.gearshape"
            case .repositories: return "externaldrive.fill.badge.checkmark"
            case .bulk: return "square.stack.3d.up"
            }
        }
    }

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("Workspace Manager")
                    .font(DesignTokens.Typography.headline)
                    .padding()

                Divider()

                List(WorkspaceManagerView.allCases, id: \.self, selection: $selectedView) { view in
                    Label(view.rawValue, systemImage: view.icon)
                        .tag(view)
                }
                .listStyle(.sidebar)
            }
            .frame(width: 200)

            // Content
            VStack(spacing: 0) {
                contentView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingTemplateEditor) {
            TemplateEditorSheet(
                template: selectedTemplate,
                onSave: { template in
                    if selectedTemplate != nil {
                        workspaceManager.updateTemplate(template)
                    } else {
                        workspaceManager.addTemplate(template)
                    }
                    showingTemplateEditor = false
                }
            )
        }
        .sheet(isPresented: $showingGroupEditor) {
            GroupEditorSheet(
                group: selectedGroup,
                onSave: { group in
                    if selectedGroup != nil {
                        workspaceManager.updateGroup(group)
                    } else {
                        workspaceManager.addGroup(group)
                    }
                    showingGroupEditor = false
                }
            )
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedView {
        case .overview:
            OverviewView()
        case .templates:
            TemplatesView(
                showingEditor: $showingTemplateEditor,
                selectedTemplate: $selectedTemplate
            )
        case .groups:
            GroupsView(
                showingEditor: $showingGroupEditor,
                selectedGroup: $selectedGroup
            )
        case .repositories:
            RepositoriesView()
        case .bulk:
            BulkOperationsView()
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                try workspaceManager.importConfiguration(from: data, merge: true)
                exportMessage = "Configuration imported successfully!"
            } catch {
                exportMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            exportMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Overview View

private struct OverviewView: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @StateObject private var workspaceSettings = WorkspaceSettingsManager.shared
    @StateObject private var licenseManager = LicenseManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Header with License Badge
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack {
                            Text("Workspace Overview")
                                .font(DesignTokens.Typography.title2)

                            // Pro Badge
                            if licenseManager.isPro {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                    Text("PRO")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                        Text("Manage configurations for all your repositories")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding()

                // Statistics Cards
                HStack(spacing: DesignTokens.Spacing.md) {
                    StatCard(
                        title: "Repositories",
                        value: "\(workspaceManager.totalRepositories)",
                        icon: "folder.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Groups",
                        value: "\(workspaceManager.totalGroups)",
                        icon: "folder.badge.gearshape",
                        color: .purple
                    )

                    StatCard(
                        title: "Templates",
                        value: "\(workspaceManager.totalTemplates)",
                        icon: "doc.text.image",
                        color: .green
                    )

                    StatCard(
                        title: "Integrations",
                        value: "\(workspaceManager.repositoriesWithIntegrations().count)",
                        icon: "link",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Quick Actions
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Quick Actions")
                        .font(DesignTokens.Typography.headline)
                        .padding(.horizontal)

                    HStack(spacing: DesignTokens.Spacing.md) {
                        QuickActionButton(
                            title: "Create Template",
                            icon: "plus.circle.fill",
                            color: .blue
                        ) {
                            // Create template action
                        }

                        QuickActionButton(
                            title: "Create Group",
                            icon: "folder.badge.plus",
                            color: .purple
                        ) {
                            // Create group action
                        }

                        QuickActionButton(
                            title: "Import Config",
                            icon: "square.and.arrow.down",
                            color: .green
                        ) {
                            // Import action
                        }

                        QuickActionButton(
                            title: "Export Config",
                            icon: "square.and.arrow.up",
                            color: .orange
                        ) {
                            // Export action
                        }
                    }
                    .padding(.horizontal)
                }

                // Recent Activity
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Recent Templates")
                        .font(DesignTokens.Typography.headline)
                        .padding(.horizontal)

                    if workspaceManager.templates.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.image",
                            title: "No Templates Yet",
                            message: "Create templates to quickly configure repositories"
                        )
                    } else {
                        ForEach(workspaceManager.templates.prefix(5)) { template in
                            TemplateRow(template: template)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
    }
}

// MARK: - Templates View

private struct TemplatesView: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @Binding var showingEditor: Bool
    @Binding var selectedTemplate: WorkspaceTemplate?
    @State private var searchText = ""

    var filteredTemplates: [WorkspaceTemplate] {
        if searchText.isEmpty {
            return workspaceManager.templates
        }
        return workspaceManager.templates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                Spacer()

                Button {
                    selectedTemplate = nil
                    showingEditor = true
                } label: {
                    Label("New Template", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Templates Grid
            if filteredTemplates.isEmpty {
                EmptyStateView(
                    icon: "doc.text.image",
                    title: searchText.isEmpty ? "No Templates" : "No Results",
                    message: searchText.isEmpty ? "Create your first template" : "Try a different search"
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 280, maximum: 350), spacing: DesignTokens.Spacing.md)
                        ],
                        spacing: DesignTokens.Spacing.md
                    ) {
                        ForEach(filteredTemplates) { template in
                            TemplateCard(
                                template: template,
                                onEdit: {
                                    selectedTemplate = template
                                    showingEditor = true
                                },
                                onDelete: {
                                    workspaceManager.deleteTemplate(template)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Groups View

private struct GroupsView: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @Binding var showingEditor: Bool
    @Binding var selectedGroup: WorkspaceGroup?
    @State private var searchText = ""
    @State private var isDiscovering = false

    var filteredGroups: [WorkspaceGroup] {
        if searchText.isEmpty {
            return workspaceManager.groups
        }
        return workspaceManager.groups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search groups...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                Spacer()

                Button {
                    Task {
                        isDiscovering = true
                        let discovered = await workspaceManager.discoverGroups()
                        workspaceManager.applyDiscoveredGroups(discovered)
                        isDiscovering = false
                    }
                } label: {
                    if isDiscovering {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Label("Auto-Discover", systemImage: "sparkles")
                    }
                }
                .disabled(isDiscovering)
                .help("Automatically detect groups from GitHub organizations")

                Button {
                    selectedGroup = nil
                    showingEditor = true
                } label: {
                    Label("New Group", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Groups List
            if filteredGroups.isEmpty {
                EmptyStateView(
                    icon: "folder.badge.gearshape",
                    title: searchText.isEmpty ? "No Groups" : "No Results",
                    message: searchText.isEmpty ? "Create your first group" : "Try a different search"
                )
            } else {
                List(filteredGroups) { group in
                    GroupRow(
                        group: group,
                        onEdit: {
                            selectedGroup = group
                            showingEditor = true
                        },
                        onDelete: {
                            workspaceManager.deleteGroup(group)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Repositories View

private struct RepositoryItem: Identifiable {
    let id: String
    let path: String
    let config: WorkspaceConfig

    init(path: String, config: WorkspaceConfig) {
        self.id = path
        self.path = path
        self.config = config
    }
}

private struct RepositoriesView: View {
    @StateObject private var workspaceSettings = WorkspaceSettingsManager.shared
    @State private var searchText = ""
    @State private var selectedRepos: Set<String> = []

    var filteredRepositories: [RepositoryItem] {
        let repos = workspaceSettings.workspaces.sorted { $0.key < $1.key }.map { RepositoryItem(path: $0.key, config: $0.value) }
        if searchText.isEmpty {
            return repos
        }
        return repos.filter {
            $0.path.localizedCaseInsensitiveContains(searchText) ||
            ($0.config.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search repositories...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                Spacer()

                if !selectedRepos.isEmpty {
                    Text("\(selectedRepos.count) selected")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding()

            Divider()

            // Repositories Table
            if filteredRepositories.isEmpty {
                EmptyStateView(
                    icon: "externaldrive.fill.badge.checkmark",
                    title: "No Repositories",
                    message: "Open repositories to see them here"
                )
            } else {
                Table(filteredRepositories) {
                    TableColumn("Repository") { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.config.displayName ?? item.path)
                                .font(DesignTokens.Typography.body)
                            Text(item.path)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    TableColumn("Main Branch") { item in
                        Text(item.config.mainBranchName ?? "main")
                            .font(DesignTokens.Typography.callout.monospaced())
                    }

                    TableColumn("Integrations") { item in
                        IntegrationsTagsView(config: item.config)
                    }
                }
            }
        }
    }
}

// MARK: - Bulk Operations View

private struct BulkOperationsView: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @StateObject private var workspaceSettings = WorkspaceSettingsManager.shared
    @State private var selectedTemplate: WorkspaceTemplate?
    @State private var selectedRepos: Set<String> = []
    @State private var showingConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("Bulk Operations")
                    .font(DesignTokens.Typography.title2)
                    .padding()

                // Apply Template to Multiple Repos
                GroupBox("Apply Template to Repositories") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Select a template and repositories to apply it to")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        Picker("Template", selection: $selectedTemplate) {
                            Text("Select a template...").tag(nil as WorkspaceTemplate?)
                            ForEach(workspaceManager.templates) { template in
                                Text(template.name).tag(template as WorkspaceTemplate?)
                            }
                        }

                        MultipleRepositorySelector(selectedRepos: $selectedRepos)

                        Button("Apply Template") {
                            showingConfirmation = true
                        }
                        .disabled(selectedTemplate == nil || selectedRepos.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
        }
        .alert("Apply Template?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Apply", role: .destructive) {
                if let template = selectedTemplate {
                    workspaceManager.applyConfigToMultipleRepos(
                        template.config,
                        repositories: Array(selectedRepos)
                    )
                    selectedRepos.removeAll()
                }
            }
        } message: {
            Text("This will apply '\(selectedTemplate?.name ?? "")' template to \(selectedRepos.count) repositories. This will overwrite their current configurations.")
        }
    }
}

// MARK: - Helper Components

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
}

private struct TemplateRow: View {
    let template: WorkspaceTemplate

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: template.icon)
                .foregroundColor(Color(template.color))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(DesignTokens.Typography.body)
                Text(template.description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            ForEach(template.tags.prefix(3), id: \.self) { tag in
                Text(tag)
                    .font(DesignTokens.Typography.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent.opacity(0.1))
                    .foregroundColor(AppTheme.accent)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .padding(.horizontal)
    }
}

private struct TemplateCard: View {
    let template: WorkspaceTemplate
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: template.icon)
                    .foregroundColor(Color(template.color))
                    .font(.title2)

                Spacer()

                Menu {
                    Button("Edit") { onEdit() }
                    Button("Duplicate") { /* Duplicate */ }
                    Divider()
                    Button("Delete", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.textSecondary)
                }
                .menuStyle(.borderlessButton)
            }

            Text(template.name)
                .font(DesignTokens.Typography.headline)

            Text(template.description)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(2)

            FlowLayout(spacing: 4) {
                ForEach(template.tags, id: \.self) { tag in
                    Text(tag)
                        .font(DesignTokens.Typography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.1))
                        .foregroundColor(AppTheme.accent)
                        .cornerRadius(4)
                }
            }

            Divider()

            HStack {
                Text("Modified: \(template.modifiedAt, formatter: dateFormatter)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.lg)
    }
}

private struct GroupRow: View {
    let group: WorkspaceGroup
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: group.icon)
                .foregroundColor(Color(group.color))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(DesignTokens.Typography.body)
                Text(group.description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(group.repositoryCount) repositories")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            Button("Edit") { onEdit() }
                .buttonStyle(.borderless)

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

private struct IntegrationsTagsView: View {
    let config: WorkspaceConfig

    var integrations: [String] {
        var result: [String] = []
        if config.taigaProjectId != nil { result.append("Taiga") }
        if config.jiraProjectKey != nil { result.append("Jira") }
        if config.linearTeamId != nil { result.append("Linear") }
        if config.notionDatabaseId != nil { result.append("Notion") }
        if config.codeBuildProjectName != nil { result.append("AWS") }
        return result
    }

    var body: some View {
        HStack(spacing: 4) {
            if integrations.isEmpty {
                Text("None")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            } else {
                ForEach(integrations, id: \.self) { integration in
                    Text(integration)
                        .font(DesignTokens.Typography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.1))
                        .foregroundColor(AppTheme.accent)
                        .cornerRadius(4)
                }
            }
        }
    }
}

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)

            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.textSecondary)

            Text(message)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct MultipleRepositorySelector: View {
    @StateObject private var workspaceSettings = WorkspaceSettingsManager.shared
    @Binding var selectedRepos: Set<String>

    var body: some View {
        List(selection: $selectedRepos) {
            ForEach(Array(workspaceSettings.workspaces.keys.sorted()), id: \.self) { path in
                HStack {
                    Text(workspaceSettings.workspaces[path]?.displayName ?? "Unknown")
                    Spacer()
                    Text(path)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .tag(path)
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Sheets

private struct TemplateEditorSheet: View {
    let template: WorkspaceTemplate?
    let onSave: (WorkspaceTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var color: String
    @State private var tags: String

    init(template: WorkspaceTemplate?, onSave: @escaping (WorkspaceTemplate) -> Void) {
        self.template = template
        self.onSave = onSave
        _name = State(initialValue: template?.name ?? "")
        _description = State(initialValue: template?.description ?? "")
        _icon = State(initialValue: template?.icon ?? "folder.fill")
        _color = State(initialValue: template?.color ?? "blue")
        _tags = State(initialValue: template?.tags.joined(separator: ", ") ?? "")
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text(template == nil ? "New Template" : "Edit Template")
                .font(DesignTokens.Typography.title2)
                .padding()

            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                TextField("Icon (SF Symbol)", text: $icon)
                TextField("Color", text: $color)
                TextField("Tags (comma-separated)", text: $tags)
            }
            .padding()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    let config = template?.config ?? WorkspaceConfig()
                    let newTemplate = WorkspaceTemplate(
                        id: template?.id ?? UUID(),
                        name: name,
                        description: description,
                        config: config,
                        icon: icon,
                        color: color,
                        tags: tagArray
                    )
                    onSave(newTemplate)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

private struct GroupEditorSheet: View {
    let group: WorkspaceGroup?
    let onSave: (WorkspaceGroup) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var color: String

    init(group: WorkspaceGroup?, onSave: @escaping (WorkspaceGroup) -> Void) {
        self.group = group
        self.onSave = onSave
        _name = State(initialValue: group?.name ?? "")
        _description = State(initialValue: group?.description ?? "")
        _icon = State(initialValue: group?.icon ?? "folder.badge.gearshape")
        _color = State(initialValue: group?.color ?? "purple")
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text(group == nil ? "New Group" : "Edit Group")
                .font(DesignTokens.Typography.title2)
                .padding()

            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                TextField("Icon (SF Symbol)", text: $icon)
                TextField("Color", text: $color)
            }
            .padding()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    let newGroup = WorkspaceGroup(
                        id: group?.id ?? UUID(),
                        name: name,
                        description: description,
                        repositoryPaths: group?.repositoryPaths ?? [],
                        sharedConfig: group?.sharedConfig,
                        icon: icon,
                        color: color
                    )
                    onSave(newGroup)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 350)
    }
}

// MARK: - Formatters

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

// MARK: - Previews

#Preview("Workspace Manager") {
    WorkspaceManagerTab()
        .frame(width: 900, height: 600)
}
