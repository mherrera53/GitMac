import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-workflow-safety-'));
try {
  const enginePath = 'GitMac/Core/Services/WorkflowEngine.swift';
  const engine = process.argv.includes('--previous-source-control')
    ? execFileSync('git', ['show', `${regressionBaseline}:${enginePath}`], { cwd: root, encoding: 'utf8' })
    : await fs.readFile(path.join(root, enginePath), 'utf8');
  const source = path.join(temporary, 'WorkflowEngine.swift');
  await fs.writeFile(source, engine);
  // Explicit boundaries only. Workflow model, engine and process executor are production code.
  const harness = String.raw`import Foundation
import SwiftUI

@MainActor final class BranchStateManager {
    func createBranch(name: String, from: String, checkout: Bool) async throws { throw WorkflowError.stepFailed("unused fixture boundary") }
}
@MainActor final class WorkspaceSettingsManager {
    static let shared = WorkspaceSettingsManager()
    var mainBranch = "main"
    func getMainBranch(for path: String) -> String { mainBranch }
}
actor AIService {
    static let shared = AIService()
    func isAvailable() -> Bool { false }
    func generateText(prompt: String) throws -> String { throw WorkflowError.stepFailed("unused AI fixture") }
    func generateCommitMessage(diff: String) throws -> String { throw WorkflowError.stepFailed("unused AI fixture") }
    nonisolated static func cleanAIResponse(_ text: String) -> String { text }
}
struct GitEngine {
    func getHeadSHA(at path: String) async throws -> String { throw WorkflowError.stepFailed("unused PR fixture") }
}
@MainActor final class NotificationManager {
    static let shared = NotificationManager()
    var messages: [String] = []
    func success(_ message: String) { messages.append(message) }
}

@main struct WorkflowSafety {
    @MainActor static func main() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-workflows-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: base) }
        var failures = 0, checks = 0
        func check(_ condition: Bool, _ label: String) {
            checks += 1
            if !condition { failures += 1 }
            print("\(condition ? "PASS" : "FAIL") \(label)")
        }
        func git(_ args: [String], at repo: URL, expected: Int32 = 0) async throws -> String {
            let result = await ShellExecutor.shared.execute("git", arguments: args, workingDirectory: repo.path)
            guard result.exitCode == expected else { throw WorkflowError.stepFailed("fixture git \(args.first ?? ""): \(result.stderr)") }
            return result.stdout
        }
        func fixture(_ name: String) async throws -> URL {
            let url = base.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            _ = try await git(["init", "--initial-branch=main"], at: url)
            try "base\n".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
            _ = try await git(["add", "--", "file.txt"], at: url)
            _ = try await git(["commit", "-m", "base"], at: url)
            return url
        }
        func workflow(_ steps: [WorkflowStep]) -> GitWorkflow {
            GitWorkflow(name: "fixture", icon: "bolt", color: "#000000", triggerCondition: .manual, steps: steps)
        }
        func context(_ repo: URL) -> WorkflowContext {
            WorkflowContext(repoPath: repo.path, branchManager: BranchStateManager(), currentBranch: "main",
                commitMessage: "fixture", diff: "", showPRSheet: .constant(false), commitSHAForPR: .constant(""))
        }
        let engine = WorkflowEngine.shared
        func failed(_ label: String, _ steps: [WorkflowStep], at repo: URL) async {
            NotificationManager.shared.messages = []
            let marker = repo.appendingPathComponent("later-step")
            let sequence = steps + [.runCommand(command: "/usr/bin/touch later-step"), .notify(message: "must-not-notify")]
            var threw = false
            do { try await engine.execute(workflow(sequence), context: context(repo)) }
            catch { threw = !error.localizedDescription.isEmpty }
            check(threw, label + ": error propagated")
            check(!FileManager.default.fileExists(atPath: marker.path) && NotificationManager.shared.messages.isEmpty,
                  label + ": later step and success notification suppressed")
            check(!engine.isExecuting && engine.currentStep == 0 && engine.statusMessage.isEmpty,
                  label + ": execution state restored")
        }
        let repo = try await fixture("failure-repo")
        await failed("fetch", [.fetch(remote: "missing-local-remote")], at: repo)
        await failed("checkout", [.checkout(branch: "missing-branch")], at: repo)
        WorkspaceSettingsManager.shared.mainBranch = "missing-main"
        await failed("checkoutMain", [.checkoutMain], at: repo)
        WorkspaceSettingsManager.shared.mainBranch = "main"
        let lock = repo.appendingPathComponent(".git/index.lock")
        try Data().write(to: lock)
        await failed("stageAll", [.stageAll], at: repo)
        try FileManager.default.removeItem(at: lock)
        await failed("stageFiles", [.stageFiles(patterns: ["missing-file"])], at: repo)
        await failed("push", [.push(setUpstream: false, force: false)], at: repo)
        await failed("push upstream", [.push(setUpstream: true, force: false)], at: repo)

        let unborn = base.appendingPathComponent("unborn-repo")
        try FileManager.default.createDirectory(at: unborn, withIntermediateDirectories: false)
        _ = try await git(["init", "--initial-branch=main"], at: unborn)
        let trace = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GITMAC_WORKFLOW_TRACE"]!)
        let traceBefore = try Data(contentsOf: trace).count
        await failed("upstream branch lookup", [.push(setUpstream: true, force: false)], at: unborn)
        let traceAfter = try Data(contentsOf: trace)
        let commands = String(decoding: traceAfter.dropFirst(traceBefore), as: UTF8.self)
        check(!commands.contains("built-in: git push"), "failed branch lookup never starts push")

        let literal = try await fixture("literal-repo")
        try "selected\n".write(to: literal.appendingPathComponent("-A"), atomically: true, encoding: .utf8)
        try "unselected\n".write(to: literal.appendingPathComponent("decoy"), atomically: true, encoding: .utf8)
        NotificationManager.shared.messages = []
        do {
            try await engine.execute(workflow([.stageFiles(patterns: ["-A"])]), context: context(literal))
            let staged = try await git(["diff", "--cached", "--name-only", "-z"], at: literal)
            check(staged == "-A\0", "dash-prefixed file cannot become an add option or stage decoy")
            check(NotificationManager.shared.messages == ["Workflow 'fixture' completed"], "successful workflow emits completion once")
        } catch { check(false, "literal path stages successfully: \(error)") }

        let partial = try await fixture("partial-repo")
        for name in ["first", "last"] {
            try name.write(to: partial.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        await failed("partial stageFiles", [.stageFiles(patterns: ["first", "missing", "last"])], at: partial)
        let partialIndex = try await git(["diff", "--cached", "--name-only", "-z"], at: partial)
        check(partialIndex == "first\0", "stageFiles stops at first error and preserves earlier staged change")

        let rebase = try await fixture("rebase-repo")
        _ = try await git(["checkout", "-b", "feature"], at: rebase)
        try "feature\n".write(to: rebase.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try await git(["commit", "-am", "feature"], at: rebase)
        _ = try await git(["checkout", "main"], at: rebase)
        try "main\n".write(to: rebase.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try await git(["commit", "-am", "main"], at: rebase)
        _ = try await git(["update-ref", "refs/remotes/origin/main", "HEAD"], at: rebase)
        _ = try await git(["checkout", "feature"], at: rebase)
        await failed("rebase", [.rebaseOnMain], at: rebase)
        let unmerged = try await git(["ls-files", "-u", "-z"], at: rebase)
        check(!unmerged.isEmpty && FileManager.default.fileExists(atPath: rebase.appendingPathComponent(".git/rebase-merge").path),
              "failed rebase preserves conflict index and recovery metadata")

        let success = try await fixture("success-repo")
        let remote = base.appendingPathComponent("remote.git")
        _ = try await git(["init", "--bare", remote.path], at: success)
        _ = try await git(["remote", "add", "origin", remote.path], at: success)
        try "new\n".write(to: success.appendingPathComponent("new-file"), atomically: true, encoding: .utf8)
        NotificationManager.shared.messages = []
        do {
            try await engine.execute(workflow([.stageAll, .commit(messageStrategy: .userProvided),
                .push(setUpstream: true, force: false), .fetch(remote: "origin"),
                .checkout(branch: "main"), .checkoutMain]), context: context(success))
            let localSHA = try await git(["rev-parse", "HEAD"], at: success)
            let remoteSHA = try await git(["rev-parse", "refs/heads/main"], at: remote)
            let upstream = try await git(["rev-parse", "--abbrev-ref", "@{upstream}"], at: success)
            check(localSHA == remoteSHA && upstream == "origin/main\n", "successful workflow stages, commits and pushes to owned local bare remote")
            check(NotificationManager.shared.messages == ["Workflow 'fixture' completed"] && !engine.isExecuting,
                  "successful multi-step workflow completes once and restores state")
        } catch { check(false, "successful workflow must remain functional: \(error)") }
        print("WORKFLOW_SAFETY_CHECKS: \(checks) checks, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
`;
  const main = path.join(temporary, 'WorkflowSafety.swift');
  await fs.writeFile(main, harness);
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const binary = path.join(temporary, 'workflow-safety');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    path.join(root, 'GitMac/Core/Models/GitWorkflow.swift'), path.join(root, 'GitMac/Core/Utils/ShellExecutor.swift'), source, main, '-o', binary],
    { stdio: 'inherit', timeout: 120000 });
  const templates = path.join(temporary, 'templates'); await fs.mkdir(templates);
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !/^(GIT_|DYLD_)/.test(key)));
  Object.assign(env, { GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_ATTR_NOSYSTEM: '1',
    GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.hooksPath', GIT_CONFIG_VALUE_0: '/dev/null', GIT_TEMPLATE_DIR: templates,
    GIT_TERMINAL_PROMPT: '0', GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
    GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid' });
  env.GIT_TRACE = path.join(temporary, 'git-trace.log');
  env.GITMAC_WORKFLOW_TRACE = env.GIT_TRACE;
  execFileSync(binary, [], { env, stdio: 'inherit', timeout: 60000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
