import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-conflict-safety-'));
try {
  const file = 'GitMac/Features/MergeConflict/ConflictResolverView.swift';
  const original = process.argv.includes('--previous-source-control')
    ? execFileSync('git', ['show', `${regressionBaseline}:${file}`], { cwd: root, encoding: 'utf8' })
    : await fs.readFile(path.join(root, file), 'utf8');
  const vm = original.split('// MARK: - View Model\n')[1]?.split('// MARK: - Subviews')[0];
  if (!vm?.includes('class ConflictResolverViewModel') || !vm.includes('struct ConflictParser')) throw Error('Production extraction boundary changed');
  const recoveryProof = process.argv.includes('--previous-source-control') ? '' : String.raw`
    if let recovery = vm.recoveryURL {
      let original = try Data(contentsOf: recovery.appendingPathComponent("working-copy.original"))
      let proposed = try Data(contentsOf: recovery.appendingPathComponent("resolution.proposed"))
      let oursCopy = try Data(contentsOf: recovery.appendingPathComponent("stage-2.original"))
      let theirsCopy = try Data(contentsOf: recovery.appendingPathComponent("stage-3.original"))
      let baseCopy = try Data(contentsOf: recovery.appendingPathComponent("stage-1.original"))
      check(original == originalWorkingCopy && proposed == Data("resolved\n".utf8), "recovery stores exact original and proposed bytes")
      check(oursCopy == Data("ours\n".utf8) && theirsCopy == Data("theirs\n".utf8) && baseCopy == Data("base\n".utf8),
            "recovery preserves all three Git index versions")
      let folderMode = try FileManager.default.attributesOfItem(atPath: recovery.path)[.posixPermissions] as? NSNumber
      let fileMode = try FileManager.default.attributesOfItem(atPath: recovery.appendingPathComponent("working-copy.original").path)[.posixPermissions] as? NSNumber
      check(folderMode?.intValue == 0o700 && fileMode?.intValue == 0o600, "recovery copies have private filesystem permissions")
    } else { check(false, "successful resolution exposes its recovery location") }
    let link = fixture.appendingPathComponent("unsafe-link.txt")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fileURL)
    do {
      _ = try await ConflictResolutionSnapshot.capture(repositoryPath: fixture.path, path: "unsafe-link.txt")
      check(false, "symbolic links cannot be opened as writable text conflicts")
    } catch { check(true, "symbolic links cannot be opened as writable text conflicts") }
    do {
      _ = try await ConflictResolutionSnapshot.capture(repositoryPath: fixture.path, path: "../escape.txt")
      check(false, "paths outside the worktree are rejected before reading")
    } catch { check(true, "paths outside the worktree are rejected before reading") }
`;
  const operationProof = process.argv.includes('--previous-source-control') ? '' : String.raw`
    let markerContinuation = await vm.continueMerge()
    check(!markerContinuation && vm.error?.contains("markers") == true, "continuation refuses conflict markers staged by another tool")
    let unsafeLink = fixture.appendingPathComponent("unsafe-link.txt")
    if FileManager.default.fileExists(atPath: unsafeLink.path) { try FileManager.default.removeItem(at: unsafeLink) }
    _ = try await git(["merge", "--abort"])
    let rootOID = try await git(["rev-list", "--max-parents=0", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
    _ = try await git(["merge", "other"], expected: 1)
    await vm.loadConflicts(from: repository)
    check(vm.operation == .merge, "active merge is detected from the actual git directory")
    vm.conflictFiles[0].isResolved = true
    let premature = await vm.continueMerge()
    check(!premature && vm.error != nil, "Git index overrides a falsely resolved UI flag")
    await vm.loadConflicts(from: repository)
    await vm.resolveWithCustom(vm.conflictFiles[0], content: "resolved operation\n")
    let beforeHook = try await git(["rev-parse", "HEAD"])
    let hooks = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GIT_CONFIG_VALUE_0"]!)
    let hook = hooks.appendingPathComponent("pre-commit")
    try "#!/bin/sh\nprintf 'fixture-hook-refusal\\n' >&2\nexit 1\n".write(to: hook, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
    let refusedHook = await vm.continueMerge()
    let afterHook = try await git(["rev-parse", "HEAD"])
    check(!refusedHook && vm.error?.contains("fixture-hook-refusal") == true && afterHook == beforeHook,
          "hook failure is visible and cannot create or bypass a commit")
    try FileManager.default.removeItem(at: hook)
    let continued = await vm.continueMerge()
    let mergeParents = try await git(["rev-list", "--parents", "-n", "1", "HEAD"])
    check(continued && mergeParents.split(whereSeparator: \.isWhitespace).count == 3,
          "merge continuation creates the actual two-parent merge")
    let mergedOID = try await git(["rev-parse", "HEAD"])
    let duplicate = await vm.continueMerge()
    let duplicateOID = try await git(["rev-parse", "HEAD"])
    check(!duplicate && duplicateOID == mergedOID, "a second continuation cannot create an unrelated commit")

    _ = try await git(["checkout", "-b", "rebase-topic", rootOID])
    try "topic change\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "topic message"])
    _ = try await git(["rebase", "main"], expected: 1)
    await vm.loadConflicts(from: repository)
    check(vm.operation == .rebase && vm.conflictFiles.first?.oursContent == "resolved operation\n"
          && vm.conflictFiles.first?.theirsContent == "topic change\n", "rebase identifies the checked-out base and replayed sides correctly")
    await vm.resolveWithCustom(vm.conflictFiles[0], content: "rebased operation\n")
    let rebased = await vm.continueMerge()
    let rebaseBranch = try await git(["branch", "--show-current"])
    check(rebased && vm.operation == .none && rebaseBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "rebase-topic",
          "rebase continues its sequencer instead of creating a merge commit")

    _ = try await git(["checkout", "main"])
    _ = try await git(["checkout", "-b", "pick-source"])
    try "pick source\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "pick message"])
    let pickOID = try await git(["rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
    _ = try await git(["checkout", "main"])
    try "main changed\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "main change"])
    _ = try await git(["cherry-pick", pickOID], expected: 1)
    await vm.loadConflicts(from: repository)
    check(vm.operation == .cherryPick, "cherry-pick operation is detected")
    await vm.resolveWithCustom(vm.conflictFiles[0], content: "picked resolution\n")
    let picked = await vm.continueMerge()
    let pickMessage = try await git(["log", "-1", "--format=%s"])
    check(picked && pickMessage.trimmingCharacters(in: .whitespacesAndNewlines) == "pick message", "cherry-pick continuation preserves its prepared message")
    _ = try await git(["revert", "--no-edit", pickOID], expected: 1)
    await vm.loadConflicts(from: repository)
    check(vm.operation == .revert, "revert operation is detected")
    await vm.resolveWithCustom(vm.conflictFiles[0], content: "reverted resolution\n")
    let reverted = await vm.continueMerge()
    check(reverted && vm.operation == .none, "revert continues the correct sequencer")

    _ = try await git(["checkout", "-b", "abort-source"])
    try "abort incoming\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "abort incoming"])
    _ = try await git(["checkout", "main"])
    try "abort current\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "abort current"])
    _ = try await git(["merge", "abort-source"], expected: 1)
    let abortOriginal = try Data(contentsOf: fileURL)
    let localFile = fixture.appendingPathComponent("keep-local.txt")
    try Data("untracked local work\n".utf8).write(to: localFile)
    await vm.loadConflicts(from: repository)
    let blockedAbort = await vm.abortMerge()
    let keptLocal = try Data(contentsOf: localFile)
    check(!blockedAbort && keptLocal == Data("untracked local work\n".utf8)
          && FileManager.default.fileExists(atPath: fixture.appendingPathComponent(".git/MERGE_HEAD").path),
          "abort refuses additional local work without resetting or deleting it")
    try FileManager.default.removeItem(at: localFile)
    let aborted = await vm.abortMerge()
    let afterAbort = try Data(contentsOf: fileURL)
    let abortBackup = try vm.recoveryURL.map { try Data(contentsOf: $0.appendingPathComponent("working-copy.original")) }
    check(aborted && afterAbort == Data("abort current\n".utf8) && abortBackup == abortOriginal,
          "supported abort restores Git state only after preserving the conflicted bytes")

    try "stash local\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["stash", "push", "--quiet"])
    try "after stash\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "after stash"])
    _ = try await git(["stash", "pop"], expected: 1)
    await vm.loadConflicts(from: repository)
    check(vm.operation == .none && vm.conflictFiles.count == 1, "stash conflicts are detected without inventing a merge operation")
    await vm.resolveWithCustom(vm.conflictFiles[0], content: "stash resolution\n")
    let stashHead = try await git(["rev-parse", "HEAD"])
    let stashContinued = await vm.continueMerge()
    let stashAfter = try await git(["rev-parse", "HEAD"])
    check(!stashContinued && stashAfter == stashHead, "resolving a stash cannot automatically create a commit")
    // Only this disposable fixture is reset; no user files or repositories.
    _ = try await git(["reset", "--hard", "HEAD"])
    let manyPaths = (0..<32).map { "many-\($0).txt" }
    for (index, name) in manyPaths.enumerated() {
      try "base-\(index)\n".write(to: fixture.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    _ = try await git(["add", "--"] + manyPaths)
    _ = try await git(["commit", "-m", "many base"])
    _ = try await git(["checkout", "-b", "many-incoming"])
    for (index, name) in manyPaths.enumerated() {
      try String(repeating: "incoming-\(index) " + String(repeating: "y", count: 400) + "\n", count: 128)
        .write(to: fixture.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    _ = try await git(["commit", "-am", "many incoming"])
    _ = try await git(["checkout", "main"])
    for (index, name) in manyPaths.enumerated() {
      try String(repeating: "current-\(index) " + String(repeating: "x", count: 400) + "\n", count: 128)
        .write(to: fixture.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    _ = try await git(["commit", "-am", "many current"])
    _ = try await git(["merge", "many-incoming"], expected: 1)
    await vm.loadConflicts(from: repository)
    let retained = vm.conflictFiles.compactMap(\.snapshot)
    let retainedBytes = retained.reduce(0) { $0 + $1.workingData.count + $1.stages.values.reduce(0) { $0 + $1.count } }
    check(vm.conflictFiles.count == 32 && retained.count == 1 && retainedBytes < 512 * 1024,
          "all conflict paths remain visible without retaining every file's versions in memory")
`;
  const harness = `import Foundation
import SwiftUI
import Combine
struct AIConflictResolution {}
actor AIService {
  func suggestConflictResolution(ours: String, theirs: String, base: String?, filename: String) async throws -> AIConflictResolution { AIConflictResolution() }
}
@MainActor final class NotificationManager {
  static let shared = NotificationManager()
  func success(_ message: String, detail: String = "") {}
  func error(_ message: String, detail: String = "") {}
}
${vm}
@main struct ConflictSafetyCheck {
  @MainActor static func main() async throws {
    let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-conflict-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: fixture) }
    var failures = 0
    func check(_ value: Bool, _ label: String) {
      print("\\(value ? "PASS" : "FAIL") " + label)
      if !value { failures += 1 }
    }
    func git(_ arguments: [String], expected: Int32 = 0) async throws -> String {
      let result = await ShellExecutor.shared.execute("git", arguments: arguments, workingDirectory: fixture.path)
      guard result.exitCode == expected else { throw NSError(domain: "fixture-git", code: Int(result.exitCode), userInfo: [NSLocalizedDescriptionKey: result.stderr]) }
      return result.stdout
    }
    let filePath = "-conflict.txt"
    let fileURL = fixture.appendingPathComponent(filePath)
    _ = try await git(["init", "--initial-branch=main"])
    try "base\\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["add", "--", filePath]); _ = try await git(["commit", "-m", "base"])
    _ = try await git(["checkout", "-b", "other"])
    try "theirs\\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "theirs"])
    _ = try await git(["checkout", "main"])
    try "ours\\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try await git(["commit", "-am", "ours"])
    _ = try await git(["merge", "other"], expected: 1)
    let originalIndex = try Data(contentsOf: fixture.appendingPathComponent(".git/index"))
    let originalWorkingCopy = try Data(contentsOf: fileURL)
    let vm = ConflictResolverViewModel()
    var repository = Repository(path: fixture.path, name: "fixture")
    await vm.loadConflicts(from: repository)
    check(vm.conflictFiles.count == 1, "conflict detection queries Git even with an empty cached UI status")
    // Let the previous-source control continue far enough to expose independent
    // preservation failures after its cached-status defect has been recorded.
    if vm.conflictFiles.isEmpty {
      repository.status.conflicted = [FileStatus(path: filePath, status: .unmerged)]
      await vm.loadConflicts(from: repository)
    }
    let stages = await vm.loadConflictContent(for: filePath)
    check(stages.ours == "ours\\n" && stages.theirs == "theirs\\n" && stages.base == "base\\n", "real unmerged index stages agree with Git")
    let file = vm.conflictFiles[0]
    let lock = fixture.appendingPathComponent(".git/index.lock")
    try Data().write(to: lock)
    await vm.resolveWithCustom(file, content: "resolved\\n")
    check(vm.error != nil && !vm.conflictFiles[0].isResolved, "failed staging cannot publish resolved state")
    check(try Data(contentsOf: fileURL) == originalWorkingCopy, "an existing index lock prevents overwriting local conflict content")
    vm.error = nil; vm.conflictFiles = [file]
    await vm.markResolved(file)
    check(vm.error != nil && !vm.conflictFiles[0].isResolved, "markResolved waits for successful Git add")
    try FileManager.default.removeItem(at: lock)
    vm.error = nil
    await vm.resolveWithCustom(file, content: "resolved\\n")
    let remaining = try await git(["ls-files", "-u", "-z"])
    check(vm.error == nil && vm.conflictFiles[0].isResolved && remaining.isEmpty,
          "dash-prefixed file stages only after successful resolution")
    check(try String(contentsOf: fileURL, encoding: .utf8) == "resolved\\n", "resolution content remains exact")
    ${recoveryProof}
    let crlf = "first\\r\\nsecond\\r\\n"
    let unchanged = ConflictParser.applyResolutions(to: crlf, chunks: [])
    check(unchanged == crlf, "no-op resolution preserves original CRLF bytes")
    let marked = "before\\r\\n<<<<<<< HEAD\\r\\nours\\r\\n=======\\r\\ntheirs\\r\\n>>>>>>> other\\r\\nafter\\r\\n"
    var chunks = ConflictParser.parseConflicts(from: marked)
    check(chunks.count == 1, "CRLF conflict parses as one logical block")
    if !chunks.isEmpty { chunks[0].resolution = .ours }
    check(ConflictParser.applyResolutions(to: marked, chunks: chunks) == "before\\r\\nours\\r\\nafter\\r\\n",
          "resolved CRLF block preserves surrounding bytes and line endings")
    let lf = "before\\n<<<<<<< HEAD\\nours\\n=======\\ntheirs\\n>>>>>>> other\\nafter"
    var lfChunks = ConflictParser.parseConflicts(from: lf)
    if !lfChunks.isEmpty { lfChunks[0].resolution = .theirs }
    check(ConflictParser.applyResolutions(to: lf, chunks: lfChunks) == "before\\ntheirs\\nafter",
          "resolved LF block preserves missing final newline")
    let emptyOurs = "<<<<<<< HEAD\\n=======\\nincoming\\n>>>>>>> other\\n"
    var emptyOursChunks = ConflictParser.parseConflicts(from: emptyOurs)
    if !emptyOursChunks.isEmpty { emptyOursChunks[0].resolution = .both }
    check(ConflictParser.applyResolutions(to: emptyOurs, chunks: emptyOursChunks) == "incoming\\n",
          "accepting both with an empty current side does not invent a blank line")
    if !emptyOursChunks.isEmpty { emptyOursChunks[0].resolution = .ours }
    check(ConflictParser.applyResolutions(to: emptyOurs, chunks: emptyOursChunks).isEmpty,
          "choosing an empty side removes the entire block including its marker newline")
    let emptyMiddle = "before\\n" + emptyOurs + "after\\n"
    var emptyMiddleChunks = ConflictParser.parseConflicts(from: emptyMiddle)
    if !emptyMiddleChunks.isEmpty { emptyMiddleChunks[0].resolution = .ours }
    check(ConflictParser.applyResolutions(to: emptyMiddle, chunks: emptyMiddleChunks) == "before\\nafter\\n",
          "an empty middle resolution does not leave a fabricated blank line")
    if !emptyOursChunks.isEmpty { emptyOursChunks[0].resolution = .custom("custom\\n") }
    check(ConflictParser.applyResolutions(to: emptyOurs, chunks: emptyOursChunks) == "custom\\n",
          "a custom resolution's final newline is not duplicated")
    let emptyTheirs = "<<<<<<< HEAD\\ncurrent\\n=======\\n>>>>>>> other\\n"
    var emptyTheirsChunks = ConflictParser.parseConflicts(from: emptyTheirs)
    if !emptyTheirsChunks.isEmpty { emptyTheirsChunks[0].resolution = .both }
    check(ConflictParser.applyResolutions(to: emptyTheirs, chunks: emptyTheirsChunks) == "current\\n",
          "accepting both with an empty incoming side does not invent a blank line")
    check(ConflictParser.parseConflicts(from: "<<<<<<< HEAD\\ncurrent\\n>>>>>>> other\\n").isEmpty,
          "malformed blocks without a separator cannot become resolvable chunks")
    check(ConflictParser.parseConflicts(from: "<<<<<<< HEAD\\na\\n<<<<<<< nested\\nb\\n=======\\nc\\n>>>>>>> other\\n").isEmpty,
          "nested markers cannot silently discard conflict content")
    // Restore only this owned disposable fixture to its exact unmerged state.
    try originalIndex.write(to: fixture.appendingPathComponent(".git/index"), options: .atomic)
    try originalWorkingCopy.write(to: fileURL, options: .atomic)
    await vm.loadConflicts(from: repository)
    let staleFile = vm.conflictFiles[0]
    let localEdit = Data("LOCAL EDIT AFTER OPEN\\n".utf8)
    try localEdit.write(to: fileURL, options: .atomic)
    await vm.resolveWithCustom(staleFile, content: "obsolete proposal\\n")
    let afterStaleAttempt = try Data(contentsOf: fileURL)
    check(vm.error != nil && afterStaleAttempt == localEdit,
          "a concurrent local edit survives a stale resolution attempt")
    check(!(try await git(["ls-files", "-u", "-z"])).isEmpty,
          "a stale resolution does not silently clear unmerged index entries")
    try originalIndex.write(to: fixture.appendingPathComponent(".git/index"), options: .atomic)
    try originalWorkingCopy.write(to: fileURL, options: .atomic)
    await vm.loadConflicts(from: repository)
    let obsoleteIndexFile = vm.conflictFiles[0]
    _ = try await git(["add", "--", filePath])
    await vm.resolveWithCustom(obsoleteIndexFile, content: "obsolete index proposal\\n")
    let afterIndexChange = try Data(contentsOf: fileURL)
    check(vm.error != nil && afterIndexChange == originalWorkingCopy,
          "a changed index invalidates the old resolver before writing")
    ${operationProof}
    print("CONFLICT_SAFETY_CHECKS: \\(failures) failures")
    if failures != 0 { exit(1) }
  }
}
`;
  const main = path.join(temporary, 'ConflictSafetyMain.swift');
  await fs.writeFile(main, harness);
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const models = ['Branch', 'Commit', 'Repository', 'Remote', 'Tag', 'Stash'].map(name => path.join(root, `GitMac/Core/Git/${name}.swift`));
  const binary = path.join(temporary, 'conflict-safety');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    ...models, path.join(root, 'GitMac/Core/Utils/ShellExecutor.swift'), main, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')));
  const templates = path.join(temporary, 'templates'); await fs.mkdir(templates);
  const hooks = path.join(temporary, 'hooks'); await fs.mkdir(hooks);
  Object.assign(env, { GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_ATTR_NOSYSTEM: '1',
    GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.hooksPath', GIT_CONFIG_VALUE_0: hooks,
    GIT_TEMPLATE_DIR: templates, GIT_TERMINAL_PROMPT: '0', GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
    GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid' });
  execFileSync(binary, [], { env, stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
