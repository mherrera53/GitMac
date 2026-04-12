//
//  GitMacScreenshotTests.swift
//  GitMacUITests
//
//  Automated screenshot capture for GitMac website and documentation
//

import XCTest

final class GitMacScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleInterfaceStyle", "Light"]
        app.launch()
        sleep(3)

        // Open demo repository
        app.typeKey("o", modifierFlags: .command)
        sleep(2)
        app.typeText("/Users/mario/gitmac-demo-repo")
        app.typeKey(.return, modifierFlags: [])
        sleep(4)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func captureScreenshot(named name: String) {
        sleep(2)
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("📸 \(name)")
    }

    func test01_MainWindow() throws {
        // Main window with repository open
        captureScreenshot(named: "01-main-window-light")
    }

    func test02_CommitDialog() throws {
        // Open commit dialog (if there are changes)
        app.typeKey(.return, modifierFlags: .command)
        sleep(1)
        captureScreenshot(named: "02-commit-dialog-light")
        // Close with Escape
        app.typeKey(.escape, modifierFlags: [])
    }

    func test03_Search() throws {
        // Open search
        app.typeKey("f", modifierFlags: .command)
        sleep(1)
        captureScreenshot(named: "03-search-light")
        app.typeKey(.escape, modifierFlags: [])
    }

    func test04_BranchDialog() throws {
        // New branch dialog
        app.typeKey("b", modifierFlags: [.command, .shift])
        sleep(1)
        captureScreenshot(named: "04-new-branch-light")
        app.typeKey(.escape, modifierFlags: [])
    }
}

// MARK: - Settings Tests

final class GitMacScreenshotTestsSettings: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleInterfaceStyle", "Light"]
        app.launch()
        sleep(2)

        // Open settings
        app.typeKey(",", modifierFlags: .command)
        sleep(2)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func captureScreenshot(named name: String) {
        sleep(1)
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("📸 \(name)")
    }

    func test11_Settings_General() throws {
        captureScreenshot(named: "11-settings-general-light")
    }

    func test12_Settings_Appearance() throws {
        // Try to click Appearance tab if it exists
        let appearanceTab = app.buttons["Appearance"]
        if appearanceTab.waitForExistence(timeout: 1) {
            appearanceTab.click()
            sleep(1)
        }
        captureScreenshot(named: "12-settings-appearance-light")
    }

    func test13_Settings_Git() throws {
        let gitTab = app.buttons["Git"]
        if gitTab.waitForExistence(timeout: 1) {
            gitTab.click()
            sleep(1)
        }
        captureScreenshot(named: "13-settings-git-light")
    }
}

// MARK: - Dark Mode Tests

final class GitMacScreenshotTestsDarkMode: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        sleep(3)

        // Open demo repository
        app.typeKey("o", modifierFlags: .command)
        sleep(2)
        app.typeText("/Users/mario/gitmac-demo-repo")
        app.typeKey(.return, modifierFlags: [])
        sleep(4)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func captureScreenshot(named name: String) {
        sleep(2)
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("📸 \(name)")
    }

    func test21_MainWindow_Dark() throws {
        captureScreenshot(named: "21-main-window-dark")
    }

    func test22_Search_Dark() throws {
        app.typeKey("f", modifierFlags: .command)
        sleep(1)
        captureScreenshot(named: "22-search-dark")
        app.typeKey(.escape, modifierFlags: [])
    }

    func test23_BranchDialog_Dark() throws {
        app.typeKey("b", modifierFlags: [.command, .shift])
        sleep(1)
        captureScreenshot(named: "23-new-branch-dark")
        app.typeKey(.escape, modifierFlags: [])
    }
}

// MARK: - Settings Dark Mode

final class GitMacScreenshotTestsSettingsDark: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        sleep(2)

        app.typeKey(",", modifierFlags: .command)
        sleep(2)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func captureScreenshot(named name: String) {
        sleep(1)
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("📸 \(name)")
    }

    func test31_Settings_Dark() throws {
        captureScreenshot(named: "31-settings-dark")
    }
}
