import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-terminal-contracts-'));
const controls = ['--stale-result-control', '--unquoted-path-control', '--logical-pixel-control'].filter(flag => process.argv.includes(flag));
if (controls.length > 1) throw Error('Run controls separately');
try {
  const file = 'GitMac/Features/Terminal/Views/TerminalInputBar.swift';
  const original = await fs.readFile(path.join(root, file), 'utf8');
  let contracts = original.split('// MARK: - Terminal command contracts\n')[1];
  if (!contracts?.includes('final class TerminalSuggestionController') || !contracts.includes('enum TerminalViewport')) throw Error('Production contract boundary changed');
  if (controls[0] === '--stale-result-control') contracts = contracts.replace('guard !Task.isCancelled, generation == request else { return }', '');
  if (controls[0] === '--unquoted-path-control') contracts = contracts.replace('quoteArgument(path) + "\\n"', 'path + "\\n"');
  if (controls[0] === '--logical-pixel-control') contracts = contracts.replace('size.width * scale', 'size.width').replace('size.height * scale', 'size.height');
  await fs.writeFile(path.join(temporary, 'Contracts.swift'), `import SwiftUI\nimport AppKit\n${contracts}\n`);
  await fs.writeFile(path.join(temporary, 'Checks.swift'), String.raw`import Foundation
import SwiftUI
import Darwin
struct FixtureSuggestion { let command: String }
actor AIService {
    static let shared = AIService()
    func suggestTerminalCommands(input: String, repoPath: String?) async throws -> [FixtureSuggestion] {
        fatalError("Default provider must not run in this isolated harness")
    }
}
@MainActor final class Gate {
    var calls = 0
    var continuation: CheckedContinuation<[String], Error>?
    func ask() async throws -> [String] {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ values: [String]) {
        let pending = continuation; continuation = nil
        pending?.resume(returning: values)
    }
}
@main struct TerminalChecks {
 @MainActor static func main() async throws {
    var checks = 0, failures = 0
    func check(_ condition: Bool, _ message: String) {
        checks += 1; if !condition { failures += 1 }
        print("\(condition ? "PASS" : "FAIL") \(message)")
    }
    func settle() async { for _ in 0..<10 { await Task.yield() }; try? await Task.sleep(nanoseconds: 20_000_000) }
    func wait(_ predicate: () -> Bool) async -> Bool {
        for _ in 0..<400 { if predicate() { return true }; try? await Task.sleep(nanoseconds: 5_000_000) }
        return false
    }
    let gate = Gate()
    let controller = TerminalSuggestionController { _, _ in try await gate.ask() }
    controller.update(input: "gi", directory: "/fixture/a")
    controller.update(input: "git st", directory: "/fixture/a")
    await settle()
    check(gate.calls == 0 && !controller.isLoading, "typing and context changes never request AI")
    controller.request(input: "git st", directory: "/fixture/a")
    check(await wait { gate.calls == 1 }, "explicit request invokes the provider")
    controller.request(input: "git st", directory: "/fixture/a")
    await settle()
    check(gate.calls == 1, "duplicate request cannot overlap the active request")
    controller.update(input: "git diff", directory: "/fixture/a")
    gate.finish(["git status"])
    await settle()
    check(controller.results.isEmpty && !controller.isLoading, "late result cannot replace changed input")
    controller.request(input: "git diff", directory: "/fixture/a")
    check(await wait { gate.calls == 2 }, "second explicit request starts after invalidation")
    controller.update(input: "git diff", directory: "/fixture/b")
    gate.finish(["git diff --staged"])
    await settle()
    check(controller.results.isEmpty, "late result cannot leak into another repository")
    controller.request(input: "git status", directory: "/fixture/b")
    check(await wait { gate.calls == 3 }, "new repository can request independently")
    controller.cancel()
    gate.finish(["git status --short"])
    await settle()
    check(controller.results.isEmpty && !controller.isLoading, "dismissal cancels and rejects a late result")
    controller.request(input: "\u{0}unsafe", directory: "/fixture/b")
    check(controller.error != nil && gate.calls == 3, "NUL input is rejected before the provider")
    controller.request(input: String(repeating: "x", count: 4097), directory: "/fixture/b")
    check(controller.error != nil && gate.calls == 3, "excessive input is rejected before the provider")
    controller.request(input: "one\ntwo", directory: "/fixture/b")
    check(controller.error != nil && gate.calls == 3, "multiline input is not silently sent as one suggestion")
    let valid = TerminalSuggestionController { _, _ in ["git status", "\u{0}bad", "one\ntwo", String(repeating: "z", count: 4097), "git diff", "git log", "git branch"] }
    valid.request(input: "show status", directory: "/fixture/b")
    check(await wait { !valid.isLoading }, "explicit suggestion completes")
    check(valid.results == ["git status", "git diff", "git log"], "suggestions are bounded reviewable commands with no NUL or extra lines")
    let broken = TerminalSuggestionController { _, _ in throw NSError(domain: "Fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "fixture provider failure"]) }
    broken.request(input: "show status", directory: "/fixture/b")
    check(await wait { !broken.isLoading }, "provider error finishes loading")
    check(broken.error == "fixture provider failure", "provider failure is visible")
    let empty = TerminalSuggestionController { _, _ in [] }
    empty.request(input: "show status", directory: "/fixture/b")
    check(await wait { !empty.isLoading }, "empty provider response finishes")
    check(empty.error != nil, "empty response is not presented as a successful suggestion")

    let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    for name in ["space directory", "apostrophe's directory", "name; touch sentinel", "$(touch sentinel)", "unicode-ñ-空", "line\nbreak"] {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let command = TerminalShell.changeDirectoryCommand(directory.path)!
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-f", "-c", command + "/bin/pwd -P"]
        process.currentDirectoryURL = root
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        try process.run(); let actual = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard let resolved = realpath(directory.path, nil) else { throw CocoaError(.fileReadUnknown) }
        let physicalPath = String(cString: resolved)
        free(resolved)
        let expected = Data((physicalPath + "\n").utf8)
        if process.terminationStatus != 0 || actual != expected {
            print("PATH_DIAGNOSTIC " + String(reflecting: command) + " actual=" + String(reflecting: String(decoding: actual, as: UTF8.self)) + " expected=" + String(reflecting: String(decoding: expected, as: UTF8.self)) + " exit=\(process.terminationStatus)")
        }
        check(process.terminationStatus == 0 && actual == expected, "shell keeps path literal: " + name.replacingOccurrences(of: "\n", with: "<LF>"))
    }
    check(!FileManager.default.fileExists(atPath: root.appendingPathComponent("sentinel").path), "path interpolation cannot execute an injected command")
    check(TerminalShell.changeDirectoryCommand("relative") == nil && TerminalShell.changeDirectoryCommand("/bad\u{0}path") == nil, "invalid directory command is rejected before shell input")
    for scale: CGFloat in [1, 1.5, 2, 3] {
        let size = TerminalViewport.pixelSize(CGSize(width: 100, height: 60), scale: scale)
        check(size?.width == UInt32(100 * scale) && size?.height == UInt32(60 * scale), "native terminal dimensions use backing pixels at scale \(scale)")
    }
    check(TerminalViewport.pixelSize(CGSize(width: 10.1, height: 20.1), scale: 2)?.width == 21, "fractional backing dimensions round up")
    for size in [CGSize.zero, CGSize(width: CGFloat.nan, height: 10), CGSize(width: CGFloat.infinity, height: 10), CGSize(width: CGFloat(UInt32.max), height: 10)] {
        check(TerminalViewport.pixelSize(size, scale: 2) == nil, "invalid or overflowing terminal size is rejected")
    }
    check(TerminalViewport.pixelSize(CGSize(width: 10, height: 10), scale: 0) == nil, "invalid backing scale is rejected")
    print("TERMINAL_COMMAND_CHECKS: \(checks) checks, \(failures) failures")
    if failures > 0 { exit(1) }
 }
}
`);
  const binary = path.join(temporary, 'checks');
  execFileSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', path.join(temporary, 'Contracts.swift'), path.join(temporary, 'Checks.swift'), '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, [temporary], { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
