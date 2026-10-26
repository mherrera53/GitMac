import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-terminal-wire-'));
try {
  const source = await fs.readFile(path.join(root, 'GitMac/Features/BottomPanel/Views/BottomPanelContent.swift'), 'utf8');
  const native = source.slice(source.indexOf('// MARK: - Native Ghostty NSView'));
  const start = native.indexOf('    func sendText(_ text: String) -> Bool {');
  const end = native.indexOf('\n    func sendEnter()', start);
  if (start < 0 || end < 0) throw Error('Native writer boundary changed');
  let method = native.slice(start, end);
  if (process.argv.includes('--early-return-control')) {
    const boundary = '\n\n        // Split text and newlines';
    if (!method.includes(boundary)) throw Error('Mutation boundary changed');
    method = method.replace(boundary, '\n        return true' + boundary);
  }
  const swift = String.raw`import Foundation
import Darwin
@MainActor var events: [String] = []
@MainActor var exited = false
@MainActor func ghostty_surface_process_exited(_ surface: OpaquePointer) -> Bool { exited }
@MainActor func ghostty_surface_text(_ surface: OpaquePointer, _ text: UnsafePointer<CChar>, _ count: UInt) {
    events.append("text:" + Data(bytes: text, count: Int(count)).base64EncodedString())
}
enum Logger { static func debug(_ message: String) {} }
@MainActor final class NativeWire {
    var surface: OpaquePointer? = OpaquePointer(bitPattern: 1)
METHOD
    func sendEnter() { events.append("enter") }
}
@main struct Checks {
 @MainActor static func main() {
    let wire = NativeWire()
    var checks = 0, failures = 0
    func check(_ text: String, accepted: Bool, expected: [String], label: String) {
        events = []
        let result = wire.sendText(text)
        let passed = result == accepted && events == expected
        checks += 1; if !passed { failures += 1 }
        print("\(passed ? "PASS" : "FAIL") \(label)")
    }
    func text(_ value: String) -> String { "text:" + Data(value.utf8).base64EncodedString() }
    wire.surface = nil
    check("hello\n", accepted: false, expected: [], label: "missing surface rejects without writing")
    wire.surface = OpaquePointer(bitPattern: 1); exited = true
    check("hello\n", accepted: false, expected: [], label: "exited process rejects without writing")
    exited = false
    check("bad\u{0}text", accepted: false, expected: [], label: "NUL rejects without a partial write")
    check("\n", accepted: true, expected: ["enter"], label: "newline reaches Enter")
    check("hello\n", accepted: true, expected: [text("hello"), "enter"], label: "success writes before returning")
    check("ñ空🙂", accepted: true, expected: [text("ñ空🙂")], label: "Unicode byte length is exact")
    check("'quoted' \\ literal", accepted: true, expected: [text("'quoted' \\ literal")], label: "quotes and backslashes remain literal")
    check("\none\n\ntwo", accepted: true, expected: ["enter", text("one"), "enter", "enter", text("two")], label: "multiline ordering preserves empty lines")
    print("NATIVE_TERMINAL_WIRE_CHECKS: \(checks) checks, \(failures) failures")
    if failures > 0 { exit(1) }
 }
}
`.replace('METHOD', method);
  const file = path.join(temporary, 'NativeWireChecks.swift');
  const binary = path.join(temporary, 'checks');
  await fs.writeFile(file, swift);
  execFileSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', file, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
