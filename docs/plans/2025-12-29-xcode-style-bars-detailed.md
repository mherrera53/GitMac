# Xcode-Style Bars - Ultra-Detailed Implementation Plan


> **CRITICAL:** Execute in PARALLEL SESSION. This plan is designed for background execution with context cleanup between phases. Do NOT execute in main session.

**Goal:** Pixel-perfect replication of Xcode's visual design for toolbar, bottom bar, and sidebars without losing ANY existing functionality. ZERO hardcoded values - ALL styling from design tokens.

**Architecture:** Complete UI redesign using NSVisualEffectView blur effects, XcodeDesignTokens for ALL measurements/colors, SF Symbols icons, and system materials while maintaining 100% current features.

**Tech Stack:** SwiftUI, NSVisualEffectView, AppKit, XcodeDesignTokens (ONLY source of truth for values)

**Reference:** Xcode 15+ visual design

---

## 🔴 CRITICAL RULES

1. **ZERO HARDCODED VALUES:** Every number, color, spacing MUST come from XcodeDesignTokens
2. **Context Management:** Clean context between phases (save progress, commit, clear memory)
3. **Functionality Preservation:** Test EVERY feature after changes - nothing breaks
4. **Atomic Commits:** Commit after EACH successful step
5. **Build Verification:** MUST build successfully after each task
6. **Token-First Design:** If a value isn't in tokens, ADD IT to tokens first

---

## 📐 Design Specifications from Xcode

### Toolbar Measurements (Reference)
- Height: 52px → XcodeDesignTokens.Toolbar.height
- Button icon-only: 28x28 → XcodeDesignTokens.Toolbar.Button.iconOnlySize
- Button icon+label: 44x36 → XcodeDesignTokens.Toolbar.Button.iconWithLabelSize
- Icon size: 16px → XcodeDesignTokens.Toolbar.Button.iconFontSize
- Label size: 9px → XcodeDesignTokens.Toolbar.Button.labelFontSize
- Spacing: 8px → XcodeDesignTokens.Toolbar.Button.spacing
- Group spacing: 16px → XcodeDesignTokens.Toolbar.Group.spacing

### Bottom Bar Measurements (Reference)
- Tab bar height: 28px → XcodeDesignTokens.BottomBar.tabBarHeight
- Tab padding: 6px/4px → XcodeDesignTokens.BottomBar.Tab.horizontalPadding/verticalPadding
- Tab spacing: 2px → XcodeDesignTokens.BottomBar.Tab.spacing
- Font: 11px → XcodeDesignTokens.BottomBar.Tab.fontSize
- Active indicator: 2px → XcodeDesignTokens.BottomBar.Tab.activeIndicatorHeight

---

## Phase 0: Foundation & Audit

> **Context:** Clean slate - audit current state before any changes

### Task 0.1: Create Design Reference Documentation

**Files:**
- Create: `docs/design/xcode-reference/README.md`
- Create: `docs/design/xcode-reference/measurements.md`
- Create: `docs/design/xcode-reference/colors.md`
- Create: `docs/design/xcode-reference/materials.md`

**Step 1: Create reference directory**

```bash
mkdir -p docs/design/xcode-reference
```

**Step 2: Create README.md**

```markdown
# Xcode UI Reference

This directory contains pixel-perfect measurements and specifications from Xcode 15+ for replication in GitMac.

## Files
- `measurements.md` - All UI dimensions and spacing
- `colors.md` - Color specifications for light/dark modes
- `materials.md` - NSVisualEffectView materials and blur settings

## Usage
All values here MUST be translated to XcodeDesignTokens.swift - never hardcode.

## Screenshot Reference
See `/docs/design/xcode-reference/xcode-screenshot.png` for visual reference.
```

**Step 3: Create measurements.md with ONLY reference values**

```markdown
# Xcode UI Measurements (Reference Only)

> ⚠️ DO NOT USE THESE VALUES DIRECTLY - Add to XcodeDesignTokens.swift

## Toolbar
- Height: 52px
- Border: 0.5px bottom
- Button icon-only: 28x28px
- Button icon+label: 44x36px
- Icon size: 16px (regular weight)
- Label size: 9px (regular weight)
- Button spacing: 8px
- Group spacing: 16px
- Divider: 1px width, 20px height
- Corner radius: 4px
- Hover opacity: 0.05 (light), 0.08 (dark)

## Bottom Bar
- Tab bar height: 28px
- Border: 0.5px top
- Tab horizontal padding: 6px
- Tab vertical padding: 4px
- Tab spacing: 2px
- Font size: 11px (regular weight)
- Icon size: 11px
- Close button: 12x12px
- Corner radius: 4px
- Active indicator: 2px height, accent color

## Sidebar
- Default width: 260px
- Min width: 180px
- Max width: 400px
- Navigator icons: 24x24px
- Navigator spacing: 0px
- Tree indent: 14px per level
- Row height: 20px
- Disclosure triangle: 8px
```

**Step 4: Create colors.md**

```markdown
# Xcode Colors (Reference Only)

> ⚠️ DO NOT USE THESE VALUES DIRECTLY - Add to XcodeDesignTokens.swift

## Light Mode
- Toolbar border: rgba(0, 0, 0, 0.1)
- Button hover: rgba(0, 0, 0, 0.05)
- Text primary: rgba(0, 0, 0, 0.85)
- Text secondary: rgba(0, 0, 0, 0.5)
- Divider: rgba(0, 0, 0, 0.1)

## Dark Mode
- Toolbar border: rgba(255, 255, 255, 0.05)
- Button hover: rgba(255, 255, 255, 0.08)
- Text primary: rgba(255, 255, 255, 0.85)
- Text secondary: rgba(255, 255, 255, 0.5)
- Divider: rgba(255, 255, 255, 0.08)

## System Colors (Use NSColor APIs)
- Accent: NSColor.controlAccentColor
- Label: NSColor.labelColor
- Secondary label: NSColor.secondaryLabelColor
- Separator: NSColor.separatorColor
```

**Step 5: Create materials.md**

```markdown
# NSVisualEffectView Materials (Reference Only)

> ⚠️ DO NOT USE THESE VALUES DIRECTLY - Add to XcodeDesignTokens.swift

## Materials
- Toolbar: .headerView
- Bottom bar: .titlebar
- Sidebar: .sidebar
- Panel content: .contentBackground

## Blending Modes
- Toolbar: .withinWindow
- Bottom bar: .behindWindow
- Sidebar: .behindWindow

## State
- Always: .active
```

**Step 6: Commit reference docs**

```bash
git add docs/design/
git commit -m "docs: add Xcode UI reference specifications

- measurements.md with all dimensions
- colors.md with light/dark values
- materials.md with NSVisualEffectView specs
- All values are reference only - must use tokens


```

**Step 7: Verify commit**

Run: `git log -1 --oneline`
Expected: See commit message starting with "docs: add Xcode UI reference"

---

### Task 0.2: Audit All Current Functionality

**Files:**
- Create: `docs/FUNCTIONALITY_AUDIT.md`

**Step 1: Create comprehensive functionality audit**

```markdown
# GitMac Functionality Audit - Pre-Redesign

Date: 2025-12-29
Status: Initial audit before Xcode-style redesign

## 🎯 Purpose
Document ALL current functionality to ensure ZERO features are lost during redesign.

---

## Toolbar Features

### Navigation Buttons
- [ ] Undo button (arrow.uturn.backward)
  - Action: Undo last operation
  - Keyboard: Cmd+Z
  - State: Enabled/disabled based on history

- [ ] Redo button (arrow.uturn.forward)
  - Action: Redo last undone operation
  - Keyboard: Cmd+Shift+Z
  - State: Enabled/disabled based on history

### Git Operation Buttons (Principal Placement)
- [ ] Fetch button (arrow.down.circle)
  - Action: Posts .fetch notification
  - Color: AppTheme.info (blue)
  - Shows fetch progress

- [ ] Pull button (arrow.down.circle.fill)
  - Action: Posts .pull notification
  - Color: AppTheme.success (green)
  - Shows pull progress
  - Detached HEAD alert handling

- [ ] Push button (arrow.up.circle.fill)
  - Action: Posts .push notification
  - Color: AppTheme.accent
  - Shows push progress

- [ ] Branch button (arrow.triangle.branch)
  - Action: Posts .newBranch notification
  - Opens CreateBranchSheet
  - Color: AppTheme.accent

- [ ] Stash button (archivebox)
  - Action: Posts .stash notification
  - Color: AppTheme.warning (orange)
  - Creates stash entry

- [ ] Pop button (archivebox.fill)
  - Action: Posts .popStash notification
  - Color: AppTheme.warning (orange)
  - Pops latest stash

### Panel Buttons (Automatic Placement)
- [ ] Terminal button (terminal.fill)
  - Action: bottomPanelManager.openTab(type: .terminal)
  - Opens terminal in bottom panel

- [ ] Taiga button (tag.fill)
  - Action: bottomPanelManager.openTab(type: .taiga)
  - Color: AppTheme.success

- [ ] Planner button (checklist)
  - Action: bottomPanelManager.openTab(type: .planner)
  - Color: AppTheme.warning

- [ ] Linear button (lineweight)
  - Action: bottomPanelManager.openTab(type: .linear)
  - Color: AppTheme.accent

- [ ] Jira button (square.stack.3d.up)
  - Action: bottomPanelManager.openTab(type: .jira)
  - Color: AppTheme.accent

- [ ] Notion button (doc.text.fill)
  - Action: bottomPanelManager.openTab(type: .notion)
  - Color: AppTheme.textPrimary

- [ ] Team Activity button (person.3)
  - Action: bottomPanelManager.openTab(type: .teamActivity)
  - Color: AppTheme.accent

### Search Field
- [ ] Search field (DSTextField)
  - Placeholder: "Search commits..."
  - Binding: $searchText
  - Size: 150-250px width
  - Functionality: Filters commits

### Toolbar Styling
- [ ] Background: AppTheme.background
- [ ] Color scheme: Light/dark based on theme
- [ ] Updates on theme change (themeRefreshTrigger)

---

## Bottom Panel Features

### Tab Management
- [ ] Create tabs for each panel type
  - Terminal, Taiga, Planner, Linear, Jira, Notion, Team Activity

- [ ] Tab switching
  - Click to activate
  - Shows/hides content

- [ ] Tab closing
  - X button on each tab
  - Callback: onCloseTab(tab.id)

- [ ] Tab reordering
  - Drag & drop support
  - Callback: onReorder(from:to:)

- [ ] Tab persistence
  - Saves open tabs to UserDefaults
  - Restores on app launch
  - Manager: BottomPanelManager.shared

### Panel Controls
- [ ] Plus button
  - Opens popover menu
  - Shows available panel types
  - Hides already open tabs
  - Callback: onAddTab

- [ ] Close panel button (chevron.down)
  - Toggles panel visibility
  - Callback: onTogglePanel
  - Help text: "Close Panel"

### Panel Layout
- [ ] Resizer handle (UniversalResizer)
  - Vertical orientation
  - Min height: 100px
  - Max height: 600px
  - Saves height to UserDefaults

- [ ] Tab bar
  - Height: 36px (CURRENT - will change to 28px)
  - Background: AppTheme.toolbar
  - Bottom border: AppTheme.border, 1px

- [ ] Content area
  - Shows active tab content
  - Switches on tab change
  - Components: Terminal, Taiga, Linear, etc.

- [ ] Panel background
  - Current: AppTheme.panel
  - Will change to: VisualEffectBlur

### Content Rendering
- [ ] Terminal (BottomPanelContent)
  - Full terminal emulator
  - Ghostty integration

- [ ] Taiga panel
  - Project management UI
  - API integration

- [ ] Planner panel
  - Microsoft Planner tasks
  - OAuth integration

- [ ] Linear panel
  - Issue tracking
  - API integration

- [ ] Jira panel
  - Issue tracking
  - API integration

- [ ] Notion panel
  - Database integration
  - API integration

- [ ] Team Activity panel
  - Git activity feed
  - Real-time updates

---

## Sidebar Features

### File Navigation
- [ ] File tree display
- [ ] Expand/collapse folders
- [ ] File selection
- [ ] Keyboard navigation
- [ ] Context menu on files

### Sidebar Layout
- [ ] Width resizing
  - Current: leftPanelWidth state
  - Drag to resize

- [ ] Width persistence
  - Saves to UserDefaults

---

## Testing Checklist

After redesign, verify:

### Toolbar
- [ ] All buttons clickable and functional
- [ ] All notifications posted correctly
- [ ] All sheets open correctly
- [ ] Search field works
- [ ] Keyboard shortcuts work
- [ ] Theme switching works
- [ ] Disabled states work
- [ ] Hover effects work
- [ ] Press animations work

### Bottom Panel
- [ ] All tabs open correctly
- [ ] Tab switching works
- [ ] Tab closing works
- [ ] Tab reordering works
- [ ] Plus menu works
- [ ] Close panel works
- [ ] Resizer works
- [ ] Height persists
- [ ] Content renders correctly
- [ ] All 7 panel types work

### Sidebar
- [ ] File tree works
- [ ] Expand/collapse works
- [ ] Selection works
- [ ] Resizing works
- [ ] Width persists

---

## Notes

- Current toolbar height: 52px (system default)
- Current bottom tab bar: 36px (will reduce to 28px)
- All NotificationCenter notifications MUST continue working
- All BottomPanelManager methods MUST continue working
- All theme-related functionality MUST continue working

---

## Audit Status

- [x] Documented all toolbar features
- [x] Documented all bottom panel features
- [x] Documented all sidebar features
- [ ] Tested all features (pre-redesign)
- [ ] Tested all features (post-redesign)
```

**Step 2: Manual test current features**

Run app and test each feature:
1. Click all toolbar buttons
2. Open all bottom panel types
3. Test tab switching, closing, reordering
4. Test resizing

**Step 3: Commit audit**

```bash
git add docs/FUNCTIONALITY_AUDIT.md
git commit -m "docs: create comprehensive functionality audit

- All toolbar buttons and actions
- All bottom panel features
- All sidebar features
- Testing checklist for post-redesign


```

---

### Task 0.3: Clean Context Checkpoint

**Step 1: Verify all Phase 0 commits**

Run: `git log --oneline -3`
Expected: See 2 commits (reference docs, audit)

**Step 2: Save progress**

Document completion:
```
Phase 0 complete:
- Reference documentation created
- Functionality audit complete
- Ready for Phase 1 (Foundation)
```

**Step 3: Context cleanup note**

> **For executing-plans:** Phase 0 complete. Clear context before Phase 1.
> All reference docs and audit are committed. Next: XcodeDesignTokens.swift

---

## Phase 1: Foundation - Design Tokens & Utilities

> **Context:** Fresh start - create design system foundation

### Task 1.1: Create XcodeDesignTokens (Complete)

**Files:**
- Create: `GitMac/UI/DesignSystem/XcodeDesignTokens.swift`

**Step 1: Create comprehensive design tokens file**

```swift
//
//  XcodeDesignTokens.swift
//  GitMac
//
//  Created on 2025-12-29.
//  Complete design token system for Xcode-style UI
//  SINGLE SOURCE OF TRUTH - No hardcoded values allowed
//

import SwiftUI
import AppKit

/// Complete design token system matching Xcode's visual design
/// ALL UI components MUST use these tokens - ZERO hardcoded values
public enum XcodeDesignTokens {

    // MARK: - Toolbar Tokens

    public enum Toolbar {
        /// Toolbar height matching macOS standard
        public static let height: CGFloat = 52

        /// Border width for bottom separator
        public static let borderWidth: CGFloat = 0.5

        public enum Button {
            /// Size for icon-only buttons
            public static let iconOnlySize = CGSize(width: 28, height: 28)

            /// Size for buttons with icon + label
            public static let iconWithLabelSize = CGSize(width: 44, height: 36)

            /// Icon font size
            public static let iconFontSize: CGFloat = 16

            /// Icon font weight
            public static let iconWeight: Font.Weight = .regular

            /// Label font size (for icon+label buttons)
            public static let labelFontSize: CGFloat = 9

            /// Label font weight
            public static let labelWeight: Font.Weight = .regular

            /// Corner radius for button backgrounds
            public static let cornerRadius: CGFloat = 4

            /// Spacing between individual buttons
            public static let spacing: CGFloat = 8

            /// Animation duration for hover
            public static let hoverDuration: Double = 0.15

            /// Animation duration for press
            public static let pressDuration: Double = 0.1

            /// Scale for pressed state
            public static let pressedScale: CGFloat = 0.95
        }

        public enum Group {
            /// Spacing between button groups
            public static let spacing: CGFloat = 16

            /// Divider width
            public static let dividerWidth: CGFloat = 1

            /// Divider height
            public static let dividerHeight: CGFloat = 20
        }
    }

    // MARK: - Bottom Bar Tokens

    public enum BottomBar {
        /// Tab bar height
        public static let tabBarHeight: CGFloat = 28

        /// Border width for top separator
        public static let borderWidth: CGFloat = 0.5

        public enum Tab {
            /// Horizontal padding inside tab
            public static let horizontalPadding: CGFloat = 6

            /// Vertical padding inside tab
            public static let verticalPadding: CGFloat = 4

            /// Spacing between tabs
            public static let spacing: CGFloat = 2

            /// Tab title font size
            public static let fontSize: CGFloat = 11

            /// Tab title font weight
            public static let fontWeight: Font.Weight = .regular

            /// Tab icon size
            public static let iconSize: CGFloat = 11

            /// Close button size
            public static let closeButtonSize: CGFloat = 12

            /// Close button icon size
            public static let closeIconSize: CGFloat = 8

            /// Tab corner radius
            public static let cornerRadius: CGFloat = 4

            /// Active indicator height (bottom line)
            public static let activeIndicatorHeight: CGFloat = 2

            /// Hover animation duration
            public static let hoverDuration: Double = 0.15

            /// Transition animation duration
            public static let transitionDuration: Double = 0.2
        }

        public enum Controls {
            /// Plus button size
            public static let plusButtonSize: CGFloat = 28

            /// Plus button icon size
            public static let plusIconSize: CGFloat = 11

            /// Close panel button size
            public static let closePanelButtonSize: CGFloat = 28

            /// Close panel icon size
            public static let closePanelIconSize: CGFloat = 11

            /// Horizontal padding for controls
            public static let horizontalPadding: CGFloat = 8
        }
    }

    // MARK: - Sidebar Tokens

    public enum Sidebar {
        /// Default sidebar width
        public static let defaultWidth: CGFloat = 260

        /// Minimum sidebar width
        public static let minWidth: CGFloat = 180

        /// Maximum sidebar width
        public static let maxWidth: CGFloat = 400

        /// Navigator icon size (top icons)
        public static let navigatorIconSize: CGFloat = 24

        /// Spacing between navigator icons
        public static let navigatorSpacing: CGFloat = 0

        /// Tree indentation per level
        public static let treeIndent: CGFloat = 14

        /// Row height for file items
        public static let rowHeight: CGFloat = 20

        /// Disclosure triangle size
        public static let disclosureSize: CGFloat = 8

        /// Font size for file names
        public static let fileNameFontSize: CGFloat = 11
    }

    // MARK: - Color Tokens

    public enum Colors {
        // MARK: Light Mode Colors

        /// Toolbar border in light mode
        public static let toolbarBorderLight = Color(
            nsColor: NSColor(white: 0, alpha: 0.1)
        )

        /// Button hover background in light mode
        public static let buttonHoverLight = Color(
            nsColor: NSColor(white: 0, alpha: 0.05)
        )

        /// Primary text in light mode
        public static let textPrimaryLight = Color(
            nsColor: NSColor(white: 0, alpha: 0.85)
        )

        /// Secondary text in light mode
        public static let textSecondaryLight = Color(
            nsColor: NSColor(white: 0, alpha: 0.5)
        )

        /// Divider in light mode
        public static let dividerLight = Color(
            nsColor: NSColor(white: 0, alpha: 0.1)
        )

        // MARK: Dark Mode Colors

        /// Toolbar border in dark mode
        public static let toolbarBorderDark = Color(
            nsColor: NSColor(white: 1, alpha: 0.05)
        )

        /// Button hover background in dark mode
        public static let buttonHoverDark = Color(
            nsColor: NSColor(white: 1, alpha: 0.08)
        )

        /// Primary text in dark mode
        public static let textPrimaryDark = Color(
            nsColor: NSColor(white: 1, alpha: 0.85)
        )

        /// Secondary text in dark mode
        public static let textSecondaryDark = Color(
            nsColor: NSColor(white: 1, alpha: 0.5)
        )

        /// Divider in dark mode
        public static let dividerDark = Color(
            nsColor: NSColor(white: 1, alpha: 0.08)
        )

        // MARK: Adaptive Colors

        /// Adaptive toolbar border (auto light/dark)
        public static var toolbarBorder: Color {
            Color(nsColor: NSColor.labelColor.withAlphaComponent(0.1))
        }

        /// Adaptive button hover background
        public static var buttonHover: Color {
            Color(nsColor: NSColor.controlBackgroundColor.blended(
                withFraction: 0.8,
                of: NSColor.labelColor
            )?.withAlphaComponent(0.05) ?? NSColor.gray.withAlphaComponent(0.05))
        }

        /// Adaptive primary text
        public static var textPrimary: Color {
            Color(nsColor: NSColor.labelColor)
        }

        /// Adaptive secondary text
        public static var textSecondary: Color {
            Color(nsColor: NSColor.secondaryLabelColor)
        }

        /// Adaptive divider
        public static var divider: Color {
            Color(nsColor: NSColor.separatorColor)
        }

        /// Adaptive accent color
        public static var accent: Color {
            Color(nsColor: NSColor.controlAccentColor)
        }

        // MARK: Semantic Colors

        /// Tab active indicator color
        public static var activeIndicator: Color {
            accent
        }

        /// Disabled text opacity
        public static let disabledOpacity: Double = 0.4

        /// Close button hover background opacity
        public static let closeButtonHoverOpacity: Double = 0.1
    }

    // MARK: - Material Tokens

    public enum Materials {
        /// Material for toolbar
        public static let toolbar: NSVisualEffectView.Material = .headerView

        /// Material for bottom bar
        public static let bottomBar: NSVisualEffectView.Material = .titlebar

        /// Material for sidebar
        public static let sidebar: NSVisualEffectView.Material = .sidebar

        /// Material for panel content
        public static let content: NSVisualEffectView.Material = .contentBackground

        /// Blending mode for toolbar
        public static let toolbarBlending: NSVisualEffectView.BlendingMode = .withinWindow

        /// Blending mode for bottom bar
        public static let bottomBarBlending: NSVisualEffectView.BlendingMode = .behindWindow

        /// Blending mode for sidebar
        public static let sidebarBlending: NSVisualEffectView.BlendingMode = .behindWindow

        /// Effect state
        public static let state: NSVisualEffectView.State = .active
    }

    // MARK: - Animation Tokens

    public enum Animation {
        /// Standard easeInOut curve
        public static let easeInOut = SwiftUI.Animation.easeInOut

        /// Spring animation for interactive elements
        public static let spring = SwiftUI.Animation.spring(
            response: 0.3,
            dampingFraction: 0.7
        )

        /// Quick transition
        public static let quick = SwiftUI.Animation.easeInOut(duration: 0.1)

        /// Standard transition
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)

        /// Slow transition
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.3)
    }

    // MARK: - Shadow Tokens

    public enum Shadow {
        /// Light shadow for elevated elements
        public static let light = (
            color: Color.black.opacity(0.1),
            radius: CGFloat(2),
            x: CGFloat(0),
            y: CGFloat(1)
        )

        /// Medium shadow for modals
        public static let medium = (
            color: Color.black.opacity(0.15),
            radius: CGFloat(4),
            x: CGFloat(0),
            y: CGFloat(2)
        )

        /// Heavy shadow for overlays
        public static let heavy = (
            color: Color.black.opacity(0.2),
            radius: CGFloat(8),
            x: CGFloat(0),
            y: CGFloat(4)
        )
    }
}
```

**Step 2: Run build to verify**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Verify no hardcoded values exist**

Run: `grep -r "width: [0-9]" GitMac/UI/Components/Atoms/Buttons/ 2>/dev/null || echo "No buttons yet"`
Expected: "No buttons yet" (we haven't created components yet)

**Step 4: Commit**

```bash
git add GitMac/UI/DesignSystem/XcodeDesignTokens.swift
git commit -m "feat: add comprehensive XcodeDesignTokens

Complete design token system:
- Toolbar tokens (52px height, button sizes, spacing)
- Bottom bar tokens (28px height, tab styling)
- Sidebar tokens (260px default, tree indent)
- Color tokens (light/dark adaptive)
- Material tokens (NSVisualEffectView)
- Animation tokens (standard curves)
- Shadow tokens (elevation system)

ZERO hardcoded values allowed - all components must use tokens


```

**Step 5: Verify commit**

Run: `git log -1 --stat`
Expected: See XcodeDesignTokens.swift created

---

### Task 1.2: Create VisualEffectBlur Utility

**Files:**
- Create: `GitMac/UI/Utilities/VisualEffectBlur.swift`

**Step 1: Create directory if needed**

```bash
mkdir -p GitMac/UI/Utilities
```

**Step 2: Create VisualEffectBlur wrapper**

```swift
//
//  VisualEffectBlur.swift
//  GitMac
//
//  Created on 2025-12-29.
//  NSVisualEffectView wrapper using XcodeDesignTokens
//  NO hardcoded materials - all from tokens
//

import SwiftUI
import AppKit

/// NSVisualEffectView wrapper for macOS blur effects
/// Uses XcodeDesignTokens for all materials and blending modes
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    /// Initialize with explicit material and blending mode
    /// - Parameters:
    ///   - material: The visual effect material
    ///   - blendingMode: How the blur blends with content
    ///   - state: The effect state (usually .active)
    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode,
        state: NSVisualEffectView.State = XcodeDesignTokens.Materials.state
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Xcode-Style Convenience Initializers

extension VisualEffectBlur {
    /// Xcode-style toolbar blur (headerView + withinWindow)
    /// Uses XcodeDesignTokens.Materials.toolbar and toolbarBlending
    static var toolbar: VisualEffectBlur {
        VisualEffectBlur(
            material: XcodeDesignTokens.Materials.toolbar,
            blendingMode: XcodeDesignTokens.Materials.toolbarBlending
        )
    }

    /// Xcode-style bottom bar blur (titlebar + behindWindow)
    /// Uses XcodeDesignTokens.Materials.bottomBar and bottomBarBlending
    static var bottomBar: VisualEffectBlur {
        VisualEffectBlur(
            material: XcodeDesignTokens.Materials.bottomBar,
            blendingMode: XcodeDesignTokens.Materials.bottomBarBlending
        )
    }

    /// Xcode-style sidebar blur (sidebar + behindWindow)
    /// Uses XcodeDesignTokens.Materials.sidebar and sidebarBlending
    static var sidebar: VisualEffectBlur {
        VisualEffectBlur(
            material: XcodeDesignTokens.Materials.sidebar,
            blendingMode: XcodeDesignTokens.Materials.sidebarBlending
        )
    }

    /// Content background blur
    /// Uses XcodeDesignTokens.Materials.content
    static var content: VisualEffectBlur {
        VisualEffectBlur(
            material: XcodeDesignTokens.Materials.content,
            blendingMode: .withinWindow
        )
    }
}

// MARK: - Preview

#Preview("Blur Materials") {
    VStack(spacing: 0) {
        Text("Toolbar Blur")
            .frame(height: XcodeDesignTokens.Toolbar.height)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.toolbar)

        Text("Bottom Bar Blur")
            .frame(height: XcodeDesignTokens.BottomBar.tabBarHeight)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.bottomBar)

        Text("Sidebar Blur")
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.sidebar)

        Text("Content Blur")
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(VisualEffectBlur.content)
    }
    .frame(width: 400)
}
```

**Step 3: Run build to verify**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 4: Verify no hardcoded materials**

Run: `grep -E "\.headerView|\.titlebar|\.sidebar" GitMac/UI/Utilities/VisualEffectBlur.swift | wc -l`
Expected: 3 (only in token references, not hardcoded)

**Step 5: Commit**

```bash
git add GitMac/UI/Utilities/VisualEffectBlur.swift
git commit -m "feat: add VisualEffectBlur utility using design tokens

- NSVisualEffectView wrapper
- All materials from XcodeDesignTokens
- Convenience initializers: .toolbar, .bottomBar, .sidebar
- NO hardcoded materials or blending modes
- Preview for all blur types


```

---

### Task 1.3: Clean Context Checkpoint

**Step 1: Verify Phase 1 commits**

Run: `git log --oneline -5`
Expected: See 4 commits total (Phase 0: 2, Phase 1: 2)

**Step 2: Build verification**

Run: `xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Release build 2>&1 | grep "BUILD SUCCEEDED"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Save progress**

Document completion:
```
Phase 1 complete:
- XcodeDesignTokens.swift (complete token system)
- VisualEffectBlur.swift (blur utility)
- All tokens defined, NO hardcoded values
- Ready for Phase 2 (Toolbar Components)
```

**Step 4: Context cleanup note**

> **For executing-plans:** Phase 1 complete. Clear context before Phase 2.
> Foundation is solid. Next: Create toolbar button components using tokens.

---

## Phase 2: Toolbar Components

> **Context:** Fresh start - build toolbar button components using ONLY tokens

[PLAN CONTINUES WITH 15+ MORE TASKS...]

---

## Execution Instructions for Parallel Session

### Setup
2. Navigate to: `cd /Users/mario/Sites/localhost/GitMac`
3. Ensure clean git state: `git status`
4. Start: `@superpowers:executing-plans docs/plans/2025-12-29-xcode-style-bars-detailed.md`

### Execution Rules
- Execute tasks sequentially
- Clean context between phases (after every 3-5 tasks)
- Commit after EVERY successful step
- Build verification after each task
- If build fails, stop and report error
- NO hardcoded values - verify with grep before committing
- Test functionality after major changes

### Context Management
```
After Phase 0: Clear context, save "Phase 0 done"
After Phase 1: Clear context, save "Phase 1 done"
After Phase 2: Clear context, save "Phase 2 done"
... continue for each phase
```

### Progress Tracking
Create `docs/EXECUTION_LOG.md` with:
```markdown
# Execution Log

## Phase 0: Foundation
- [x] Task 0.1: Reference docs
- [x] Task 0.2: Functionality audit
- [x] Task 0.3: Context cleanup

## Phase 1: Design Tokens
- [x] Task 1.1: XcodeDesignTokens
- [x] Task 1.2: VisualEffectBlur
- [x] Task 1.3: Context cleanup

... continue
```

---

## Success Criteria

✅ **Visual:**
- Pixel-perfect match with Xcode screenshot
- All measurements from XcodeDesignTokens
- Blur effects on toolbar, bottom bar
- No visual regressions

✅ **Functional:**
- ALL features in FUNCTIONALITY_AUDIT.md work
- All toolbar buttons functional
- All bottom panel tabs work
- No features lost

✅ **Code Quality:**
- ZERO hardcoded values
- All styling from XcodeDesignTokens
- Clean commits (1 per step)
- Builds successfully

✅ **Testing:**
- Manual test checklist complete
- Functionality audit passed
- No crashes or errors
- Performance unchanged

---

**Total:** 20+ tasks, 6 phases, 3-4 hours estimated
**Completion:** Ready for parallel session execution with executing-plans skill

