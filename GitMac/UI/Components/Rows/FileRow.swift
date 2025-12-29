import SwiftUI

// MARK: - File Row

/// Specialized row for displaying git file status
/// Built on top of BaseRow with file-specific features
struct FileRow: View {
    let file: FileStatus
    let isSelected: Bool
    var style: RowStyle = .default
    var showStatusIcon: Bool = true
    var showFileIcon: Bool = true
    var showDirectory: Bool = true
    var showStats: Bool = true
    var contextMenu: (() -> AnyView)? = nil
    var onSelect: (() -> Void)? = nil

    // File actions
    var onStage: (() async -> Void)? = nil
    var onUnstage: (() async -> Void)? = nil
    var onDiscard: (() async -> Void)? = nil
    var onDiscardStaged: (() async -> Void)? = nil

    var body: some View {
        BaseRow(
            isSelected: isSelected,
            style: style,
            actions: buildActions(),
            contextMenu: contextMenu,
            onSelect: onSelect
        ) {
            fileContent
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        // Status icon
        if showStatusIcon {
            StatusIcon(status: file.status, size: .medium, style: .badge)
        }

        // File type icon
        if showFileIcon {
            Image(systemName: "doc.fill")
                .foregroundColor(AppTheme.info)
                .frame(width: 16)
        }

        // File name and directory
        VStack(alignment: .leading, spacing: 0) {
            Text(file.filename)
                .lineLimit(1)

            if showDirectory && !file.directory.isEmpty && file.directory != "." {
                Text(file.directory)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }

        Spacer()

        // Diff stats
        if showStats && file.hasChanges {
            DiffStatsView(additions: file.additions, deletions: file.deletions)
        }
    }

    private func buildActions() -> [RowAction] {
        var actions: [RowAction] = []

        if let stage = onStage {
            actions.append(.stage(action: stage))
        }

        if let unstage = onUnstage {
            actions.append(.unstage(action: unstage))
        }

        if let discard = onDiscard {
            actions.append(.discard(action: discard))
        }

        if let discardStaged = onDiscardStaged {
            actions.append(
                RowAction(
                    icon: "xmark.circle",
                    color: AppTheme.error,
                    tooltip: "Discard staged changes",
                    action: discardStaged
                )
            )
        }

        return actions
    }
}

// MARK: - Convenience Initializers

extension FileRow {
    /// Creates a file row for unstaged files
    static func unstaged(
        file: FileStatus,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil,
        onStage: @escaping () async -> Void,
        onDiscard: @escaping () async -> Void
    ) -> FileRow {
        FileRow(
            file: file,
            isSelected: isSelected,
            onSelect: onSelect,
            onStage: onStage,
            onDiscard: onDiscard
        )
    }

    /// Creates a file row for staged files
    static func staged(
        file: FileStatus,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil,
        onUnstage: @escaping () async -> Void,
        onDiscardStaged: (() async -> Void)? = nil
    ) -> FileRow {
        FileRow(
            file: file,
            isSelected: isSelected,
            onSelect: onSelect,
            onUnstage: onUnstage,
            onDiscardStaged: onDiscardStaged
        )
    }

    /// Creates a read-only file row (no actions)
    static func readOnly(
        file: FileStatus,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil
    ) -> FileRow {
        FileRow(
            file: file,
            isSelected: isSelected,
            onSelect: onSelect
        )
    }
}

// MARK: - File Row Data Adapter

/// Makes FileStatus conform to RowData for use with DataRow
extension FileStatus: RowData {
    var primaryText: String { filename }

    var secondaryText: String? {
        !directory.isEmpty && directory != "." ? directory : nil
    }

    var leadingIcon: RowIcon? {
        RowIcon(systemName: "doc.fill", color: .accentColor, size: 16)
    }

    var trailingContent: RowTrailingContent? {
        hasChanges ? .stats(additions: additions, deletions: deletions) : nil
    }
}

// MARK: - Preview

#if DEBUG
struct FileRow_Previews: PreviewProvider {
    static let sampleFile = FileStatus(
        path: "src/components/Button.tsx",
        status: .modified,
        additions: 15,
        deletions: 3
    )

    static let sampleUntracked = FileStatus(
        path: "docs/README.md",
        status: .untracked,
        additions: 0,
        deletions: 0
    )

    static var previews: some View {
        VStack(spacing: 8) {
            // Modified file with actions
            FileRow.unstaged(
                file: sampleFile,
                isSelected: false,
                onStage: { print("Stage") },
                onDiscard: { print("Discard") }
            )

            // Selected file
            FileRow.staged(
                file: sampleFile,
                isSelected: true,
                onUnstage: { print("Unstage") }
            )

            // Untracked file
            FileRow.unstaged(
                file: sampleUntracked,
                onStage: { print("Stage") },
                onDiscard: { print("Discard") }
            )

            // Read-only file
            FileRow.readOnly(file: sampleFile)

            // Compact style
            FileRow(
                file: sampleFile,
                isSelected: false,
                style: .compact
            )
        }
        .padding()
        .frame(width: 500)
    }
}
#endif
