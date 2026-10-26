import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-ui-foundation-'));
try {
  const source = await fs.readFile(path.join(root, 'GitMacUITests/SnapshotHelper.swift'), 'utf8');
  const repository = source.split('final class UITestRepository {')[1]?.split('/// Screenshot infrastructure')[0];
  if (!repository?.trimEnd().endsWith('}')) throw Error('UI fixture extraction boundary changed');
  let actualClass = 'final class UITestRepository {' + repository;
  if (process.argv.includes('--unsafe-path-control')) {
    actualClass = actualClass.replace('"--performance-fixture"', '"-demo-mode"');
    console.log('NEGATIVE CONTROL: fixture flag changed only in disposable copy');
  }
  for (const file of await fs.readdir(path.join(root, 'GitMacUITests'))) {
    if (!file.endsWith('.swift')) continue;
    const ignored = spawnSync('git', ['check-ignore', '--quiet', '--', `GitMacUITests/${file}`], { cwd: root });
    assert.equal(ignored.status, 1, `${file}: UI test source must remain eligible for version control`);
    const text = await fs.readFile(path.join(root, 'GitMacUITests', file), 'utf8');
    assert(!text.includes('/Users/'), `${file}: personal path in UI automation`);
    assert(!text.includes('"-demo-mode"'), `${file}: unsafe session launch`);
    assert(text.includes('UITestRepository') || text.includes('engine.launchApp()'), `${file}: missing fixture wiring`);
    const launches = [...text.matchAll(/app\.launchArguments\s*=\s*(?:fixture|repository)\.launchArguments/g)].length;
    const environments = [...text.matchAll(/app\.launchEnvironment\s*=\s*(?:fixture|repository)\.launchEnvironment/g)].length;
    assert.equal(launches, environments, `${file}: isolate Git environment in the launched app, not only fixture creation`);
  }
  const harness = `import Foundation
${actualClass}
@main struct FixtureCheck {
  static func main() throws {
    var fixture: UITestRepository? = try UITestRepository()
    let root = fixture!.root
    let repository = fixture!.repository
    func require(_ value: Bool, _ description: String) {
      guard value else { fixture = nil; print("FAIL " + description); exit(1) }
      print("PASS " + description)
    }
    func git(_ arguments: [String]) throws -> String {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
      process.arguments = arguments
      process.currentDirectoryURL = repository
      var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("GIT_") }
      environment["GIT_CONFIG_NOSYSTEM"] = "1"; environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
      process.environment = environment
      let output = Pipe(); process.standardOutput = output; process.standardError = output
      try process.run()
      let bytes = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
      require(process.terminationStatus == 0, "Git oracle completed")
      return String(decoding: bytes, as: UTF8.self)
    }
    require(fixture!.launchArguments().prefix(2) == ["--performance-fixture", repository.path][...], "isolated launch mode and exact repository")
    require(fixture!.launchArguments(style: "Dark").contains("Dark"), "explicit appearance retained")
    require(fixture!.launchEnvironment()["GIT_CONFIG_GLOBAL"] == root.appendingPathComponent("ui.gitconfig").path,
            "launched app cannot read or overwrite real global Git config")
    require(try String(contentsOf: root.appendingPathComponent("ui.gitconfig"), encoding: .utf8).contains("ui-fixture@example.invalid"),
            "Git settings receives synthetic identity")
    require(try git(["branch", "--show-current"]) == "main\\n", "deterministic branch")
    require(try git(["log", "-1", "--format=%an <%ae>"]) == "Fixture <fixture@example.invalid>\\n", "inherited identity cannot leak into fixture")
    require(try git(["show", "HEAD:README.md"]) == "# UI fixture\\n", "committed blob oracle")
    require(try git(["status", "--porcelain"]) == " M README.md\\n", "intentional unstaged example")
    require(try git(["remote"]).isEmpty, "no remote can receive a push")
    fixture = nil
    require(!FileManager.default.fileExists(atPath: root.path), "only owned fixture cleaned after release")
    print("UI_FIXTURE_CHECKS_PASSED")
  }
}
`;
  const main = path.join(temporary, 'FixtureCheck.swift');
  await fs.writeFile(main, harness);
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const binary = path.join(temporary, 'fixture-check');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    main, '-o', binary], { stdio: 'inherit', timeout: 60000 });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 30000, env: { ...process.env,
    GIT_TEMPLATE_DIR: '/does-not-exist/gitmac-adversarial-template', GIT_AUTHOR_NAME: 'UNSAFE INHERITED',
    GIT_COMMITTER_EMAIL: 'unsafe@example.invalid', GIT_CONFIG_GLOBAL: '/does-not-exist/gitmac-adversarial-config' } });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
