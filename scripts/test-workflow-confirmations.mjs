import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-workflow-confirmations-'));
try {
  const enginePath = 'GitMac/Core/Services/WorkflowEngine.swift';
  const engine = process.argv.includes('--previous-source-control')
    ? execFileSync('git', ['show', `${regressionBaseline}:${enginePath}`], { cwd: root, encoding: 'utf8' })
    : await fs.readFile(path.join(root, enginePath), 'utf8');
  const source = path.join(temporary, 'WorkflowEngine.swift');
  // Older engines have no decision identity. This API-only compatibility seam
  // forwards to their real methods so controls fail by behavior, not compilation.
  const legacyAPI = engine.includes('func confirmPending(id: UUID)') ? '' : `
extension WorkflowEngine {
    var pendingConfirmationID: UUID? {
        pendingConfirmation == nil ? nil : UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }
    func confirmPending(id: UUID) { confirmPending() }
    func cancelPending(id: UUID) { cancelPending() }
}
`;
  await fs.writeFile(source, engine + legacyAPI);
  // Reuse the explicitly documented collaborator seams, not a copy of the engine.
  const safety = await fs.readFile(path.join(root, 'scripts/test-workflow-safety.mjs'), 'utf8');
  const seams = safety.split('const harness = String.raw`')[1]?.split('@main struct WorkflowSafety')[0];
  if (!seams?.includes('final class NotificationManager')) throw Error('Fixture extraction boundary changed');
  const harness = String.raw`
@MainActor final class Completion { var finished = false; var cancelled = false; var succeeded = false }
@main struct ConfirmationChecks {
    @MainActor static func main() async throws {
        let engine = WorkflowEngine.shared
        let result = Completion()
        let context = WorkflowContext(repoPath: "/unused-confirmation-fixture", branchManager: BranchStateManager(),
            currentBranch: "main", commitMessage: "fixture", diff: "", showPRSheet: .constant(false), commitSHAForPR: .constant(""))
        func workflow(_ steps: [WorkflowStep]) -> GitWorkflow {
            GitWorkflow(name: "confirmation fixture", icon: "bolt", color: "#000000", triggerCondition: .manual, steps: steps)
        }
        func start(_ steps: [WorkflowStep]) -> Task<Void, Never> {
            Task { @MainActor in
                do { try await engine.execute(workflow(steps), context: context); result.succeeded = true }
                catch is CancellationError { result.cancelled = true }
                catch { }
                result.finished = true
            }
        }
        func until(_ condition: @MainActor () -> Bool) async -> Bool {
            for _ in 0..<250 {
                if condition() { return true }
                try? await Task.sleep(for: .milliseconds(2))
            }
            return condition()
        }
        func require(_ condition: Bool, _ label: String) {
            if !condition { print("FAIL " + label); exit(1) }
        }
        let scenario = CommandLine.arguments[1]
        NotificationManager.shared.messages = []
        let steps: [WorkflowStep] = scenario == "stale-decision"
            ? [.waitForConfirmation(message: "first"), .waitForConfirmation(message: "second"), .notify(message: "after decision")]
            : [.waitForConfirmation(message: "first"), .notify(message: "after decision")]
        let task = start(steps)
        if scenario == "cancel-before-start" {
            task.cancel()
            let completed = await until { result.finished }
            require(completed && result.cancelled && !result.succeeded, "cancel before execution propagates")
        } else {
            let waiting = await until { engine.pendingConfirmation == "first" }
            require(waiting && engine.isExecuting, "first execution reaches confirmation")
            guard let decisionID = engine.pendingConfirmationID else { print("FAIL missing decision identity"); exit(1) }
            switch scenario {
            case "double-confirm": engine.confirmPending(id: decisionID); engine.confirmPending(id: decisionID)
            case "double-cancel": engine.cancelPending(id: decisionID); engine.cancelPending(id: decisionID)
            case "cancel-wait": task.cancel()
            case "cancel-confirm": task.cancel(); engine.confirmPending(id: decisionID)
            case "stale-decision":
                engine.confirmPending(id: decisionID)
                let waitingSecond = await until { engine.pendingConfirmation == "second" }
                require(waitingSecond, "execution reaches second confirmation")
                guard let secondID = engine.pendingConfirmationID else { print("FAIL second identity missing"); exit(1) }
                engine.confirmPending(id: decisionID)
                engine.cancelPending(id: decisionID)
                require(engine.pendingConfirmation == "second" && !result.finished,
                        "late response to first prompt cannot resolve the next prompt")
                engine.confirmPending(id: secondID)
            case "exclusive":
                var rejected = false
                do { try await engine.execute(workflow([.notify(message: "intruder")]), context: context) }
                catch { rejected = true }
                require(rejected, "concurrent execution rejected")
                require(engine.isExecuting && engine.currentStep == 1 && engine.pendingConfirmation == "first",
                        "rejected execution preserves active execution state")
                engine.confirmPending(id: decisionID)
            default: preconditionFailure("unknown scenario")
            }
            let completed = await until { result.finished }
            require(completed, "decision or cancellation resumes suspended task")
            if ["double-confirm", "exclusive", "stale-decision"].contains(scenario) {
                require(result.succeeded && NotificationManager.shared.messages == ["after decision", "Workflow 'confirmation fixture' completed"],
                        "accepted execution completes exactly once")
            } else {
                require(!result.succeeded && NotificationManager.shared.messages.isEmpty, "rejection/cancellation suppresses later steps")
                if scenario != "double-cancel" { require(result.cancelled, "task cancellation keeps CancellationError") }
            }
        }
        require(!engine.isExecuting && engine.pendingConfirmation == nil && engine.currentStep == 0 && engine.statusMessage.isEmpty,
                "terminal state releases pending confirmation and execution")
        // A fresh execution remains usable after every terminal path.
        result.finished = false; result.cancelled = false; result.succeeded = false
        NotificationManager.shared.messages = []
        _ = start([.waitForConfirmation(message: "first"), .notify(message: "after decision")])
        let waitingAgain = await until { engine.pendingConfirmation == "first" }
        require(waitingAgain, "next execution can wait")
        guard let nextID = engine.pendingConfirmationID else { print("FAIL new execution identity missing"); exit(1) }
        engine.confirmPending(id: nextID)
        let finishedAgain = await until { result.finished }
        require(finishedAgain && result.succeeded && !engine.isExecuting, "next execution completes")
        print("PASS " + scenario)
    }
}
`;
  const main = path.join(temporary, 'Checks.swift'); await fs.writeFile(main, seams + harness);
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const binary = path.join(temporary, 'checks');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    path.join(root, 'GitMac/Core/Models/GitWorkflow.swift'), path.join(root, 'GitMac/Core/Utils/ShellExecutor.swift'), source, main, '-o', binary],
    { stdio: 'inherit', timeout: 120000 });
  let failures = 0;
  const scenarios = ['double-confirm', 'double-cancel', 'cancel-wait', 'cancel-confirm', 'exclusive', 'cancel-before-start', 'stale-decision'];
  for (const scenario of scenarios) {
    // Trap and timeout are contained in a separate process for each scenario.
    const result = spawnSync(binary, [scenario], { encoding: 'utf8', timeout: 10000, maxBuffer: 16000 });
    if (result.status !== 0) failures++;
    console.log(JSON.stringify({ scenario, passed: result.status === 0, exitCode: result.status,
      signal: result.signal, error: result.error?.message, output: result.stdout.trim(),
      diagnostic: result.stderr.split('\n').slice(0, 3).join('\n') }));
  }
  console.log(`WORKFLOW_CONFIRMATION_CHECKS: ${scenarios.length} scenarios, ${failures} failures`);
  if (failures) process.exitCode = 1;
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
