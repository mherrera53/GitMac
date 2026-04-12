import SwiftUI

struct GitConfigView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var defaultBranch = "main"
    @AppStorage("autoFetch") private var autoFetch = true
    @AppStorage("autoFetchInterval") private var autoFetchInterval = 5
    @AppStorage("pruneOnFetch") private var pruneOnFetch = true
    @State private var isLoading = true
    @State private var saveStatus: String?
    @State private var showAdvancedEditor = false

    var body: some View {
        Form {
            SettingsSection(title: "User") {
                DSTextField(placeholder: "Name", text: $userName)
                    .onChange(of: userName) { _, newValue in
                        saveGitConfig(key: "user.name", value: newValue)
                    }
                DSTextField(placeholder: "Email", text: $userEmail)
                    .onChange(of: userEmail) { _, newValue in
                        saveGitConfig(key: "user.email", value: newValue)
                    }

                Text("These values are used for commits in repositories without local config")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                if let status = saveStatus {
                    Text(status)
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.success)
                }
            }

            SettingsSection(title: "Defaults") {
                DSTextField(placeholder: "Default branch name", text: $defaultBranch)
                    .onChange(of: defaultBranch) { _, newValue in
                        saveGitConfig(key: "init.defaultBranch", value: newValue)
                    }
            }

            SettingsSection(title: "Fetching") {
                DSToggle("Auto-fetch in background", isOn: $autoFetch)

                if autoFetch {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Fetch interval")
                            .font(DesignTokens.Typography.callout)
                            .foregroundStyle(AppTheme.textSecondary)

                        DSPicker(
                            items: ["1 minute", "5 minutes", "10 minutes", "15 minutes", "30 minutes"],
                            selection: Binding(
                                get: {
                                    switch autoFetchInterval {
                                    case 1: return "1 minute"
                                    case 5: return "5 minutes"
                                    case 10: return "10 minutes"
                                    case 15: return "15 minutes"
                                    case 30: return "30 minutes"
                                    default: return "5 minutes"
                                    }
                                },
                                set: { value in
                                    guard let val = value else { return }
                                    switch val {
                                    case "1 minute": autoFetchInterval = 1
                                    case "5 minutes": autoFetchInterval = 5
                                    case "10 minutes": autoFetchInterval = 10
                                    case "15 minutes": autoFetchInterval = 15
                                    case "30 minutes": autoFetchInterval = 30
                                    default: autoFetchInterval = 5
                                    }
                                }
                            )
                        )
                    }
                }

                DSToggle("Prune remote-tracking branches on fetch", isOn: $pruneOnFetch)
            }

            SettingsSection(title: "Email Aliases") {
                EmailAliasesView()
            }

            SettingsSection(title: "Advanced") {
                DSButton("Open Advanced Config Editor", variant: .secondary, size: .sm) {
                    showAdvancedEditor = true
                }
            }
        }
        .padding()
        .background(AppTheme.background)
        .task {
            await loadGitConfig()
        }
        .sheet(isPresented: $showAdvancedEditor) {
            AdvancedGitConfigEditor()
        }
    }

    private func loadGitConfig() async {
        let shell = ShellExecutor.shared
        let nameResult = await shell.execute("git", arguments: ["config", "--global", "user.name"])
        let emailResult = await shell.execute("git", arguments: ["config", "--global", "user.email"])
        let branchResult = await shell.execute("git", arguments: ["config", "--global", "init.defaultBranch"])

        if nameResult.isSuccess {
            userName = nameResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if emailResult.isSuccess {
            userEmail = emailResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if branchResult.isSuccess {
            defaultBranch = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        isLoading = false
    }

    private func saveGitConfig(key: String, value: String) {
        guard !isLoading, !value.isEmpty else { return }
        Task {
            let shell = ShellExecutor.shared
            let result = await shell.execute("git", arguments: ["config", "--global", key, value])
            if result.isSuccess {
                saveStatus = "Saved"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    saveStatus = nil
                }
            }
        }
    }
}

// MARK: - Advanced Git Config Editor

struct AdvancedGitConfigEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var globalEntries: [GitConfigEntry] = []
    @State private var localEntries: [GitConfigEntry] = []
    @State private var isLoading = true
    @State private var selectedScope: ConfigScope = .global
    @State private var searchText = ""
    @State private var showRawEditor = false
    @State private var rawConfigText = ""
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var editingEntry: GitConfigEntry?
    @State private var editValue = ""
    @State private var hasLocalRepo = false

    enum ConfigScope: String, CaseIterable {
        case global = "Global"
        case local = "Local (Repository)"
    }

    var currentEntries: [GitConfigEntry] {
        let entries = selectedScope == .global ? globalEntries : localEntries
        if searchText.isEmpty { return entries }
        return entries.filter {
            $0.key.localizedStandardContains(searchText) ||
            $0.value.localizedStandardContains(searchText)
        }
    }

    var groupedEntries: [(String, [GitConfigEntry])] {
        let grouped = Dictionary(grouping: currentEntries) { entry in
            String(entry.key.split(separator: ".").first ?? Substring(entry.key))
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Advanced Git Configuration")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.thinMaterial)

            Divider()

            // Toolbar
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Scope picker
                Picker("", selection: $selectedScope) {
                    ForEach(ConfigScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .disabled(!hasLocalRepo && selectedScope == .local)

                Spacer()

                // Search
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                    TextField("Filter config keys...", text: $searchText)
                        .font(.system(size: 12))
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppTheme.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 220)

                Button {
                    showRawEditor.toggle()
                } label: {
                    Image(systemName: showRawEditor ? "list.bullet" : "doc.text")
                        .font(.system(size: 13))
                        .foregroundStyle(showRawEditor ? AppTheme.accent : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(showRawEditor ? "Show structured view" : "Show raw config")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary.opacity(0.5))

            Divider()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if showRawEditor {
                rawEditorView
            } else {
                structuredView
            }

            Divider()

            // Add new entry
            HStack(spacing: DesignTokens.Spacing.sm) {
                TextField("key (e.g. core.autocrlf)", text: $newKey)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                TextField("value", text: $newValue)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Button("Add") {
                    addEntry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newKey.isEmpty || newValue.isEmpty)
            }
            .padding()
            .background(AppTheme.backgroundSecondary.opacity(0.5))
        }
        .frame(width: 700, height: 500)
        .background(AppTheme.background)
        .task {
            await loadAllConfig()
        }
        .onChange(of: selectedScope) { _, _ in
            Task { await loadRawConfig() }
        }
    }

    // MARK: - Structured View

    private var structuredView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if currentEntries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.textMuted)
                        Text(searchText.isEmpty ? "No config entries" : "No matching entries")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(groupedEntries, id: \.0) { section, entries in
                        configSection(title: section, entries: entries)
                    }
                }
            }
        }
    }

    private func configSection(title: String, entries: [GitConfigEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                Text("\(entries.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(AppTheme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.backgroundSecondary.opacity(0.3))

            // Entries
            ForEach(entries) { entry in
                configEntryRow(entry)
            }
        }
    }

    @ViewBuilder
    private func configEntryRow(_ entry: GitConfigEntry) -> some View {
        HStack(spacing: 8) {
            // Key
            Text(entry.key)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
                .frame(minWidth: 200, alignment: .leading)

            Text("=")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.textMuted)

            // Value (editable if editing)
            if editingEntry?.id == entry.id {
                TextField("value", text: $editValue)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .onSubmit { saveEditedEntry(entry) }

                Button("Save") { saveEditedEntry(entry) }
                    .controlSize(.small)
                Button("Cancel") { editingEntry = nil }
                    .controlSize(.small)
            } else {
                Text(entry.value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    editingEntry = entry
                    editValue = entry.value
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)

                Button {
                    deleteEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.error.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(AppTheme.background)
    }

    // MARK: - Raw Editor

    private var rawEditorView: some View {
        VStack(spacing: 0) {
            TextEditor(text: $rawConfigText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)

            HStack {
                Spacer()
                Button("Save Raw Config") {
                    Task { await saveRawConfig() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(AppTheme.backgroundSecondary.opacity(0.5))
        }
    }

    // MARK: - Actions

    private func loadAllConfig() async {
        isLoading = true
        let shell = ShellExecutor.shared

        // Load global config
        let globalResult = await shell.execute("git", arguments: ["config", "--global", "--list"])
        if globalResult.isSuccess {
            globalEntries = parseConfigEntries(globalResult.stdout)
        }

        // Check if we're in a repo for local config
        let repoCheck = await shell.execute("git", arguments: ["rev-parse", "--git-dir"])
        hasLocalRepo = repoCheck.isSuccess

        if hasLocalRepo {
            let localResult = await shell.execute("git", arguments: ["config", "--local", "--list"])
            if localResult.isSuccess {
                localEntries = parseConfigEntries(localResult.stdout)
            }
        }

        await loadRawConfig()
        isLoading = false
    }

    private func loadRawConfig() async {
        let shell = ShellExecutor.shared
        let scope = selectedScope == .global ? "--global" : "--local"
        let result = await shell.execute("git", arguments: ["config", scope, "--list"])
        if result.isSuccess {
            rawConfigText = result.stdout
        }
    }

    private func parseConfigEntries(_ output: String) -> [GitConfigEntry] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count >= 1 else { return nil }
            let key = String(parts[0])
            let value = parts.count > 1 ? String(parts[1]) : ""
            return GitConfigEntry(key: key, value: value)
        }
    }

    private func addEntry() {
        let scope = selectedScope == .global ? "--global" : "--local"
        Task {
            let shell = ShellExecutor.shared
            let result = await shell.execute("git", arguments: ["config", scope, newKey, newValue])
            if result.isSuccess {
                newKey = ""
                newValue = ""
                await loadAllConfig()
            }
        }
    }

    private func saveEditedEntry(_ entry: GitConfigEntry) {
        let scope = selectedScope == .global ? "--global" : "--local"
        Task {
            let shell = ShellExecutor.shared
            let result = await shell.execute("git", arguments: ["config", scope, entry.key, editValue])
            if result.isSuccess {
                editingEntry = nil
                await loadAllConfig()
            }
        }
    }

    private func deleteEntry(_ entry: GitConfigEntry) {
        let scope = selectedScope == .global ? "--global" : "--local"
        Task {
            let shell = ShellExecutor.shared
            let _ = await shell.execute("git", arguments: ["config", scope, "--unset", entry.key])
            await loadAllConfig()
        }
    }

    private func saveRawConfig() async {
        // Write raw config back by parsing and setting each key
        let shell = ShellExecutor.shared
        let scope = selectedScope == .global ? "--global" : "--local"

        // Get the config file path and write directly
        let pathResult = await shell.execute("git", arguments: ["config", scope, "--list", "--show-origin"])
        if let firstLine = pathResult.stdout.split(separator: "\n").first {
            let parts = firstLine.split(separator: "\t", maxSplits: 1)
            if let filePart = parts.first {
                let filePath = String(filePart).replacingOccurrences(of: "file:", with: "")
                // Write the raw config
                do {
                    try rawConfigText.write(toFile: filePath, atomically: true, encoding: .utf8)
                    await loadAllConfig()
                } catch {
                    // Fallback: silently fail
                }
            }
        }
    }
}

// MARK: - Git Config Entry Model

struct GitConfigEntry: Identifiable {
    let id = UUID()
    let key: String
    let value: String
}

// MARK: - Email Aliases View

struct EmailAliasesView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var settings = EmailAliasSettings.shared
    @State private var newAlias = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Add email aliases to show your avatar on commits with different emails")
                .foregroundStyle(AppTheme.textPrimary)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)

            HStack {
                DSTextField(placeholder: "Email alias (e.g. work@company.com)", text: $newAlias)

                DSButton("Add", variant: .primary, size: .sm, isDisabled: newAlias.isEmpty) {
                    settings.addAlias(newAlias)
                    newAlias = ""
                }
            }

            if !settings.aliases.isEmpty {
                ForEach(settings.aliases, id: \.self) { alias in
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(alias)
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(DesignTokens.Typography.body.monospaced())
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        DSIconButton(iconName: "xmark.circle.fill", variant: .ghost, size: .sm) {
                            settings.removeAlias(alias)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                }
            }
        }
    }
}
