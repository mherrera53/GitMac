import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '../../../..');
const model = 'qwen3-coder:30b';
const weights = (await fetch('http://127.0.0.1:11434/api/tags').then(response => response.json())).models.find(item => item.name === model);
if (!weights || weights.remote_host || weights.remote_model || weights.size < 1e9) throw Error('Local weights required');
const source = await fs.readFile(path.join(root, 'GitMac/Core/Git/GitEngine.swift'), 'utf8');
const lines = source.split('\n');
const methods = ['getStatus', 'getStatusV2', 'parseDiffStats', 'parseStatusV2', 'statusTypeFromCharV2', 'unstage'];
let corpus = '';
for (const name of methods) {
  const start = lines.findIndex(line => new RegExp(`^    (?:private )?func ${name}\\(`).test(line));
  const end = lines.findIndex((line, index) => index > start && line === '    }');
  if (start < 0 || end < 0) throw Error(name);
  corpus += `\nGitEngine.swift:${start + 1}\n${lines.slice(start, end + 1).join('\n')}`;
}
for (const file of ['GitMac/Core/Git/Repository.swift', 'Tests/CoreRegressions/GitIntegrationMain.swift']) {
  corpus += `\nFILE ${file}\n${await fs.readFile(path.join(root, file), 'utf8')}`;
}
const response = await fetch('http://127.0.0.1:11434/api/generate', {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(600000),
  body: JSON.stringify({ model, stream: false, keep_alive: 0, format: 'json',
    options: { num_ctx: 16384, num_predict: 1800, temperature: 0.1 },
    prompt: `Revisa contratos reales de Git porcelain v2 -z y numstat -z. Devuelve JSON findings:[{evidence,change,test}], limitations:[] en español. No inventes defectos ni digas que ejecutaste pruebas. Busca estados XY perdidos, framing tabs/NUL, rename old/new, fallos ocultos, aborto de conflictos y unborn. git diff --numstat -z usa a TAB d TAB path NUL; renames usan a TAB d TAB NUL old NUL new NUL. El test importa el GitEngine completo real, no un parser duplicado. Las operaciones Git solo ocurren en fixtures temporales aislados.\n${corpus}` }),
});
if (!response.ok) throw Error(`HTTP ${response.status}`);
const result = await response.json();
const report = { date: new Date().toISOString(), model, remote: false, digest: weights.digest,
  inputTokens: result.prompt_eval_count, outputTokens: result.eval_count, review: JSON.parse(result.response), status: 'Unverified model proposals' };
await fs.writeFile(path.join(directory, 'local-status-review.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
