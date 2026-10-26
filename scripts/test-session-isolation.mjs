import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-session-isolation-'));
try {
  const file = 'GitMac/App/GitMacApp.swift';
  const source = await fs.readFile(path.join(root, file), 'utf8');
  let state = source.split('// MARK: - App State\n')[1]?.split('// MARK: - Data Models')[0];
  if (!state?.includes('class AppState')) throw Error('Production AppState boundary missing');
  if (process.argv.includes('--stale-refresh-control')) {
    const original = execFileSync('git', ['show', `${regressionBaseline}:${file}`], { cwd: root, encoding: 'utf8' });
    const extract = text => text.match(/^    func refresh\(\) async \{[\s\S]*?^    \}/m)?.[0];
    const before = extract(original), after = extract(state);
    if (!before || !after || before === after) throw Error('Negative control missing');
    state = state.replace(after, before);
    console.log('NEGATIVE CONTROL: old refresh only, in disposable copy; current app untouched');
  }
  const fixture = await fs.readFile(path.join(root, 'Tests/CoreRegressions/SessionIsolationMain.swift'), 'utf8');
  const main = path.join(temporary, 'SessionIsolationMain.swift');
  await fs.writeFile(main, fixture.replace('// PRODUCTION_APP_STATE', state));
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const models = ['Branch', 'Commit', 'Repository', 'Remote', 'Tag', 'Stash'].map(name => path.join(root, `GitMac/Core/Git/${name}.swift`));
  const binary = path.join(temporary, 'session-tests');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0',
    '-sdk', sdk, ...models, path.join(root, 'GitMac/Core/Utils/MemoryPressureHandler.swift'), main, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
