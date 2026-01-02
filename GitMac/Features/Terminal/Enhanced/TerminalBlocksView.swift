//
//  TerminalBlocksView.swift
//  GitMac
//
//  Warp-style terminal blocks with command grouping
//

import SwiftUI

// MARK: - Terminal Block Model

struct TerminalBlock: Identifiable, Codable {
    let id: UUID
    var command: TrackedCommand
    var isSelected: Bool = false
    var isCollapsed: Bool = false

    init(command: TrackedCommand) {
        self.id = command.id
        self.command = command
    }
}

// MARK: - Terminal Blocks View

struct TerminalBlocksView: View {
    @ObservedObject var viewModel: GhosttyEnhancedViewModel
    @State private var selectedBlockId: UUID?
    @State private var hoveredBlockId: UUID?

    var blocks: [TerminalBlock] {
        viewModel.trackedCommands.map { TerminalBlock(command: $0) }
    }

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 8) {
                    ForEach(blocks) { block in
                        TerminalBlockRow(
                            block: block,
                            isSelected: selectedBlockId == block.id,
                            isHovered: hoveredBlockId == block.id,
                            onSelect: { selectedBlockId = block.id },
                            onCopy: { copyBlock(block) },
                            onShare: { shareBlock(block) }
                        )
                        .id(block.id)
                        .onHover { hovering in
                            if hovering {
                                hoveredBlockId = block.id
                            } else if hoveredBlockId == block.id {
                                hoveredBlockId = nil
                            }
                        }
                    }
                }
                .padding(12)
                .onChange(of: blocks.count) { _, _ in
                    // Auto-scroll to latest block
                    if let lastBlock = blocks.last {
                        withAnimation {
                            proxy.scrollTo(lastBlock.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(AppTheme.background)
    }

    private func copyBlock(_ block: TerminalBlock) {
        let text = """
        $ \(block.command.command)
        \(block.command.output)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func shareBlock(_ block: TerminalBlock) {
        // TODO: Implement sharing via Session Sharing feature
        copyBlock(block)
    }
}

// MARK: - Terminal Block Row

struct TerminalBlockRow: View {
    let block: TerminalBlock
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void

    @State private var isCollapsed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Command Header
            HStack(spacing: 12) {
                // Status indicator
                Image(systemName: block.command.statusIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
                    .frame(width: 16, height: 16)

                // Command
                Text(block.command.command)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Metadata
                HStack(spacing: 12) {
                    // Git branch
                    if let branch = block.command.gitBranch {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                            Text(branch)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(AppTheme.textMuted)
                    }

                    // Duration
                    Text(block.command.durationFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)

                    // Timestamp
                    Text(timeAgo(from: block.command.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }

                // Actions (visible on hover)
                if isHovered || isSelected {
                    HStack(spacing: 4) {
                        Button(action: { isCollapsed.toggle() }) {
                            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .help("Collapse/Expand")

                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Copy Block")

                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Share Block")
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(headerBackground)

            // Output (collapsible)
            if !isCollapsed && !block.command.output.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Redacted output
                    Text(redactedOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppTheme.textSecondary)
                        .textSelection(.enabled)
                        .padding(16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.backgroundSecondary)
            }

            // Error message if failed
            if let code = block.command.exitCode, code != 0, !isCollapsed {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.error)

                    Text("Command failed with exit code \(code)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.error)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.error.opacity(0.1))
            }
        }
        .background(blockBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: isSelected ? 8 : 2, y: isSelected ? 4 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private var statusColor: Color {
        if !block.command.isComplete {
            return AppTheme.info
        }
        if let code = block.command.exitCode {
            return code == 0 ? AppTheme.success : AppTheme.error
        }
        return AppTheme.textSecondary
    }

    private var headerBackground: Color {
        if isSelected {
            return AppTheme.accent.opacity(0.1)
        } else if isHovered {
            return AppTheme.hover
        }
        return Color.clear
    }

    private var blockBackground: Color {
        if isSelected {
            return AppTheme.backgroundTertiary
        }
        return AppTheme.backgroundSecondary
    }

    private var borderColor: Color {
        if isSelected {
            return AppTheme.accent
        } else if isHovered {
            return AppTheme.border.opacity(0.5)
        }
        return AppTheme.border.opacity(0.2)
    }

    private var redactedOutput: String {
        let (redacted, _) = SecretRedactionService.shared.redactSecrets(in: block.command.output)
        return redacted
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Preview

#Preview {
    TerminalBlocksView(viewModel: GhosttyEnhancedViewModel())
        .frame(width: 800, height: 600)
}
