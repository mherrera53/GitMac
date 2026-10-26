import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Differential compatibility only. Independent Git/topology oracles and whole
// product physical footprint are separate gates, not inferred from this test.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-minimap-allocation-'));
try {
  const current = await fs.readFile(path.join(root, 'GitMac/Features/CommitGraph/Models/GraphNode.swift'), 'utf8');
  const previous = await fs.readFile(path.join(root, 'docs/roadmap/2026-10-20/implementation/experiments/minimap-allocation/GraphNode.before.swift'), 'utf8');
  function layout(source, includeNode) {
    const start = source.indexOf(includeNode ? 'struct MinimapCommitNode:' : 'enum MinimapLayout {');
    const end = source.indexOf('    static func visibleRange(');
    if (start < 0 || end <= start) throw Error('Production extraction boundary changed');
    return source.slice(start, end) + '}\n';
  }
  let actual = layout(current, true);
  if (process.argv.includes('--parent-lane-control')) {
    if (!actual.includes('parentLanes.append(lane)')) throw Error('Mutation boundary changed');
    actual = actual.replace('parentLanes.append(lane)', 'parentLanes.append(0)');
  }
  const source = path.join(temporary, 'Actual.swift');
  await fs.writeFile(source, 'import Foundation\nimport CoreGraphics\n' + actual + layout(previous, false).replace('enum MinimapLayout {', 'enum PreviousMinimapLayout {'));
  const main = path.join(temporary, 'Checks.swift');
  await fs.writeFile(main, String.raw`import Foundation
@main struct MinimapAllocationChecks {
    static func main() {
        var checks = 0, failures = 0
        func compare(_ log: String, _ label: String) {
            let actual = MinimapLayout.build(log: log), expected = PreviousMinimapLayout.build(log: log)
            checks += 1
            let equal = actual.count == expected.count && zip(actual, expected).allSatisfy { a, b in
                a.index == b.index && a.sha == b.sha && a.lane == b.lane && a.isMerge == b.isMerge
                    && a.parentIndices == b.parentIndices && a.parentLanes == b.parentLanes
            }
            if !equal { failures += 1; print("FAIL " + label) }
        }
        compare("", "empty")
        compare("\n \n\t\n", "whitespace")
        compare("a b\na b\nb\n", "duplicate rows")
        compare("merge missing present\npresent\n", "missing first parent")
        compare("merge a missing b\na root\nb root\nroot\n", "missing later parent")
        compare("a b\nb c\nc\nx y\ny\n", "independent tips reuse lanes")
        compare("a b c d\nb r\nc r\nd r\nr\n", "octopus merge")
        compare("a\tb c\nb root\nc root\nroot\na duplicate\n", "tabs and late duplicate")
        compare("único raíz\nraíz\n", "valid UTF8 slices")
        var seed: UInt64 = 0x4d494e494d4150
        func next() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1; return seed }
        for sample in 0..<120 {
            let shas = (0..<64).map { String(format: "%040x", $0 + 1) }
            let log = shas.indices.map { index in
                let parents = shas.indices.dropFirst(index + 1).filter { _ in next() % 11 == 0 }.map { shas[$0] }
                return ([shas[index]] + parents).joined(separator: " ")
            }.joined(separator: "\n")
            compare(log, "seeded DAG \(sample)")
        }
        let shas = (0..<100_000).map { String(format: "%040x", $0 + 1) }
        let log = shas.indices.map { index in index + 1 < shas.count ? shas[index] + " " + shas[index + 1] : shas[index] }.joined(separator: "\n")
        compare(log, "100k full-length SHA chain")
        if CommandLine.arguments.contains("--parser-edge-cases") {
            for input in ["a b", " a\t b \n b \t", "a b\na c\nb\nc\n",
                "a missing\nb missing\n", "a b\nb a\n", "a a\n", "a b b b\nb\n",
                "a\r\nb\r\n", "a\rb\n", "a\u{0} b\nb\n", "é e\u{301}\ne\u{301}\n",
                " \u{301} b\nb\n", "\t\u{301} b\nb\n", "a\n\u{301} b\nb\n",
                String(repeating: "a", count: 64) + " " + String(repeating: "b", count: 64) + "\n" + String(repeating: "b", count: 64)] {
                compare(input, "parser boundary " + String(reflecting: input))
            }
            let tokens = ["a", "b", "c", "d", "é", "e\u{301}", "🙂", "\u{0}", " \u{301}"]
            let separators = [" ", "\t", "  ", " \t "]
            let endings = ["\n", "\r\n", "\r", "\n\u{301}"]
            for sample in 0..<1000 {
                var input = ""
                for _ in 0..<24 {
                    let fields = (0..<Int(next() % 5)).map { _ in tokens[Int(next() % UInt64(tokens.count))] }
                    input += fields.joined(separator: separators[Int(next() % UInt64(separators.count))])
                        + endings[Int(next() % UInt64(endings.count))]
                }
                compare(input, "parser fuzz \(sample)")
            }
        }
        print("MINIMAP_ALLOCATION_CHECKS: \(checks) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
`);
  const binary = path.join(temporary, 'checks');
  execFileSync('/usr/bin/xcrun', ['swiftc', '-O', '-parse-as-library', '-swift-version', '5', source, main, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, process.argv.includes('--parser-edge-cases') ? ['--parser-edge-cases'] : [], { stdio: 'inherit', timeout: 60000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
