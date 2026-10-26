import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const unboundedStashControl = process.argv.includes('--unbounded-stash-control');
const watcherLifecycleControl = process.argv.includes('--watcher-lifecycle-control');
const compactIndexControl = process.argv.includes('--compact-index-control');
if ([unboundedStashControl, watcherLifecycleControl, compactIndexControl].filter(Boolean).length > 1) throw Error('Run negative controls separately');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-production-suites-'));
const sourceFiles = ['Branch', 'Commit', 'Repository', 'Remote', 'Tag', 'Stash', 'Worktree', 'GitEngine', 'DiffEngine']
  .map(name => `GitMac/Core/Git/${name}.swift`)
  .concat(['GitMac/Core/Utils/ShellExecutor.swift', 'GitMac/Core/Utils/Logger.swift',
    'GitMac/Core/Utils/MemoryPressureHandler.swift', 'GitMac/Core/Utils/KeychainManager.swift', 'GitMac/App/Models/CommitFile.swift',
    'GitMac/Core/Services/AIService.swift', 'Tests/CoreRegressions/LocalAIBackendFixture.swift',
    'GitMac/Core/Utils/FileWatcher.swift', 'GitMac/Core/Utils/AppActivityManager.swift',
    'GitMac/Features/Diff/DiffCache.swift', 'GitMac/Features/Diff/DiffOptions.swift',
    'GitMac/UI/Theme/DesignTokens.swift',
    'GitMac/UI/Components/Common/UniversalResizer.swift',
    'GitMac/App/Panels/Right/StashDetailPanel.swift',
    'GitMac/App/Panels/Right/StashComponents.swift',
    'GitMac/Features/CommitGraph/Models/StashNode.swift',
    'GitMac/Features/CommitGraph/Models/GraphNode.swift',
    'GitMac/Features/CommitGraph/Models/TimelineItem.swift',
    'GitMac/Features/CommitGraph/Services/GraphLayoutEngine.swift',
    'GitMac/Features/Diff/Renderers/DiffParser.swift',
    'Tests/CoreRegressions/ThemeFixture.swift']);
const environment = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')));
await fs.mkdir(path.join(temporary, 'Templates'));
Object.assign(environment, { GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_ATTR_NOSYSTEM: '1',
  GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.hooksPath', GIT_CONFIG_VALUE_0: '/dev/null',
  GIT_TEMPLATE_DIR: path.join(temporary, 'Templates'), GIT_TERMINAL_PROMPT: '0',
  GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
  GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid' });
try {
  await fs.mkdir(path.join(temporary, 'Sources'));
  await fs.mkdir(path.join(temporary, 'Tests'));
  await fs.copyFile(path.join(root, 'Tests/CoreRegressions/Package.template.swift'), path.join(temporary, 'Package.swift'));
  for (const file of sourceFiles) {
    const destination = path.join(temporary, 'Sources', path.basename(file));
    if (watcherLifecycleControl && file.endsWith('/FileWatcher.swift')) {
      const previous = execFileSync('git', ['show', `${regressionBaseline}:${file}`], { cwd: root, encoding: 'utf8' });
      // Old source needs the framework explicitly imported in this headless
      // module. Only the disposable copy is changed, never production source.
      await fs.writeFile(destination, 'import CoreServices\n' + previous);
      console.log('NEGATIVE CONTROL: previous FileWatcher in disposable module');
    } else if (unboundedStashControl && file.endsWith('/StashDetailPanel.swift')) {
      const original = await fs.readFile(path.join(root, file), 'utf8');
      const boundary = /GeometryReader \{ geometry in\n            panelContent\n                \.frame\(width: geometry\.size\.width, height: geometry\.size\.height, alignment: \.topLeading\)\n        \}/g;
      if ([...original.matchAll(boundary)].length !== 1) throw Error('Stash mutation boundary changed');
      // Negative control: only the disposable module copy is mutated.
      await fs.writeFile(destination, original.replace(boundary, 'panelContent'));
    } else if (compactIndexControl && file.endsWith('/GraphNode.swift')) {
      const original = await fs.readFile(path.join(root, file), 'utf8');
      const boundary = 'return nodes[position].index';
      if (original.split(boundary).length !== 2) throw Error('Compact index mutation boundary changed');
      await fs.writeFile(destination, original.replace(boundary, 'return middle'));
      console.log('NEGATIVE CONTROL: sorted rank substituted for global history index in disposable copy');
    } else await fs.symlink(path.join(root, file), destination);
  }
  for (const file of await fs.readdir(path.join(root, 'Tests/GitMacTests'))) {
    if (file.endsWith('.swift')) await fs.symlink(path.join(root, 'Tests/GitMacTests', file), path.join(temporary, 'Tests', file));
  }
  execFileSync('swift', ['test', '--package-path', temporary, '--scratch-path', path.join(root, 'build/ProductionTests'), '-j', '4',
    ...(unboundedStashControl ? ['--filter', 'loadingAndLoadedContentDoNotChangeInspectorMinimumSize']
      : watcherLifecycleControl ? ['--filter', 'RepositoryScopeWatcherTests']
      : compactIndexControl ? ['--filter', 'compactSHAIndex'] : [])],
    { env: environment, stdio: 'inherit', timeout: 180000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
