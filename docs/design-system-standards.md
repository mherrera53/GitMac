# Design System Standards - GitKraken Style

**Date**: 2025-12-30
**Status**: Normalization Standard

## Icon Sizing (Strict Standards)

### Size Categories
```swift
// Toolbar Actions (Main)
.font(.system(size: 17, weight: .medium))

// Panel Headers (Secondary)
.font(.system(size: 12, weight: .medium))

// List Items / Status Icons (Tertiary)
.font(.system(size: 11, weight: .medium))

// Column Headers (Small)
.font(.system(size: 10, weight: .medium))

// Inline Indicators (Tiny)
.font(.system(size: 9, weight: .medium))
```

### StatusIcon Normalized Sizes
- **small**: 11pt (list items, file status in rows)
- **medium**: 12pt (panel headers, prominent indicators)
- **large**: 14pt (special emphasis, large displays)
- **weight**: Always `.medium` (GitKraken standard)

## Color Standards

### Semantic Colors (ALWAYS use AppTheme)
```swift
// File Status
AppTheme.success      // Added files, positive actions (+)
AppTheme.warning      // Modified files, current state (*)
AppTheme.error        // Deleted files, conflicts, destructive (-)
AppTheme.accent       // Renamed, copied, special features
AppTheme.info         // Pull, neutral remote operations

// Text Colors
AppTheme.textPrimary  // Main text
AppTheme.textSecondary // Secondary text
AppTheme.textMuted    // Disabled/muted states
```

### Theme Colors (Use Color.Theme instance)
```swift
let theme = Color.Theme(themeManager.colors)

theme.text            // Primary text (theme-aware)
theme.textSecondary   // Secondary text (theme-aware)
theme.textMuted       // Muted text (theme-aware)
theme.background      // Main background
theme.backgroundSecondary // Panel backgrounds
```

### Rule: When to Use Which
- **AppTheme**: For semantic colors that should NOT change with theme (success, error, warning, info, accent)
- **theme.xxx**: For colors that should adapt to light/dark theme (text, backgrounds)

## Typography Standards

### Font Weights
```swift
.regular      // Body text only
.medium       // ALL icons, most labels
.semibold     // Emphasis, current/active state
.bold         // Headers, critical emphasis
```

### Text Styles
```swift
// Headers
DesignTokens.Typography.caption2
    .fontWeight(.semibold)
    .foregroundColor(theme.text)

// Labels
DesignTokens.Typography.caption
    .fontWeight(.medium)
    .foregroundColor(theme.text)

// Secondary Info
DesignTokens.Typography.caption
    .fontWeight(.regular)
    .foregroundColor(theme.textSecondary)

// Counts/Numbers
DesignTokens.Typography.caption2
    .monospacedDigit()
    .fontWeight(.semibold)
```

## Symbol Rendering Modes

### Standard Modes
```swift
.hierarchical   // DEFAULT for most icons (depth with single color)
.multicolor     // ONLY for critical states (conflicts, success indicators)
.monochrome     // Structural elements (graph lines, simple shapes)
```

### Usage Rules
- **Toolbar actions**: `.hierarchical`
- **Panel headers**: `.hierarchical`
- **File status**: `.hierarchical` (except unmerged: `.multicolor`)
- **Graph structure**: `.monochrome`
- **Success indicators**: `.multicolor` (star, checkmark.seal)

## Spacing Standards

Use DesignTokens.Spacing consistently:
```swift
.xxs    // 2pt  - Tight spacing
.xs     // 4pt  - Small gaps
.sm     // 8pt  - Default padding
.md     // 12pt - Section spacing
.lg     // 16pt - Large gaps
.xl     // 24pt - Major sections
```

## Component-Specific Standards

### Toolbar
```swift
Icon: .font(.system(size: 17, weight: .medium))
Color: AppTheme.{semantic} or theme.textMuted (disabled)
Rendering: .hierarchical
Help: Required for all buttons
Style: .plain (for pointer cursor)
```

### Graph Column Headers
```swift
Icon: .font(.system(size: 10, weight: .medium))
Text: DesignTokens.Typography.caption2.fontWeight(.semibold)
Color: theme.textMuted (icons), theme.text (labels)
Height: 28pt
```

### File Status Icons (StatusIcon)
```swift
Size: .small (11pt), .medium (12pt), .large (14pt)
Weight: .medium (consistent)
Color: AppTheme.{semantic}
Rendering: .hierarchical (default), .multicolor (unmerged only)
```

### Branch Panel
```swift
Header Icons: .font(.system(size: 12, weight: .medium))
Row Icons: .font(.system(size: 11, weight: .medium))
Current Indicator: star.circle.fill, 13pt, .semibold, .multicolor
Colors: AppTheme.warning (current), AppTheme.success (ahead), AppTheme.accent (general)
```

## Validation Checklist

Before committing icon/style changes:
- [ ] All icons use .medium weight (unless special emphasis needed)
- [ ] Sizes match category (17pt toolbar, 12pt panel, 11pt list, 10pt column)
- [ ] Semantic colors use AppTheme (success, error, warning, info, accent)
- [ ] Theme-aware colors use theme.xxx instance
- [ ] All toolbar buttons have .help() tooltips
- [ ] All buttons use .plain style for pointer cursor
- [ ] Symbol rendering mode is appropriate (hierarchical default)
- [ ] Typography uses DesignTokens.Typography
- [ ] Spacing uses DesignTokens.Spacing

## Anti-Patterns to Avoid

❌ **DON'T**:
```swift
.font(.system(size: 16, weight: .semibold))  // Random size
.foregroundColor(.blue)                       // Hard-coded color
.font(.body)                                  // Non-standard font
.buttonStyle(.borderless)                     // No pointer cursor
Image(systemName: "star").frame(width: 20)    // Wrong sizing
```

✅ **DO**:
```swift
.font(.system(size: 12, weight: .medium))    // Standard size
.foregroundColor(AppTheme.success)            // Semantic color
.font(DesignTokens.Typography.caption)        // Design token
.buttonStyle(.plain)                          // Pointer cursor
Image(systemName: "star.circle.fill")         // Proper icon variant
```

---

**Enforce these standards in ALL new code and refactoring.**
