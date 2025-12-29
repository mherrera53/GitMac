//
//  ComponentCatalog.swift
//  GitMac
//
//  Created on 28/12/2025.
//  Complete Design System Component Catalog
//  Showcases all 48 components organized by Atomic Design principles
//

import SwiftUI

// MARK: - Main Catalog View

struct ComponentCatalog: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AtomsView()
                .tabItem {
                    Label("Atoms", systemImage: "atom")
                }
                .tag(0)

            MoleculesView()
                .tabItem {
                    Label("Molecules", systemImage: "cube.transparent")
                }
                .tag(1)

            OrganismsView()
                .tabItem {
                    Label("Organisms", systemImage: "square.stack.3d.up")
                }
                .tag(2)

            DesignTokensView()
                .tabItem {
                    Label("Tokens", systemImage: "paintpalette")
                }
                .tag(3)
        }
        .frame(minWidth: 900, minHeight: 700)
        .background(AppTheme.background)
    }
}

// MARK: - Atoms View (22 Components)

struct AtomsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                // MARK: Buttons (6 components)
                CatalogSection(title: "Buttons", description: "6 button components for user actions") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSButton
                        ComponentShowcase(
                            name: "DSButton",
                            description: "Primary button with variants and async support"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                // Variants
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    DSButton(variant: .primary, size: .md) {
                                        print("Primary")
                                    } label: { Text("Primary") }

                                    DSButton(variant: .secondary, size: .md) {
                                        print("Secondary")
                                    } label: { Text("Secondary") }

                                    DSButton(variant: .danger, size: .md) {
                                        print("Danger")
                                    } label: { Text("Danger") }
                                }

                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    DSButton(variant: .ghost, size: .md) {
                                        print("Ghost")
                                    } label: { Text("Ghost") }

                                    DSButton(variant: .outline, size: .md) {
                                        print("Outline")
                                    } label: { Text("Outline") }

                                    DSButton(variant: .link, size: .md) {
                                        print("Link")
                                    } label: { Text("Link") }
                                }

                                // Sizes
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    DSButton(variant: .primary, size: .sm) {
                                        print("Small")
                                    } label: { Text("Small") }

                                    DSButton(variant: .primary, size: .md) {
                                        print("Medium")
                                    } label: { Text("Medium") }

                                    DSButton(variant: .primary, size: .lg) {
                                        print("Large")
                                    } label: { Text("Large") }
                                }

                                // States
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    DSButton(variant: .primary, size: .md) {
                                        print("Normal")
                                    } label: { Text("Normal") }

                                    DSButton(variant: .primary, size: .md, isDisabled: true) {
                                        print("Disabled")
                                    } label: { Text("Disabled") }
                                }
                            }
                        }

                        // DSIconButton
                        ComponentShowcase(
                            name: "DSIconButton",
                            description: "Icon-only button for compact actions"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                DSIconButton(iconName: "gear", variant: .primary) {
                                    print("Settings")
                                }

                                DSIconButton(iconName: "trash", variant: .danger) {
                                    print("Delete")
                                }

                                DSIconButton(iconName: "star.fill", variant: .secondary) {
                                    print("Star")
                                }

                                DSIconButton(iconName: "ellipsis", variant: .ghost) {
                                    print("More")
                                }
                            }
                        }

                        // DSTabButton
                        ComponentShowcase(
                            name: "DSTabButton",
                            description: "Tab switcher button"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                DSTabButton(title: "Files", isSelected: true) {
                                    print("Files")
                                }
                                DSTabButton(title: "Commits", isSelected: false) {
                                    print("Commits")
                                }
                                DSTabButton(title: "Branches", isSelected: false) {
                                    print("Branches")
                                }
                            }
                        }

                        // DSToolbarButton
                        ComponentShowcase(
                            name: "DSToolbarButton",
                            description: "Toolbar button with icon"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                DSToolbarButton(iconName: "arrow.uturn.backward", tooltip: "Undo") {
                                    print("Undo")
                                }
                                DSToolbarButton(iconName: "arrow.uturn.forward", tooltip: "Redo") {
                                    print("Redo")
                                }
                                DSToolbarButton(iconName: "square.and.arrow.up", tooltip: "Share") {
                                    print("Share")
                                }
                            }
                        }

                        // DSCloseButton
                        ComponentShowcase(
                            name: "DSCloseButton",
                            description: "Close/dismiss button"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                DSCloseButton {
                                    print("Close")
                                }
                                DSCloseButton(size: .lg) {
                                    print("Close Large")
                                }
                            }
                        }

                        // DSLinkButton
                        ComponentShowcase(
                            name: "DSLinkButton",
                            description: "Hyperlink-style button"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.sm) {
                                DSLinkButton(title: "View Documentation") {
                                    print("Docs")
                                }
                                DSLinkButton(title: "Learn More", iconName: "arrow.right") {
                                    print("Learn")
                                }
                            }
                        }
                    }
                }

                // MARK: Inputs (6 components)
                CatalogSection(title: "Inputs", description: "6 form input components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSTextField
                        ComponentShowcase(
                            name: "DSTextField",
                            description: "Text input field with states"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                DSTextField(placeholder: "Normal state", text: .constant(""))
                                DSTextField(placeholder: "With text", text: .constant("Sample text"))
                                DSTextField(
                                    placeholder: "Error state",
                                    text: .constant(""),
                                    state: .error,
                                    errorMessage: "This field is required"
                                )
                                DSTextField(placeholder: "Disabled", text: .constant(""), state: .disabled)
                            }
                            .frame(width: 300)
                        }

                        // DSSecureField
                        ComponentShowcase(
                            name: "DSSecureField",
                            description: "Password input field"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                DSSecureField(placeholder: "Enter password", text: .constant(""))
                                DSSecureField(
                                    placeholder: "Confirm password",
                                    text: .constant(""),
                                    state: .error,
                                    errorMessage: "Passwords don't match"
                                )
                            }
                            .frame(width: 300)
                        }

                        // DSTextEditor
                        ComponentShowcase(
                            name: "DSTextEditor",
                            description: "Multi-line text editor"
                        ) {
                            DSTextEditor(
                                placeholder: "Enter description...",
                                text: .constant("Multi-line text editor\nSupports multiple lines\nWith proper styling")
                            )
                            .frame(width: 300, height: 120)
                        }

                        // DSPicker
                        ComponentShowcase(
                            name: "DSPicker",
                            description: "Dropdown picker component"
                        ) {
                            DSPickerExample()
                        }

                        // DSToggle
                        ComponentShowcase(
                            name: "DSToggle",
                            description: "Toggle switch component"
                        ) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                DSToggle("Enable notifications", isOn: .constant(true))
                                DSToggle("Dark mode", isOn: .constant(false))
                                DSToggle("Auto-fetch", isOn: .constant(true))
                            }
                        }

                        // DSSearchField
                        ComponentShowcase(
                            name: "DSSearchField",
                            description: "Search input with icon"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                DSSearchField(placeholder: "Search files...", text: .constant(""))
                                DSSearchField(placeholder: "Search...", text: .constant("component"))
                            }
                            .frame(width: 300)
                        }
                    }
                }

                // MARK: Display (6 components)
                CatalogSection(title: "Display", description: "6 visual display components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSText
                        ComponentShowcase(
                            name: "DSText",
                            description: "Typography component with variants"
                        ) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                DSText("Large Title", variant: .largeTitle)
                                DSText("Title 1", variant: .title1)
                                DSText("Title 2", variant: .title2)
                                DSText("Headline", variant: .headline)
                                DSText("Body text", variant: .body)
                                DSText("Caption text", variant: .caption)
                            }
                        }

                        // DSIcon
                        ComponentShowcase(
                            name: "DSIcon",
                            description: "Icon component with sizes"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                HStack(spacing: DesignTokens.Spacing.lg) {
                                    DSIcon("star.fill", size: .sm, color: .yellow)
                                    DSIcon("star.fill", size: .md, color: .yellow)
                                    DSIcon("star.fill", size: .lg, color: .yellow)
                                    DSIcon("star.fill", size: .xl, color: .yellow)
                                }
                                HStack(spacing: DesignTokens.Spacing.lg) {
                                    DSIcon("checkmark.circle.fill", size: .md, color: AppTheme.success)
                                    DSIcon("xmark.circle.fill", size: .md, color: AppTheme.error)
                                    DSIcon("info.circle.fill", size: .md, color: AppTheme.info)
                                    DSIcon("exclamationmark.triangle.fill", size: .md, color: AppTheme.warning)
                                }
                            }
                        }

                        // DSBadge
                        ComponentShowcase(
                            name: "DSBadge",
                            description: "Badge/tag component with variants"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    DSBadge("Info", variant: .info)
                                    DSBadge("Success", variant: .success)
                                    DSBadge("Warning", variant: .warning)
                                    DSBadge("Error", variant: .error)
                                    DSBadge("Neutral", variant: .neutral)
                                }
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    DSBadge("New", variant: .success, icon: "sparkles")
                                    DSBadge("Beta", variant: .info, icon: "info.circle")
                                    DSBadge("Alert", variant: .warning, icon: "exclamationmark.triangle")
                                    DSBadge("v1.0", variant: .neutral, icon: "tag.fill")
                                }
                            }
                        }

                        // DSAvatar
                        ComponentShowcase(
                            name: "DSAvatar",
                            description: "Avatar component with sizes"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                DSAvatar(initials: "JD", size: .sm)
                                DSAvatar(initials: "JS", size: .md)
                                DSAvatar(initials: "AJ", size: .lg)
                                DSAvatar(initials: "BW", size: .xl)
                            }
                        }

                        // DSDivider
                        ComponentShowcase(
                            name: "DSDivider",
                            description: "Separator line component"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                Text("Content above")
                                DSDivider()
                                Text("Content below")
                                DSDivider(color: AppTheme.accent)
                                Text("With custom color")
                            }
                            .frame(width: 300)
                        }

                        // DSSpacer
                        ComponentShowcase(
                            name: "DSSpacer",
                            description: "Fixed spacing component"
                        ) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Start")
                                DSSpacer(.sm)
                                Text("After SM spacing")
                                DSSpacer(.md)
                                Text("After MD spacing")
                                DSSpacer(.lg)
                                Text("After LG spacing")
                            }
                            .frame(width: 300)
                            .padding(DesignTokens.Spacing.sm)
                            .background(AppTheme.backgroundSecondary)
                            .cornerRadius(DesignTokens.CornerRadius.md)
                        }
                    }
                }

                // MARK: Feedback (4 components)
                CatalogSection(title: "Feedback", description: "4 feedback and loading components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSSpinner
                        ComponentShowcase(
                            name: "DSSpinner",
                            description: "Loading spinner with sizes"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.xl) {
                                DSSpinner(size: .sm)
                                DSSpinner(size: .md)
                                DSSpinner(size: .lg)
                                DSSpinner(size: .xl)
                            }
                        }

                        // DSProgressBar
                        ComponentShowcase(
                            name: "DSProgressBar",
                            description: "Progress indicator bar"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                DSProgressBar(value: 0.3)
                                DSProgressBar(value: 0.6, foregroundColor: AppTheme.success)
                                DSProgressBar(value: 0.9, foregroundColor: AppTheme.warning)
                            }
                            .frame(width: 300)
                        }

                        // DSSkeletonBox
                        ComponentShowcase(
                            name: "DSSkeletonBox",
                            description: "Skeleton loading placeholder"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                DSSkeletonBox(width: 200, height: 20)
                                DSSkeletonBox(width: 150, height: 20)
                                DSSkeletonBox(width: 180, height: 20)
                            }
                        }

                        // DSTooltip
                        ComponentShowcase(
                            name: "DSTooltip",
                            description: "Hover tooltip component"
                        ) {
                            DSTooltip("This is a helpful tooltip") {
                                DSButton(variant: .secondary) {
                                    print("Hover me")
                                } label: {
                                    Text("Hover for tooltip")
                                }
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}

// MARK: - Molecules View (13 Components)

struct MoleculesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                // MARK: Display (5 components)
                CatalogSection(title: "Display", description: "5 display molecule components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSEmptyState
                        ComponentShowcase(
                            name: "DSEmptyState",
                            description: "Empty state with icon, title, and action"
                        ) {
                            DSEmptyState(
                                icon: "tray",
                                title: "No Items",
                                description: "There are no items to display.",
                                actionTitle: "Add Item",
                                action: { print("Add item") }
                            )
                            .frame(height: 250)
                        }

                        // DSLoadingState
                        ComponentShowcase(
                            name: "DSLoadingState",
                            description: "Loading state with spinner and message"
                        ) {
                            DSLoadingState(message: "Loading data...")
                                .frame(height: 150)
                        }

                        // DSErrorState
                        ComponentShowcase(
                            name: "DSErrorState",
                            description: "Error state with retry action"
                        ) {
                            DSErrorState(
                                title: "Connection Failed",
                                message: "Unable to connect to server",
                                onRetry: { print("Retry") }
                            )
                            .frame(height: 200)
                        }

                        // DSStatusBadge
                        ComponentShowcase(
                            name: "DSStatusBadge",
                            description: "Status indicator badge"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                DSStatusBadge("Active", icon: "checkmark.circle.fill", variant: .success)
                                DSStatusBadge("Pending", icon: "clock.fill", variant: .warning)
                                DSStatusBadge("Failed", icon: "xmark.circle.fill", variant: .error)
                                DSStatusBadge("Syncing", icon: "arrow.triangle.2.circlepath", variant: .info)
                            }
                        }

                        // DSHeader
                        ComponentShowcase(
                            name: "DSHeader",
                            description: "Section header with optional action"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                DSHeader(title: "Recent Commits")
                                DSHeader(title: "Branches") {
                                    DSButton(variant: .ghost, size: .sm) {
                                        print("View all")
                                    } label: {
                                        Text("View All")
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: Forms (4 components)
                CatalogSection(title: "Forms", description: "4 form molecule components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSLabeledField
                        ComponentShowcase(
                            name: "DSLabeledField",
                            description: "Text field with label"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                DSLabeledField(
                                    label: "Repository Name",
                                    text: .constant(""),
                                    placeholder: "my-project"
                                )
                                DSLabeledField(
                                    label: "Email Address",
                                    text: .constant(""),
                                    placeholder: "user@example.com",
                                    errorMessage: "We'll never share your email"
                                )
                            }
                            .frame(width: 350)
                        }

                        // DSSearchBar
                        ComponentShowcase(
                            name: "DSSearchBar",
                            description: "Search bar with filters"
                        ) {
                            DSSearchBar(
                                searchText: .constant(""),
                                placeholder: "Search repositories..."
                            )
                            .frame(width: 400)
                        }

                        // DSFilterMenu
                        ComponentShowcase(
                            name: "DSFilterMenu",
                            description: "Filter menu button"
                        ) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                DSFilterMenu(
                                    label: "Status",
                                    selectedFilter: .constant("All"),
                                    options: [
                                        DSFilterOption(label: "All"),
                                        DSFilterOption(label: "Active"),
                                        DSFilterOption(label: "Completed")
                                    ]
                                )
                                DSFilterMenu(
                                    label: "Type",
                                    selectedFilter: .constant("Feature"),
                                    options: [
                                        DSFilterOption(label: "Feature"),
                                        DSFilterOption(label: "Bugfix"),
                                        DSFilterOption(label: "Hotfix")
                                    ]
                                )
                            }
                        }

                        // DSActionBar
                        ComponentShowcase(
                            name: "DSActionBar",
                            description: "Action bar with buttons"
                        ) {
                            Text("Action Bar Example")
                                .frame(height: 50)
                        }
                    }
                }

                // MARK: Lists (4 components)
                CatalogSection(title: "Lists", description: "4 list item molecule components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSListItem
                        ComponentShowcase(
                            name: "DSListItem",
                            description: "Basic list item with icon and text"
                        ) {
                            VStack(spacing: 0) {
                                DSListItem(
                                    title: "README.md",
                                    subtitle: "Updated 2 hours ago",
                                    leading: {
                                        DSIcon("doc.text", size: .md, color: AppTheme.textSecondary)
                                    }
                                )
                                DSListItem(
                                    title: "Sources",
                                    subtitle: "12 files",
                                    leading: {
                                        DSIcon("folder", size: .md, color: AppTheme.textSecondary)
                                    },
                                    trailing: {
                                        DSBadge("New", variant: .success)
                                    }
                                )
                                DSListItem(
                                    title: "ContentView.swift",
                                    subtitle: "Modified",
                                    leading: {
                                        DSIcon("swift", size: .md, color: AppTheme.accent)
                                    }
                                )
                            }
                            .frame(width: 350)
                        }

                        // DSExpandableItem
                        ComponentShowcase(
                            name: "DSExpandableItem",
                            description: "Expandable/collapsible list item"
                        ) {
                            VStack(spacing: 0) {
                                DSExpandableItem(
                                    title: "Components",
                                    isExpanded: true
                                ) {
                                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                        Text("  • Atoms")
                                        Text("  • Molecules")
                                        Text("  • Organisms")
                                    }
                                    .padding(.vertical, DesignTokens.Spacing.sm)
                                }
                                DSExpandableItem(
                                    title: "Features",
                                    isExpanded: false
                                ) {
                                    Text("Content here")
                                }
                            }
                            .frame(width: 350)
                        }

                        // DSDraggableItem
                        ComponentShowcase(
                            name: "DSDraggableItem",
                            description: "Draggable list item"
                        ) {
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                DSDraggableItem(
                                    id: "1",
                                    title: "First Item",
                                    subtitle: "Drag to reorder"
                                ) {
                                    DSIcon("1.circle", size: .sm, color: AppTheme.accent)
                                }
                                DSDraggableItem(
                                    id: "2",
                                    title: "Second Item",
                                    subtitle: "Drag to reorder"
                                ) {
                                    DSIcon("2.circle", size: .sm, color: AppTheme.accent)
                                }
                                DSDraggableItem(
                                    id: "3",
                                    title: "Third Item",
                                    subtitle: "Drag to reorder"
                                ) {
                                    DSIcon("3.circle", size: .sm, color: AppTheme.accent)
                                }
                            }
                            .frame(width: 300)
                        }

                        // DSDropZone
                        ComponentShowcase(
                            name: "DSDropZone",
                            description: "Drop zone for drag and drop"
                        ) {
                            DSDropZone(
                                title: "Drop files here",
                                subtitle: "Drag and drop files to upload",
                                icon: "arrow.down.doc"
                            ) { providers in
                                print("Dropped \(providers.count) items")
                                return true
                            }
                            .frame(width: 350, height: 150)
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}

// MARK: - Organisms View (13 Components)

struct OrganismsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                // MARK: Panels (4 components)
                CatalogSection(title: "Panels", description: "4 panel organism components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSPanel
                        ComponentShowcase(
                            name: "DSPanel",
                            description: "Basic panel container"
                        ) {
                            DSPanel(title: "Settings") {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                    Text("Panel content goes here")
                                    Text("With proper styling")
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(width: 400, height: 150)
                        }

                        // DSResizablePanel
                        ComponentShowcase(
                            name: "DSResizablePanel",
                            description: "Resizable panel with drag handle"
                        ) {
                            ResizablePanelWrapper()
                        }

                        // DSCollapsiblePanel
                        ComponentShowcase(
                            name: "DSCollapsiblePanel",
                            description: "Collapsible panel"
                        ) {
                            DSCollapsiblePanel(
                                title: "Collapsible Section",
                                isExpanded: .constant(true)
                            ) {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    Text("This content can be collapsed")
                                    Text("Click the header to toggle")
                                }
                                .padding()
                            }
                            .frame(width: 400)
                        }

                        // DSTabPanel
                        ComponentShowcase(
                            name: "DSTabPanel",
                            description: "Tabbed panel container"
                        ) {
                            DSTabPanelExample()
                        }
                    }
                }

                // MARK: Lists (4 components)
                CatalogSection(title: "Lists", description: "4 advanced list organism components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSDraggableList
                        ComponentShowcase(
                            name: "DSDraggableList",
                            description: "List with drag-to-reorder"
                        ) {
                            DSDraggableListExample()
                        }

                        // DSInfiniteList
                        ComponentShowcase(
                            name: "DSInfiniteList",
                            description: "Infinite scrolling list"
                        ) {
                            DSInfiniteListExample()
                        }

                        // DSGroupedList
                        ComponentShowcase(
                            name: "DSGroupedList",
                            description: "Grouped/sectioned list"
                        ) {
                            DSGroupedListExample()
                        }

                        // DSVirtualizedList
                        ComponentShowcase(
                            name: "DSVirtualizedList",
                            description: "Virtualized list for performance"
                        ) {
                            DSVirtualizedListExample()
                        }
                    }
                }

                // MARK: Integration (3 components)
                CatalogSection(title: "Integration", description: "3 integration organism components") {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // DSIntegrationPanel
                        ComponentShowcase(
                            name: "DSIntegrationPanel",
                            description: "Third-party integration panel"
                        ) {
                            Text("Integration Panel Example")
                                .frame(width: 400, height: 180)
                        }

                        // DSLoginPrompt
                        ComponentShowcase(
                            name: "DSLoginPrompt",
                            description: "Login/authentication prompt"
                        ) {
                            DSLoginPromptExample()
                        }

                        // DSSettingsSheet
                        ComponentShowcase(
                            name: "DSSettingsSheet",
                            description: "Settings sheet container"
                        ) {
                            DSSettingsSheet(
                                title: "Preferences",
                                onClose: { print("Close settings") }
                            ) {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                                    Text("Settings content goes here")
                                        .font(DesignTokens.Typography.body)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}

// MARK: - Design Tokens View

struct DesignTokensView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                // MARK: Typography
                CatalogSection(title: "Typography", description: "Font scale and semantic styles") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        TokenRow(name: "Large Title", value: "28pt, Bold") {
                            Text("Large Title")
                                .font(DesignTokens.Typography.largeTitle)
                        }
                        TokenRow(name: "Title 1", value: "22pt, Bold") {
                            Text("Title 1")
                                .font(DesignTokens.Typography.title1)
                        }
                        TokenRow(name: "Title 2", value: "20pt") {
                            Text("Title 2")
                                .font(DesignTokens.Typography.title2)
                        }
                        TokenRow(name: "Title 3", value: "17pt") {
                            Text("Title 3")
                                .font(DesignTokens.Typography.title3)
                        }
                        TokenRow(name: "Headline", value: "14pt, Semibold") {
                            Text("Headline")
                                .font(DesignTokens.Typography.headline)
                        }
                        TokenRow(name: "Subheadline", value: "15pt") {
                            Text("Subheadline")
                                .font(DesignTokens.Typography.subheadline)
                        }
                        TokenRow(name: "Body", value: "13pt (base)") {
                            Text("Body")
                                .font(DesignTokens.Typography.body)
                        }
                        TokenRow(name: "Callout", value: "12pt") {
                            Text("Callout")
                                .font(DesignTokens.Typography.callout)
                        }
                        TokenRow(name: "Caption", value: "11pt") {
                            Text("Caption")
                                .font(DesignTokens.Typography.caption)
                        }
                        TokenRow(name: "Caption 2", value: "10pt") {
                            Text("Caption 2")
                                .font(DesignTokens.Typography.caption2)
                        }

                        DSDivider()

                        Text("Git-Specific Typography")
                            .font(DesignTokens.Typography.headline)
                            .padding(.top, DesignTokens.Spacing.sm)

                        TokenRow(name: "Commit Hash", value: "11pt, Monospaced") {
                            Text("a7f3c2d")
                                .font(DesignTokens.Typography.commitHash)
                        }
                        TokenRow(name: "Branch Name", value: "12pt, Medium") {
                            Text("feature/new")
                                .font(DesignTokens.Typography.branchName)
                        }
                        TokenRow(name: "Diff Line", value: "12pt, Monospaced") {
                            Text("+ Added line")
                                .font(DesignTokens.Typography.diffLine)
                        }
                    }
                }

                // MARK: Spacing
                CatalogSection(title: "Spacing", description: "8pt grid system") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        SpacingRow(name: "XXS", value: "2px", spacing: DesignTokens.Spacing.xxs)
                        SpacingRow(name: "XS", value: "4px", spacing: DesignTokens.Spacing.xs)
                        SpacingRow(name: "SM", value: "8px (base)", spacing: DesignTokens.Spacing.sm)
                        SpacingRow(name: "MD", value: "12px", spacing: DesignTokens.Spacing.md)
                        SpacingRow(name: "LG", value: "16px", spacing: DesignTokens.Spacing.lg)
                        SpacingRow(name: "XL", value: "24px", spacing: DesignTokens.Spacing.xl)
                        SpacingRow(name: "XXL", value: "32px", spacing: DesignTokens.Spacing.xxl)
                    }
                }

                // MARK: Corner Radius
                CatalogSection(title: "Corner Radius", description: "Border radius values") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        CornerRadiusRow(name: "None", value: "0px", radius: DesignTokens.CornerRadius.none)
                        CornerRadiusRow(name: "SM", value: "4px", radius: DesignTokens.CornerRadius.sm)
                        CornerRadiusRow(name: "MD", value: "6px", radius: DesignTokens.CornerRadius.md)
                        CornerRadiusRow(name: "LG", value: "8px", radius: DesignTokens.CornerRadius.lg)
                        CornerRadiusRow(name: "XL", value: "12px", radius: DesignTokens.CornerRadius.xl)
                    }
                }

                // MARK: Colors
                CatalogSection(title: "Colors", description: "Theme color palette") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        Text("Primary Colors")
                            .font(DesignTokens.Typography.headline)

                        HStack(spacing: DesignTokens.Spacing.md) {
                            CatalogColorSwatch(name: "Accent", color: AppTheme.accent)
                            CatalogColorSwatch(name: "Success", color: AppTheme.success)
                            CatalogColorSwatch(name: "Warning", color: AppTheme.warning)
                            CatalogColorSwatch(name: "Error", color: AppTheme.error)
                            CatalogColorSwatch(name: "Info", color: AppTheme.info)
                        }

                        Text("Background Colors")
                            .font(DesignTokens.Typography.headline)
                            .padding(.top, DesignTokens.Spacing.sm)

                        HStack(spacing: DesignTokens.Spacing.md) {
                            CatalogColorSwatch(name: "Primary", color: AppTheme.background)
                            CatalogColorSwatch(name: "Secondary", color: AppTheme.backgroundSecondary)
                            CatalogColorSwatch(name: "Tertiary", color: AppTheme.backgroundTertiary)
                        }

                        Text("Text Colors")
                            .font(DesignTokens.Typography.headline)
                            .padding(.top, DesignTokens.Spacing.sm)

                        HStack(spacing: DesignTokens.Spacing.md) {
                            CatalogColorSwatch(name: "Primary", color: AppTheme.textPrimary)
                            CatalogColorSwatch(name: "Secondary", color: AppTheme.textSecondary)
                            CatalogColorSwatch(name: "Muted", color: AppTheme.textMuted)
                        }

                        Text("Git Colors")
                            .font(DesignTokens.Typography.headline)
                            .padding(.top, DesignTokens.Spacing.sm)

                        HStack(spacing: DesignTokens.Spacing.md) {
                            CatalogColorSwatch(name: "Added", color: AppTheme.gitAdded)
                            CatalogColorSwatch(name: "Modified", color: AppTheme.gitModified)
                            CatalogColorSwatch(name: "Deleted", color: AppTheme.gitDeleted)
                            CatalogColorSwatch(name: "Conflict", color: AppTheme.gitConflict)
                        }
                    }
                }

                // MARK: Animation
                CatalogSection(title: "Animation", description: "Standard animation timings") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        TokenRow(name: "Instant", value: "0.1s") {
                            Text("Instant")
                        }
                        TokenRow(name: "Fast", value: "0.2s") {
                            Text("Fast")
                        }
                        TokenRow(name: "Normal", value: "0.3s") {
                            Text("Normal")
                        }
                        TokenRow(name: "Slow", value: "0.5s") {
                            Text("Slow")
                        }
                    }
                }

                // MARK: Sizes
                CatalogSection(title: "Component Sizes", description: "Predefined component dimensions") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        Text("Icons")
                            .font(DesignTokens.Typography.headline)

                        HStack(spacing: DesignTokens.Spacing.xl) {
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: DesignTokens.Size.iconXS))
                                Text("XS: 12px")
                                    .font(DesignTokens.Typography.caption)
                            }
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: DesignTokens.Size.iconSM))
                                Text("SM: 14px")
                                    .font(DesignTokens.Typography.caption)
                            }
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: DesignTokens.Size.iconMD))
                                Text("MD: 16px")
                                    .font(DesignTokens.Typography.caption)
                            }
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: DesignTokens.Size.iconLG))
                                Text("LG: 20px")
                                    .font(DesignTokens.Typography.caption)
                            }
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: DesignTokens.Size.iconXL))
                                Text("XL: 24px")
                                    .font(DesignTokens.Typography.caption)
                            }
                        }

                        Text("Buttons")
                            .font(DesignTokens.Typography.headline)
                            .padding(.top, DesignTokens.Spacing.sm)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Text("SM:")
                                    .frame(width: 50, alignment: .leading)
                                Text("24px height")
                                Rectangle()
                                    .fill(AppTheme.accent.opacity(0.3))
                                    .frame(width: 100, height: DesignTokens.Size.buttonHeightSM)
                            }
                            HStack {
                                Text("MD:")
                                    .frame(width: 50, alignment: .leading)
                                Text("28px height")
                                Rectangle()
                                    .fill(AppTheme.accent.opacity(0.3))
                                    .frame(width: 100, height: DesignTokens.Size.buttonHeightMD)
                            }
                            HStack {
                                Text("LG:")
                                    .frame(width: 50, alignment: .leading)
                                Text("32px height")
                                Rectangle()
                                    .fill(AppTheme.accent.opacity(0.3))
                                    .frame(width: 100, height: DesignTokens.Size.buttonHeightLG)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}

// MARK: - Helper Components

struct CatalogSection<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(AppTheme.textPrimary)

                Text(description)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ComponentShowcase<Content: View>: View {
    let name: String
    let description: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack {
                    Text(name)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    DSBadge("Component", variant: .neutral)
                }

                Text(description)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(AppTheme.textSecondary)
            }

            VStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.lg)
            .background(AppTheme.backgroundSecondary.opacity(0.5))
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .stroke(AppTheme.border.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

struct TokenRow<Content: View>: View {
    let name: String
    let value: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(name)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Text(value)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .frame(width: 150, alignment: .leading)

            Spacer()

            content()
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundSecondary.opacity(0.3))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

struct SpacingRow: View {
    let name: String
    let value: String
    let spacing: CGFloat

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(name)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Text(value)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .frame(width: 150, alignment: .leading)

            Spacer()

            Rectangle()
                .fill(AppTheme.accent)
                .frame(width: spacing, height: 20)

            Text("\(Int(spacing))px")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundSecondary.opacity(0.3))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

struct CornerRadiusRow: View {
    let name: String
    let value: String
    let radius: CGFloat

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(name)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Text(value)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .frame(width: 150, alignment: .leading)

            Spacer()

            RoundedRectangle(cornerRadius: radius)
                .fill(AppTheme.accent.opacity(0.3))
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(AppTheme.accent, lineWidth: 2)
                )
        }
        .padding(DesignTokens.Spacing.sm)
        .background(AppTheme.backgroundSecondary.opacity(0.3))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

struct CatalogColorSwatch: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

            Text(name)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview("Component Catalog") {
    ComponentCatalog()
}

#Preview("Atoms Only") {
    AtomsView()
        .frame(width: 900, height: 700)
}

#Preview("Molecules Only") {
    MoleculesView()
        .frame(width: 900, height: 700)
}

// MARK: - Helper Views for Stateful Components

private struct ResizablePanelWrapper: View {
    @State private var panelHeight: CGFloat = 200

    var body: some View {
        DSResizablePanel(
            title: "Resizable Panel",
            height: $panelHeight,
            minHeight: 150,
            maxHeight: 400
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Drag the top edge to resize")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Height: \(Int(panelHeight))px")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("Min: 150px, Max: 400px")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding()
        }
        .frame(height: panelHeight)
    }
}

private struct PickerOption: Identifiable, Hashable {
    let id: String
    let title: String

    init(_ title: String) {
        self.id = title
        self.title = title
    }
}

private struct DSPickerExample: View {
    @State private var selectedBranch: PickerOption? = PickerOption("main")
    @State private var selectedTheme: PickerOption? = PickerOption("Dark")

    let branches = [PickerOption("main"), PickerOption("develop"), PickerOption("feature/new")]
    let themes = [PickerOption("Light"), PickerOption("Dark"), PickerOption("System")]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Branch")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                DSPicker(items: branches, selection: $selectedBranch) { branch in
                    Text(branch.title)
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Theme")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                DSPicker(items: themes, selection: $selectedTheme) { theme in
                    Text(theme.title)
                }
            }
        }
        .frame(width: 250)
    }
}

private struct DSTabPanelExample: View {
    @State private var selectedTab = "files"

    let tabs = [
        DSTabItem(id: "files", title: "Files", icon: "doc.text"),
        DSTabItem(id: "history", title: "History", icon: "clock"),
        DSTabItem(id: "settings", title: "Settings", icon: "gear")
    ]

    var body: some View {
        DSTabPanel(tabs: tabs, selectedTab: $selectedTab) { tabId in
            VStack(spacing: DesignTokens.Spacing.md) {
                Text("\(tabId.capitalized) Content")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("This is the content for the \(tabId) tab")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .frame(width: 450, height: 200)
    }
}

private struct DraggableItem: Identifiable, Equatable {
    let id: String
    let title: String

    init(_ title: String) {
        self.id = UUID().uuidString
        self.title = title
    }
}

private struct DSDraggableListExample: View {
    @State private var items = [
        DraggableItem("First Item"),
        DraggableItem("Second Item"),
        DraggableItem("Third Item"),
        DraggableItem("Fourth Item")
    ]

    var body: some View {
        DSDraggableList(items: $items) { item in
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(AppTheme.textMuted)
                Text(item.title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .frame(width: 350, height: 200)
    }
}

private struct InfiniteListItem: Identifiable {
    let id: Int
    let title: String
}

private struct DSInfiniteListExample: View {
    @State private var items: [InfiniteListItem] = (1...20).map { InfiniteListItem(id: $0, title: "Item \($0)") }
    @State private var isLoading = false
    @State private var hasMore = true

    var body: some View {
        DSInfiniteList(
            items: items,
            isLoading: isLoading,
            hasMore: hasMore,
            loadMore: {
                guard !isLoading else { return }
                await loadMoreItems()
            }
        ) { item in
            HStack {
                Text(item.title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("#\(item.id)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .frame(width: 350, height: 250)
    }

    private func loadMoreItems() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        let nextId = items.count + 1
        let newItems = (nextId..<nextId+10).map { InfiniteListItem(id: $0, title: "Item \($0)") }
        items.append(contentsOf: newItems)
        if items.count >= 50 {
            hasMore = false
        }
        isLoading = false
    }
}

private struct VirtualizedListItem: Identifiable {
    let id: Int
    let title: String

    init(_ title: String, id: Int) {
        self.title = title
        self.id = id
    }
}

private struct DSVirtualizedListExample: View {
    let items = Array(1...1000).enumerated().map { VirtualizedListItem("Item \($0.element)", id: $0.offset) }

    var body: some View {
        DSVirtualizedList(items: items) { item in
            HStack {
                Text(item.title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("#\(item.id)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .estimatedItemHeight(44)
        .frame(width: 350, height: 300)
    }
}

private struct GroupedListItem: Identifiable {
    let id: String
    let title: String

    init(_ title: String) {
        self.id = UUID().uuidString
        self.title = title
    }
}

@MainActor
private class MockLoginViewModel: IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?

    func authenticate() async throws {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isAuthenticated = true
        isLoading = false
    }

    func refresh() async throws {}
}

private struct DSLoginPromptExample: View {
    @StateObject private var viewModel = MockLoginViewModel()

    var body: some View {
        DSLoginPrompt(viewModel: viewModel)
            .frame(width: 400, height: 200)
    }
}

private struct DSGroupedListExample: View {
    let sections = [
        DSListSection(id: "recent", items: [
            GroupedListItem("File 1"),
            GroupedListItem("File 2")
        ], title: "Recent"),
        DSListSection(id: "today", items: [
            GroupedListItem("File 3"),
            GroupedListItem("File 4"),
            GroupedListItem("File 5")
        ], title: "Today"),
        DSListSection(id: "yesterday", items: [
            GroupedListItem("File 6")
        ], title: "Yesterday")
    ]

    var body: some View {
        DSGroupedList(
            sections: sections,
            header: { section in
                Text(section.title ?? "")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
            },
            content: { item in
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(AppTheme.textMuted)
                    Text(item.title)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
        )
        .frame(width: 350, height: 300)
    }
}

#Preview("Organisms Only") {
    OrganismsView()
        .frame(width: 900, height: 700)
}

#Preview("Design Tokens Only") {
    DesignTokensView()
        .frame(width: 900, height: 700)
}
