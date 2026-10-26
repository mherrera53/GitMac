import fs from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '../../../..');
const model = process.env.GITMAC_LOCAL_REVIEW_MODEL || 'qwen3-coder:30b';
const reportName = process.argv[2] || 'local-implementation-review';
if (!/^[a-z0-9-]+$/.test(reportName)) throw Error('Invalid report name');
const tags = await fetch('http://127.0.0.1:11434/api/tags').then(response => response.json());
const weights = tags.models.find(item => item.name === model);
if (!weights || weights.remote_host || weights.remote_model || weights.size < 1e9) throw Error('Real local weights required');
const files = process.argv.length > 3 ? process.argv.slice(3) : ['GitMac/Features/CloudPatches/CloudPatchService.swift',
  'GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift',
  'GitMac/Features/CommitGraph/Services/GraphLayoutEngine.swift',
  'Tests/CoreRegressions/RegressionMain.swift', 'scripts/verify-xcodebuild.sh'];
const source = (await Promise.all(files.map(async file => `FILE ${file}\n${await fs.readFile(path.join(root, file), 'utf8')}`))).join('\n');
const diff = execFileSync('git', ['diff', '--', ...files], { cwd: root, encoding: 'utf8' });
const start = Date.now();
const response = await fetch('http://127.0.0.1:11434/api/generate', {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ model, stream: false, keep_alive: 0, format: 'json', options: { temperature: 0.1, num_ctx: 24576, num_predict: 2300 },
    prompt: `Revisa este cambio Swift/macOS y bash. Devuelve JSON findings:[{file,evidence,severity,change,test}], limitations:[] en español. Prioriza regresiones introducidas, riesgos restantes y pruebas falsamente verdes. Cada finding debe citar código concreto y un escenario alcanzable. No ejecutes ni afirmes haber ejecutado tests. Las suites GitIntegrationMain/ProcessIntegrationMain importan el motor real completo. El harness RegressionMain extrae solo cuatro métodos del VM y no prueba su contenedor. waitid WNOWAIT mantiene el PID sin reap hasta después de limpiar el grupo. bufferingOldest descarta el nuevo elemento cuando está lleno y el productor lo reintenta; no supongas que se perdió. NUL no es un filename POSIX válido. No propongas APIs inventadas.\n${diff}\n${source}` }),
  signal: AbortSignal.timeout(600000),
});
if (!response.ok) throw Error(`HTTP ${response.status}`);
const output = await response.json();
const report = { date: new Date().toISOString(), model, digest: weights.digest, remote: false,
  seconds: (Date.now() - start) / 1000, inputTokens: output.prompt_eval_count, outputTokens: output.eval_count,
  review: JSON.parse(output.response), status: 'Model proposals; independently verify before accepting.' };
await fs.writeFile(path.join(directory, reportName + '.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
