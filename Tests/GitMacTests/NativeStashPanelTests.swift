import AppKit
import SwiftUI
import Testing
@testable import GitMac

@Suite("Native stash inspector layout", .serialized)
@MainActor struct NativeStashPanelTests {
    private func panel(_ model: StashDetailViewModel, longMessage: Bool = false) -> StashDetailPanel {
        StashDetailPanel(stash: Stash(index: 0,
            message: longMessage ? String(repeating: "Long stash message ", count: 30) : "Saved changes",
            sha: String(repeating: "a", count: 40), date: Date(),
            branchName: String(repeating: "feature/long-branch-", count: 12)),
            viewModel: model, selectedFileDiff: .constant(nil), onClose: {})
        // repositoryPath intentionally nil: no AppState, credentials, session
        // restoration or user repository operations are initialized by this test.
    }

    @Test func loadingAndLoadedContentDoNotChangeInspectorMinimumSize() async throws {
        _ = NSApplication.shared
        let model = StashDetailViewModel()
        model.isLoading = true
        let host = NSHostingView(rootView: panel(model))
        host.frame = NSRect(x: 0, y: 0, width: 220, height: 700)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 50_000_000)
        let minimum = host.fittingSize

        model.isLoading = false
        model.stashFiles = (0..<100).map {
            StashFile(path: "deep/directory/File\($0).swift", filename: "File\($0).swift", status: .modified)
        }
        host.rootView = panel(model, longMessage: true)
        try await Task.sleep(nanoseconds: 50_000_000)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize == minimum)
    }

    @Test func nativeSplitInspectorSurvivesRepeatedStashLoadingTransitions() async throws {
        _ = NSApplication.shared
        let model = StashDetailViewModel()
        let host = NSHostingView(rootView: NavigationSplitView {
            Text("Repositories").navigationSplitViewColumnWidth(min: 120, ideal: 170, max: 260)
        } detail: {
            Text("Graph").frame(maxWidth: .infinity, maxHeight: .infinity)
        }.inspector(isPresented: .constant(true)) {
            panel(model, longMessage: true).inspectorColumnWidth(min: 160, ideal: 220, max: 340)
        })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1105, height: 791),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        for index in 0..<30 {
            model.isLoading = index.isMultiple(of: 2)
            model.stashFiles = (0..<(index % 5)).map {
                StashFile(path: "File\($0).swift", filename: "File\($0).swift", status: .modified)
            }
            window.setContentSize(NSSize(width: [640, 1105, 1512][index % 3], height: 700))
            try await Task.sleep(nanoseconds: 20_000_000)
            window.updateConstraintsIfNeeded()
            window.layoutIfNeeded()
            #expect(host.frame.width.isFinite && host.frame.height.isFinite)
        }
    }

    @Test func panelTaskLoadsFilesFromAnIsolatedRepository() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func git(_ arguments: [String]) async throws -> String {
            let result = await ShellExecutor.shared.execute("git", arguments: arguments, workingDirectory: directory.path)
            #expect(result.exitCode == 0)
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        _ = try await git(["init", "--quiet"])
        let file = directory.appendingPathComponent("Example.swift")
        try Data("before\n".utf8).write(to: file)
        _ = try await git(["add", "--", "Example.swift"])
        _ = try await git(["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                          "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Fixture"])
        try Data("after\n".utf8).write(to: file)
        _ = try await git(["stash", "push", "--quiet", "-m", "Fixture stash"])
        let sha = try await git(["rev-parse", "stash@{0}"])
        let model = StashDetailViewModel()
        let host = NSHostingView(rootView: StashDetailPanel(
            stash: Stash(index: 0, message: "Fixture stash", sha: sha, date: Date()),
            viewModel: model, selectedFileDiff: .constant(nil), onClose: {}, repositoryPath: directory.path))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 220, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        for _ in 0..<100 {
            if !model.isLoading && !model.stashFiles.isEmpty { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(!model.isLoading)
        #expect(model.stashFiles.map(\.path) == ["Example.swift"])
        // Inspection must not pop/apply/drop the fixture stash.
        #expect(try await git(["rev-parse", "stash@{0}"]) == sha)
        #expect(try String(contentsOf: file, encoding: .utf8) == "before\n")
    }
}
