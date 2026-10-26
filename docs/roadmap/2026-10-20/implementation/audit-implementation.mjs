import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '../../../..');
const files = [
  'VERSION', 'scripts/regression-baseline.mjs', 'GitMac/Core/Git/Commit.swift',
  '.gitignore', '.github/workflows/swift.yml', '.github/workflows/release.yml',
  'GitMac/App/ContentView.swift', 'GitMac/Features/Analytics/AnalyticsDashboard.swift',
  'GitMac/App/GitMacApp.swift', 'GitMac/Core/Services/AIService.swift',
  'GitMac/Core/Services/GitService.swift', 'GitMac/Core/Utils/FileWatcher.swift',
  'GitMac/Core/Utils/MemoryPressureHandler.swift',
  'GitMac/Core/Services/AI/MLXProvider.swift', 'GitMac/Features/Settings/Tabs/AISettingsTab.swift',
  'GitMac/App/Panels/Right/StashDetailPanel.swift', 'GitMac/App/Panels/Right/RightStagingPanel.swift',
  'GitMac/App/Panels/Center/DiffViewWithClose.swift',
  'GitMac/UI/Theme/DesignTokens.swift', 'GitMac/UI/Components/Common/UniversalResizer.swift',
  'GitMac/Features/BottomPanel/Views/UnifiedBottomPanel.swift', 'project.yml',
  'GitMac/Core/Git/GitEngine.swift', 'GitMac/Core/Git/Repository.swift', 'GitMac/Core/Git/DiffEngine.swift',
  'GitMac/Core/Utils/ShellExecutor.swift', 'GitMac/Core/Utils/KeychainManager.swift',
  'GitMac/Features/CloudPatches/CloudPatchService.swift',
  'GitMac/Features/CommitGraph/Services/GraphLayoutEngine.swift',
  'GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift',
  'GitMac/Features/CommitGraph/CommitGraphView.swift',
  'GitMac/Features/CommitGraph/Components/GraphMinimapView.swift',
  'GitMac/Features/CommitGraph/Components/GraphRow.swift',
  'GitMac/Features/CommitGraph/Components/GraphStashRow.swift',
  'GitMac/Features/CommitGraph/Components/UncommittedChangesRow.swift',
  'GitMac/Features/CommitGraph/Models/GraphNode.swift',
  'GitMac/UI/Components/Navigation/RepositoryTabsView.swift',
  'GitMac/Core/Git/Worktree.swift', 'GitMac/Core/Services/WorktreeManager.swift',
  'GitMac/App/Panels/Left/WorktreeComponents.swift', 'GitMac/Features/Worktrees/WorktreeListView.swift',
  'Tests/GitMacTests/MinimapLayoutTests.swift', 'Tests/GitMacTests/WorktreeHelpTests.swift',
  'Tests/GitMacTests/LocalAIPolicyTests.swift', 'Tests/CoreRegressions/LocalAIBackendFixture.swift',
  'scripts/benchmark-local-ai.mjs', 'scripts/check-memory-budget.mjs', 'scripts/test-memory-budget.mjs',
  'Tests/GitMacTests/GitMacTests.swift', 'Tests/CoreRegressions/RegressionMain.swift',
  'Tests/GitMacTests/DiffEngineTests.swift', 'Tests/GitMacTests/CredentialStorageTests.swift',
  'Tests/GitMacTests/ResponsiveLayoutTests.swift', 'Tests/GitMacTests/NativeResizerTests.swift',
  'Tests/GitMacTests/NativeStashPanelTests.swift',
  'Tests/GitMacTests/RepositoryScopeWatcherTests.swift',
  'Tests/CoreRegressions/SessionIsolationMain.swift',
  'scripts/test-session-isolation.mjs', 'scripts/profile-release-memory.mjs',
  'Tests/CoreRegressions/GitIntegrationMain.swift', 'Tests/CoreRegressions/ProcessIntegrationMain.swift',
  'Tests/CoreRegressions/ThemeFixture.swift', 'Tests/CoreRegressions/Package.template.swift',
  'scripts/verify-xcodebuild.sh', 'scripts/test-xcodebuild-gate.mjs', 'scripts/test-core-regressions.mjs',
  'scripts/test-git-integration.mjs', 'scripts/test-production-suites.mjs', 'scripts/prepare-distribution.mjs', 'scripts/finish-distribution.mjs',
  'scripts/export-xcodegen-baseline.rb', 'scripts/check-project-generation.rb',
  'GitMacUITests/SnapshotHelper.swift', 'GitMacUITests/GitMacComprehensiveScreenshots.swift',
  'GitMacUITests/GitMacScreenshotTests.swift', 'GitMacUITests/GitMacUITests.swift',
  'GitMacUITests/GitMacUITestsLaunchTests.swift',
  'scripts/test-ui-test-foundation.mjs', 'scripts/check-threat-model.mjs',
  'GitMac/Features/Settings/SettingsView.swift',
  'GitMac/Features/Settings/Components/SettingsSection.swift',
  'GitMac/Features/Settings/Components/ThemeButton.swift',
  'GitMac/Features/Settings/Tabs/GeneralSettingsTab.swift',
  'GitMac/Features/Settings/Tabs/KeyboardShortcutsTab.swift',
  'scripts/test-settings-window.mjs', 'scripts/audit-window-surfaces.mjs',
  'GitMac/Features/MergeConflict/ConflictResolverView.swift',
  'GitMac/Core/Services/WorkflowEngine.swift',
  'GitMac/UI/Theme/ThemeManager.swift', 'GitMac/UI/Components/AppTheme.swift',
  'GitMac/UI/Components/Atoms/Buttons/DSButton.swift',
  'GitMac/UI/Components/Atoms/Buttons/DSIconButton.swift',
  'GitMac/Features/Settings/Tabs/AccountsSettingsTab.swift',
  'GitMac/Features/Settings/Tabs/WorkflowSettingsTab.swift',
  'scripts/test-conflict-staging.mjs', 'scripts/test-workflow-safety.mjs',
  'scripts/test-workflow-confirmations.mjs', 'scripts/local-agents.mjs',
  'scripts/test-local-agents.mjs', 'scripts/test-custom-themes.mjs',
  'scripts/test-theme-controls.mjs', 'scripts/review-local-visuals.mjs',
  'scripts/prepare-theme-visual-review.py',
  'scripts/check-theme-account-contrast.py',
  'scripts/test-native-graph-rendering.mjs',
  'GitMac/App/Panels/Left/LeftSidebarPanel.swift',
  'GitMac/UI/Components/Xcode/XcodeSidebarNavigator.swift',
  'GitMac/Features/ConflictPrevention/ConflictPreventionView.swift',
  'GitMac/Features/Launchpad/LaunchpadView.swift',
  'GitMac/UI/Components/Terminal/AITerminalInputView.swift',
  'scripts/audit-sf-symbols.py', 'scripts/test-minimap-allocation.mjs',
  'GitMac/Features/BottomPanel/Views/BottomPanelContent.swift',
  'GitMac/Features/Terminal/Views/TerminalInputBar.swift',
  'GitMac/Features/Terminal/Core/TerminalSharedTypes.swift',
  'scripts/test-terminal-command-contracts.mjs',
  'scripts/test-native-terminal-wire.mjs',
  'scripts/check-conflict-caption-contrast.py',
];
const digest = data => crypto.createHash('sha256').update(data).digest('hex');
const tracked = new Set(execFileSync('git', ['ls-files', '-z'], { cwd: root, encoding: 'utf8' }).split('\0'));
const changes = [];
for (const file of files) {
  const content = await fs.readFile(path.join(root, file));
  const previous = tracked.has(file) ? execFileSync('git', ['show', `HEAD:${file}`], { cwd: root }) : null;
  const diff = tracked.has(file) ? execFileSync('git', ['diff', '--unified=0', '--', file], { cwd: root, encoding: 'utf8' }) : '';
  const ranges = [...diff.matchAll(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/gm)].map(match => ({
    oldStart: Number(match[1]), oldCount: Number(match[2] ?? 1), newStart: Number(match[3]), newCount: Number(match[4] ?? 1),
  }));
  if (!previous) ranges.push({ oldStart: 0, oldCount: 0, newStart: 1, newCount: content.toString().trimEnd().split('\n').length });
  changes.push({ file, beforeSHA256: previous && digest(previous), afterSHA256: digest(content), ranges });
}
const graph = JSON.parse(await fs.readFile(path.join(directory, 'mapping/source-graph.json'), 'utf8'));
const errors = [];
for (const file of files) {
  const ignored = spawnSync('git', ['check-ignore', '--quiet', '--', file], { cwd: root });
  if (ignored.status !== 1) errors.push(`Reviewed file is ignored or cannot be checked: ${file}`);
}
for (const entry of graph.files) {
  if (digest(await fs.readFile(path.join(root, entry.path))) !== entry.sha256) errors.push(`Stale current mapping: ${entry.path}`);
}
const nodes = new Set(graph.nodes.map(node => node.id));
for (const edge of graph.edges) {
  if (!nodes.has(edge.target)) errors.push(`Missing target ${edge.target}`);
  if (!nodes.has(edge.source) && !graph.files.some(file => `file:${file.path}` === edge.source)) errors.push(`Missing source ${edge.source}`);
}
const checks = [];
for (const [name, args, expectedExitCode] of [
  ['ci-gate', ['scripts/test-xcodebuild-gate.mjs'], 0],
  ['memory-budget-validator', ['scripts/test-memory-budget.mjs'], 0],
  ['core-regressions-and-models', ['scripts/test-core-regressions.mjs'], 0],
  ['production-model-mutation', ['scripts/test-core-regressions.mjs', '--mutate-model'], 1],
  ['git-and-process-integration', ['scripts/test-git-integration.mjs'], 0],
  ['production-suites-current', ['scripts/test-production-suites.mjs'], 0],
  ['compact-index-position-negative', ['scripts/test-production-suites.mjs', '--compact-index-control'], 1],
  ['session-isolation-current', ['scripts/test-session-isolation.mjs'], 0],
  ['session-isolation-current-negative', ['scripts/test-session-isolation.mjs', '--stale-refresh-control'], 1],
  ['repository-watchers-negative', ['scripts/test-production-suites.mjs', '--watcher-lifecycle-control'], 1],
  ['stash-panel-negative-control', ['scripts/test-production-suites.mjs', '--unbounded-stash-control'], 1],
  ['ui-test-fixtures', ['scripts/test-ui-test-foundation.mjs'], 0],
  ['ui-test-fixtures-negative', ['scripts/test-ui-test-foundation.mjs', '--unsafe-path-control'], 1],
  ['threat-model', ['scripts/check-threat-model.mjs'], 0],
  ['threat-model-negative', ['scripts/check-threat-model.mjs', '--omit-boundary-control'], 1],
  ['window-surfaces-inventory', ['scripts/audit-window-surfaces.mjs'], 0],
  ['settings-native-container', ['scripts/test-settings-window.mjs'], 0],
  ['settings-fixed-size-negative', ['scripts/test-settings-window.mjs', '--fixed-size-control'], 1],
  ['settings-eager-pane-negative', ['scripts/test-settings-window.mjs', '--eager-control'], 1],
  ['local-agent-contracts-current', ['scripts/test-local-agents.mjs'], 0],
  ['workflow-git-current', ['scripts/test-workflow-safety.mjs'], 0],
  ['workflow-confirmations-current', ['scripts/test-workflow-confirmations.mjs'], 0],
  ['workflow-confirmations-negative', ['scripts/test-workflow-confirmations.mjs', '--previous-source-control'], 1],
  ['custom-themes-current', ['scripts/test-custom-themes.mjs'], 0],
  ['custom-theme-toolbar-negative', ['scripts/test-custom-themes.mjs', '--previous-toolbar-control'], 1],
  ['custom-theme-tokens-negative', ['scripts/test-custom-themes.mjs', '--previous-app-theme-control'], 1],
  ['theme-controls-current', ['scripts/test-theme-controls.mjs'], 0],
  ['theme-controls-negative', ['scripts/test-theme-controls.mjs', '--previous-source-control'], 1],
  ['native-graph-current', ['scripts/test-native-graph-rendering.mjs'], 0],
  ['native-graph-dash-negative', ['scripts/test-native-graph-rendering.mjs', '--dash-control'], 1],
  ['conflict-preservation-current', ['scripts/test-conflict-staging.mjs'], 0],
  ['conflict-preservation-negative', ['scripts/test-conflict-staging.mjs', '--previous-source-control'], 1],
  ['lossless-process-negative', ['scripts/test-git-integration.mjs', '--only-process', '--binary-decoding-control'], 1],
  ['minimap-allocation-current', ['scripts/test-minimap-allocation.mjs'], 0],
  ['minimap-parser-boundaries-current', ['scripts/test-minimap-allocation.mjs', '--parser-edge-cases'], 0],
  ['minimap-allocation-negative', ['scripts/test-minimap-allocation.mjs', '--parent-lane-control'], 1],
  ['terminal-command-current', ['scripts/test-terminal-command-contracts.mjs'], 0],
  ['terminal-stale-result-negative', ['scripts/test-terminal-command-contracts.mjs', '--stale-result-control'], 1],
  ['terminal-unquoted-path-negative', ['scripts/test-terminal-command-contracts.mjs', '--unquoted-path-control'], 1],
  ['terminal-logical-pixel-negative', ['scripts/test-terminal-command-contracts.mjs', '--logical-pixel-control'], 1],
  ['terminal-native-wire-current', ['scripts/test-native-terminal-wire.mjs'], 0],
  ['terminal-native-wire-negative', ['scripts/test-native-terminal-wire.mjs', '--early-return-control'], 1],
]) {
  const result = spawnSync(process.execPath, args, { cwd: root, encoding: 'utf8', timeout: 180000 });
  await fs.writeFile(path.join(directory, `${name}.log`), `${result.stdout || ''}${result.stderr || ''}`);
  checks.push({ name, exitCode: result.status, expectedExitCode, error: result.error?.message || null });
  if (result.status !== expectedExitCode) errors.push(`${name}: unexpected exit status`);
  if (name === 'settings-fixed-size-negative' &&
      !`${result.stdout}${result.stderr}`.includes('FAIL native minimum permits compact settings window')) errors.push('Settings control must detect fixed native size');
  if (name === 'settings-eager-pane-negative' &&
      !`${result.stdout}${result.stderr}`.includes('FAIL inactive settings panes are not initialized')) errors.push('Settings control must detect eager inactive content');
  if (name === 'ui-test-fixtures-negative' &&
      !`${result.stdout}${result.stderr}`.includes('FAIL isolated launch mode and exact repository')) errors.push('UI fixture control must reject the unsafe launch mode');
  if (name === 'threat-model-negative' &&
      !`${result.stdout}${result.stderr}`.includes('15 !== 16')) errors.push('Threat model control must detect a missing boundary');
  if (name === 'production-model-mutation' &&
      !`${result.stdout}${result.stderr}`.includes('Executed 12 tests, with 1 failure')) errors.push('Mutation did not fail exactly one real XCTest');
  if (name === 'compact-index-position-negative' &&
      (!`${result.stdout}${result.stderr}`.includes('Test run with 2 tests')
       || !`${result.stdout}${result.stderr}`.includes('compactSHAIndexViewportUsesGlobalIndices() failed'))) errors.push('Compact index control must fail real lookup/viewport tests rather than compilation');
  if (name === 'stash-panel-negative-control' &&
      !`${result.stdout}${result.stderr}`.includes('host.fittingSize == minimum')) errors.push('Stash control did not detect unstable native minimum size');
  if (name === 'session-isolation-current-negative' &&
      !`${result.stdout}${result.stderr}`.includes('SESSION_CHECKS: 6 failures')) errors.push('Session control did not reproduce stale publications');
  if (name === 'repository-watchers-negative' &&
      (!`${result.stdout}${result.stderr}`.includes('Expectation failed: ownsFixture(replacement)')
       || !`${result.stdout}${result.stderr}`.includes('Expectation failed: watcher.lastSignal == nil'))) {
    errors.push('Watcher control must fail behavior assertions, not compilation');
  }
  if (name === 'workflow-confirmations-negative' &&
      (!`${result.stdout}${result.stderr}`.includes('WORKFLOW_CONFIRMATION_CHECKS: 7 scenarios, 5 failures')
       || !result.stdout.includes('SIGTRAP'))) errors.push('Workflow control must reproduce continuation misuse and behavioral failures');
  if (name === 'custom-theme-toolbar-negative' &&
      !`${result.stdout}${result.stderr}`.includes('CUSTOM_THEME_CHECKS: 92 checks, 2 failures')) errors.push('Toolbar control must reproduce both custom light appearance failures');
  if (name === 'native-graph-dash-negative' &&
      !`${result.stdout}${result.stderr}`.includes('NATIVE_GRAPH_CHECKS: 37 checks, 4 failures')) errors.push('Graph control must detect dash gaps and phase at both backing scales');
  if (name === 'conflict-preservation-negative' &&
      !`${result.stdout}${result.stderr}`.includes('CONFLICT_SAFETY_CHECKS: 16 failures')) errors.push('Conflict control must reproduce preservation and parser behavior failures');
  if (name === 'minimap-allocation-negative' &&
      !`${result.stdout}${result.stderr}`.includes('MINIMAP_ALLOCATION_CHECKS: 130 checks, 124 failures')) errors.push('Minimap control must detect altered parent lane geometry');
  if (name === 'minimap-parser-boundaries-current' &&
      !`${result.stdout}${result.stderr}`.includes('MINIMAP_ALLOCATION_CHECKS: 1145 checks, 0 failures')) errors.push('Minimap parser must complete every boundary/fuzz compatibility case');
  if (name === 'lossless-process-negative' &&
      !`${result.stdout}${result.stderr}`.includes('FAIL F13 binary capture preserves NUL, CRLF and invalid UTF8 exactly')) errors.push('Binary control must fail exact-byte preservation rather than compilation');
  for (const [control, failures] of [['terminal-stale-result-negative', 3], ['terminal-unquoted-path-negative', 6], ['terminal-logical-pixel-negative', 5]]) {
    if (name === control && !`${result.stdout}${result.stderr}`.includes(`TERMINAL_COMMAND_CHECKS: 35 checks, ${failures} failures`)) errors.push(`${control}: expected behavioral failures were not reproduced`);
  }
  if (name === 'terminal-native-wire-negative' && !`${result.stdout}${result.stderr}`.includes('NATIVE_TERMINAL_WIRE_CHECKS: 8 checks, 5 failures')) errors.push('Native terminal control must detect successful returns without writes, not compilation failure');
}
for (const negative of [false, true]) {
  const captures = negative ? 'conflict-theme-final-captures' : 'terminal-literal-input-captures';
  const name = negative ? 'conflict-caption-before-negative' : 'conflict-caption-current';
  const result = spawnSync('python3', ['scripts/check-conflict-caption-contrast.py', `docs/roadmap/2026-10-20/implementation/${captures}`],
    { cwd: root, encoding: 'utf8', timeout: 30000 });
  await fs.writeFile(path.join(directory, `${name}.log`), `${result.stdout || ''}${result.stderr || ''}`);
  checks.push({ name, exitCode: result.status, expectedExitCode: negative ? 1 : 0, error: result.error?.message || null });
  if (result.status !== (negative ? 1 : 0)) errors.push(`${name}: unexpected exit status`);
  try {
    const caption = JSON.parse(result.stdout);
    if (caption.checks !== 9 || caption.failures !== (negative ? 9 : 0)) errors.push(`${name}: incomplete or unexpected rendered caption results`);
  } catch { errors.push(`${name}: rendered caption report is missing or invalid`); }
}
for (const negative of [false, true]) {
  const symbols = spawnSync('python3', ['scripts/audit-sf-symbols.py', ...(negative ? ['--missing-symbol-control'] : [])],
    { cwd: root, encoding: 'utf8', timeout: 120000 });
  const name = negative ? 'sf-symbols-negative' : 'sf-symbols-current';
  await fs.writeFile(path.join(directory, `${name}.log`), `${symbols.stdout || ''}${symbols.stderr || ''}`);
  checks.push({ name, exitCode: symbols.status, expectedExitCode: negative ? 1 : 0, error: symbols.error?.message || null });
  if (symbols.status !== (negative ? 1 : 0)) errors.push(`${name}: unexpected exit status`);
  if (negative && !`${symbols.stdout}`.includes('gitmac.deliberately.unavailable.symbol')) errors.push('Symbol control did not detect the injected unavailable name');
}
const contrast = spawnSync('python3', ['scripts/check-theme-account-contrast.py',
  'docs/roadmap/2026-10-20/implementation/conflict-theme-final-captures'], { cwd: root, encoding: 'utf8', timeout: 30000 });
await fs.writeFile(path.join(directory, 'account-contrast-current.log'), `${contrast.stdout || ''}${contrast.stderr || ''}`);
checks.push({ name: 'account-rendered-contrast-current', exitCode: contrast.status, expectedExitCode: 0, error: contrast.error?.message || null });
if (contrast.status !== 0) errors.push('Rendered account foreground regression check failed or captures are missing');
const whitespace = spawnSync('git', ['diff', '--check', '--', ...files], { cwd: root, encoding: 'utf8' });
if (whitespace.status !== 0) errors.push(whitespace.stdout || whitespace.stderr);
const report = { date: new Date().toISOString(), head: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
  scope: 'Changed application, tests, CI and support files; current syntax-map integrity; NOT approval of all 40 roadmap tasks.',
  changes, checks, sourceMapFiles: graph.files.length, sourceMapSymbols: graph.nodes.length,
  sourceMapEdges: graph.edges.length, parserLimitedFiles: graph.report.swiftFilesWithSyntaxErrors,
  errors, passed: errors.length === 0,
  limits: ['View-model test container and engine I/O boundary are fixtures; four method bodies are extracted from production.',
    'Other regression inputs and model module compile actual production files unchanged.',
    'Production suites cover the actual linked core sources, not the full app container.',
    'AIService transport/policy is actual production; MLX weights/GPU and prompt-template boundary are fixtures in the headless module.',
    'Passing the memory-budget validator is not meeting the product budget; actual product measurements are separate and may fail.',
    'Session tests compile the complete production AppState unchanged; GitService I/O and unrelated services are explicit fixtures.',
    'Watcher tests use actual native descriptors, late creation, atomic-replace bursts and Git fixtures; no full-product multiwindow approval.',
    'UI fixture checks compile the actual fixture helper; signed UI execution and window captures are separate xcresult evidence.',
    'Settings container compiles unchanged with explicit pane/theme fixtures; native minimum/ideal size and inactive initialization are tested, not credentials or integrations.',
    'Theme and button checks compile actual palette/color/button implementations with isolated defaults; private state is exposed in same-file test extensions, not reimplemented.',
    'Workflow confirmation scenarios isolate traps in subprocesses; engine/model/executor are actual code, AI/PR/notification/branch-manager collaborators are explicit fixtures.',
    'Local visual model and signed screenshot execution are separate dated artifacts; this audit does not infer visual approval from a completed inference.',
    'Caption/account pixel checks apply to their dated, fixed native capture fixtures; candidate hashes and later terminal changes are recorded separately.',
    'Terminal contracts compile production controller/shell/geometry unchanged; AI transport is an explicit injected seam. Live Ghostty execution is a separate signed UI test.',
    'Worktree lifecycle uses real Git in isolated fixtures; manager/window concurrency is not covered by those tests.',
    'The 100k minimap fixture checks identity/layout and drawing budget, not full-product latency or memory benchmarks.',
    'Native resizer test hosts the actual production component; it is not a full-product visual/UI approval.',
    'Native stash tests host actual panel/VM, with isolated Git fixture; negative control proves minimum-size feedback, not a deterministic reproduction of the full app abort.',
    'Does not run full UI, VoiceOver, benchmarks, hosted CI, signing or notarization; distribution evidence is separate.'] };
await fs.writeFile(path.join(directory, 'verification.json'), JSON.stringify(report, null, 2) + '\n');
const rows = [['file','old_start','old_count','new_start','new_count','before_sha256','after_sha256'],
  ...changes.flatMap(change => change.ranges.map(range => [change.file, range.oldStart, range.oldCount, range.newStart, range.newCount, change.beforeSHA256 || '', change.afterSHA256]))];
await fs.writeFile(path.join(directory, 'changes.csv'), rows.map(row => row.map(value => `"${String(value).replaceAll('"','""')}"`).join(',')).join('\n') + '\n');
console.log(JSON.stringify({ ...report, changes: changes.map(change => ({ file: change.file, ranges: change.ranges })) }, null, 2));
if (errors.length) process.exitCode = 1;
