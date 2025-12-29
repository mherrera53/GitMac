//
//  DSLinkButton.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Atomic Design System - Level 2: Link Button Atom
//

import SwiftUI

/// Link-style button with underline on hover
struct DSLinkButton: View {
    let title: String
    let iconName: String?
    let size: DSButtonSize
    let isDisabled: Bool
    let action: () async -> Void

    @State private var isLoading = false
    @State private var isHovered = false

    init(
        title: String,
        iconName: String? = nil,
        size: DSButtonSize = .md,
        isDisabled: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button {
            guard !isLoading && !isDisabled else { return }
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    if let iconName = iconName {
                        Image(systemName: iconName)
                            .font(.system(size: iconSizeForSize))
                    }

                    Text(title)
                        .font(fontForSize)
                        .underline(isHovered && !isDisabled)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Size Properties

    private var fontForSize: Font {
        switch size {
        case .sm: return DesignTokens.Typography.caption
        case .md: return DesignTokens.Typography.body
        case .lg: return DesignTokens.Typography.callout
        }
    }

    private var iconSizeForSize: CGFloat {
        switch size {
        case .sm: return DesignTokens.Size.iconSM
        case .md: return DesignTokens.Size.iconMD
        case .lg: return DesignTokens.Size.iconLG
        }
    }

    // MARK: - Colors

    private var foregroundColor: Color {
        if isDisabled {
            return AppTheme.textMuted
        }

        return isHovered ? AppTheme.linkHover : AppTheme.link
    }
}

// MARK: - Previews

#Preview("Link Buttons") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        DSLinkButton(title: "View documentation") {
            print("Docs clicked")
        }

        DSLinkButton(title: "Learn more", iconName: "arrow.right") {
            print("Learn more clicked")
        }

        DSLinkButton(title: "Open in browser", iconName: "safari") {
            print("Browser clicked")
        }

        DSLinkButton(title: "Disabled link", isDisabled: true) {
            print("Disabled clicked")
        }
    }
    .padding()
}

#Preview("Link Sizes") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
        DSLinkButton(title: "Small link", size: .sm) {
            print("Small clicked")
        }

        DSLinkButton(title: "Medium link", size: .md) {
            print("Medium clicked")
        }

        DSLinkButton(title: "Large link", size: .lg) {
            print("Large clicked")
        }
    }
    .padding()
}

#Preview("Link in Context") {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
        Text("GitMac")
            .font(DesignTokens.Typography.title2)
            .foregroundColor(AppTheme.textPrimary)

        Text("A modern Git client for macOS with powerful features.")
            .font(DesignTokens.Typography.body)
            .foregroundColor(AppTheme.textSecondary)

        HStack(spacing: DesignTokens.Spacing.md) {
            DSLinkButton(title: "Documentation", iconName: "book") {
                print("Docs")
            }

            DSLinkButton(title: "GitHub", iconName: "link") {
                print("GitHub")
            }

            DSLinkButton(title: "Report Issue", iconName: "exclamationmark.triangle") {
                print("Issue")
            }
        }
    }
    .padding()
    .frame(width: 400)
}

#Preview("External Link") {
    HStack(spacing: DesignTokens.Spacing.xs) {
        Text("Read more about Git workflows")
            .font(DesignTokens.Typography.body)
            .foregroundColor(AppTheme.textPrimary)

        DSLinkButton(title: "here", iconName: "arrow.up.right.square") {
            print("External link")
        }
    }
    .padding()
}
