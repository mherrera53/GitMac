import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-git-integration-'));
const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
const sources = ['Branch', 'Commit', 'Repository', 'Remote', 'Tag', 'Stash', 'Worktree', 'GitEngine']
  .map(name => `GitMac/Core/Git/${name}.swift`)
  .concat(['GitMac/Core/Utils/ShellExecutor.swift', 'GitMac/Core/Utils/Logger.swift',
    'GitMac/App/Models/CommitFile.swift', 'Tests/CoreRegressions/ThemeFixture.swift']);
const environment = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')));
Object.assign(environment, { GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_ATTR_NOSYSTEM: '1',
  GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.hooksPath', GIT_CONFIG_VALUE_0: '/dev/null',
  GIT_TERMINAL_PROMPT: '0', GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
  GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid',
  GIT_AUTHOR_DATE: '2020-01-01T00:00:00Z', GIT_COMMITTER_DATE: '2020-01-01T00:00:00Z' });
await fs.mkdir(path.join(temporary, 'templates'));
environment.GIT_TEMPLATE_DIR = path.join(temporary, 'templates');
try {
  const compileSources = sources.map(file => path.join(root, file));
  if (process.argv.includes('--binary-decoding-control')) {
    const file = path.join(root, 'GitMac/Core/Utils/ShellExecutor.swift');
    const source = await fs.readFile(file, 'utf8');
    const anchor = 'stdoutData: captureBytes ? output.bytes : nil';
    if (source.split(anchor).length !== 2) throw Error('Binary capture mutation boundary changed');
    const control = path.join(temporary, 'ShellExecutor.swift');
    await fs.writeFile(control, source.replace(anchor, 'stdoutData: captureBytes ? Data(String(decoding: output.bytes, as: UTF8.self).utf8) : nil'));
    compileSources[compileSources.indexOf(file)] = control;
  }
  execFileSync(compiler, ['-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    '-module-name', 'GitMac', '-enable-testing', '-emit-library', '-emit-module',
    '-emit-module-path', path.join(temporary, 'GitMac.swiftmodule'), ...compileSources,
    '-o', path.join(temporary, 'libGitMac.dylib')], { stdio: 'inherit', timeout: 120000 });
  const suites = process.argv.includes('--only-git') ? ['GitIntegrationMain']
    : process.argv.includes('--only-process') ? ['ProcessIntegrationMain'] : ['GitIntegrationMain', 'ProcessIntegrationMain'];
  for (const suite of suites) {
    const executable = path.join(temporary, suite);
    execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
      '-I', temporary, '-L', temporary, '-lGitMac', '-Xlinker', '-rpath', '-Xlinker', temporary,
      path.join(root, `Tests/CoreRegressions/${suite}.swift`), '-o', executable], { stdio: 'inherit', timeout: 120000 });
    execFileSync(executable, [], { env: environment, stdio: 'inherit', timeout: 120000 });
  }
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
