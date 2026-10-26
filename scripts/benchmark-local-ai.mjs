import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = 'http://127.0.0.1:11434';
const request = async (endpoint, body) => {
  const response = await fetch(base + endpoint, { signal: AbortSignal.timeout(120000),
    ...(body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {}) });
  if (!response.ok) throw Error(`${endpoint}: HTTP ${response.status}`);
  return response.json();
};
const running = await request('/api/ps');
if (running.models?.length) throw Error('Another model is loaded. Refuse to disturb its request or residency.');
const installed = await request('/api/tags');
const selected = ['qwen2.5:3b', 'phi4-mini:latest'];
const fixtures = [
  { id: 'commit-fix', prompt: 'Return ONLY one Conventional Commit subject, max 72 characters. No explanation. Diff:\n- if (index <= items.count)\n+ if (index < items.count)',
    criterion: 'fix subject describes preventing an out-of-bounds access, without invented changes' },
  { id: 'commit-feature', prompt: 'Return ONLY one Conventional Commit subject, max 72 characters. No explanation. Diff:\n+ Button("Help") { showSearchableOfflineGitGuide = true }',
    criterion: 'feat subject describes searchable/offline help; no claim of full Git coverage' },
  { id: 'safe-explanation', prompt: 'Explain in Spanish in at most 3 short sentences: the difference between git stash apply, pop and drop. Do not execute anything. Mention the destructive operation.',
    criterion: 'apply retains stash; successful pop removes it; drop removes entry and is destructive' },
];
const results = [];
for (const model of selected) {
  const tag = installed.models?.find(item => item.name === model);
  if (!tag || tag.remote_host || tag.remote_model) throw Error('Not installed local weights: ' + model);
  const metadata = await request('/api/show', { model });
  if (metadata.remote_host || metadata.remote_model || !['gguf', 'safetensors'].includes(metadata.details?.format)) {
    throw Error('Cannot attest local weights: ' + model);
  }
  for (const fixture of fixtures) {
    const start = performance.now();
    const response = await request('/api/generate', { model, prompt: fixture.prompt, stream: false,
      keep_alive: 0, options: { num_ctx: 4096, num_predict: 160, temperature: 0, seed: 42 } });
    if (!response.done || response.error) throw Error('Incomplete response: ' + model);
    const responseSeconds = (performance.now() - start) / 1000;
    const releaseStart = performance.now();
    let resident = await request('/api/ps');
    const present = () => resident.models?.some(item => item.name === model || item.model === model);
    while (present() && performance.now() - releaseStart < 5000) {
      await new Promise(resolve => setTimeout(resolve, 100));
      resident = await request('/api/ps');
    }
    results.push({ model, digest: tag.digest, installedBytes: tag.size, fixture: fixture.id,
      seconds: responseSeconds, loadSeconds: response.load_duration / 1e9,
      inputTokens: response.prompt_eval_count, outputTokens: response.eval_count,
      response: response.response, reasoning: response.thinking || null,
      unloadedAfterResponse: !present(), releaseObservedMilliseconds: performance.now() - releaseStart,
      criterion: fixture.criterion, qualityAssessment: 'Requires independent review; no automatic pass from nonempty text' });
    if (present()) throw Error('Model remains loaded after bounded release observation; do not overlap another model');
    console.error(`${model}: ${fixture.id} completed, keep_alive=0`);
  }
}
const report = { date: new Date().toISOString(), backend: await request('/api/version'),
  localOnly: true, downloadedModels: false, context: 4096, maximumOutput: 160, results,
  limits: ['Three synthetic prompts per model, cold loading each time; not a p95 study or whole-codebase review.',
    'Installed bytes are disk weight sizes, not peak RAM; Ollama is a separate process, not free memory.',
    'Does not test uninstalled newer models and cannot establish a universal best model.'] };
const reportName = process.argv[2] || 'local-model-comparison-v2';
if (!/^[a-z0-9-]+$/.test(reportName)) throw Error('Invalid report name');
const output = path.join(root, 'docs/roadmap/2026-10-20/implementation', reportName + '.json');
await fs.writeFile(output, JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify(report, null, 2));
