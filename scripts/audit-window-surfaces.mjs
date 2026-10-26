import fs from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const files = execFileSync('rg', ['--files', 'GitMac', '-g', '*.swift'], { cwd: root, encoding: 'utf8' }).trim().split('\n').sort();
const surfaces = [];
for (const file of files) {
  const source = await fs.readFile(path.join(root, file), 'utf8');
  const patterns = [
    ['scene', /^\s*(?:WindowGroup|Window|Settings|MenuBarExtra)\s*(?:\(|\{)/gm],
    ['presentation', /\.(?:sheet|fullScreenCover|popover|confirmationDialog|alert)\s*\(/g],
    ['native-window', /\b(?:NSWindow|NSPanel|NSOpenPanel|NSSavePanel)\s*\(/g],
    ['large-literal-frame', /\.frame\s*\([^)]*\)/g],
  ];
  for (const [kind, pattern] of patterns) {
    for (const match of source.matchAll(pattern)) {
      if (kind === 'large-literal-frame' && ![...match[0].matchAll(/\b(?:width|height|minWidth|minHeight|maxWidth|maxHeight):\s*(\d+(?:\.\d+)?)/g)]
        .some(value => Number(value[1]) >= 300)) continue;
      surfaces.push({ file, line: source.slice(0, match.index).split('\n').length, kind,
        declaration: match[0].trim().replace(/\s+/g, ' ') });
    }
  }
}
const report = { date: new Date().toISOString(), scannedSwiftFiles: files.length,
  counts: Object.fromEntries([...new Set(surfaces.map(item => item.kind))].sort().map(kind => [kind, surfaces.filter(item => item.kind === kind).length])),
  limits: ['Lexical inventory of every non-ignored first-party Swift source under GitMac, not a runtime window count.',
    'Includes previews/examples/comments when they match; dynamic sizes and indirect presentation can require manual review.',
    'A large literal frame is a review candidate, not proof of clipping or a defect.'], surfaces };
const destination = path.join(root, 'docs/roadmap/2026-10-20/implementation/window-surfaces-current.json');
await fs.writeFile(destination, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ scannedSwiftFiles: files.length, counts: report.counts, output: destination, passed: files.length > 0 && surfaces.length > 0 }, null, 2));
if (!files.length || !surfaces.length) process.exitCode = 1;
