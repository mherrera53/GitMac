import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const base = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const plan = await fs.readFile(path.join(base, '10-plan-trabajo-auditado.md'), 'utf8');
const progress = JSON.parse(await fs.readFile(path.join(base, 'implementation/task-state.json'), 'utf8'));
const tasks = [...plan.matchAll(/^\| (T\d{2}) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$/gm)].map(match => {
  const saved = progress[match[1]] ?? { state: 'pendiente', evidence: '' };
  if (!['verificada', 'en_curso', 'pendiente'].includes(saved.state)) throw Error('Unknown task state');
  if (saved.state === 'verificada' && (!saved.acceptanceVerified || !saved.evidence)) throw Error('Missing explicit acceptance evidence');
  return { id: match[1], work: match[2].trim(), acceptance: match[5].trim(),
    state: saved.state, evidence: saved.evidence, requiresFurtherWork: saved.state !== 'verificada' };
});
if (tasks.length !== 40 || new Set(tasks.map(task => task.id)).size !== 40) throw Error('Expected 40 unique criteria');
if (Object.keys(progress).some(id => !tasks.some(task => task.id === id))) throw Error('Progress references unknown task');
const report = { date: new Date().toISOString(),
  scope: 'Closure status of all 40 declared acceptance criteria; NOT execution of every product scenario',
  taskCount: tasks.length,
  counts: Object.fromEntries(['verificada', 'en_curso', 'pendiente'].map(state => [state, tasks.filter(task => task.state === state).length])),
  allTasksVerified: tasks.every(task => !task.requiresFurtherWork), tasks };
await fs.writeFile(path.join(base, 'implementation/task-closure-audit.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ ...report, tasks: undefined }, null, 2));
// Status-only unless the caller explicitly requires integral completion.
if (process.argv.includes('--require-all') && !report.allTasksVerified) process.exitCode = 1;
