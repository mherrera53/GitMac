//
//  GitMacComprehensiveScreenshots.swift
//  GitMacUITests
//
//  COMPREHENSIVE Screenshot Tests - Covers ALL GitMac Features
//  Single app launch, systematic navigation through every feature
//
//  Based on exhaustive UI mapping:
//  - 8 Settings Tabs
//  - 8 Bottom Panel Tabs
//  - 9 Sidebar Navigator Sections
//  - All Dialogs via Keyboard Shortcuts
//  - All Context Menus
//

import XCTest

// MARK: - Comprehensive Light Mode Tests

final class ComprehensiveLightScreenshots: XCTestCase {

    static var engine: ScreenshotEngine!

    override class func setUp() {
        super.setUp()
        engine = ScreenshotEngine(
            app: XCUIApplication(),
            category: "00-Comprehensive",
            mode: .light
        )
        engine.launchApp()
    }

    override class func tearDown() {
        engine.terminateApp()
        super.tearDown()
    }

    // ============================================================
    // MARK: - 1. MAIN WINDOW STATES
    // ============================================================

    func test_01_01_MainWindowOverview() throws {
        Self.engine.capture("main-window-overview", testCase: self)
    }

    // ============================================================
    // MARK: - 2. SIDEBAR NAVIGATOR SECTIONS (Cmd+1 to Cmd+7)
    // ============================================================

    func test_02_01_NavigatorRepositories() throws {
        Self.engine.app.typeKey("1", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-repositories", testCase: self)
    }

    func test_02_02_NavigatorBranches() throws {
        Self.engine.app.typeKey("2", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-branches", testCase: self)
    }

    func test_02_03_NavigatorRemotes() throws {
        Self.engine.app.typeKey("3", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-remotes", testCase: self)
    }

    func test_02_04_NavigatorStashes() throws {
        Self.engine.app.typeKey("4", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-stashes", testCase: self)
    }

    func test_02_05_NavigatorTags() throws {
        Self.engine.app.typeKey("5", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-tags", testCase: self)
    }

    func test_02_06_NavigatorWorktrees() throws {
        Self.engine.app.typeKey("6", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-worktrees", testCase: self)
    }

    func test_02_07_NavigatorCICD() throws {
        Self.engine.app.typeKey("7", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-cicd", testCase: self)
    }

    // ============================================================
    // MARK: - 3. COMMIT GRAPH INTERACTIONS
    // ============================================================

    func test_03_01_CommitGraphView() throws {
        // Cmd+Shift+G - Show commit graph
        Self.engine.app.typeKey("g", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("commit-graph-view", testCase: self)
    }

    func test_03_02_CommitSelected() throws {
        // Select a commit using arrow keys
        Self.engine.app.typeKey(.downArrow, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
        Self.engine.app.typeKey(.downArrow, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
        Self.engine.capture("commit-selected", testCase: self)
    }

    func test_03_03_CommitContextMenu() throws {
        // Right-click on the selected commit
        let window = Self.engine.app.windows.firstMatch
        if window.exists {
            // Find center of window and right-click
            let center = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.rightClick()
            Thread.sleep(forTimeInterval: 0.8)
            Self.engine.capture("commit-context-menu", testCase: self)
            Self.engine.app.typeKey(.escape, modifierFlags: [])
        }
    }

    func test_03_04_HistoryView() throws {
        // Cmd+Shift+H - Show history
        Self.engine.app.typeKey("h", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("history-view", testCase: self)
    }

    // ============================================================
    // MARK: - 4. DIFF VIEWER
    // ============================================================

    func test_04_01_DiffView() throws {
        // Select a commit to show diff
        Self.engine.app.typeKey(.downArrow, modifierFlags: [])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("diff-view", testCase: self)
    }

    func test_04_02_DiffSearch() throws {
        // Cmd+F - Search in diff
        Self.engine.app.typeKey("f", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("diff-search", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
    }

    // ============================================================
    // MARK: - 5. BRANCH DIALOGS
    // ============================================================

    func test_05_01_NewBranchDialog() throws {
        // Cmd+Shift+B - New Branch
        Self.engine.app.typeKey("b", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-new-branch", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_05_02_MergeDialog() throws {
        // Cmd+Shift+M - Merge
        Self.engine.app.typeKey("m", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-merge", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_05_03_RebaseDialog() throws {
        // Cmd+Shift+R - Rebase
        Self.engine.app.typeKey("r", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-rebase", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // ============================================================
    // MARK: - 6. REPOSITORY OPERATIONS
    // ============================================================

    func test_06_01_FetchOperation() throws {
        // Cmd+Shift+F - Fetch
        Self.engine.app.typeKey("f", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.5)
        Self.engine.capture("operation-fetch", testCase: self)
    }

    func test_06_02_StashDialog() throws {
        // Cmd+Option+S - Stash
        Self.engine.app.typeKey("s", modifierFlags: [.command, .option])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-stash", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // ============================================================
    // MARK: - 7. BOTTOM PANEL TABS
    // ============================================================

    func test_07_01_TerminalPanel() throws {
        // Cmd+Shift+T - Terminal
        Self.engine.app.typeKey("t", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 2.0)
        Self.engine.capture("panel-terminal", testCase: self)
    }

    func test_07_02_TerminalWithCommand() throws {
        // Type git status in terminal
        Self.engine.app.typeText("git status")
        Self.engine.app.typeKey(.return, modifierFlags: [])
        Thread.sleep(forTimeInterval: 1.5)
        Self.engine.capture("terminal-git-status", testCase: self)
    }

    // Toggle bottom panel to access tabs
    func test_07_03_BottomPanelTabBar() throws {
        // The terminal should already be open, capture the tab bar
        Self.engine.capture("bottom-panel-tabs", testCase: self)
    }

    // ============================================================
    // MARK: - 8. VIEW TOGGLES
    // ============================================================

    func test_08_01_ToggleSidebar() throws {
        // Cmd+Ctrl+S - Toggle Sidebar
        Self.engine.app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("sidebar-hidden", testCase: self)
        // Toggle back
        Self.engine.app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("sidebar-visible", testCase: self)
    }

    // ============================================================
    // MARK: - 9. SEARCH & COMMAND PALETTE
    // ============================================================

    func test_09_01_CommandPalette() throws {
        // Cmd+Shift+P - Command Palette
        Self.engine.app.typeKey("p", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("command-palette", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_09_02_FuzzyFileFinder() throws {
        // Cmd+P - Fuzzy File Finder
        Self.engine.app.typeKey("p", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("fuzzy-file-finder", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // ============================================================
    // MARK: - 10. SETTINGS TABS
    // ============================================================

    func test_10_01_SettingsGeneral() throws {
        // Cmd+, - Settings
        Self.engine.app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.5)
        Self.engine.capture("settings-general", testCase: self)
    }

    func test_10_02_SettingsAccounts() throws {
        // Click Accounts tab
        let accountsTab = Self.engine.app.buttons["Accounts"].firstMatch
        if accountsTab.waitForExistence(timeout: 2) {
            accountsTab.click()
            Thread.sleep(forTimeInterval: 0.8)
        }
        Self.engine.capture("settings-accounts", testCase: self)
    }

    func test_10_03_SettingsIntegrations() throws {
        let tab = Self.engine.app.buttons["Integrations"].firstMatch
        if tab.waitForExistence(timeout: 2) {
            tab.click()
            Thread.sleep(forTimeInterval: 0.8)
        }
        Self.engine.capture("settings-integrations", testCase: self)
    }

    func test_10_04_SettingsAI() throws {
        let tab = Self.engine.app.buttons["AI"].firstMatch
        if tab.waitForExistence(timeout: 2) {
            tab.click()
            Thread.sleep(forTimeInterval: 0.8)
        }
        Self.engine.capture("settings-ai", testCase: self)
    }

    func test_10_05_SettingsGit() throws {
        let tab = Self.engine.app.buttons["Git"].firstMatch
        if tab.waitForExistence(timeout: 2) {
            tab.click()
            Thread.sleep(forTimeInterval: 0.8)
        }
        Self.engine.capture("settings-git", testCase: self)
    }

    func test_10_06_SettingsWorkspace() throws {
        let tab = Self.engine.app.buttons["Workspace"].firstMatch
        if tab.waitForExistence(timeout: 2) {
            tab.click()
            Thread.sleep(forTimeInterval: 0.8)
        }
        Self.engine.capture("settings-workspace", testCase: self)
    }

    func test_10_07_SettingsShortcuts() throws {
        let tab = Self.engine.app.buttons["Shortcuts"].firstMatch
        if tab.waitForExistence(timeout: 2) {
            tab.click()
            Thread.sleep(forTimeInterval: 0.8)
        }
        Self.engine.capture("settings-shortcuts", testCase: self)
    }

    func test_10_08_SettingsSubscription() throws {
        let tab = Self.engine.app.buttons["Subscription"].firstMatch
        if tab.waitForExistence(timeout: 2) {
            tab.click()
            Thread.sleep(forTimeInterval: 0.8)
        }
        Self.engine.capture("settings-subscription", testCase: self)
        // Close settings
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // ============================================================
    // MARK: - 11. THEME EDITOR
    // ============================================================

    func test_11_01_ThemeEditor() throws {
        // Cmd+Option+T - Theme Editor
        Self.engine.app.typeKey("t", modifierFlags: [.command, .option])
        Thread.sleep(forTimeInterval: 1.5)
        Self.engine.capture("theme-editor", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // ============================================================
    // MARK: - 12. FILE DIALOGS
    // ============================================================

    func test_12_01_OpenRepositoryDialog() throws {
        // Cmd+O - Open Repository
        Self.engine.app.typeKey("o", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-open-repository", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_12_02_CloneRepositoryDialog() throws {
        // Cmd+Shift+N - Clone Repository
        Self.engine.app.typeKey("n", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-clone-repository", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_12_03_InitRepositoryDialog() throws {
        // Cmd+Shift+I - Init Repository
        Self.engine.app.typeKey("i", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-init-repository", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // ============================================================
    // MARK: - 13. STAGING AREA
    // ============================================================

    func test_13_01_StagingArea() throws {
        // The right panel should show staging area by default
        Self.engine.capture("staging-area", testCase: self)
    }

    func test_13_02_CommitMessageArea() throws {
        // Focus on commit message text area
        let textView = Self.engine.app.textViews.firstMatch
        if textView.waitForExistence(timeout: 2) {
            textView.click()
            Thread.sleep(forTimeInterval: 0.5)
            Self.engine.app.typeText("feat: Add new feature")
            Thread.sleep(forTimeInterval: 0.5)
        }
        Self.engine.capture("commit-message-typed", testCase: self)
    }

    // ============================================================
    // MARK: - 14. FINAL OVERVIEW
    // ============================================================

    func test_14_01_FinalOverview() throws {
        // Take a final overview screenshot
        Self.engine.capture("final-overview", testCase: self)
    }
}

// MARK: - Comprehensive Dark Mode Tests

final class ComprehensiveDarkScreenshots: XCTestCase {

    static var engine: ScreenshotEngine!

    override class func setUp() {
        super.setUp()
        engine = ScreenshotEngine(
            app: XCUIApplication(),
            category: "00-Comprehensive",
            mode: .dark
        )
        engine.launchApp()
    }

    override class func tearDown() {
        engine.terminateApp()
        super.tearDown()
    }

    func test_01_MainWindowDark() throws {
        Self.engine.capture("main-window-overview", testCase: self)
    }

    func test_02_NavigatorBranchesDark() throws {
        Self.engine.app.typeKey("2", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("navigator-branches", testCase: self)
    }

    func test_03_CommitGraphDark() throws {
        Self.engine.app.typeKey("g", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("commit-graph-view", testCase: self)
    }

    func test_04_NewBranchDialogDark() throws {
        Self.engine.app.typeKey("b", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("dialog-new-branch", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
    }

    func test_05_TerminalDark() throws {
        Self.engine.app.typeKey("t", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 2.0)
        Self.engine.capture("panel-terminal", testCase: self)
    }

    func test_06_CommandPaletteDark() throws {
        Self.engine.app.typeKey("p", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)
        Self.engine.capture("command-palette", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
    }

    func test_07_SettingsDark() throws {
        Self.engine.app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.5)
        Self.engine.capture("settings-general", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
    }

    func test_08_ThemeEditorDark() throws {
        Self.engine.app.typeKey("t", modifierFlags: [.command, .option])
        Thread.sleep(forTimeInterval: 1.5)
        Self.engine.capture("theme-editor", testCase: self)
        Self.engine.app.typeKey(.escape, modifierFlags: [])
    }
}
