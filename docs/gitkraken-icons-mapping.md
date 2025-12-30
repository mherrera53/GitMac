# GitKraken Icon Mapping to SF Symbols

**Date**: 2025-12-30
**Source**: https://help.gitkraken.com/gitkraken-desktop/interface/

## Toolbar Icons (Main Actions)

| GitKraken Icon | Purpose | SF Symbol | Size | Weight | Rendering |
|---------------|---------|-----------|------|--------|-----------|
| **Undo** | Reverse last action | `arrow.uturn.backward.circle.fill` | 17pt | medium | hierarchical |
| **Redo** | Reverse last undo | `arrow.uturn.forward.circle.fill` | 17pt | medium | hierarchical |
| **Pull** | Download from remote | `arrow.down.doc.fill` | 17pt | medium | hierarchical |
| **Push** | Upload to remote | `arrow.up.doc.fill` | 17pt | medium | hierarchical |
| **Branch** | Create new branch | `arrow.triangle.branch.circle.fill` | 17pt | medium | hierarchical |
| **Stash** | Save changes temporarily | `archivebox.circle.fill` | 17pt | medium | hierarchical |
| **Pop Stash** | Restore stash | `tray.and.arrow.up.fill` | 17pt | medium | hierarchical |
| **LFS** | Git LFS indicator | `externaldrive.fill.badge.checkmark` | 17pt | medium | hierarchical |

## Left Panel Section Icons

| Section | Purpose | SF Symbol | Size | Weight | Rendering |
|---------|---------|-----------|------|--------|-----------|
| **Local** | Local branches | `desktopcomputer` | 12pt | medium | hierarchical |
| **Remote** | Remote branches | `cloud.fill` | 12pt | medium | hierarchical |
| **Pull Requests** | Active PRs | `arrow.triangle.merge` | 12pt | medium | hierarchical |
| **Issues** | Issue tracker | `exclamationmark.circle.fill` | 12pt | medium | hierarchical |
| **Teams** | Team members | `person.3.fill` | 12pt | medium | hierarchical |
| **Tags** | Git tags | `tag.circle.fill` | 12pt | medium | hierarchical |
| **Stashes** | Saved stashes | `archivebox.circle.fill` | 12pt | medium | hierarchical |
| **Submodules** | Git submodules | `folder.fill.badge.gearshape` | 12pt | medium | hierarchical |

## Commit Panel Icons

| Element | Purpose | SF Symbol | Size | Weight | Rendering |
|---------|---------|-----------|------|--------|-----------|
| **Unstaged** | Modified files | `doc.badge.ellipsis` | 11pt | medium | hierarchical |
| **Staged** | Ready to commit | `doc.badge.plus` | 11pt | medium | hierarchical |
| **Commit** | Create commit | `checkmark.circle.fill` | 17pt | semibold | hierarchical |
| **Amend** | Modify last commit | `pencil.circle.fill` | 17pt | medium | hierarchical |

## File Status Icons

| Status | Purpose | SF Symbol | Color | Rendering |
|--------|---------|-----------|-------|-----------|
| **Modified** | File changed | `pencil.circle.fill` | warning | hierarchical |
| **Added** | New file | `plus.circle.fill` | success | hierarchical |
| **Deleted** | Removed file | `minus.circle.fill` | error | hierarchical |
| **Renamed** | File renamed | `arrow.left.arrow.right.circle.fill` | info | hierarchical |
| **Conflicted** | Merge conflict | `exclamationmark.triangle.fill` | error | multicolor |

## Graph Column Icons

| Column | Purpose | SF Symbol | Size | Weight |
|--------|---------|-----------|------|--------|
| **Branch/Tag** | Show refs | `arrow.triangle.branch` | 10pt | medium |
| **Graph** | Commit graph | `point.3.connected.trianglepath.dotted` | 10pt | medium |
| **Author** | Committer | `person.circle.fill` | 10pt | medium |
| **Date/Time** | Timestamp | `clock.fill` | 10pt | medium |
| **SHA** | Commit hash | `number.circle.fill` | 10pt | medium |

## Action Button Icons

| Action | Purpose | SF Symbol | Color | Rendering |
|--------|---------|-----------|-------|-----------|
| **Checkout** | Switch branch | `arrow.uturn.backward.circle.fill` | accent | hierarchical |
| **Merge** | Merge branches | `arrow.triangle.merge` | purple | hierarchical |
| **Rebase** | Rebase branch | `arrow.up.arrow.down.circle.fill` | info | hierarchical |
| **Cherry Pick** | Apply commit | `cherry.fill` | error | hierarchical |
| **Reset** | Reset to commit | `arrow.counterclockwise.circle.fill` | warning | hierarchical |
| **Revert** | Revert commit | `arrow.uturn.left.circle.fill` | warning | hierarchical |
| **Delete** | Remove branch/tag | `trash.circle.fill` | error | multicolor |

## Panel Controls

| Control | Purpose | SF Symbol | Size | Rendering |
|---------|---------|-----------|-------|-----------|
| **Collapse** | Hide section | `chevron.right.circle.fill` | 11pt | hierarchical |
| **Expand** | Show section | `chevron.down.circle.fill` | 11pt | hierarchical |
| **Maximize** | Full panel | `arrow.up.left.and.arrow.down.right` | 11pt | hierarchical |
| **Close** | Close panel | `xmark.circle.fill` | 14pt | hierarchical |
| **Settings** | Configure | `gearshape.circle.fill` | 14pt | hierarchical |

## Navigation Icons

| Element | Purpose | SF Symbol | Size | Rendering |
|---------|---------|-----------|------|-----------|
| **Tab** | Repository tab | `doc.fill` | 12pt | hierarchical |
| **Tab Close** | Close repo | `xmark.circle.fill` | 10pt | hierarchical |
| **Tab Dropdown** | All repos | `chevron.down.circle.fill` | 11pt | hierarchical |
| **Search** | Find commits | `magnifyingglass.circle.fill` | 14pt | hierarchical |
| **Filter** | Filter results | `line.3.horizontal.decrease.circle.fill` | 14pt | hierarchical |

## Special Indicators

| Indicator | Purpose | SF Symbol | Color | Rendering |
|-----------|---------|-----------|-------|-----------|
| **Current Branch** | HEAD pointer | `star.circle.fill` | warning | multicolor |
| **Upstream** | Tracking branch | `arrow.up.circle.fill` | success | hierarchical |
| **Diverged** | Branch diverged | `arrow.triangle.2.circlepath` | warning | hierarchical |
| **Ahead** | Commits ahead | `arrow.up.circle.fill` | success | hierarchical |
| **Behind** | Commits behind | `arrow.down.circle.fill` | warning | hierarchical |
| **Conflict** | Has conflicts | `exclamationmark.triangle.fill` | error | multicolor |
| **Uncommitted** | WIP changes | `pencil.circle.fill` | info | hierarchical |

## Design Principles

### Icon Sizing
- **Toolbar actions**: 17pt (large, primary)
- **Panel headers**: 12pt (medium, secondary)
- **List items**: 11pt (small, tertiary)
- **Inline indicators**: 9-10pt (tiny, contextual)

### Color Coding
- **Success**: Green (commits ahead, successful operations)
- **Warning**: Yellow/Orange (current branch, commits behind, pending actions)
- **Error**: Red (conflicts, deletions, destructive actions)
- **Info**: Blue (neutral actions, remote operations)
- **Accent**: Purple (special features, highlights)

### Rendering Modes
- **Hierarchical**: Default for most icons (depth with single color)
- **Multicolor**: Special states (current branch star, conflicts, success)
- **Monochrome**: Text-adjacent icons, subtle indicators

### Consistency Rules
1. All circle-based icons use `.fill` variant for active states
2. All toolbar icons are 17pt with medium weight
3. All panel section headers use hierarchical rendering
4. All status indicators use appropriate semantic colors
5. All buttons have `.plain` style for cursor pointer
6. All buttons have `.help()` tooltips

---

**Usage**: Reference this mapping when updating any icons in GitMac to ensure consistency with GitKraken's professional design.
