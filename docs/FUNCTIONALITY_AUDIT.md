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
