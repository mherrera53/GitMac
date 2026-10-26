import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const base=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const content=await fs.readFile(path.join(base,'10-plan-trabajo-auditado.md'),'utf8');
const specsText=await fs.readFile(path.join(base,'05-specs.md'),'utf8');
const validSpecs=new Set([...specsText.matchAll(/^## (GM-\d{3})/gm)].map(m=>m[1]));
const tasks=[...content.matchAll(/^\| (T\d{2}) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$/gm)]
  .map(m=>({id:m[1],work:m[2].trim(),specs:m[3].trim(),dependencies:m[4].trim(),
    acceptance:m[5].trim(),owner:'por asignar',state:'pendiente',commit:'',evidence:''}));
const errors=[];
// A structural check must never reset recorded implementation progress.
let progress = {};
try { progress = JSON.parse(await fs.readFile(path.join(base, 'implementation/task-state.json'), 'utf8')); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
for (const task of tasks) {
  if (!progress[task.id]) continue;
  const saved = progress[task.id];
  if (!['pendiente', 'en_curso', 'verificada'].includes(saved.state)) errors.push(`${task.id}: invalid state`);
  if (saved.state === 'verificada' && (!saved.evidence || !saved.acceptanceVerified)) errors.push(`${task.id}: missing completion evidence`);
  task.state = saved.state;
  task.evidence = saved.evidence || '';
  task.owner = saved.owner || task.owner;
}
const ids=new Set(tasks.map(t=>t.id));
const covered=new Set();
if(tasks.length!==40||ids.size!==40)errors.push('Expected 40 unique tasks');
for(let i=1;i<=40;i++)if(!ids.has(`T${String(i).padStart(2,'0')}`))errors.push(`Missing task ${i}`);
const graph=new Map();
for(const task of tasks){
  const deps=task.dependencies.match(/T\d{2}/g)||[];
  graph.set(task.id,deps);
  for(const dep of deps)if(!ids.has(dep))errors.push(`${task.id}: unknown dependency ${dep}`);
  for(const spec of task.specs.match(/GM-\d{3}/g)||[]){
    covered.add(spec);if(!validSpecs.has(spec))errors.push(`${task.id}: unknown spec ${spec}`);
  }
}
const visited=new Set(),active=new Set();
function visit(id){if(active.has(id)){errors.push(`Cycle at ${id}`);return;}if(visited.has(id))return;
  active.add(id);for(const dep of graph.get(id)||[])visit(dep);active.delete(id);visited.add(id);}
for(const id of ids)visit(id);
for(const spec of validSpecs)if(!covered.has(spec))errors.push(`Uncovered spec ${spec}`);
const matrix=[...content.matchAll(/^\| (GM-\d{3}) \| [^|]+ \| [^|]+ \| [^|]+ \|$/gm)].map(m=>m[1]);
if(new Set(matrix).size!==28)errors.push('Expected 28 quality matrix rows');
const columns=['id','work','specs','dependencies','acceptance','owner','state','commit','evidence'];
const quote=v=>'"'+String(v).replaceAll('"','""')+'"';
await fs.writeFile(path.join(base,'execution-tasks.csv'),[columns.join(','),...tasks.map(t=>columns.map(k=>quote(t[k])).join(','))].join('\n')+'\n');
const report={date:new Date().toISOString(),tasks:tasks.length,specsCovered:covered.size,qualityMatrixRows:matrix.length,
  taskStates:Object.fromEntries(['pendiente','en_curso','verificada'].map(state=>[state,tasks.filter(task=>task.state===state).length])),errors,passed:errors.length===0,
  limits:['Checks plan structure and coverage; does not certify correctness, speed or security of GitMac.']};
await fs.writeFile(path.join(base,'evidence/execution-plan-validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));if(errors.length)process.exitCode=1;
