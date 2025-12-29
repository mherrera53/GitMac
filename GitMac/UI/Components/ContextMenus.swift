import SwiftUI
import AppKit

// MARK: - Context Menu for Diff Lines

struct DiffLineContextMenu: View {
    let line: DiffLine
    let onCopyLine: () -> Void
    let onStageLine: (() -> Void)?
    let onDiscardLine: (() -> Void)?
    let onCopyContent: () -> Void

    var body: some View {
        Group {
            Button {
                onCopyContent()
            } label: {
                Label("Copy Line Content", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)

            Button {
                onCopyLine()
            } label: {
                Label("Copy with Line Number", systemImage: "list.number")
            }

            if let stageLine = onStageLine, line.type != .context {
                Divider()

                Button {
                    stageLine()
                } label: {
                    Label("Stage This Line", systemImage: "plus.circle")
                }
            }

            if let discardLine = onDiscardLine, line.type != .context {
                Button(role: .destructive) {
                    discardLine()
                } label: {
                    Label("Discard This Line", systemImage: "trash")
                }
            }
        }
    }
}

/// Context menu for branches
struct BranchContextMenu: View {
    let branchName: String
    let isCurrentBranch: Bool
    let isRemote: Bool
    let onCheckout: () -> Void
    let onMerge: () -> Void
    let onRebase: () -> Void
    let onRename: (() -> Void)?
    let onDelete: () -> Void
    let onPush: (() -> Void)?
    let onPull: (() -> Void)?
    let onCopyName: () -> Void

    var body: some View {
        Group {
            if !isCurrentBranch {
                Button {
                    onCheckout()
                } label: {
                    Label("Checkout", systemImage: "arrow.right.circle")
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button {
                    onMerge()
                } label: {
                    Label("Merge into Current", systemImage: "arrow.triangle.merge")
                }

                Button {
                    onRebase()
                } label: {
                    Label("Rebase Current onto This", systemImage: "arrow.triangle.pull")
                }

                Divider()
            }

            if !isRemote {
                if let push = onPush {
                    Button {
                        push()
                    } label: {
                        Label("Push", systemImage: "arrow.up.circle")
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }

                if let pull = onPull {
                    Button {
                        pull()
                    } label: {
                        Label("Pull", systemImage: "arrow.down.circle")
                    }
                    .keyboardShortcut("p", modifiers: .command)
                }

                Divider()

                if let rename = onRename, !isCurrentBranch {
                    Button {
                        rename()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                }
            }

            if !isCurrentBranch {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }

            Divider()

            Button {
                onCopyName()
            } label: {
                Label("Copy Branch Name", systemImage: "doc.on.doc")
            }
        }
    }
}

/// Context menu for stash entries
struct StashContextMenu: View {
    let stashIndex: Int
    let onApply: () -> Void
    let onPop: () -> Void
    let onDrop: () -> Void
    let onCreateBranch: () -> Void

    var body: some View {
        Group {
            Button {
                onApply()
            } label: {
                Label("Apply", systemImage: "arrow.down.doc")
            }

            Button {
                onPop()
            } label: {
                Label("Pop", systemImage: "arrow.down.doc.fill")
            }

            Divider()

            Button {
                onCreateBranch()
            } label: {
                Label("Create Branch from Stash", systemImage: "arrow.triangle.branch")
            }

            Divider()

            Button(role: .destructive) {
                onDrop()
            } label: {
                Label("Drop", systemImage: "trash")
            }
        }
    }
}

// MARK: - Utility Functions

struct ContextMenuHelper {
    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func openInDefaultEditor(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    static func openInExternalEditor(path: String, editor: String = "code") {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [editor, path]
        try? process.run()
    }
}

// MARK: - Toast Notification

struct ToastView: View {
    let message: String
    let icon: String
    let type: ToastType

    enum ToastType {
        case success, error, info, warning

        @MainActor
        var color: Color {
            switch self {
            case .success: return AppTheme.accentGreen
            case .error: return AppTheme.accentRed
            case .info: return AppTheme.accent
            case .warning: return AppTheme.accentOrange
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(type.color)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.backgroundSecondary)
                .shadow(color: AppTheme.shadow.opacity(0.3), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Toast Manager

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: (message: String, icon: String, type: ToastView.ToastType)?
    @Published var isShowing = false

    func show(_ message: String, icon: String = "checkmark.circle.fill", type: ToastView.ToastType = .success) {
        currentToast = (message, icon, type)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isShowing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.isShowing = false
            }
        }
    }

    func showError(_ message: String) {
        show(message, icon: "xmark.circle.fill", type: .error)
    }

    func showInfo(_ message: String) {
        show(message, icon: "info.circle.fill", type: .info)
    }

    func showWarning(_ message: String) {
        show(message, icon: "exclamationmark.triangle.fill", type: .warning)
    }
}

// MARK: - Toast Overlay Modifier

struct ToastOverlay: ViewModifier {
    @ObservedObject var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if manager.isShowing, let toast = manager.currentToast {
                    ToastView(message: toast.message, icon: toast.icon, type: toast.type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40)
                }
            }
    }
}

extension View {
    func withToastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
