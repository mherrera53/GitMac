//
//  GitOperationProgressView.swift
//  GitMac
//
//  UI component for displaying git operation progress
//

import SwiftUI

struct GitOperationProgressView: View {
    @ObservedObject var tracker = GitProgressTracker.shared

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.sm) {
            ForEach(tracker.activeOperations) { operation in
                OperationProgressCard(operation: operation)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(DesignTokens.Spacing.md)
    }
}

struct OperationProgressCard: View {
    let operation: GitProgressTracker.GitOperation
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon
            Image(systemName: operation.type.icon)
                .font(.system(size: DesignTokens.Size.iconMD))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(operation.message)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(operation.phase.description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    if !operation.progress.isIndeterminate {
                        Text("·")
                            .foregroundColor(AppTheme.textMuted)
                        Text("\(Int(operation.progress.percentage))%")
                            .font(DesignTokens.Typography.caption.monospacedDigit())
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                // Progress bar
                if operation.isActive {
                    ProgressView(value: operation.progress.percentage, total: 100)
                        .progressViewStyle(.linear)
                        .tint(AppTheme.accent)
                        .frame(height: 4)
                }
            }

            // Close button (on hover)
            if isHovered {
                Button {
                    GitProgressTracker.shared.cancelOperation(operationId: operation.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .frame(width: 280)
        .background(backgroundMaterial)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var iconColor: Color {
        switch operation.phase {
        case .complete:
            return AppTheme.success
        case .failed:
            return AppTheme.error
        default:
            return AppTheme.accent
        }
    }

    @ViewBuilder
    private var backgroundMaterial: some View {
        if #available(macOS 12.0, *) {
            Color(nsColor: .controlBackgroundColor)
                .overlay(Material.ultraThinMaterial)
        } else {
            Color(nsColor: .controlBackgroundColor)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                GitOperationProgressView()
            }
        }
    }
    .frame(width: 800, height: 600)
}
