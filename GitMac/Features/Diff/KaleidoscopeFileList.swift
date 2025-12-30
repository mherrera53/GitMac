import SwiftUI

// MARK: - Kaleidoscope File List Sidebar (LEFT side)

/// Left sidebar showing changed files in the changeset (Kaleidoscope-style)
struct KaleidoscopeFileList: View {
    let files: [FileDiff]
    @Binding var selectedFile: FileDiff?
    @State private var filterText: String = ""
    @State private var expandedDirectories: Set<String> = []

    @StateObject private var themeManager = ThemeManager.shared

    private var groupedFiles: [String: [FileDiff]] {
        var groups: [String: [FileDiff]] = [:]

        for file in filteredFiles {
            let dir = (file.displayPath as NSString).deletingLastPathComponent
            let directory = dir.isEmpty ? "Root" : dir

            if groups[directory] == nil {
                groups[directory] = []
            }
            groups[directory]?.append(file)
        }

        return groups
    }

    private var filteredFiles: [FileDiff] {
        if filterText.isEmpty {
            return files
        }
        return files.filter { file in
            file.displayPath.localizedCaseInsensitiveContains(filterText)
        }
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Search/Filter
            searchBarView

            Divider()

            // File list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedFiles.keys.sorted(), id: \.self) { directory in
                        Section {
                            if expandedDirectories.contains(directory) {
                                ForEach(groupedFiles[directory] ?? []) { file in
                                    FileListRow(
                                        file: file,
                                        isSelected: selectedFile?.id == file.id,
                                        onSelect: { selectedFile = file }
                                    )
                                }
                            }
                        } header: {
                            DirectoryHeader(
                                directory: directory,
                                fileCount: groupedFiles[directory]?.count ?? 0,
                                isExpanded: expandedDirectories.contains(directory),
                                onToggle: {
                                    if expandedDirectories.contains(directory) {
                                        expandedDirectories.remove(directory)
                                    } else {
                                        expandedDirectories.insert(directory)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .background(theme.background)
        }
        .frame(width: 280)
        .background(theme.backgroundSecondary)
        .onAppear {
            // Expand all by default
            expandedDirectories = Set(groupedFiles.keys)
        }
    }

    // MARK: - Components

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "doc.on.doc")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(AppTheme.accent)

            Text("Files")
                .font(DesignTokens.Typography.headline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Text("\(files.count)")
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, 2)
                .background(AppTheme.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .padding(DesignTokens.Spacing.md)
    }

    private var searchBarView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textMuted)

            TextField("Filter Files", text: $filterText)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)

            if !filterText.isEmpty {
                Button {
                    filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundTertiary)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

// MARK: - Directory Header

struct DirectoryHeader: View {
    let directory: String
    let fileCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        Button(action: onToggle) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(DesignTokens.Typography.caption2.weight(.bold))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 12)

                Image(systemName: "folder")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.accent)

                Text(directory)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(fileCount)")
                    .font(DesignTokens.Typography.caption2.monospaced())
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(theme.backgroundTertiary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - File List Row

struct FileListRow: View {
    let file: FileDiff
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

    private var fileName: String {
        (file.displayPath as NSString).lastPathComponent
    }

    private var statusIcon: String {
        switch file.status {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .added: return AppTheme.diffAddition
        case .modified: return AppTheme.info
        case .deleted: return AppTheme.diffDeletion
        case .renamed, .copied: return AppTheme.warning
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Status icon
                Image(systemName: statusIcon)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(statusColor)
                    .frame(width: 16)

                // File name
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    // Stats
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if file.additions > 0 {
                            Text("+\(file.additions)")
                                .font(DesignTokens.Typography.caption2.monospaced())
                                .foregroundColor(AppTheme.diffAddition)
                        }
                        if file.deletions > 0 {
                            Text("-\(file.deletions)")
                                .font(DesignTokens.Typography.caption2.monospaced())
                                .foregroundColor(AppTheme.diffDeletion)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(backgroundForState)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(borderForState, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .onHover { isHovered = $0 }
    }

    private var backgroundForState: Color {
        if isSelected {
            return AppTheme.accent.opacity(0.15)
        }
        if isHovered {
            return AppTheme.hover
        }
        return Color.clear
    }

    private var borderForState: Color {
        isSelected ? AppTheme.accent : Color.clear
    }
}

// MARK: - Preview

#if DEBUG
struct KaleidoscopeFileList_Previews: PreviewProvider {
    static var sampleFiles: [FileDiff] {
        [
            FileDiff(
                oldPath: "src/components/Button.tsx",
                newPath: "src/components/Button.tsx",
                status: .modified,
                hunks: [],
                additions: 12,
                deletions: 5
            ),
            FileDiff(
                oldPath: "src/utils/helpers.ts",
                newPath: "src/utils/helpers.ts",
                status: .modified,
                hunks: [],
                additions: 8,
                deletions: 2
            ),
            FileDiff(
                oldPath: "README.md",
                newPath: "README.md",
                status: .modified,
                hunks: [],
                additions: 3,
                deletions: 1
            ),
            FileDiff(
                oldPath: "src/config/settings.json",
                newPath: "src/config/settings.json",
                status: .added,
                hunks: [],
                additions: 15,
                deletions: 0
            ),
        ]
    }

    static var previews: some View {
        KaleidoscopeFileList(
            files: sampleFiles,
            selectedFile: .constant(nil)
        )
        .frame(height: 600)
    }
}
#endif
