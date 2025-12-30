# Xcode-Style Bars Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign bottom bar, right sidebar, and app toolbar to match Xcode's exact visual style using DesignTokens and AppTheme system without losing any existing functionality.

**Architecture:** Refactor existing UnifiedBottomPanel, BottomPanelTabBar, and ContentView toolbar to use Xcode-inspired design patterns: subtle backgrounds with blur effects, compact icon-only buttons with separators, cleaner tab styling, and consistent spacing/typography from DesignTokens.

**Tech Stack:** SwiftUI, DesignTokens, AppTheme, macOS visual effects API

---

## Phase 1: Design Tokens Enhancement

### Task 1: Add Xcode-Style Design Tokens

**Files:**
- Modify: `GitMac/UI/Components/DesignTokens.swift`

**Step 1: Add new color tokens for Xcode-style backgrounds**

```swift
// Add to DesignTokens struct
struct XcodeStyle {
    // Toolbar colors
    static let toolbarBackground = Color.clear // Use system blur
    static let toolbarDivider = Color.gray.opacity(0.15)
    static let toolbarButtonHover = Color.gray.opacity(0.1)

    // Tab bar colors
    static let tabBarBackground = Color(nsColor: .controlBackgroundColor)
    static let tabBarDivider = Color.gray.opacity(0.2)
    static let activeTabIndicator = Color.accentColor
    static let inactiveTabText = Color.secondary

    // Spacing for toolbar
    static let toolbarButtonSpacing: CGFloat = 8
    static let toolbarGroupSpacing: CGFloat = 16
    static let toolbarHeight: CGFloat = 40
    static let tabBarHeight: CGFloat = 28
}
```

**Step 2: Run build to verify syntax**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add GitMac/UI/Components/DesignTokens.swift
git commit -m "feat: add Xcode-style design tokens

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: Bottom Bar Redesign

### Task 2: Create Xcode-Style Tab Button Component

**Files:**
- Create: `GitMac/UI/Components/Atoms/Buttons/DSXcodeTabButton.swift`

**Step 1: Create new Xcode-style tab button component**

```swift
//
//  DSXcodeTabButton.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Xcode-inspired tab button for bottom panel
//

import SwiftUI

struct DSXcodeTabButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let onClose: (() -> Void)?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundColor(textColor)

                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(textColor)

                if let closeAction = onClose, isHovered {
                    Button(action: closeAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        isSelected ? AppTheme.textPrimary : DesignTokens.XcodeStyle.inactiveTabText
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppTheme.backgroundSecondary
        }
        return isHovered ? DesignTokens.XcodeStyle.toolbarButtonHover : Color.clear
    }

    private var borderColor: Color {
        isSelected ? DesignTokens.XcodeStyle.activeTabIndicator : Color.clear
    }
}
```

**Step 2: Run build to verify**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add GitMac/UI/Components/Atoms/Buttons/DSXcodeTabButton.swift
git commit -m "feat: add Xcode-style tab button component

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Redesign BottomPanelTabBar with Xcode Style

**Files:**
- Modify: `GitMac/Features/BottomPanel/Views/BottomPanelTabBar.swift`

**Step 1: Update BottomPanelTabBar to use DSXcodeTabButton**

```swift
// Replace the ScrollView section (lines 23-42) with:
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 2) { // Xcode uses minimal spacing
        ForEach(tabs) { tab in
            DSXcodeTabButton(
                title: tab.displayTitle,
                iconName: tab.type.icon,
                isSelected: tab.id == activeTabId,
                onClose: {
                    onCloseTab(tab.id)
                },
                action: {
                    onSelectTab(tab.id)
                }
            )
        }
    }
    .padding(.horizontal, DesignTokens.Spacing.sm)
    .padding(.vertical, 4)
}
```

**Step 2: Update toolbar styling to match Xcode**

```swift
// Replace .frame(height: 36) and styling (lines 77-83) with:
.frame(height: DesignTokens.XcodeStyle.tabBarHeight)
.background(
    VisualEffectBlur(material: .titlebar, blendingMode: .behindWindow)
)
.overlay(alignment: .top) {
    Rectangle()
        .fill(DesignTokens.XcodeStyle.toolbarDivider)
        .frame(height: 1)
}
```

**Step 3: Add VisualEffectBlur helper at end of file**

```swift
// Add after PanelTypeMenu struct
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
```

**Step 4: Run build to verify**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build`
Expected: BUILD SUCCEEDED

**Step 5: Test bottom panel tabs**

Manual test:
1. Run app
2. Open bottom panel (Terminal, Taiga, etc.)
3. Verify tabs have Xcode-style appearance
4. Hover over tabs - should show close button
5. Click tabs - should switch active tab
6. Close tabs - should remove tab

Expected: All tab functionality works with new styling

**Step 6: Commit**

```bash
git add GitMac/Features/BottomPanel/Views/BottomPanelTabBar.swift
git commit -m "feat: redesign bottom panel tab bar with Xcode style

- Use DSXcodeTabButton for tabs
- Add visual effect blur background
- Update spacing and height to match Xcode

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: Toolbar Redesign

### Task 4: Create Xcode-Style Toolbar Button Component

**Files:**
- Create: `GitMac/UI/Components/Atoms/Buttons/DSXcodeToolbarButton.swift`

**Step 1: Create compact toolbar button component**

```swift
//
//  DSXcodeToolbarButton.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Xcode-inspired compact toolbar button
//

import SwiftUI

struct DSXcodeToolbarButton: View {
    let iconName: String
    let action: () -> Void
    let helpText: String

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered ? DesignTokens.XcodeStyle.toolbarButtonHover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovered = $0 }
    }
}

struct DSXcodeToolbarButtonWithLabel: View {
    let iconName: String
    let label: String
    let color: Color
    let action: () -> Void
    let helpText: String

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(color)
            }
            .frame(width: 44, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? DesignTokens.XcodeStyle.toolbarButtonHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovered = $0 }
    }
}
```

**Step 2: Run build to verify**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add GitMac/UI/Components/Atoms/Buttons/DSXcodeToolbarButton.swift
git commit -m "feat: add Xcode-style toolbar button components

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Redesign Main Toolbar with Xcode Style

**Files:**
- Modify: `GitMac/App/ContentView.swift:295-473`

**Step 1: Replace navigation buttons with DSXcodeToolbarButton**

```swift
// Replace ToolbarItem(placement: .navigation) section (lines 296-316) with:
ToolbarItem(placement: .navigation) {
    HStack(spacing: 0) {
        DSXcodeToolbarButton(
            iconName: "arrow.uturn.backward",
            action: {},
            helpText: "Undo"
        )

        DSXcodeToolbarButton(
            iconName: "arrow.uturn.forward",
            action: {},
            helpText: "Redo"
        )
    }
}
```

**Step 2: Replace principal buttons with compact labeled buttons**

```swift
// Replace ToolbarItemGroup(placement: .principal) section (lines 318-402) with:
ToolbarItemGroup(placement: .principal) {
    DSXcodeToolbarButtonWithLabel(
        iconName: "arrow.down.circle",
        label: "Fetch",
        color: AppTheme.info,
        action: { NotificationCenter.default.post(name: .fetch, object: nil) },
        helpText: "Fetch"
    )

    DSXcodeToolbarButtonWithLabel(
        iconName: "arrow.down.circle.fill",
        label: "Pull",
        color: AppTheme.success,
        action: { NotificationCenter.default.post(name: .pull, object: nil) },
        helpText: "Pull"
    )

    DSXcodeToolbarButtonWithLabel(
        iconName: "arrow.up.circle.fill",
        label: "Push",
        color: AppTheme.accent,
        action: { NotificationCenter.default.post(name: .push, object: nil) },
        helpText: "Push"
    )

    Divider()
        .frame(height: 20)
        .padding(.horizontal, 4)

    DSXcodeToolbarButtonWithLabel(
        iconName: "arrow.triangle.branch",
        label: "Branch",
        color: AppTheme.accent,
        action: { NotificationCenter.default.post(name: .newBranch, object: nil) },
        helpText: "Branch"
    )

    DSXcodeToolbarButtonWithLabel(
        iconName: "archivebox",
        label: "Stash",
        color: AppTheme.warning,
        action: { NotificationCenter.default.post(name: .stash, object: nil) },
        helpText: "Stash"
    )

    DSXcodeToolbarButtonWithLabel(
        iconName: "archivebox.fill",
        label: "Pop",
        color: AppTheme.warning,
        action: { NotificationCenter.default.post(name: .popStash, object: nil) },
        helpText: "Pop"
    )
}
```

**Step 3: Replace automatic buttons with compact icon-only buttons**

```swift
// Replace ToolbarItemGroup(placement: .automatic) section (lines 404-470) with:
ToolbarItemGroup(placement: .automatic) {
    Divider()
        .frame(height: 20)
        .padding(.horizontal, 4)

    DSXcodeToolbarButton(
        iconName: "terminal.fill",
        action: { bottomPanelManager.openTab(type: .terminal) },
        helpText: "Terminal"
    )

    DSXcodeToolbarButton(
        iconName: "tag.fill",
        action: { bottomPanelManager.openTab(type: .taiga) },
        helpText: "Taiga"
    )

    DSXcodeToolbarButton(
        iconName: "checklist",
        action: { bottomPanelManager.openTab(type: .planner) },
        helpText: "Planner"
    )

    DSXcodeToolbarButton(
        iconName: "lineweight",
        action: { bottomPanelManager.openTab(type: .linear) },
        helpText: "Linear"
    )

    DSXcodeToolbarButton(
        iconName: "square.stack.3d.up",
        action: { bottomPanelManager.openTab(type: .jira) },
        helpText: "Jira"
    )

    DSXcodeToolbarButton(
        iconName: "doc.text.fill",
        action: { bottomPanelManager.openTab(type: .notion) },
        helpText: "Notion"
    )

    DSXcodeToolbarButton(
        iconName: "person.3",
        action: { bottomPanelManager.openTab(type: .teamActivity) },
        helpText: "Team Activity"
    )

    Divider()
        .frame(height: 20)
        .padding(.horizontal, 4)

    DSTextField(placeholder: "Search commits...", text: $searchText)
        .frame(minWidth: 150, maxWidth: 200)
}
```

**Step 4: Update toolbar background styling**

```swift
// Replace lines 472-473 with:
.toolbarBackground(.hidden, for: .windowToolbar)
.background(
    VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
        .ignoresSafeArea()
)
```

**Step 5: Add VisualEffectBlur to ContentView if not already present**

```swift
// Add at end of ContentView.swift file
extension ContentView {
    struct VisualEffectBlur: NSViewRepresentable {
        let material: NSVisualEffectView.Material
        let blendingMode: NSVisualEffectView.BlendingMode

        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
        }
    }
}
```

**Step 6: Run build to verify**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build`
Expected: BUILD SUCCEEDED

**Step 7: Test all toolbar buttons**

Manual test:
1. Run app
2. Test each toolbar button (Undo, Redo, Fetch, Pull, Push, Branch, Stash, Pop)
3. Test panel buttons (Terminal, Taiga, Planner, Linear, Jira, Notion, Team Activity)
4. Hover over buttons - should show subtle highlight
5. Verify search field still works

Expected: All buttons functional, new styling applied

**Step 8: Commit**

```bash
git add GitMac/App/ContentView.swift
git commit -m "feat: redesign main toolbar with Xcode style

- Use DSXcodeToolbarButton components
- Add visual effect blur background
- Add dividers between button groups
- Reduce button sizes for compact look

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4: Right Sidebar Enhancement (Optional)

### Task 6: Add Xcode-Style Right Sidebar

**Note:** This task is optional if right sidebar doesn't currently exist or needs enhancement.

**Files:**
- Check if exists: Search for right sidebar implementation
- Create if needed: `GitMac/Features/RightSidebar/XcodeStyleSidebar.swift`

**Step 1: Search for existing right sidebar**

Run: `grep -r "rightPanel\|rightSidebar" GitMac/ --include="*.swift"`
Expected: Find existing implementation or none

**Step 2: If sidebar exists, update styling to match Xcode**

Apply same principles:
- Use VisualEffectBlur for background
- Use DSXcodeTabButton for any tabs
- Match spacing and colors from DesignTokens.XcodeStyle

**Step 3: If sidebar doesn't exist, skip this task**

Document: "Right sidebar not found, skipping Task 6"

**Step 4: Commit if changes made**

```bash
git add [modified files]
git commit -m "feat: enhance right sidebar with Xcode style

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 5: Polish and Testing

### Task 7: Update UnifiedBottomPanel Background

**Files:**
- Modify: `GitMac/Features/BottomPanel/Views/UnifiedBottomPanel.swift:49`

**Step 1: Replace background with visual effect blur**

```swift
// Replace line 49:
.background(AppTheme.panel)

// With:
.background(
    VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
)
```

**Step 2: Add VisualEffectBlur to file if not already present**

```swift
// Add at end of file
extension UnifiedBottomPanel {
    struct VisualEffectBlur: NSViewRepresentable {
        let material: NSVisualEffectView.Material
        let blendingMode: NSVisualEffectView.BlendingMode

        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
        }
    }
}
```

**Step 3: Run build to verify**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add GitMac/Features/BottomPanel/Views/UnifiedBottomPanel.swift
git commit -m "feat: add visual effect blur to bottom panel background

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Final Testing and Verification

**Step 1: Build and run full app**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build && open build/Release/GitMac.app`
Expected: App launches successfully

**Step 2: Manual UI testing checklist**

Test each component:
- [ ] Bottom panel tabs appear with Xcode styling
- [ ] Bottom panel tab hover effects work
- [ ] Bottom panel tab close buttons appear on hover
- [ ] Bottom panel tab switching works
- [ ] Bottom panel background has blur effect
- [ ] Toolbar buttons appear compact and Xcode-like
- [ ] Toolbar button hover effects work
- [ ] All toolbar buttons are functional (Fetch, Pull, Push, etc.)
- [ ] Panel buttons work (Terminal, Taiga, etc.)
- [ ] Search field works in toolbar
- [ ] Toolbar has blur background effect
- [ ] Dividers appear between button groups
- [ ] No functionality lost from original design

**Step 3: Take screenshots for documentation**

Capture:
1. Full app with new styling
2. Bottom panel close-up
3. Toolbar close-up
4. Hover states

**Step 4: Document any issues found**

Create: `docs/XCODE_STYLE_ISSUES.md` if needed

**Step 5: Final commit**

```bash
git add -A
git commit -m "docs: add screenshots and testing notes for Xcode-style redesign

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary

**Total Tasks:** 8 tasks across 5 phases
**Estimated Time:** 60-90 minutes
**Key Files Modified:**
- DesignTokens.swift (new tokens)
- BottomPanelTabBar.swift (redesigned)
- UnifiedBottomPanel.swift (blur background)
- ContentView.swift (toolbar redesign)

**New Components Created:**
- DSXcodeTabButton.swift
- DSXcodeToolbarButton.swift

**Testing:** Manual UI testing of all components + build verification after each task

---
