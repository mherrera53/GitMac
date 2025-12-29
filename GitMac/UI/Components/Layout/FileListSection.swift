import SwiftUI

// MARK: - File List Section

/// Collapsible section with header and scrollable content
/// Optimized for file lists with LazyVStack
struct FileListSection<HeaderActions: View, Content: View>: View {
    let title: String
    let count: Int
    let icon: String
    let headerColor: Color
    @ViewBuilder let headerActions: () -> HeaderActions
    @ViewBuilder let content: () -> Content
    var style: SectionHeader<HeaderActions>.HeaderStyle = .default
    var maxHeight: CGFloat? = nil
    var showScrollIndicators: Bool = true

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SectionHeader(
                title: title,
                count: count,
                icon: icon,
                color: headerColor,
                isCollapsible: true,
                isExpanded: $isExpanded,
                actions: headerActions,
                style: style
            )

            // Content - LazyVStack for performance with stable ID to prevent jumping
            if isExpanded {
                ScrollView(showsIndicators: showScrollIndicators) {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        content()
                    }
                    .id(count)  // Stable ID prevents view jumping
                    .animation(.none, value: count)
                }
                .frame(maxHeight: maxHeight)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension FileListSection where HeaderActions == EmptyView {
    /// Creates a file list section without header actions
    init(
        title: String,
        count: Int,
        icon: String,
        headerColor: Color = AppTheme.accent,
        style: SectionHeader<EmptyView>.HeaderStyle = .default,
        maxHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.count = count
        self.icon = icon
        self.headerColor = headerColor
        self.headerActions = { EmptyView() }
        self.content = content
        self.style = style
        self.maxHeight = maxHeight
    }
}

// MARK: - Simple List Section

/// Generic list section for any content (not just files)
struct ListSection<HeaderActions: View, Content: View>: View {
    let title: String
    let count: Int
    let icon: String
    var color: Color = AppTheme.accent
    var style: SectionHeader<HeaderActions>.HeaderStyle = .default
    var isScrollable: Bool = true
    var maxHeight: CGFloat? = nil
    @ViewBuilder let headerActions: () -> HeaderActions
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SectionHeader(
                title: title,
                count: count,
                icon: icon,
                color: color,
                isCollapsible: true,
                isExpanded: $isExpanded,
                actions: headerActions,
                style: style
            )

            // Content
            if isExpanded {
                if isScrollable {
                    ScrollView {
                        VStack(spacing: 0) {
                            content()
                        }
                    }
                    .frame(maxHeight: maxHeight)
                } else {
                    VStack(spacing: 0) {
                        content()
                    }
                }
            }
        }
    }
}

// MARK: - Convenience Initializers for ListSection

extension ListSection where HeaderActions == EmptyView {
    /// Creates a list section without header actions
    init(
        title: String,
        count: Int,
        icon: String,
        color: Color = AppTheme.accent,
        style: SectionHeader<EmptyView>.HeaderStyle = .default,
        isScrollable: Bool = true,
        maxHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.count = count
        self.icon = icon
        self.color = color
        self.style = style
        self.isScrollable = isScrollable
        self.maxHeight = maxHeight
        self.headerActions = { EmptyView() }
        self.content = content
    }
}

// MARK: - Preview

#if DEBUG
struct FileListSection_Previews: PreviewProvider {
    static var sampleFiles = [
        "src/components/Button.tsx",
        "src/components/Input.tsx",
        "src/utils/helpers.ts",
        "src/styles/theme.css",
        "README.md"
    ]

    static var previews: some View {
        VStack(spacing: 16) {
            // File list section with actions
            FileListSection(
                title: "Unstaged Files",
                count: 5,
                icon: "doc.badge.ellipsis",
                headerColor: AppTheme.warning,
                headerActions: {
                    HStack(spacing: 4) {
                        DSIconButton(iconName: "plus.circle.fill", variant: .ghost, size: .sm, action: { print("Stage all") })
                            .help("Stage All")
                        DSIconButton(iconName: "trash.fill", variant: .ghost, size: .sm, action: { print("Discard all") })
                            .help("Discard All")
                    }
                },
                content: {
                    ForEach(sampleFiles, id: \.self) { file in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(AppTheme.textSecondary)
                            Text(file)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.clear)
                    }
                },
                maxHeight: 200
            )

            Divider()

            // Simple list section
            ListSection(
                title: "Branches",
                count: 3,
                icon: "arrow.branch",
                color: AppTheme.accent,
                isScrollable: false
            ) {
                VStack(spacing: 4) {
                    Text("main")
                    Text("develop")
                    Text("feature/new-ui")
                }
                .padding()
            }

            Divider()

            // Compact style
            FileListSection(
                title: "Stashed Changes",
                count: 2,
                icon: "tray.fill",
                headerColor: AppTheme.accentPurple,
                style: .compact
            ) {
                Text("Stash 1: WIP on main")
                    .padding()
                Text("Stash 2: Experimental feature")
                    .padding()
            }
        }
        .padding()
        .frame(width: 500, height: 700)
    }
}
#endif
