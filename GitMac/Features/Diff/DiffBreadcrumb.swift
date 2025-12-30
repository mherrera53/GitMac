import SwiftUI

// MARK: - Diff Breadcrumb Navigation (Kaleidoscope-style)

/// Breadcrumb navigation showing file path and version selectors
struct DiffBreadcrumb: View {
    let filePath: String
    let additions: Int
    let deletions: Int
    let changes: Int
    @Binding var selectedVersionA: String?
    @Binding var selectedVersionB: String?
    let versions: [FileVersion]

    @StateObject private var themeManager = ThemeManager.shared

    private var pathComponents: [String] {
        filePath.components(separatedBy: "/").filter { !$0.isEmpty }
    }

    var body: some View {
        let theme = Color.Theme(themeManager.colors)

        HStack(spacing: DesignTokens.Spacing.md) {
            // File path breadcrumb
            breadcrumbPath

            Spacer()

            // Stats
            diffStats

            // Version selectors
            versionSelectors
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(theme.toolbar)
    }

    // MARK: - Components

    private var breadcrumbPath: some View {
        HStack(spacing: 4) {
            ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                HStack(spacing: 4) {
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(AppTheme.textMuted)
                    }

                    if index == pathComponents.count - 1 {
                        // File name (highlighted)
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: fileIcon(for: component))
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.accent)

                            Text(component)
                                .font(DesignTokens.Typography.body.weight(.semibold))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    } else {
                        // Directory path
                        Text(component)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
        }
    }

    private var diffStats: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Additions
            HStack(spacing: 2) {
                Text("\(additions)")
                    .font(DesignTokens.Typography.caption.weight(.semibold).monospaced())
                Text("Additions")
                    .font(DesignTokens.Typography.caption2)
            }
            .foregroundColor(AppTheme.diffAddition)

            // Deletions
            HStack(spacing: 2) {
                Text("\(deletions)")
                    .font(DesignTokens.Typography.caption.weight(.semibold).monospaced())
                Text("Deletions")
                    .font(DesignTokens.Typography.caption2)
            }
            .foregroundColor(AppTheme.diffDeletion)

            // Changes
            HStack(spacing: 2) {
                Text("\(changes)")
                    .font(DesignTokens.Typography.caption.weight(.semibold).monospaced())
                Text("Changes")
                    .font(DesignTokens.Typography.caption2)
            }
            .foregroundColor(AppTheme.info)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }

    private var versionSelectors: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Version A selector
            versionSelector(
                label: "A",
                selectedVersion: $selectedVersionA,
                color: AppTheme.accent
            )

            // Version B selector
            versionSelector(
                label: "B",
                selectedVersion: $selectedVersionB,
                color: AppTheme.info
            )
        }
    }

    private func versionSelector(
        label: String,
        selectedVersion: Binding<String?>,
        color: Color
    ) -> some View {
        Menu {
            ForEach(versions, id: \.id) { version in
                Button {
                    selectedVersion.wrappedValue = version.identifier
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(version.name)
                                .font(DesignTokens.Typography.body)
                            Text(version.description)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textMuted)
                        }

                        Spacer()

                        if selectedVersion.wrappedValue == version.identifier {
                            Image(systemName: "checkmark")
                                .foregroundColor(color)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Label badge
                Text(label)
                    .font(DesignTokens.Typography.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(color)
                    .cornerRadius(DesignTokens.CornerRadius.sm)

                // Selected version name
                if let identifier = selectedVersion.wrappedValue,
                   let version = versions.first(where: { $0.identifier == identifier }) {
                    Text(version.name)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                } else {
                    Text("Select version...")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textMuted)
                }

                Image(systemName: "chevron.down")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "md", "markdown": return "doc.text"
        case "json": return "curlybraces.square"
        case "xml", "html": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss": return "paintbrush"
        case "jpg", "jpeg", "png", "gif": return "photo"
        default: return "doc"
        }
    }
}

// MARK: - File Version Model

struct FileVersion: Identifiable {
    let id = UUID()
    let identifier: String // commit SHA or reference
    let name: String // Short display name (e.g., "380fe8c2")
    let description: String // Additional info (e.g., "23. September 2025 at 19:55")
}

// MARK: - Preview

#if DEBUG
struct DiffBreadcrumb_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            DiffBreadcrumb(
                filePath: "turbopack/crates/turbopack-core/src/resolve/mod.rs",
                additions: 39,
                deletions: 15,
                changes: 43,
                selectedVersionA: .constant("1300acfe"),
                selectedVersionB: .constant("380fe8c2"),
                versions: [
                    FileVersion(
                        identifier: "1300acfe",
                        name: "1300acfe",
                        description: "23. September 2025 at 19:50"
                    ),
                    FileVersion(
                        identifier: "380fe8c2",
                        name: "380fe8c2",
                        description: "23. September 2025 at 19:55"
                    ),
                    FileVersion(
                        identifier: "9bd5a76d",
                        name: "9bd5a76d",
                        description: "24. September 2025 at 10:30"
                    ),
                ]
            )

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            Spacer()
        }
        .frame(width: 900, height: 400)
        .background(AppTheme.background)
    }
}
#endif
