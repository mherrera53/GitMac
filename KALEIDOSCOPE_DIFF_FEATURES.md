# Kaleidoscope-Style Diff Viewer

This document describes the professional diff viewer implementation inspired by [Kaleidoscope](https://kaleidoscope.app/), featuring advanced visualization and navigation capabilities.

## Overview

The Kaleidoscope-style diff viewer provides a polished, professional interface for comparing file versions with features matching the industry-leading Kaleidoscope app.

## Key Features

### 1. **Commit History Sidebar** (`CommitHistorySidebar.swift`)
- **Location**: Right side of the diff view
- **Features**:
  - Chronological list of commits with author avatars
  - Author name and timestamp for each commit
  - A/B version selectors for quick comparison
  - Commit message preview
  - SHA hash display
  - Filter/search functionality
  - Change navigation (Change X of Y)
  - Color-coded avatar generation from author name

### 2. **Breadcrumb Navigation** (`DiffBreadcrumb.swift`)
- **Location**: Top of the diff view
- **Features**:
  - File path breadcrumb with directory hierarchy
  - File type icon detection
  - Diff statistics (Additions, Deletions, Changes)
  - Version selectors with dropdowns (A/B)
  - Visual badges for each version
  - Descriptive version information with timestamps

### 3. **Enhanced Split View** (`KaleidoscopeSplitDiffView.swift`)
- **Features**:
  - Side-by-side comparison with synchronized scrolling
  - Connected change visualization lines between panels
  - Character-level diff highlighting
  - Color-coded change indicators:
    - Blue curves: Modified lines
    - Red arrows: Deletions
    - Green arrows: Additions
  - Hunk headers with visual separation
  - Empty line placeholders for alignment
  - Line number gutter with context-aware background

### 4. **Main Container** (`KaleidoscopeDiffView.swift`)
- **Features**:
  - Integrated breadcrumb, diff view, and history sidebar
  - Multiple view modes:
    - **Split**: Side-by-side with connection lines
    - **Inline**: Traditional unified diff
    - **Changes Only**: Shows only modified lines
  - Professional toolbar with:
    - View mode selector
    - Line number toggle
    - Whitespace visibility toggle
    - History sidebar toggle
    - Info and share buttons
  - Collapsible history panel
  - Smooth animations

## Design Principles

### Visual Design
- **Clean, Polished UI**: Rounded corners, subtle shadows, professional spacing
- **Kaleidoscope Color Scheme**: Matching the professional look of Kaleidoscope
- **Consistent Design Tokens**: Using centralized spacing, typography, and sizing
- **macOS-Native Feel**: Platform-appropriate controls and interactions

### User Experience
- **Quick Version Comparison**: Easy A/B selection from history
- **Contextual Information**: File path, stats, and version info always visible
- **Efficient Navigation**: Change navigation, filtering, and search
- **Flexible Viewing**: Multiple view modes for different workflows

## Components

### CommitHistorySidebar
```swift
CommitHistorySidebar(
    commits: [Commit],
    selectedCommitA: Binding<Commit?>,
    selectedCommitB: Binding<Commit?> )
```

### DiffBreadcrumb
```swift
DiffBreadcrumb(
    filePath: String,
    additions: Int,
    deletions: Int,
    changes: Int,
    selectedVersionA: Binding<String?>,
    selectedVersionB: Binding<String?>,
    versions: [FileVersion]
)
```

### KaleidoscopeSplitDiffView
```swift
KaleidoscopeSplitDiffView(
    hunks: [DiffHunk],
    showLineNumbers: Bool,
    scrollOffset: Binding<CGFloat>,
    viewportHeight: Binding<CGFloat>,
    contentHeight: Binding<CGFloat>
)
```

### KaleidoscopeDiffView
```swift
KaleidoscopeDiffView(
    fileDiff: FileDiff,
    commits: [Commit],
    repoPath: String? = nil
)
```

## Usage

### Basic Usage

```swift
import SwiftUI

struct MyView: View {
    let fileDiff: FileDiff
    let commits: [Commit]

    var body: some View {
        KaleidoscopeDiffView(
            fileDiff: fileDiff,
            commits: commits
        )
    }
}
```

### Integration with Existing DiffView

The Kaleidoscope view can be integrated into the existing `DiffView` as an alternative view mode:

```swift
// In DiffView.swift
@State private var useKaleidoscopeMode = true

var body: some View {
    if useKaleidoscopeMode {
        KaleidoscopeDiffView(
            fileDiff: fileDiff,
            commits: availableCommits
        )
    } else {
        // Existing diff view
        traditionalDiffView
    }
}
```

## Features Comparison

| Feature | Traditional Diff | Kaleidoscope Diff |
|---------|-----------------|-------------------|
| Split View | ✅ | ✅ Enhanced |
| Inline View | ✅ | ✅ |
| Line Numbers | ✅ | ✅ |
| Word-Level Diff | ✅ | ✅ Enhanced |
| History Sidebar | ❌ | ✅ |
| Breadcrumb Navigation | ❌ | ✅ |
| Connected Changes | ❌ | ✅ |
| A/B Version Selector | ❌ | ✅ |
| Change Navigation | ❌ | ✅ |
| Commit Filtering | ❌ | ✅ |
| Author Avatars | ❌ | ✅ |

## Technical Implementation

### Character-Level Diff
Uses the existing `WordLevelDiff` engine to highlight character-level changes within modified lines, making it easy to spot exactly what changed.

### Connection Lines
Custom Canvas drawing to create smooth, curved connection lines between changed sections in split view, visually linking related modifications.

### Avatar Generation
Deterministic color generation from author names ensures consistent avatar colors across sessions while maintaining visual variety.

### Performance
- Lazy loading for large commit histories
- Efficient diffing with word-level granularity
- Optimized rendering with SwiftUI best practices

## Future Enhancements

Potential improvements to match even more Kaleidoscope features:

- [ ] Image diffing with pixel-level comparison
- [ ] Folder/directory comparison
- [ ] 3-way merge view for conflict resolution
- [ ] Syntax highlighting integration
- [ ] Bookmark/annotation support
- [ ] Export diff as HTML/PDF
- [ ] Keyboard shortcuts for navigation
- [ ] Dark mode optimizations

## References

- [Kaleidoscope App](https://kaleidoscope.app/)
- [Kaleidoscope Features](https://martech.zone/kaleidoscope-diff-apple/)
- [Git Diff and Merge Tools](https://www.producthunt.com/products/kaleidoscope-2-4)

## Credits

Inspired by Kaleidoscope, the professional diff and merge tool for macOS developers.

Implementation by GitMac - Native SwiftUI diff viewer with Kaleidoscope-style features.
