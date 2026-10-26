import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-terminal-buffer-'));
try {
  const original = await fs.readFile(path.join(root, 'GitMac/Features/Terminal/Core/TerminalSharedTypes.swift'), 'utf8');
  const start = original.indexOf('@MainActor final class TerminalInputBuffer:');
  const end = original.indexOf('\nstruct AITextEditor:', start);
  if (start < 0 || end < start) throw Error('Production buffer boundary changed');
  let source = original.slice(start, end);
  if (process.argv.includes('--typing-as-replacement-control')) {
    const from = 'snapshot = Snapshot(text: value, replacementRevision: snapshot.replacementRevision)';
    if (source.split(from).length !== 2) throw Error('Mutation boundary changed');
    source = source.replace(from, 'snapshot = Snapshot(text: value, replacementRevision: snapshot.replacementRevision &+ 1)');
  }
  await fs.writeFile(path.join(temporary, 'Actual.swift'), 'import SwiftUI\n' + source);
  await fs.writeFile(path.join(temporary, 'Checks.swift'), String.raw`import Foundation
import Combine
@main struct BufferChecks {
 @MainActor static func main() {
    var checks = 0, failures = 0
    func check(_ value: Bool, _ description: String) {
      checks += 1; if !value { failures += 1 }
      print("\(value ? "PASS" : "FAIL") \(description)")
    }
    let buffer = TerminalInputBuffer()
    var observed: [TerminalInputBuffer.Snapshot] = []
    let subscription = buffer.$snapshot.sink { observed.append($0) }
    check(buffer.text.isEmpty && buffer.snapshot.replacementRevision == 0, "initial buffer has no pending replacement")
    let command = "printf 'terminal fixture\\n' | /usr/bin/tee gitmac-terminal-proof.txt"
    var typed = ""
    for character in command { typed.append(character); buffer.nativeTextChanged(typed) }
    check(buffer.text == command, "every native keystroke preserves literal command bytes")
    check(observed.allSatisfy { $0.replacementRevision == 0 }, "typing never authorizes a SwiftUI write-back")
    let count = observed.count
    buffer.nativeTextChanged(command)
    check(observed.count == count, "duplicate native notification does not publish a redundant update")
    buffer.replace("git diff --staged")
    check(buffer.text == "git diff --staged" && buffer.snapshot.replacementRevision == 1, "explicit completion replaces text with its revision atomically")
    check(observed.first(where: { $0.replacementRevision == 1 })?.text == "git diff --staged", "subscribers never see a new replacement revision with old text")
    buffer.nativeTextChanged("git diff --cached")
    check(buffer.text == "git diff --cached" && buffer.snapshot.replacementRevision == 1, "typing after completion retains its external replacement revision")
    buffer.replace("")
    check(buffer.text.isEmpty && buffer.snapshot.replacementRevision == 2, "successful submission can explicitly clear the native editor")
    buffer.replace("")
    check(buffer.snapshot.replacementRevision == 3, "explicit replacement can reassert an empty input")
    let unicode = "é e\u{301} 空 'quoted' \\path\nsecond line"
    buffer.nativeTextChanged(unicode)
    check(Data(buffer.text.utf8) == Data(unicode.utf8) && buffer.snapshot.replacementRevision == 3, "Unicode, combining characters and multiline drafts remain exact native text")
    withExtendedLifetime(subscription) {}
    print("TERMINAL_BUFFER_CHECKS: \(checks) checks, \(failures) failures")
    if failures > 0 { exit(1) }
 }
}
`);
  const binary = path.join(temporary, 'checks');
  execFileSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', path.join(temporary, 'Actual.swift'), path.join(temporary, 'Checks.swift'), '-o', binary], { stdio: 'inherit', timeout: 60000 });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 10000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
