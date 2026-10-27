//
//  GitMacUITests.swift
//  GitMacUITests
//
//  Created by Mario Herrera on 30/12/25.
//

import XCTest
import AppKit
import ApplicationServices
import ImageIO

final class GitMacUITests: XCTestCase {
    private var fixture: UITestRepository!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        fixture = try UITestRepository()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        fixture = nil
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        app.terminate()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = fixture.launchArguments()
            app.launchEnvironment = fixture.launchEnvironment()
            app.launch()
            app.terminate()
        }
    }

    @MainActor
    func testRepositoryLoadsAndSettingsOpen() throws {
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15), "Private fixture did not load")
        XCTAssertTrue(app.buttons["History minimap"].waitForExistence(timeout: 10), "Graph toolbar did not appear")
        let branches = expectation(for: NSPredicate { _, _ in !app.staticTexts["No Branch"].exists }, evaluatedWith: nil)
        wait(for: [branches], timeout: 10)
        let main = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        main.name = "Loaded private repository"
        main.lifetime = .keepAlways
        add(main)
        let count = app.windows.count
        let settings = app.buttons["application-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.click()
        let opened = expectation(for: NSPredicate { _, _ in app.windows.count > count }, evaluatedWith: nil)
        wait(for: [opened], timeout: 10)
        for category in ["general", "accounts", "integrations", "ai", "git", "workflows", "workspace", "shortcuts", "subscription"] {
            XCTAssertTrue(app.descendants(matching: .any)["settings-tab-\(category)"].firstMatch.exists,
                          "Missing settings category: \(category)")
        }
        let shortcuts = app.descendants(matching: .any)["settings-tab-shortcuts"].firstMatch
        shortcuts.click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-content-shortcuts"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open Repository"].waitForExistence(timeout: 5))
        app.scrollViews["settings-content-shortcuts"].scroll(byDeltaX: 0, deltaY: -700)
        XCTAssertTrue(app.staticTexts["Pop Stash"].isHittable, "Shortcuts below the fold must be reachable")
        app.descendants(matching: .any)["settings-tab-general"].firstMatch.click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-content-general"].firstMatch.waitForExistence(timeout: 5))
        let notifications = app.staticTexts["Play sounds for notifications"]
        let generalPage = app.scrollViews["settings-content-general"]
        generalPage.scroll(byDeltaX: 0, deltaY: -700)
        XCTAssertTrue(notifications.waitForExistence(timeout: 5))
        XCTAssertTrue(notifications.isHittable, "General settings must remain reachable by scrolling")
        let window = app.windows.firstMatch
        let panel = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        panel.name = "Settings after opening"
        panel.lifetime = .keepAlways
        add(panel)
        generalPage.scroll(byDeltaX: 0, deltaY: 700)
        for appearance in ["Light", "Dark", "System"] {
            let choice = app.buttons[appearance]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.click()
            XCTAssertEqual(choice.value as? String, "Selected")
            let themed = XCTAttachment(screenshot: try validationWindowScreenshot(app))
            themed.name = "Settings appearance \(appearance)"
            themed.lifetime = .keepAlways
            add(themed)
        }
        window.buttons[XCUIIdentifierCloseWindow].click()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["settings-tab-general"].firstMatch.waitForExistence(timeout: 5),
                      "Native Command-comma must reopen Settings")
    }

    @MainActor func testVisualSettingsMatrix() throws {
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["History minimap"].waitForExistence(timeout: 10))
        func capture(_ name: String) throws {
            let attachment = XCTAttachment(screenshot: try validationWindowScreenshot(app))
            attachment.name = "Visual-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.buttons["application-settings"].click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-tab-general"].firstMatch.waitForExistence(timeout: 5))
        for appearance in ["Light", "Dark"] {
            app.descendants(matching: .any)["settings-tab-general"].firstMatch.click()
            let general = app.scrollViews["settings-content-general"]
            XCTAssertTrue(general.waitForExistence(timeout: 5))
            general.scroll(byDeltaX: 0, deltaY: 700)
            let choice = app.buttons[appearance]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.click()
            XCTAssertEqual(choice.value as? String, "Selected")
            for category in ["general", "accounts", "integrations", "ai", "git", "workflows", "workspace", "shortcuts", "subscription"] {
                try activateValidationApplication(app)
                let item = app.descendants(matching: .any)["settings-tab-\(category)"].firstMatch
                XCTAssertTrue(item.isHittable, "Category must be reachable: \(category)")
                item.click()
                XCTAssertTrue(app.descendants(matching: .any)["settings-content-\(category)"].firstMatch.waitForExistence(timeout: 5))
                try capture("Settings-\(appearance)-\(category)")
            }
            app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow].click()
            try capture("Repository-\(appearance)")
            app.typeKey(",", modifierFlags: .command)
            XCTAssertTrue(app.descendants(matching: .any)["settings-tab-general"].firstMatch.waitForExistence(timeout: 5))
        }
    }

    @MainActor func testCustomThemePresetsPersist() throws {
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        func openGeneral() {
            XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
            app.buttons["application-settings"].click()
            let general = app.descendants(matching: .any)["settings-tab-general"].firstMatch
            XCTAssertTrue(general.waitForExistence(timeout: 5))
            general.click()
            XCTAssertTrue(app.buttons["theme-customize"].waitForExistence(timeout: 5))
        }
        func capture(_ label: String) throws {
            let attachment = XCTAttachment(screenshot: try validationWindowScreenshot(app))
            attachment.name = "Visual-Custom-\(label)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        openGeneral()
        for (palette, appearance, background) in [("Solarized Light", "Light", [CGFloat(253), 246, 227]),
                                                  ("GitHub Dark", "Dark", [CGFloat(13), 17, 23])] {
            app.buttons["theme-customize"].click()
            let editor = app.windows["gitmac.theme-editor"]
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            let choice = app.buttons["theme-palette-\(palette)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.click()
            XCTAssertEqual(choice.value as? String, "Selected")
            try capture("\(appearance)-Editor")
            app.buttons["theme-apply"].click()
            let closed = expectation(for: NSPredicate { _, _ in !editor.exists }, evaluatedWith: nil)
            wait(for: [closed], timeout: 5)
            XCTAssertEqual(app.buttons["theme-customize"].value as? String, "Custom theme active")
            try capture("\(appearance)-Applied")
            try assertCustomBackground(background, in: app)
            app.terminate()
            app.launch()
            openGeneral()
            XCTAssertEqual(app.buttons["theme-customize"].value as? String, "Custom theme active")
            try capture("\(appearance)-Restored")
            try assertCustomBackground(background, in: app)
        }
        app.buttons["System"].click()
    }

    @MainActor private func assertCustomBackground(_ components: [CGFloat], in app: XCUIApplication) throws {
        let data = try validationWindowScreenshot(app).pngRepresentation
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: -CGFloat(image.width * 2 / 3), y: -CGFloat(image.height - image.height / 3 - 1))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        for (actual, expected) in zip(pixel.prefix(3), components) {
            XCTAssertEqual(CGFloat(actual) / 255, expected / 255, accuracy: 0.015,
                           "Visible background must match the selected custom palette in sRGB")
        }
    }

    @MainActor func testAllThemePresetsMatrix() throws {
        fixture = try UITestRepository(includeConflict: true)
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        app.buttons["application-settings"].click()
        let presets: [(String, [CGFloat])] = [
            ("GitHub Light", [255, 255, 255]), ("Solarized Light", [253, 246, 227]),
            ("GitHub Dark", [13, 17, 23]), ("Dracula", [40, 42, 54]),
            ("Nord", [46, 52, 64]), ("One Dark Pro", [40, 44, 52]),
            ("Monokai Pro", [45, 42, 46]), ("Tokyo Night", [26, 27, 38]),
            ("Solarized Dark", [0, 43, 54])
        ]
        func capture(_ label: String) throws {
            let attachment = XCTAttachment(screenshot: try validationWindowScreenshot(app))
            attachment.name = "Visual-Preset-\(label)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        for (palette, background) in presets {
            try activateValidationApplication(app)
            let general = app.descendants(matching: .any)["settings-tab-general"].firstMatch
            XCTAssertTrue(general.waitForExistence(timeout: 5))
            general.click()
            app.buttons["theme-customize"].click()
            XCTAssertTrue(app.windows["gitmac.theme-editor"].waitForExistence(timeout: 5))
            let choice = app.buttons["theme-palette-\(palette)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            let list = app.scrollViews["theme-preset-list"]
            for _ in 0..<6 {
                if choice.isHittable { break }
                list.scroll(byDeltaX: 0, deltaY: -350)
            }
            XCTAssertTrue(choice.isHittable, "Preset must be reachable: \(palette)")
            choice.click()
            XCTAssertEqual(choice.value as? String, "Selected")
            try capture("\(palette)-Editor")
            app.buttons["theme-apply"].click()
            XCTAssertTrue(app.buttons["theme-customize"].waitForExistence(timeout: 5))
            try assertCustomBackground(background, in: app)
            for category in ["general", "accounts", "integrations", "ai", "git", "workflows", "workspace", "shortcuts", "subscription"] {
                try activateValidationApplication(app)
                let item = app.descendants(matching: .any)["settings-tab-\(category)"].firstMatch
                XCTAssertTrue(item.isHittable, "Category must be reachable: \(category)")
                item.click()
                XCTAssertTrue(app.descendants(matching: .any)["settings-content-\(category)"].firstMatch.waitForExistence(timeout: 5))
                try capture("\(palette)-Settings-\(category)")
            }
            app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow].click()
            try capture("\(palette)-Repository")
            try activateValidationApplication(app)
            let conflicts = app.buttons["navigator-conflicts"]
            for _ in 0..<6 {
                if conflicts.isHittable { break }
                app.scrollViews["repository-navigators"].scroll(byDeltaX: -300, deltaY: 0)
            }
            XCTAssertTrue(conflicts.isHittable)
            conflicts.click()
            app.buttons["open-conflict-resolver"].click()
            let accept = app.buttons["conflict-accept-both"].firstMatch
            XCTAssertTrue(accept.waitForExistence(timeout: 10))
            try capture("\(palette)-Conflict-Unresolved")
            try activateValidationApplication(app)
            accept.click()
            XCTAssertTrue(app.buttons["conflict-save-stage"].waitForExistence(timeout: 5))
            try capture("\(palette)-Conflict-Preview")
            app.buttons["conflict-close"].click()
            XCTAssertFalse(try fixture.unmergedEntries().isEmpty, "Theme previews must not resolve or stage a conflict")
            app.buttons["open-conflict-analysis"].click()
            XCTAssertTrue(app.buttons["conflict-analysis-close"].waitForExistence(timeout: 5))
            try capture("\(palette)-Conflict-Analysis")
            app.buttons["conflict-analysis-close"].click()
            app.typeKey(",", modifierFlags: .command)
            XCTAssertTrue(general.waitForExistence(timeout: 5))
        }
        app.descendants(matching: .any)["settings-tab-general"].firstMatch.click()
        app.buttons["System"].click()
    }

    @MainActor func testMinimapDragAndEndpoints() throws {
        try checkMinimapDragAndEndpoints(canvasControl: false)
    }

    @MainActor func testCanvasMinimapDragControl() throws {
        try checkMinimapDragAndEndpoints(canvasControl: true)
    }

    @MainActor func testMinimapEndpointNavigation() throws {
        try checkMinimapDragAndEndpoints(canvasControl: false, endpointsOnly: true)
    }

    @MainActor private func checkMinimapDragAndEndpoints(canvasControl: Bool, endpointsOnly: Bool = false) throws {
        fixture = try UITestRepository(historyLength: 8)
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        if canvasControl { app.launchArguments.append("--canvas-graph-control") }
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        let toggle = app.buttons["History minimap"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if toggle.value as? String != "Shown" { toggle.click() }
        XCTAssertEqual(toggle.value as? String, "Shown")
        let map = app.sliders["history-minimap"]
        XCTAssertTrue(map.waitForExistence(timeout: 8))
        defer {
            if let screenshot = try? validationWindowScreenshot(app) {
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Diagnostic-Minimap-State"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        func position() -> Double? {
            (map.value as? NSNumber)?.doubleValue ?? Double(map.value as? String ?? "")
        }
        let loaded = expectation(for: NSPredicate { _, _ in map.label.contains("8 commits") }, evaluatedWith: nil)
        wait(for: [loaded], timeout: 8)
        if !endpointsOnly {
        let top = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let bottom = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        let owner = try activateValidationApplication(app)
        top.press(forDuration: 0.1, thenDragTo: bottom)
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, owner.processIdentifier,
                       "The fixture must retain foreground during the drag")
        print("MINIMAP_AFTER_DRAG: " + map.debugDescription)
        let dragCapture = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        dragCapture.name = "Diagnostic-Minimap-After-Drag"
        dragCapture.lifetime = .keepAlways
        add(dragCapture)
        let sought = expectation(for: NSPredicate { _, _ in position() == 7 }, evaluatedWith: nil)
        wait(for: [sought], timeout: 8)
        }
        try activateValidationApplication(app)
        XCTAssertTrue(app.buttons["Go to oldest local commit"].isHittable)
        app.buttons["Go to oldest local commit"].click()
        let oldest = expectation(for: NSPredicate { _, _ in position() == 8 }, evaluatedWith: nil)
        wait(for: [oldest], timeout: 8)
        try activateValidationApplication(app)
        app.buttons["Go to newest commit"].click()
        let newest = expectation(for: NSPredicate { _, _ in position() == 1 }, evaluatedWith: nil)
        wait(for: [newest], timeout: 8)
        let capture = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        capture.name = "Visual-Native-Interactive-Minimap"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor func testStashFileViewerRemainsOpen() throws {
        fixture = try UITestRepository(includeStash: true)
        let sha = try XCTUnwrap(fixture.stashSHA)
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        let stash = app.descendants(matching: .any)["graph-stash-\(sha)"].firstMatch
        XCTAssertTrue(stash.waitForExistence(timeout: 10))
        stash.click()
        if !app.staticTexts["Stashed Files"].exists {
            let inspector = app.buttons["inspector-toggle"]
            XCTAssertTrue(inspector.waitForExistence(timeout: 5))
            inspector.click()
        }
        XCTAssertTrue(app.staticTexts["Stashed Files"].waitForExistence(timeout: 8))
        let file = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "README.md")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8))
        file.click()
        let viewer = app.descendants(matching: .any)["file-diff-viewer"].firstMatch
        XCTAssertTrue(viewer.waitForExistence(timeout: 10), "Stash file must open the actual diff viewer")
        XCTAssertTrue(viewer.staticTexts["README.md"].firstMatch.exists)
        let actions = app.descendants(matching: .any)["stash-actions"].firstMatch
        XCTAssertTrue(actions.exists)
        for identifier in ["stash-apply", "stash-pop", "stash-drop"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.isHittable, "Stash action must remain reachable: \(identifier)")
            XCTAssertGreaterThanOrEqual(button.frame.width, 28)
            XCTAssertTrue(actions.frame.contains(button.frame), "Action must fit inside the narrow inspector")
        }
        let capture = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        capture.name = "Visual-Native-Stash-File-Viewer"
        capture.lifetime = .keepAlways
        add(capture)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor func testConflictAnalysisCaptionAcrossThemes() throws {
        fixture = try UITestRepository(includeConflict: true)
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        app.buttons["application-settings"].click()
        for preset in ["GitHub Light", "Solarized Light", "GitHub Dark", "Dracula", "Nord", "One Dark Pro", "Monokai Pro", "Tokyo Night", "Solarized Dark"] {
            try activateValidationApplication(app)
            let general = app.descendants(matching: .any)["settings-tab-general"].firstMatch
            XCTAssertTrue(general.waitForExistence(timeout: 5))
            general.click()
            app.buttons["theme-customize"].click()
            let choice = app.buttons["theme-palette-\(preset)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            for _ in 0..<6 {
                if choice.isHittable { break }
                app.scrollViews["theme-preset-list"].scroll(byDeltaX: 0, deltaY: -350)
            }
            XCTAssertTrue(choice.isHittable)
            choice.click()
            app.buttons["theme-apply"].click()
            XCTAssertTrue(app.buttons["theme-customize"].waitForExistence(timeout: 5))
            app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow].click()
            let conflicts = app.buttons["navigator-conflicts"]
            for _ in 0..<6 {
                if conflicts.isHittable { break }
                app.scrollViews["repository-navigators"].scroll(byDeltaX: -300, deltaY: 0)
            }
            XCTAssertTrue(conflicts.isHittable)
            conflicts.click()
            app.buttons["open-conflict-analysis"].click()
            XCTAssertTrue(app.buttons["conflict-analysis-close"].waitForExistence(timeout: 5))
            let capture = XCTAttachment(screenshot: try validationWindowScreenshot(app))
            capture.name = "Visual-Preset-\(preset)-Conflict-Analysis"
            capture.lifetime = .keepAlways
            add(capture)
            app.buttons["conflict-analysis-close"].click()
            XCTAssertFalse(try fixture.unmergedEntries().isEmpty)
            app.typeKey(",", modifierFlags: .command)
            XCTAssertTrue(general.waitForExistence(timeout: 5))
        }
        app.buttons["System"].click()
    }

    @MainActor func testNativeSearchFieldPreservesLiteralTyping() throws {
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        try activateValidationApplication(app)
        let field = app.textFields["Search commits by message, author or SHA"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        app.typeKey("a", modifierFlags: .command)
        let text = "abc'xyz' gitmac C"
        typeLiteralFixtureText(text, into: field, app: app)
        XCTAssertEqual(field.value as? String, text, "Control: standard native field must preserve the same characters")
    }

    @MainActor func testTerminalRunsInTheFixtureAndSuggestionsNeedAnExplicitRequest() throws {
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        try activateValidationApplication(app)
        let input = app.textViews["terminal-command-input"].firstMatch
        if !input.waitForExistence(timeout: 2) {
            let open = app.buttons["open-terminal"]
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            open.click()
        }
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        let proof = fixture.repository.appendingPathComponent("gitmac-terminal-proof.txt")
        let cwdProof = fixture.repository.appendingPathComponent("gitmac-terminal-cwd.txt")
        defer {
            let bytes = try? Data(contentsOf: proof)
            let diagnostic = XCTAttachment(string: "Terminal input: \(input.value as? String ?? "<unavailable>"); proofExists=\(bytes != nil); proofBase64=\(bytes?.base64EncodedString() ?? "<missing>")")
            diagnostic.name = "Terminal fixture diagnostic"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
            if let screenshot = try? validationWindowScreenshot(app) {
                let snapshot = XCTAttachment(screenshot: screenshot)
                snapshot.name = "Visual-Terminal-Submission-Diagnostic"
                snapshot.lifetime = .keepAlways
                add(snapshot)
            }
        }
        input.click()
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = "export GITMAC_UI_SESSION_PROOF=still-alive; printf 'terminal fixture\\n' | /usr/bin/tee \(quote(proof.path)); pwd -P > \(quote(cwdProof.path))"
        typeLiteralFixtureText(command, into: input, app: app)
        XCTAssertEqual(input.value as? String, command, "Terminal input must preserve literal quotes and backslashes")
        let suggest = app.buttons["terminal-request-suggestion"]
        XCTAssertTrue(suggest.isHittable)
        XCTAssertTrue(suggest.isEnabled, "Typing must not start AI or disable its explicit request button")
        let run = app.buttons["terminal-run-command"]
        XCTAssertTrue(run.isHittable && run.isEnabled, "Run must remain visible for a single-line command")
        run.click()
        let executed = expectation(for: NSPredicate { _, _ in
            (try? Data(contentsOf: proof)) == Data("terminal fixture\n".utf8)
                && (try? Data(contentsOf: cwdProof).isEmpty) == false
        }, evaluatedWith: nil)
        wait(for: [executed], timeout: 15)
        let actualDirectory = try String(contentsOf: cwdProof, encoding: .utf8).trimmingCharacters(in: .newlines)
        let actualAttributes = try FileManager.default.attributesOfItem(atPath: actualDirectory)
        let expectedAttributes = try FileManager.default.attributesOfItem(atPath: fixture.repository.path)
        XCTAssertEqual(actualAttributes[.systemFileNumber] as? NSNumber, expectedAttributes[.systemFileNumber] as? NSNumber)
        XCTAssertEqual(actualAttributes[.systemNumber] as? NSNumber, expectedAttributes[.systemNumber] as? NSNumber)
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        XCTAssertEqual(input.value as? String, "", "Input clears only after a ready terminal accepts the command")
        input.click()
        let keyboardCommand = "printf 'keyboard fixture\\n' > \(quote(proof.path))"
        typeLiteralFixtureText(keyboardCommand, into: input, app: app)
        app.typeKey(.return, modifierFlags: [])
        let keyboardExecuted = expectation(for: NSPredicate { _, _ in
            (try? Data(contentsOf: proof)) == Data("keyboard fixture\n".utf8)
        }, evaluatedWith: nil)
        wait(for: [keyboardExecuted], timeout: 15)
        XCTAssertEqual(input.value as? String, "", "Return must retain the same delivery contract as Run")
        let terminalTabs = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "bottom-panel-tab-", "Terminal")).allElementsBoundByIndex
        let originalTab = try XCTUnwrap(terminalTabs.first { $0.value as? String == "Selected" }, "Locate the active terminal, including restored tabs")
        let originalIdentifier = originalTab.identifier
        app.buttons["bottom-panel-add"].click()
        let newTerminal = app.buttons["panel-type-terminal"]
        XCTAssertTrue(newTerminal.waitForExistence(timeout: 5))
        newTerminal.click()
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        app.descendants(matching: .any)[originalIdentifier].firstMatch.click()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.click()
        let sessionCommand = "printenv GITMAC_UI_SESSION_PROOF > \(quote(proof.path))"
        typeLiteralFixtureText(sessionCommand, into: input, app: app)
        app.buttons["terminal-run-command"].click()
        let sessionPreserved = expectation(for: NSPredicate { _, _ in
            (try? Data(contentsOf: proof)) == Data("still-alive\n".utf8)
        }, evaluatedWith: nil)
        wait(for: [sessionPreserved], timeout: 15)
        let capture = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        capture.name = "Visual-Terminal-Explicit-Demand-And-Command"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor func testConflictOnlyWIPIsVisible() throws {
        fixture = try UITestRepository(includeConflict: true, includeLocalNote: false)
        XCTAssertFalse(try fixture.unmergedEntries().isEmpty)
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        let row = app.descendants(matching: .any)["graph-working-copy"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(row.label.contains("1 conflict"), "Conflict-only WIP must identify the unresolved file: \(row.label)")
        let capture = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        capture.name = "Visual-Conflict-Only-WIP"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor func testConflictResolutionPreservesLocalWork() throws {
        fixture = try UITestRepository(includeConflict: true)
        let readme = fixture.repository.appendingPathComponent("README.md")
        let localNote = fixture.repository.appendingPathComponent("keep-local.txt")
        let original = try Data(contentsOf: readme)
        let originalHead = try fixture.currentHeadOID()
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        try activateValidationApplication(app)
        let conflicts = app.buttons["navigator-conflicts"]
        XCTAssertTrue(conflicts.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if conflicts.isHittable { break }
            app.scrollViews["repository-navigators"].scroll(byDeltaX: -300, deltaY: 0)
        }
        XCTAssertTrue(conflicts.isHittable)
        conflicts.click()
        let open = app.buttons["open-conflict-resolver"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.click()
        let accept = app.buttons["conflict-accept-both"].firstMatch
        XCTAssertTrue(accept.waitForExistence(timeout: 15))
        try activateValidationApplication(app)
        accept.click()
        XCTAssertEqual(try Data(contentsOf: readme), original, "Choosing a preview must not write the file")
        let save = app.buttons["conflict-save-stage"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.click()
        let continueButton = app.buttons["conflict-continue"]
        let staged = expectation(for: NSPredicate { _, _ in continueButton.isEnabled }, evaluatedWith: nil)
        wait(for: [staged], timeout: 10)
        XCTAssertTrue(app.staticTexts["Saved and staged"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["conflict-recovery-copies"].isHittable)
        let resolvedRow = app.descendants(matching: .any)["conflict-file-README.md"].firstMatch
        XCTAssertTrue(resolvedRow.staticTexts["Resolved"].waitForExistence(timeout: 5))
        XCTAssertEqual(try Data(contentsOf: readme), Data("Current fixture\nIncoming fixture\n".utf8))
        XCTAssertTrue(try fixture.unmergedEntries().isEmpty)
        XCTAssertEqual(try Data(contentsOf: localNote), Data("Local note kept\n".utf8))
        let beforeContinue = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        beforeContinue.name = "Visual-Conflict-Resolution-Staged"
        beforeContinue.lifetime = .keepAlways
        add(beforeContinue)
        try activateValidationApplication(app)
        continueButton.click()
        let completed = expectation(for: NSPredicate { _, _ in
            guard let head = try? self.fixture.currentHeadOID() else { return false }
            return head != originalHead
        }, evaluatedWith: nil)
        wait(for: [completed], timeout: 10)
        XCTAssertEqual(try fixture.currentParentCount(), 2)
        XCTAssertTrue(try fixture.unmergedEntries().isEmpty)
        XCTAssertEqual(try Data(contentsOf: localNote), Data("Local note kept\n".utf8))
        let final = XCTAttachment(screenshot: try validationWindowScreenshot(app))
        final.name = "Visual-Conflict-Merge-Continued"
        final.lifetime = .keepAlways
        add(final)
    }

    @MainActor func testSettingsWindowResizesUsingAccessibility() throws {
        guard AXIsProcessTrusted() else { throw XCTSkip("macOS Accessibility permission is required; native resize is not approved by this skip") }
        let app = XCUIApplication()
        app.launchArguments = fixture.launchArguments()
        app.launchEnvironment = fixture.launchEnvironment()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Repository repository"].waitForExistence(timeout: 15))
        app.buttons["application-settings"].click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-tab-general"].firstMatch.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch
        let original = window.frame
        try resizeValidationSettings(to: CGSize(width: original.width - 100, height: original.height))
        let resized = expectation(for: NSPredicate { _, _ in window.frame.width < original.width }, evaluatedWith: nil)
        wait(for: [resized], timeout: 5)
    }

    /// Use the OS accessibility window-size API; never target the installed app.
    @MainActor private func resizeValidationSettings(to size: CGSize) throws {
        var products = Bundle(for: GitMacUITests.self).bundleURL
        for _ in 0..<4 { products.deleteLastPathComponent() }
        let expected = products.appendingPathComponent("GitMac.app").standardizedFileURL
        let candidates = NSRunningApplication.runningApplications(withBundleIdentifier: "com.gitmac.validation.GitMac")
            .filter { $0.bundleURL?.standardizedFileURL == expected }
        XCTAssertEqual(candidates.count, 1, "Refuse to target any other app/process")
        let process = try XCTUnwrap(candidates.first)
        var value: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(AXUIElementCreateApplication(process.processIdentifier),
                                                    kAXWindowsAttribute as CFString, &value), .success)
        let windows = try XCTUnwrap(value as? [AXUIElement])
        let settings = try XCTUnwrap(windows.first { window in
            var identifier: CFTypeRef?
            return AXUIElementCopyAttributeValue(window, kAXIdentifierAttribute as CFString, &identifier) == .success
                && identifier as? String == "com_apple_SwiftUI_Settings_window"
        })
        var proposed = size
        let nativeSize = try XCTUnwrap(AXValueCreate(.cgSize, &proposed))
        XCTAssertEqual(AXUIElementSetAttributeValue(settings, kAXSizeAttribute as CFString, nativeSize), .success)
    }
}
