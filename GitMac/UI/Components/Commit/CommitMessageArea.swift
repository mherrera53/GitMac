import SwiftUI

// MARK: - Commit Message Area

/// Complete commit message input area with validation and options
/// Includes message editor, character count, amend toggle, and commit button
struct CommitMessageArea: View {
    @Binding var message: String
    @Binding var isAmending: Bool
    let canCommit: Bool
    var validationError: CommitValidationError? = nil
    var hasConflicts: Bool = false
    let onCommit: () -> Void
    let onGenerateAI: () -> Void
    var style: MessageAreaStyle = .default

    enum MessageAreaStyle {
        case `default`      // Standard layout
        case compact        // Reduced padding and spacing
        case prominent      // Larger text area
    }

    var body: some View {
        VStack(spacing: style.spacing) {
            // Header
            HStack {
                Text("Commit Message")
                    .font(style.headerFont)

                Spacer()

                Button {
                    onGenerateAI()
                } label: {
                    Label("Generate with AI", systemImage: "sparkles")
                        .font(style.buttonFont)
                }
                .buttonStyle(.borderless)
            }

            // Conflict warning
            if hasConflicts {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.warning)
                    Text("Resolve merge conflicts before committing")
                        .font(.caption)
                        .foregroundColor(AppTheme.warning)
                    Spacer()
                }
                .padding(8)
                .background(AppTheme.warning.opacity(0.1))
                .cornerRadius(4)
            }

            // Text editor
            TextEditor(text: $message)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: style.minHeight, maxHeight: style.maxHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 1)
                )

            // Validation hint
            if !canCommit && !message.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(validationHint)
                        .font(.caption)
                    Spacer()
                }
                .foregroundColor(AppTheme.textPrimary)
            }

            // Character count
            HStack {
                Text("\(message.count) characters")
                    .font(.caption2)
                    .foregroundColor(message.count < 3 ? AppTheme.warning : AppTheme.textSecondary)

                Spacer()
            }

            // Actions row
            HStack {
                Toggle("Amend last commit", isOn: $isAmending)
                    .font(style.toggleFont)

                Spacer()

                Button("Commit") {
                    onCommit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommit)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(style.padding)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var borderColor: Color {
        if hasConflicts {
            return AppTheme.warning
        }
        if !canCommit && !message.isEmpty {
            return AppTheme.warning.opacity(0.5)
        }
        return AppTheme.border
    }

    var validationHint: String {
        if message.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return "Message should be at least 3 characters"
        }
        // TODO: Fix CommitValidationError structure
        // if let error = validationError {
        //     return error.message
        // }
        return ""
    }
}

// MARK: - Message Area Style Extension

extension CommitMessageArea.MessageAreaStyle {
    var spacing: CGFloat {
        switch self {
        case .default: return 8
        case .compact: return 6
        case .prominent: return 12
        }
    }

    var headerFont: Font {
        switch self {
        case .default: return .headline
        case .compact: return .body
        case .prominent: return .title3
        }
    }

    var buttonFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var toggleFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .default: return 80
        case .compact: return 60
        case .prominent: return 100
        }
    }

    var maxHeight: CGFloat {
        switch self {
        case .default: return 120
        case .compact: return 100
        case .prominent: return 180
        }
    }

    var padding: CGFloat {
        switch self {
        case .default: return 12
        case .compact: return 8
        case .prominent: return 16
        }
    }
}

// MARK: - Simple Commit Input

/// Minimal commit message input without extra features
struct SimpleCommitInput: View {
    @Binding var message: String
    var placeholder: String = "Enter commit message..."
    let onCommit: () -> Void
    var canCommit: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        VStack(spacing: 8) {
            TextEditor(text: $message)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 60, maxHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

            HStack {
                Text("\(message.count) characters")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button("Commit") {
                    onCommit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommit)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Preview

#if DEBUG
struct CommitMessageArea_Previews: PreviewProvider {
    @State static var message1 = ""
    @State static var message2 = "Fix authentication bug\n\nResolved issue where users couldn't log in with special characters in password."
    @State static var message3 = "a"
    @State static var isAmending = false

    static var previews: some View {
        VStack(spacing: 16) {
            // Default style
            CommitMessageArea(
                message: $message1,
                isAmending: $isAmending,
                canCommit: false,
                onCommit: { print("Commit") },
                onGenerateAI: { print("Generate AI") }
            )

            Divider()

            // With message
            CommitMessageArea(
                message: $message2,
                isAmending: $isAmending,
                canCommit: true,
                onCommit: { print("Commit") },
                onGenerateAI: { print("Generate AI") }
            )

            Divider()

            // With validation error
            // TODO: Fix CommitValidationError structure before uncommenting
            /*
            CommitMessageArea(
                message: $message3,
                isAmending: .constant(false),
                canCommit: false,
                validationError: CommitValidationError(type: .tooShort, message: "Message too short"),
                onCommit: { print("Commit") },
                onGenerateAI: { print("Generate AI") }
            )
            */

            Divider()

            // With conflicts
            CommitMessageArea(
                message: $message2,
                isAmending: .constant(false),
                canCommit: false,
                hasConflicts: true,
                onCommit: { print("Commit") },
                onGenerateAI: { print("Generate AI") }
            )

            Divider()

            // Simple input
            SimpleCommitInput(
                message: $message1,
                onCommit: { print("Simple commit") }
            )
        }
        .padding()
        .frame(width: 600, height: 900)
    }
}
#endif
