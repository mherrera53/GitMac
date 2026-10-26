import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-core-tests-'));
const fixtureEnvironment = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')));
await fs.mkdir(path.join(temp, 'empty-template'));
Object.assign(fixtureEnvironment, {
  GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_ATTR_NOSYSTEM: '1',
  GIT_TEMPLATE_DIR: path.join(temp, 'empty-template'), GIT_CONFIG_COUNT: '1',
  GIT_CONFIG_KEY_0: 'core.hooksPath', GIT_CONFIG_VALUE_0: '/dev/null',
});
// Compile production files unchanged. Only the UI theme and engine I/O boundary
// used by the extracted view-model methods are supplied by the test harness.
const sources = [
  'GitMac/Core/Git/Branch.swift', 'GitMac/Core/Git/Commit.swift',
  'GitMac/Core/Git/Repository.swift', 'GitMac/Core/Git/Remote.swift',
  'GitMac/Core/Git/Tag.swift', 'GitMac/Core/Git/Stash.swift',
  'GitMac/Core/Utils/ShellExecutor.swift',
  'GitMac/Features/CloudPatches/CloudPatchService.swift',
  'GitMac/Features/CommitGraph/Models/GraphNode.swift',
  'GitMac/Features/CommitGraph/Models/StashNode.swift',
  'GitMac/Features/CommitGraph/Models/TimelineItem.swift',
  'GitMac/Features/CommitGraph/Services/GraphLayoutEngine.swift',
];
const baseline = process.argv.includes('--baseline');
const viewModelFile = 'GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift';
const readProduction = async file => baseline
  ? execFileSync('git', ['show', `${regressionBaseline}:${file}`], { cwd: root, encoding: 'utf8' })
  : fs.readFile(path.join(root, file), 'utf8');
const vm = await readProduction(viewModelFile);
function method(name) {
  const lines = vm.split('\n');
  const start = lines.findIndex(line => new RegExp(`^    (?:private )?func ${name}\\(`).test(line));
  if (start < 0) throw Error(`Missing production method: ${name}`);
  // Method closing brace has exactly class-member indentation.
  const end = lines.findIndex((line, index) => index > start && line === '    }');
  if (end < 0) throw Error(`Unterminated production method: ${name}`);
  return lines.slice(start, end + 1).join('\n');
}
const methods = ['loadMore', 'loadUpTo', 'buildNodes', 'buildTimeline'].map(method).join('\n');
const template = await fs.readFile(path.join(root, 'Tests/CoreRegressions/RegressionMain.swift'), 'utf8');
const testSource = path.join(temp, 'RegressionMain.swift');
await fs.writeFile(testSource, template.replace('// PRODUCTION_VIEW_MODEL_METHODS', methods));
const compiler = process.env.GITMAC_SWIFTC || execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
const sdk = process.env.GITMAC_TEST_SDK || execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
try {
  const binary = path.join(temp, 'regressions');
  const productionPaths = [];
  for (const [index, file] of sources.entries()) {
    if (baseline) {
      const copy = path.join(temp, `${index}-${path.basename(file)}`);
      await fs.writeFile(copy, await readProduction(file));
      productionPaths.push(copy);
    } else { productionPaths.push(path.join(root, file)); }
  }
  console.log(baseline ? `BASELINE: production sources at ${regressionBaseline}` : 'WORKTREE: current production sources');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0',
    '-sdk', sdk, ...productionPaths, testSource, '-o', binary], {
    stdio: ['ignore', 'inherit', 'inherit'], timeout: 120000,
  });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 60000, env: fixtureEnvironment });
  if (!baseline) {
    // Execute the existing XCTest class against a real importable production
    // model module. No duplicate/shadow model declarations are permitted.
    const modelPaths = productionPaths.slice(0, 6);
    if (process.argv.includes('--mutate-model')) {
      const original = await fs.readFile(modelPaths[1], 'utf8');
      const mutated = original.replace('self.shortSHA = String(sha.prefix(7))', 'self.shortSHA = String(sha.prefix(6))');
      if (original === mutated) throw Error('Production mutation anchor not found');
      const mutatedPath = path.join(temp, 'MutatedCommit.swift');
      await fs.writeFile(mutatedPath, mutated);
      modelPaths[1] = mutatedPath;
      console.log('NEGATIVE CONTROL: temporary production model mutation; worktree untouched');
    }
    execFileSync(compiler, ['-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
      '-module-name', 'GitMac', '-enable-testing', '-emit-library', '-emit-module',
      '-emit-module-path', path.join(temp, 'GitMac.swiftmodule'), ...modelPaths,
      '-o', path.join(temp, 'libGitMac.dylib')], { stdio: 'inherit', timeout: 120000 });
    const xctestMain = path.join(temp, 'main.swift');
    await fs.writeFile(xctestMain, 'import XCTest\nlet suite = GitMacTests.defaultTestSuite\nprecondition(suite.testCaseCount > 0, "No model tests discovered")\nsuite.run()\nexit(suite.testRun?.hasSucceeded == true ? 0 : 1)\n');
    const xctestBinary = path.join(temp, 'model-tests');
    const developer = execFileSync('xcode-select', ['-p'], { encoding: 'utf8' }).trim();
    const testFrameworks = path.join(developer, 'Platforms/MacOSX.platform/Developer/Library/Frameworks');
    const testLibraries = path.join(developer, 'Platforms/MacOSX.platform/Developer/usr/lib');
    execFileSync(compiler, ['-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
      '-F', testFrameworks, '-Xlinker', '-rpath', '-Xlinker', testFrameworks,
      '-I', testLibraries, '-L', testLibraries, '-Xlinker', '-rpath', '-Xlinker', testLibraries,
      '-I', temp, '-L', temp, '-lGitMac', '-Xlinker', '-rpath', '-Xlinker', temp,
      path.join(root, 'Tests/GitMacTests/GitMacTests.swift'), xctestMain, '-o', xctestBinary], {
      stdio: 'inherit', timeout: 120000,
    });
    execFileSync(xctestBinary, [], { stdio: 'inherit', timeout: 60000 });
  }
} finally {
  await fs.rm(temp, { recursive: true, force: true });
}
