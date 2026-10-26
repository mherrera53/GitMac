import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { evaluateFootprint } from './check-memory-budget.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const count = Number(process.argv[2] || 1000);
const rendererArgument = process.argv.find(value => value.startsWith('--graph-renderer='));
const renderer = rendererArgument?.slice('--graph-renderer='.length);
if (renderer && !['native', 'canvas'].includes(renderer)) throw Error('Choose native or canvas graph renderer');
if (![1000, 10000, 100000].includes(count)) throw Error('Choose a controlled fixture: 1000, 10000 or 100000');
const evidence = path.join(root, 'docs/roadmap/2026-10-20/implementation');
const buildLogArgument = process.argv.find(value => value.startsWith('--build-log='));
const buildLog = buildLogArgument ? path.resolve(root, buildLogArgument.slice('--build-log='.length))
  : path.join(evidence, 'performance-fixture-release.log');
if (!(await fs.readFile(buildLog, 'utf8')).includes('** BUILD SUCCEEDED **')) throw Error('Completed performance Release required');
const candidateArgument = process.argv.find(value => value.startsWith('--candidate-directory='));
let app = path.join(root, 'build/PerformanceProducts/GitMac.app');
if (candidateArgument) {
  const directory = await fs.realpath(path.resolve(root, candidateArgument.slice('--candidate-directory='.length)));
  const allowed = await fs.realpath(path.join(root, 'build/DistributionCandidates'));
  if (!directory.startsWith(allowed + path.sep)) throw Error('Only a separate distribution candidate may be profiled');
  const preparation = JSON.parse(await fs.readFile(path.join(directory, 'preparation.json'), 'utf8'));
  app = path.join(directory, 'GitMac.app');
  if (await fs.realpath(app) !== app || preparation.app !== app || preparation.buildLog !== buildLog
      || !preparation.signatureVerified || preparation.bundleIdentifier !== 'com.gitmac.app') throw Error('Candidate preparation does not match');
  const signedHash = createHash('sha256').update(await fs.readFile(path.join(app, 'Contents/MacOS/GitMac'))).digest('hex');
  if (signedHash !== preparation.signedBinarySHA256) throw Error('Candidate binary changed after signing');
  execFileSync('/usr/bin/codesign', ['--verify', '--deep', '--strict', app], { timeout: 30000, stdio: 'pipe' });
}
if (!candidateArgument && (await fs.stat(buildLog)).mtimeMs < (await fs.stat(path.join(app, 'Contents/MacOS/GitMac'))).mtimeMs) {
  throw Error('Build log predates the executable; pass --build-log=PATH for the completed matching Release');
}
const identifier = execFileSync('/usr/bin/plutil', ['-extract', 'CFBundleIdentifier', 'raw', '-o', '-', path.join(app, 'Contents/Info.plist')], { encoding: 'utf8' }).trim();
if (identifier !== (candidateArgument ? 'com.gitmac.app' : 'com.gitmac.performance')) throw Error('Unexpected fixture application domain');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-memory-fixture-'));
const repository = path.join(temporary, 'repository');
const templates = path.join(temporary, 'templates');
await fs.mkdir(repository); await fs.mkdir(templates);
const environment = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')));
Object.assign(environment, { GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null',
  GIT_ATTR_NOSYSTEM: '1', GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.hooksPath',
  GIT_CONFIG_VALUE_0: '/dev/null', GIT_TEMPLATE_DIR: templates, GIT_TERMINAL_PROMPT: '0' });
const git = (...args) => execFileSync('/usr/bin/git', args, { cwd: repository, env: environment, encoding: 'utf8', timeout: 60000 });
let child;
let windowProbe;
let terminated = false;
try {
  git('init', '--quiet');
  const importer = spawn('/usr/bin/git', ['fast-import', '--quiet'], { cwd: repository, env: environment, stdio: ['pipe', 'ignore', 'pipe'] });
  let importError = '';
  importer.stderr.on('data', bytes => { importError += bytes.toString(); });
  const imported = once(importer, 'close');
  for (let index = 1; index <= count; index++) {
    const message = `Fixture ${index}\n`;
    const data = `commit refs/heads/main\nmark :${index}\ncommitter Fixture <fixture@example.invalid> ${1577836800 + index} +0000\ndata ${Buffer.byteLength(message)}\n${message}`
      + (index > 1 ? `from :${index - 1}\n` : 'M 100644 inline README.txt\ndata 8\nfixture\n') + '\n';
    if (!importer.stdin.write(data)) await once(importer.stdin, 'drain');
  }
  importer.stdin.end('done\n');
  const [status] = await imported;
  if (status !== 0) throw Error('Fixture fast-import failed: ' + importError);
  git('symbolic-ref', 'HEAD', 'refs/heads/main');
  // This exact repository was created above, is private and has no user data.
  git('reset', '--hard', 'HEAD');
  if (Number(git('rev-list', '--count', 'HEAD').trim()) !== count) throw Error('Fixture oracle mismatch');
  const executable = path.join(app, 'Contents/MacOS/GitMac');
  const executableSHA256 = createHash('sha256').update(await fs.readFile(executable)).digest('hex');
  const stem = `performance-memory-${count}-${Date.now()}`;
  let windowGeometry = null;
  let windowProbeBinary;
  if (process.argv.includes('--window-geometry')) {
    // Compile before app launch so the observer does not miss initial windows.
    const probeSource = path.join(temporary, 'WindowGeometry.swift');
    windowProbeBinary = path.join(temporary, 'window-geometry');
    await fs.writeFile(probeSource, `import Foundation
import CoreGraphics
@main struct WindowGeometry {
    static func main() throws {
        guard let pid = Int(CommandLine.arguments[1]), pid > 0 else { exit(64) }
        let started = Date()
        var frames: [[String: Any]] = []
        var previous = Data()
        repeat {
            let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            let owned = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int) == pid }.map { item in
                ["windowID": item[kCGWindowNumber as String] ?? 0,
                 "bounds": item[kCGWindowBounds as String] ?? [:],
                 "layer": item[kCGWindowLayer as String] ?? 0,
                 "onScreen": item[kCGWindowIsOnscreen as String] ?? false] as [String: Any]
            }
            let data = try JSONSerialization.data(withJSONObject: owned, options: [.sortedKeys])
            if data != previous {
                frames.append(["elapsedMilliseconds": Int(Date().timeIntervalSince(started) * 1000), "windows": owned])
                previous = data
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date().timeIntervalSince(started) < 12
        let result: [String: Any] = ["pid": pid, "coordinateUnit": "screen points", "intervalMilliseconds": 50,
            "scope": "Only windows owned by the exact fixture PID; no titles, screenshots or other-process geometry emitted", "frames": frames]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted])
        FileHandle.standardOutput.write(data)
    }
}
`);
    execFileSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', probeSource, '-o', windowProbeBinary],
      { timeout: 60000, stdio: 'inherit' });
    windowGeometry = path.join(evidence, stem + '-windows.json');
  }
  const applicationLog = path.join(evidence, stem + '-app.log');
  const stdout = await fs.open(applicationLog, 'wx');
  child = spawn(executable, ['--performance-fixture', repository, '-ApplePersistenceIgnoreState', 'YES',
    ...(renderer === 'canvas' ? ['--canvas-graph-control'] : [])],
    { env: environment, stdio: ['ignore', stdout.fd, stdout.fd] });
  child.on('error', () => {});
  await stdout.close();
  let windowProbeFinished;
  if (windowProbeBinary) {
    const geometryOutput = await fs.open(windowGeometry, 'wx');
    windowProbe = spawn(windowProbeBinary, [String(child.pid)], { stdio: ['ignore', geometryOutput.fd, 'pipe'] });
    windowProbeFinished = once(windowProbe, 'close');
    await geometryOutput.close();
  }
  let allocationTrace = null;
  if (process.argv.includes('--trace-startup')) {
    allocationTrace = path.join(evidence, stem + '-allocations.trace');
    // Diagnostic instrumentation changes overhead: do not use this run as a
    // before/after performance approval. Only attach to the child just owned.
    const traced = spawn('/usr/bin/xcrun', ['xctrace', 'record', '--template', 'Allocations',
      '--attach', String(child.pid), '--time-limit', '8s', '--output', allocationTrace, '--no-prompt'],
      { stdio: ['ignore', 'pipe', 'pipe'], timeout: 25000 });
    let traceOutput = '';
    traced.stdout.on('data', data => { traceOutput += data; });
    traced.stderr.on('data', data => { traceOutput += data; });
    const [traceStatus] = await once(traced, 'close');
    await fs.writeFile(path.join(evidence, stem + '-allocations.log'), traceOutput, { flag: 'wx' });
    if (traceStatus !== 0) throw Error('Allocation trace failed; diagnostic log preserved');
  }
  let events = [];
  const isReady = () => events.some(item => item.gitmacPerformance === 'repository-loaded')
    && events.some(item => item.gitmacPerformance === 'branches-loaded' && item.counts?.local >= 1)
    && events.some(item => item.gitmacPerformance === 'graph-loaded' && item.counts?.commits >= 100)
    && events.some(item => item.gitmacPerformance === 'minimap-loaded' && item.counts?.commits === count)
    && (!renderer || events.some(item => item.gitmacPerformance === `graph-${renderer}-commit-drawn`
      && item.counts?.width > 0 && item.counts?.height > 0));
  const readyDeadline = Date.now() + 30000;
  while (Date.now() < readyDeadline) {
    if (child.exitCode !== null || child.signalCode) break;
    const log = await fs.readFile(applicationLog, 'utf8');
    events = log.split('\n').filter(line => line.startsWith('{')).flatMap(line => {
      try { return [JSON.parse(line)]; } catch { return []; }
    });
    if (isReady()) break;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  if (!isReady()) {
    throw Error('Required repository/branches/graph/minimap readiness not observed; refuse an incomplete-screen memory claim. Log: ' + applicationLog);
  }
  if (!child.pid || child.exitCode !== null || child.signalCode) throw Error('Fixture app exited before measurement');
  const raw = path.join(evidence, stem + '-footprint.json');
  execFileSync('/usr/bin/footprint', ['-p', String(child.pid), '-f', 'bytes',
    ...(process.argv.includes('--detailed-samples') ? [] : ['--noCategories']),
    '--sample', '1', '--sample-duration', '20', '--json', raw], { timeout: 30000, stdio: 'ignore' });
  const result = evaluateFootprint(JSON.parse(await fs.readFile(raw, 'utf8')), child.pid);
  if (windowProbeFinished) {
    const [status] = await windowProbeFinished;
    if (status !== 0) throw Error('Window geometry observer failed; do not approve incomplete diagnostics');
  }
  const regions = path.join(evidence, stem + '-vmmap.log');
  await fs.writeFile(regions, execFileSync('/usr/bin/vmmap', ['-summary', String(child.pid)],
    { encoding: 'utf8', timeout: 15000 }), { flag: 'wx' });
  const categories = path.join(evidence, stem + '-categories.log');
  await fs.writeFile(categories, execFileSync('/usr/bin/footprint', ['-p', String(child.pid), '-f', 'bytes'],
    { encoding: 'utf8', timeout: 15000 }), { flag: 'wx' });
  let heapDiagnostic = null;
  if (process.argv.includes('--heap-diagnostic')) {
    heapDiagnostic = path.join(evidence, stem + '-heap.log');
    // Inspect only the process spawned above, after its ordinary sample. This
    // diagnostic is kept separate from uninstrumented budget comparisons.
    try {
      await fs.writeFile(heapDiagnostic, execFileSync('/usr/bin/heap', ['--sortBySize', '--showSizes', String(child.pid)],
        { encoding: 'utf8', timeout: 45000, maxBuffer: 16 * 1024 * 1024 }), { flag: 'wx' });
    } catch (error) {
      await fs.writeFile(heapDiagnostic, `${error.stdout || ''}${error.stderr || ''}\n${error.message}`, { flag: 'wx' });
      throw Error('Heap diagnostic failed; log preserved: ' + heapDiagnostic);
    }
  }
  const report = { date: new Date().toISOString(), ...result, fixtureCommits: count,
    fixture: 'Linear history with inherited small tree; no remote, hooks, user Git config or AI',
    app, executableSHA256, allocationTrace, windowGeometry, heapDiagnostic, requestedGraphRenderer: renderer ?? null,
    instrumentedDiagnosticOnly: allocationTrace !== null || windowGeometry !== null || heapDiagnostic !== null,
    bundleIdentifier: identifier, buildLog, evidence: raw, regions, categories, events,
    applicationRunningAfterSample: child.exitCode === null && !child.signalCode,
    limits: ['Fixture window only; not screenshot/VoiceOver approval, all actions, p95 or subprocess accounting.',
      'Lifetime peak includes startup; weights and original user session are not loaded.'] };
  await fs.writeFile(path.join(evidence, stem + '-result.json'), JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify(report, null, 2));
  if (!report.passed || !report.applicationRunningAfterSample) process.exitCode = 1;
} finally {
  if (windowProbe?.pid && windowProbe.exitCode === null && !windowProbe.signalCode) {
    windowProbe.kill('SIGTERM');
  }
  if (child?.pid && child.exitCode === null && !child.signalCode) {
    const expected = path.join(app, 'Contents/MacOS/GitMac');
    const actual = execFileSync('/bin/ps', ['-p', String(child.pid), '-o', 'comm='], { encoding: 'utf8' }).trim();
    if (actual !== expected) throw Error('Fixture process identity changed; refuse termination');
    const exited = once(child, 'exit');
    // Only the newly spawned isolated fixture process; never the installed app.
    child.kill('SIGTERM');
    terminated = await Promise.race([exited.then(() => true), new Promise(resolve => setTimeout(() => resolve(false), 5000))]);
  } else { terminated = true; }
  if (terminated) await fs.rm(temporary, { recursive: true, force: true });
  else { child.unref(); console.error('Fixture preserved because owned app did not exit: ' + temporary); process.exitCode = 1; }
}
