import SwiftUI

// MARK: - Diff Line Context Menu Extension

extension View {
    /// Adds a context menu with copy actions to a diff line view
    func diffLineContextMenu(line: DiffLine) -> some View {
        self.contextMenu {
            Button {
                ContextMenuHelper.copyToClipboard(line.content)
                ToastManager.shared.show("Line content copied")
            } label: {
                Label("Copy Line Content", systemImage: "doc.on.doc")
            }

            Button {
                let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 0
                let prefix: String
                switch line.type {
                case .addition: prefix = "+"
                case .deletion: prefix = "-"
                default: prefix = " "
                }
                let text = "\(lineNum): \(prefix)\(line.content)"
                ContextMenuHelper.copyToClipboard(text)
                ToastManager.shared.show("Line copied with number")
            } label: {
                Label("Copy with Line Number", systemImage: "list.number")
            }

            if line.type != .context && line.type != .hunkHeader {
                Divider()

                // Hint for hunk-level actions
                Label("Hover over hunk header for Stage/Discard", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }

    /// Extended context menu with stage/discard actions for diff lines
    func diffLineContextMenuWithActions(
        line: DiffLine,
        onStageLine: (() -> Void)? = nil,
        onDiscardLine: (() -> Void)? = nil
    ) -> some View {
        self.contextMenu {
            Button {
                ContextMenuHelper.copyToClipboard(line.content)
                ToastManager.shared.show("Line content copied")
            } label: {
                Label("Copy Line Content", systemImage: "doc.on.doc")
            }

            Button {
                let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 0
                let prefix: String
                switch line.type {
                case .addition: prefix = "+"
                case .deletion: prefix = "-"
                default: prefix = " "
                }
                let text = "\(lineNum): \(prefix)\(line.content)"
                ContextMenuHelper.copyToClipboard(text)
                ToastManager.shared.show("Line copied with number")
            } label: {
                Label("Copy with Line Number", systemImage: "list.number")
            }

            if line.type != .context && line.type != .hunkHeader {
                Divider()

                if let stageLine = onStageLine {
                    Button {
                        stageLine()
                    } label: {
                        Label("Stage This Line", systemImage: "plus.circle")
                    }
                }

                if let discardLine = onDiscardLine {
                    Button(role: .destructive) {
                        discardLine()
                    } label: {
                        Label("Discard This Line", systemImage: "trash")
                    }
                }

                if onStageLine == nil && onDiscardLine == nil {
                    Label("Hover over hunk header for Stage/Discard", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
    }
}
