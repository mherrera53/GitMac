import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
let document = await fs.readFile(path.join(root, 'docs/roadmap/2026-10-20/implementation/threat-model.md'), 'utf8');
if (process.argv.includes('--omit-boundary-control')) {
  document = document.replace(/^\| TM09 .*\n/m, '');
  console.log('NEGATIVE CONTROL: remote boundary removed only from in-memory input');
}
const rows = document.split('\n').filter(line => /^\| TM\d{2} /.test(line))
  .map(line => line.split('|').slice(1, -1).map(cell => cell.trim()));
assert.equal(rows.length, 16, 'Expected all 16 boundaries');
assert.equal(new Set(rows.map(row => row[0])).size, 16, 'Duplicate boundary');
const sourceFiles = execFileSync('rg', ['--files', 'GitMac', 'Tests', 'GitMacUITests', 'scripts',
  'docs/roadmap/2026-10-20/implementation/audit-implementation.mjs'], { cwd: root, encoding: 'utf8' }).trim().split('\n');
const sourceNames = new Set(sourceFiles.map(file => path.basename(file)));
for (const row of rows) {
  assert.equal(row.length, 9, `${row[0]}: entry/asset/threat/control/test/owner/state/task fields required`);
  assert(row.every(Boolean), `${row[0]}: empty field`);
  assert(['verificado-acotado', 'parcial', 'pendiente'].includes(row[7]), `${row[0]}: unsupported state`);
  for (const fixture of row[5].match(/\bF\d{2}\b/g) ?? []) {
    assert(Number(fixture.slice(1)) >= 1 && Number(fixture.slice(1)) <= 15, `${row[0]}: unknown fixture ${fixture}`);
  }
  assert(/\bT\d{2}\b/.test(row[8]), `${row[0]}: missing roadmap task`);
  for (const task of row[8].match(/\bT\d{2}\b/g) ?? []) assert(Number(task.slice(1)) <= 40, `${row[0]}: unknown task`);
  for (const file of row[5].match(/\b[A-Za-z][A-Za-z0-9-]*\.(swift|mjs)\b/g) ?? []) {
    assert(sourceNames.has(file), `${row[0]}: nonexistent test/source ${file}`);
  }
}
for (const concept of ['config, hooks', 'Subproceso', 'Secretos', 'Git remoto', 'HTTP proveedores', 'IA local', 'terminal', 'distribución']) {
  assert(document.includes(concept), `Missing threat domain: ${concept}`);
}
assert(document.includes('no lo convierte en un control aprobado'), 'Must not equate planned controls with implemented controls');
console.log('THREAT_MODEL_CHECKS_PASSED: 16 boundaries with owners, tests and explicit residual state; not product security approval');
