# GitMac — Performance & Quality Audit

_Generated 2026-05-24 11:04_

## Status

- ✅ **Build clean — 0 warnings** in GitMac target after this session's fixes
- ⚠️  ~104 phantom warnings from prebuilt SPM artifact (CodeEditLanguages — references paths from original maintainer's machine, not actionable)

## Fixes applied in this session

| File | Fix |
|------|-----|
| `UI/Components/AppTheme.swift` | `EnvironmentKey` struct -> `@Entry` macro (10 lines -> 3) |
| `UI/Components/Atoms/Inputs/DSPicker.swift` | Removed duplicate deprecated `.accentColor()` |
| `UI/Components/Utilities/GestureHandlers.swift` | `MagnificationGesture` -> `MagnifyGesture` (iOS 17+) |
| `Features/Settings/Tabs/WorkflowSettingsTab.swift` | `@State` -> `@State private` (added explicit init) |
| `Features/Terminal/TerminalView.swift` | `@FocusState` -> `@FocusState private` |
| `UI/Components/Utilities/StateManagement.swift` | Removed broken `where Self == AnyView` constraint |
| `Core/Utils/ShellExecutor.swift` | Added `@Sendable` to local `dbgLog` (fixed 2 concurrency warnings) |
| `UI/Components/Xcode/PushToolbarButton.swift` | Extracted 13-line repeated branch-observation pattern (3x repeated -> 1 modifier `.observeBranchChanges`); 286 -> 272 lines |

## Redundancy investigation findings

| Suspected duplicate | Verdict | Reason |
|---|---|---|
| `GhosttyTerminalView` x 2 in same file | False -- `#if GHOSTTY_AVAILABLE` / `#else` stub | Standard fallback pattern |
| `GhosttyNativeView`, `GhosttyDirectView`, `EmbeddedTerminalView`, `GhosttyEnhancedTerminalView` x 2 each | False -- same conditional pattern | Each has real impl + stub |
| `enum TerminalInputMode` x 2 same file | False -- conditional compilation | Real + stub |
| `enum DiffSide` x 4 across files | Mostly different -- different cases, different parents | One in DiffLineView (`left/right`), one Codable in CodeReview, two nested in WordLevelDiff with different cases |
| `struct ContentView` in `Services/LicenseValidator.swift` | False -- inside `/* */` comment block | Documentation example, not compiled |
| `struct ContentView` in `Features/Editor/CodeEditorView.swift` | False -- inside multiline string literal sample | Editor demo content |
| `struct TerminalAIChatView` x 2 | Apparent duplicate but only ONE compiles per build | EmbeddedTerminalView's version is gated by `canImport(SwiftTerm)` which is false in current SPM config |
| `private func updateFromBranchManager()` x 3 in `PushToolbarButton.swift` | **REAL -- refactored** | Three toolbar buttons each had own 13-line subscription pattern. Extracted into `.observeBranchChanges { }` modifier. |

## Architectural patterns to PRESERVE (not deuda)

- **`ObservableObject` (102 files) + `@StateObject` (97) + `@ObservedObject` (51)**: load-bearing for live updates in commit graph and branch checkout. **DO NOT bulk-migrate to `@Observable`** — past attempt broke real-time UI.
- **`AnyView` (5 files)**: all legitimate — polymorphic enum cases, plugin systems, Transferable drag previews.
- **`tabItem` (4 files)**: cannot migrate to new `Tab` API (requires macOS 15+; target is 14.0).

## Performance opportunities (prioritized, NOT yet applied)

### P1 -- Lazy loading audit
- 410 `List(...)` / `ForEach(...)` declarations exist. Inside `ScrollView`, these should be wrapped in `LazyVStack`/`LazyHStack` if the dataset is unbounded (commit lists, file lists, PR lists). Inside `List`, lazy is automatic.
- **Verification needed:** profile with Instruments on the heaviest list views (PRListView, BranchListView, CommitGraphView, StashListView) under real repo sizes.

### P2 — File monsters (extract sub-views)
| File | Lines | Risk if left |
|------|-------|--------------|
| Features/Diff/DiffView.swift | 3604 | SwiftUI re-evaluates entire body on any `@State` change |
| Features/Staging/StagingAreaView.swift | 3078 | Same |
| Features/PullRequests/PRListView.swift | 2277 | Same |
| Core/Git/GitEngine.swift | 2148 | Compile times + cognitive load |
| Features/Terminal/TerminalView.swift | 1978 | Same |

### P3 — Force unwraps in views (potential crashes)
- 31 view files contain force unwrap patterns. Audit individually — many will be safe (computed properties, etc.) but some may be runtime-crash risks.

### P4 — Liquid Glass (macOS 26+) opt-in
- 0 adoption. `DesignTokens.supportsLiquidGlass` flag exists at `UI/Theme/DesignTokens.swift:471` but is never consulted.
- Quick wins: `scrollEdgeEffectStyle`, `glassEffect` on toolbars and sheets, all gated with `#available(macOS 26, *)`.

## What did NOT need fixing (already correct)

- 0 `NavigationView` (already `NavigationStack`/`NavigationSplitView`)
- 0 deprecated `onChange(of:perform:)`
- 0 `UIImage(data:)` (correctly using `NSImage` for macOS)
- 0 `DispatchQueue.main.sync`
- 0 `Thread.sleep` on main
- Healthy concurrency: 163 `@MainActor`, 26 actors, 35 `nonisolated`, 16 `Sendable`

## Tools available going forward

- **`SYMBOL_DICTIONARY.md`** at repo root: complete symbol index (run `./generate_dictionary.sh` to refresh — TODO: add script)
- **CodeGraph** initialized in `.codegraph/` (partial index due to indexer memory crash on full repo; use for targeted symbol queries)
