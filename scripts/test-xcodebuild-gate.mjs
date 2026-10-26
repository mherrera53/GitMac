import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

// Generated executables are test fixtures, not changes to the user's toolchain.
const fixture = mkdtempSync(join(tmpdir(), 'gitmac-ci-gate-'));
const wrapper = resolve('scripts/verify-xcodebuild.sh');
try {
  const bin = join(fixture, 'bin');
  mkdirSync(bin);
  writeFileSync(join(bin, 'xcodebuild'), '#!/bin/bash\nprintf "%s\\n" "$FIXTURE_OUTPUT"\nexit "$FIXTURE_EXIT"\n', { mode: 0o700 });
  const cases = [
    ['build success', 'build', '** BUILD SUCCEEDED **', 0, true],
    ['test success', 'test', '** TEST SUCCEEDED **', 0, true],
    ['test build success', 'build-for-testing', '** TEST BUILD SUCCEEDED **', 0, true],
    ['incomplete test build', 'build-for-testing', '** BUILD SUCCEEDED **', 0, false],
    ['misleading test build marker', 'build-for-testing', '** TEST BUILD SUCCEEDED **', 65, false],
    ['test execution success', 'test-without-building', '** TEST EXECUTE SUCCEEDED **', 0, true],
    ['incomplete test execution', 'test-without-building', '** TEST BUILD SUCCEEDED **', 0, false],
    ['misleading test execution marker', 'test-without-building', '** TEST EXECUTE SUCCEEDED **', 65, false],
    ['compiler failure', 'build', 'file.swift: error: broken\n** BUILD FAILED **', 65, false],
    ['linker failure', 'build', 'ld: symbol not found', 65, false],
    ['codesign failure', 'build', 'codesign failed', 65, false],
    ['incomplete build', 'build', 'Resolve Package Graph', 0, false],
    ['incomplete tests', 'test', '** BUILD SUCCEEDED **', 0, false],
    ['failed tests', 'test', '** TEST FAILED **', 65, false],
    ['misleading marker', 'build', '** BUILD SUCCEEDED **', 65, false],
  ];
  for (const [label, operation, output, exitCode, expected] of cases) {
    const result = spawnSync('bash', [wrapper, operation, join(fixture, 'run.log'), '-version'], {
      encoding: 'utf8',
      env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, FIXTURE_OUTPUT: output, FIXTURE_EXIT: String(exitCode) },
    });
    assert.equal(result.status === 0, expected, `${label}: ${result.stderr}`);
    if (exitCode !== 0) assert.equal(result.status, exitCode, label);
    console.log(`PASS ${label}`);
  }
} finally {
  rmSync(fixture, { recursive: true, force: true });
}
