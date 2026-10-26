//
//  SnapshotHelper.swift
//  GitMacUITests
//
//  Fastlane Snapshot Helper for macOS
//  Professional screenshot capture utility
//

import XCTest
import AppKit
import Carbon

/// A private repository for UI automation. Never restore or open user projects.
final class UITestRepository {
    let root: URL
    let repository: URL
    private(set) var stashSHA: String?
    private var gitExecutable = ""
    private var gitEnvironment: [String: String] = [:]

    init(historyLength: Int = 1, includeStash: Bool = false, includeConflict: Bool = false, includeLocalNote: Bool = true) throws {
        guard (1...20).contains(historyLength), !(includeStash && includeConflict) else {
            throw NSError(domain: "GitMacUITestFixture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bounded fixture history required"])
        }
        root = FileManager.default.temporaryDirectory.appendingPathComponent("GitMacUITest-\(UUID().uuidString)", isDirectory: true)
        repository = root.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        do {
            try "[user]\n\tname = UI Fixture\n\temail = ui-fixture@example.invalid\n[init]\n\tdefaultBranch = main\n"
                .write(to: root.appendingPathComponent("ui.gitconfig"), atomically: true, encoding: .utf8)
            let templates = root.appendingPathComponent("templates", isDirectory: true)
            try FileManager.default.createDirectory(at: templates, withIntermediateDirectories: true)
            var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("GIT_") && !$0.key.hasPrefix("DYLD_") }
            environment.merge([
                "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_ATTR_NOSYSTEM": "1", "GIT_CONFIG_COUNT": "2",
                "GIT_CONFIG_KEY_0": "core.hooksPath", "GIT_CONFIG_VALUE_0": "/dev/null",
                "GIT_CONFIG_KEY_1": "core.attributesFile", "GIT_CONFIG_VALUE_1": "/dev/null",
                "GIT_TEMPLATE_DIR": templates.path, "GIT_TERMINAL_PROMPT": "0",
                "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
                "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid"
            ]) { _, fixture in fixture }
            // /usr/bin/git is an xcrun shim and cannot run inside XCTest's
            // sandbox. Resolve a real Git binary without relaxing the sandbox.
            let developer = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
            let candidates = (developer?.hasPrefix("/") == true ? [developer! + "/usr/bin/git"] : []) + [
                "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
                "/Library/Developer/CommandLineTools/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"
            ]
            guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                throw NSError(domain: "GitMacUITestFixture", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "A real Git binary is required; the xcrun shim is not supported in the UI runner."])
            }
            gitExecutable = executable
            gitEnvironment = environment
            @discardableResult func git(_ arguments: [String], expectedExit: Int32 = 0) throws -> String {
                try runGit(arguments, expectedExit: expectedExit)
            }
            try git(["init", "--quiet", "--initial-branch=main"])
            try "# UI fixture\n".write(to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            try git(["add", "--", "README.md"])
            try git(["commit", "--quiet", "-m", "Initial fixture"])
            if historyLength > 1 {
                for index in 2...historyLength {
                    try "# UI fixture\nHistory \(index)\n".write(to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
                    try git(["commit", "--quiet", "-am", "History \(index)"])
                }
            }
            if includeConflict {
                try git(["checkout", "--quiet", "-b", "incoming-fixture"])
                try "Incoming fixture\n".write(to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
                try git(["commit", "--quiet", "-am", "Incoming fixture"])
                try git(["checkout", "--quiet", "main"])
                try "Current fixture\n".write(to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
                try git(["commit", "--quiet", "-am", "Current fixture"])
                try git(["merge", "--no-edit", "incoming-fixture"], expectedExit: 1)
                if includeLocalNote {
                    try "Local note kept\n".write(to: repository.appendingPathComponent("keep-local.txt"), atomically: true, encoding: .utf8)
                }
            } else {
                try "# UI fixture\nUncommitted example\n".write(to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            }
            if includeStash {
                try git(["stash", "push", "--quiet", "-m", "UI Fixture stash"])
                stashSHA = try git(["rev-parse", "refs/stash"]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            if FileManager.default.fileExists(atPath: root.path) { try? FileManager.default.removeItem(at: root) }
            throw error
        }
    }

    private func runGit(_ arguments: [String], expectedExit: Int32 = 0) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitExecutable)
        process.arguments = arguments
        process.currentDirectoryURL = repository
        process.environment = gitEnvironment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == expectedExit else {
            throw NSError(domain: "GitMacUITestFixture", code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
        }
        return String(decoding: data, as: UTF8.self)
    }

    func unmergedEntries() throws -> String { try runGit(["ls-files", "--unmerged", "-z"]) }
    func currentHeadOID() throws -> String { try runGit(["rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines) }
    func currentParentCount() throws -> Int { try runGit(["rev-list", "--parents", "-n", "1", "HEAD"]).split(whereSeparator: \.isWhitespace).count - 1 }

    func launchArguments(style: String = "Light") -> [String] {
        ["--performance-fixture", repository.path, "-AppleInterfaceStyle", style, "-ApplePersistenceIgnoreState", "YES"]
    }

    func launchEnvironment() -> [String: String] {
        ["ZDOTDIR": root.appendingPathComponent("templates").path, "BASH_ENV": "/dev/null", "ENV": "/dev/null",
         "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": root.appendingPathComponent("ui.gitconfig").path,
         "GIT_ATTR_NOSYSTEM": "1", "GIT_CONFIG_COUNT": "2",
         "GIT_CONFIG_KEY_0": "core.hooksPath", "GIT_CONFIG_VALUE_0": "/dev/null",
         "GIT_CONFIG_KEY_1": "core.attributesFile", "GIT_CONFIG_VALUE_1": "/dev/null",
         "GIT_TEMPLATE_DIR": root.appendingPathComponent("templates").path, "GIT_TERMINAL_PROMPT": "0",
         "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
         "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid"]
    }

    deinit {
        if FileManager.default.fileExists(atPath: root.path) { try? FileManager.default.removeItem(at: root) }
    }
}

/// Screenshot infrastructure only: capturing a scene is not a functional test.
@MainActor @discardableResult
func activateValidationApplication(_ app: XCUIApplication) throws -> NSRunningApplication {
    guard app.state == .runningBackground || app.state == .runningForeground else {
        throw NSError(domain: "GitMacVisualCapture", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Candidate stopped; refuse to relaunch it for a screenshot"])
    }
    app.activate()
    guard app.state == .runningForeground,
          let foreground = NSWorkspace.shared.frontmostApplication,
          foreground.bundleIdentifier?.hasPrefix("com.gitmac.validation") == true,
          foreground.bundleIdentifier?.hasSuffix(".GitMac") == true else {
        throw NSError(domain: "GitMacVisualCapture", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Validation app must own foreground before capturing or interacting"])
    }
    return foreground
}

@MainActor
func validationWindowScreenshot(_ app: XCUIApplication) throws -> XCUIScreenshot {
    let owner = try activateValidationApplication(app)
    let sheet = app.sheets.firstMatch
    let screenshot = sheet.exists && sheet.frame.width > 0 && sheet.frame.height > 0
        ? sheet.screenshot() : app.windows.firstMatch.screenshot()
    guard app.state == .runningForeground,
          NSWorkspace.shared.frontmostApplication?.processIdentifier == owner.processIdentifier else {
        throw NSError(domain: "GitMacVisualCapture", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Foreground changed during capture; discard the image"])
    }
    return screenshot
}

/// Keep literal characters unmodified on the current macOS XCTest keyboard
/// path. typeText synthesized Command+C/Command+' in both a standard native
/// field and the terminal; the explicit key API supplies the intended flags.
@MainActor
func typeLiteralFixtureText(_ text: String, into element: XCUIElement, app: XCUIApplication) {
    var deadQuoteLayout = false
    if let selected = TISCopyCurrentKeyboardInputSource() {
        let source = selected.takeRetainedValue()
        if let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            let identifier = Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
            deadQuoteLayout = identifier == "com.apple.keylayout.USInternational-PC"
        }
    }
    var segment = ""
    func flush() {
        if !segment.isEmpty { element.typeText(segment); segment = "" }
    }
    for character in text {
        if character == "c" || character == "C" || character == "'" {
            flush()
            app.typeKey(character == "C" ? "c" : String(character), modifierFlags: character == "C" ? .shift : [])
            if character == "'" && deadQuoteLayout {
                // Commit this layout's dead key without consuming the next
                // literal character (notably the space after a closing quote).
                app.typeKey(" ", modifierFlags: [])
            }
        } else {
            segment.append(character)
        }
    }
    flush()
}

final class ScreenshotEngine {
    enum Mode: String { case light = "Light", dark = "Dark" }
    let app: XCUIApplication
    private let category: String
    private let mode: Mode
    private var fixture: UITestRepository?

    init(app: XCUIApplication, category: String, mode: Mode) {
        self.app = app
        self.category = category
        self.mode = mode
    }

    func launchApp() {
        do {
            let repository = try UITestRepository()
            fixture = repository
            app.launchArguments = repository.launchArguments(style: mode.rawValue)
            app.launchEnvironment = repository.launchEnvironment()
            app.launch()
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10), "Fixture window did not appear")
        } catch { XCTFail("UI fixture preparation failed: \(error)") }
    }

    func capture(_ name: String, testCase: XCTestCase) {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 5) else { XCTFail("No window for \(name)"); return }
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = "\(category)-\(mode.rawValue)-\(name)"
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }

    func terminateApp() {
        app.terminate()
        fixture = nil
    }
}

class SnapshotHelper {

    // MARK: - Properties

    private var app: XCUIApplication
    private var screenshotCount = 0
    private let outputDirectory: URL

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app

        // Get output directory from environment or use default
        if let envPath = ProcessInfo.processInfo.environment["SNAPSHOT_OUTPUT_DIR"] {
            outputDirectory = URL(fileURLWithPath: envPath)
        } else {
            outputDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("GitMac-Screenshots")
        }

        // Create output directory if needed
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Screenshot Capture

    /// Capture a screenshot with automatic naming
    func snapshot(_ name: String, waitTime: TimeInterval = 1.0) {
        // Wait for animations to complete
        sleep(UInt32(waitTime))

        screenshotCount += 1
        let paddedNumber = String(format: "%03d", screenshotCount)
        let filename = "\(paddedNumber)-\(name)"

        captureScreenshot(named: filename)
    }

    /// Capture screenshot of the main window
    private func captureScreenshot(named name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways

        // Save to file
        saveScreenshot(screenshot, named: name)

        print("📸 Captured: \(name)")
    }

    /// Save screenshot to disk
    private func saveScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        let fileURL = outputDirectory.appendingPathComponent("\(name).png")

        do {
            try screenshot.pngRepresentation.write(to: fileURL)
        } catch {
            print("⚠️ Failed to save screenshot: \(error)")
        }
    }

    // MARK: - UI Helpers

    /// Wait for an element to exist
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// Click a menu item
    func clickMenuItem(menu: String, item: String) {
        app.menuBars.menuBarItems[menu].click()
        sleep(1)
        app.menuBars.menuBarItems[menu].menuItems[item].click()
        sleep(1)
    }

    /// Open settings
    func openSettings() {
        app.typeKey(",", modifierFlags: .command)
        sleep(2)
    }

    /// Close current window/sheet
    func closeCurrentSheet() {
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)
    }

    /// Switch to a settings tab
    func switchToSettingsTab(_ tabName: String) {
        let tab = app.buttons[tabName]
        if tab.waitForExistence(timeout: 2) {
            tab.click()
            sleep(1)
        }
    }

    /// Open repository
    func openRepository(path: String) {
        app.typeKey("o", modifierFlags: .command)
        sleep(2)
        app.typeText(path)
        app.typeKey(.return, modifierFlags: [])
        sleep(4)
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {

    /// Create a snapshot helper for the test
    func createSnapshotHelper(for app: XCUIApplication) -> SnapshotHelper {
        return SnapshotHelper(app: app)
    }

    /// Attach a screenshot to the test report
    func attachScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
