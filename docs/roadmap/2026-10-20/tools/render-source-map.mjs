import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const current=process.argv.includes('--current');
const base=path.resolve(path.dirname(fileURLToPath(import.meta.url)),current?'../implementation/mapping':'../mapping');
const graph=JSON.parse(await fs.readFile(path.join(base,'source-graph.json'),'utf8'));
let audit;
if(current){
 const verification=JSON.parse(await fs.readFile(path.join(base,'../verification.json'),'utf8'));
 if(!verification.passed)throw Error('Current viewer requires a passing implementation audit');
 for(const change of verification.changes){
  const mapped=graph.files.find(f=>f.path===change.file);
  const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../../..');
  const actual=crypto.createHash('sha256').update(await fs.readFile(path.join(root,change.file))).digest('hex');
  if(actual!==change.afterSHA256||(mapped&&mapped.sha256!==actual))throw Error('Stale change mapping: '+change.file);
 }
 audit=verification.changes.map((change,index)=>({id:'C'+String(index+1).padStart(2,'0'),title:change.file,
  priority:'Cambio aplicado',status:'Verificación acotada; no certifica el producto completo',
  observation:'Antes: '+(change.beforeSHA256||'archivo nuevo')+' · Después: '+change.afterSHA256,
  proposedChange:'Rangos y hashes registrados en changes.csv. Consultar RESULTADOS.md para comportamiento, pruebas y límites.',
  acceptanceTest:'verification.json registra los comandos ejecutados y sus exit codes; no incluye aprobación UI/AX.',
  evidence:change.ranges.map(range=>({file:change.file,line:Math.max(1,range.newStart),startLine:Math.max(1,range.newStart),
   endLine:Math.max(1,range.newStart+range.newCount-1),symbol:null,
   excerpt:'Antes: '+range.oldStart+' +'+range.oldCount+' líneas; después: '+range.newStart+' +'+range.newCount+' líneas.'}))}));
}else audit=JSON.parse(await fs.readFile(path.join(base,'audit-items.json'),'utf8')).items;
const payload={report:graph.report,files:graph.files.map(f=>({...f,parseErrors:undefined})),
 symbols:graph.nodes.map(n=>({file:n.file,name:n.qualifiedName,start:n.startLine,end:n.endLine,kind:n.kind})),
 dependencies:JSON.parse(await fs.readFile(path.join(base,'file-dependencies.json'),'utf8')),
 channels:JSON.parse(await fs.readFile(path.join(base,'notifications.json'),'utf8')),
 audit,current};
const data=JSON.stringify(payload).replaceAll('<','\\u003c');
const html=`<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GitMac · mapa de código y auditoría</title>
<style>
:root{color-scheme:dark;--bg:#0c1019;--panel:#141c2a;--line:#29354a;--muted:#a7b6ca;--accent:#83d6c5}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:#edf3fa;font:14px -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif}header{padding:26px 30px;border-bottom:1px solid var(--line)}h1{font-size:26px;margin:0 0 8px}p{line-height:1.55}.muted,small{color:var(--muted)}.chips{display:flex;gap:12px;flex-wrap:wrap;margin:18px 0 8px}.chip{background:var(--panel);padding:8px 12px;border-radius:7px}main{display:grid;grid-template-columns:310px minmax(0,1fr);min-height:82vh}aside{padding:20px;border-right:1px solid var(--line)}input,select,button{font:inherit;color:inherit;background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:9px}input,select{width:100%;margin-bottom:10px}button{cursor:pointer;text-align:left}button:hover,button:focus-visible{border-color:var(--accent);outline:2px solid transparent}a{color:var(--accent)}#files{max-height:75vh;overflow:auto;display:grid;gap:5px}#files button{word-break:break-word;font-size:12px}#files button.active{border-color:var(--accent);background:#183830}section{padding:24px;min-width:0}h2{font-size:19px;overflow-wrap:anywhere}.meta{font-family:ui-monospace,monospace;font-size:11px;word-break:break-all;color:var(--muted)}svg{width:100%;height:460px;background:#101724;border:1px solid var(--line);border-radius:10px;margin:16px 0}.tabs{display:flex;gap:8px;flex-wrap:wrap}.tabs button.active{color:var(--accent);border-color:var(--accent)}.row{padding:13px 0;border-bottom:1px solid var(--line);overflow-wrap:anywhere}.row button{font-size:12px;padding:5px 8px}.pill{display:inline-block;border-radius:4px;background:#24324b;color:#b5d4ff;font-size:11px;padding:3px 6px;margin-right:6px}.warning{color:#e9bd7b}.description{max-width:1000px}pre{white-space:pre-wrap;background:#080c13;padding:12px;border-radius:6px;overflow-wrap:anywhere}.node{cursor:pointer}.node:hover rect{stroke:#fff}label{display:block;margin-bottom:6px}footer{margin-top:28px;border-top:1px solid var(--line);padding-top:16px;color:var(--muted)}@media(max-width:850px){main{grid-template-columns:1fr}aside{border-right:0;border-bottom:1px solid var(--line)}#files{max-height:220px}section{padding:18px}svg{height:400px}}
</style>
<header><h1>GitMac · mapa de código y auditoría</h1><div class="muted">Snapshot verificable de fuentes, símbolos, referencias y notificaciones.</div><div class="chips" id="stats"></div><p class="description warning">Las aristas representan candidatos por nombre extraídos de sintaxis, no dispatch probado por el compilador. Las notificaciones muestran canales explícitos. Cobertura de archivos no equivale a auditoría semántica completa.</p></header>
<main><aside><label for="search">Buscar archivo</label><input id="search" type="search" placeholder="GraphViewModel, GitEngine…"><label for="scope">Alcance del listado</label><select id="scope"><option value="all">Todo el inventario</option><option value="graph">CommitGraph</option><option value="audit">Archivos con hallazgos</option><option value="parser">Con límites del parser</option></select><small id="fileCount"></small><div id="files"></div></aside>
<section><h2 id="selected"></h2><div id="metadata" class="meta"></div><svg id="diagram" viewBox="0 0 1000 460" role="img" aria-label="Relaciones candidatas del archivo seleccionado"></svg><p id="edgeNote" class="muted"></p><div class="tabs"><button data-tab="symbols">Símbolos</button><button data-tab="relations">Relaciones</button><button data-tab="audit">Hallazgos y cambios</button><button data-tab="notifications">Notificaciones</button></div><div id="details"></div><footer><a href="AUDIT.md">Auditoría detallada</a> · <a href="audit-changes.csv">CSV de cambios</a> · <a href="symbols.csv">Símbolos y líneas</a> · <a href="proposed-pagination.patch">Patch propuesto, sin aplicar</a><p>El visor limita el dibujo al vecindario del archivo. Los índices JSON/CSV contienen el inventario completo del alcance, incluidas las ambigüedades y errores del parser.</p></footer></section></main>
<script id="mapping-data" type="application/json">${data}</script>
<script>
const D=JSON.parse(document.querySelector('#mapping-data').textContent);
const $=s=>document.querySelector(s);let selected='GitMac/Features/CommitGraph/ViewModels/GraphViewModel.swift',tab='audit';
function el(tag,text,cls){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e}
function openFile(file){selected=file;renderFiles();renderSelected()}
function fileButton(file,label){const b=el('button',label||file);b.addEventListener('click',()=>openFile(file));return b}
const stats=[D.report.files+' archivos',D.report.swiftFiles+' Swift',D.report.symbols+' símbolos',D.report.notificationChannels+' canales',D.audit.length+' registros'];
for(const s of stats)$('#stats').append(el('span',s,'chip'));
function renderFiles(){const q=$('#search').value.toLowerCase(),scope=$('#scope').value;const rows=D.files.filter(f=>f.path.toLowerCase().includes(q)&&(scope==='all'||scope==='graph'&&f.path.includes('/CommitGraph/')||scope==='audit'&&D.audit.some(a=>a.evidence.some(e=>e.file===f.path))||scope==='parser'&&f.parseStatus==='has-errors'));$('#files').replaceChildren();$('#fileCount').textContent=rows.length+' archivos';for(const f of rows){const b=fileButton(f.path);b.classList.toggle('active',f.path===selected);$('#files').append(b)}}
function neighborhood(){const edges=D.dependencies.filter(e=>e.source===selected||e.target===selected);const merged=new Map();for(const e of edges){const other=e.source===selected?e.target:e.source;const r=merged.get(other)||{file:other,count:0};r.count+=e.occurrences;merged.set(other,r)}return {edges,neighbors:[...merged.values()].sort((a,b)=>b.count-a.count)}}
function svg(tag,attrs){const e=document.createElementNS('http://www.w3.org/2000/svg',tag);for(const [k,v]of Object.entries(attrs))e.setAttribute(k,v);return e}
function draw(){const {neighbors}=neighborhood();const canvas=$('#diagram');canvas.replaceChildren();const visible=neighbors.slice(0,20);const center={x:500,y:230};function node(file,x,y,isCenter){const g=svg('g',{class:'node',tabindex:0,role:'button','aria-label':file});g.append(svg('rect',{x:x-125,y:y-18,width:250,height:36,rx:7,fill:isCenter?'#17483f':'#19263c',stroke:isCenter?'#83d6c5':'#4e6383'}));const label=svg('text',{x,y:y+4,'text-anchor':'middle',fill:'#edf3fa','font-size':11});label.textContent=file.split('/').pop().slice(0,36);g.append(label);const title=svg('title',{});title.textContent=file;g.append(title);g.addEventListener('click',()=>openFile(file));g.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openFile(file)}});canvas.append(g)}for(let i=0;i<visible.length;i++){const left=i%2===0,x=left?155:845,y=30+Math.floor(i/2)*43;canvas.append(svg('line',{x1:center.x,y1:center.y,x2:x,y2:y,stroke:'#526c90','stroke-width':1,'stroke-dasharray':'4 4'}));node(visible[i].file,x,y,false)}node(selected,center.x,center.y,true);$('#edgeNote').textContent=neighbors.length+' vecinos candidatos; dibujo de '+visible.length+'. El listado de relaciones conserva todas las ocurrencias agregadas y su clasificación.'}
function row(title,description){const r=el('div',undefined,'row');r.append(el('div',title));if(description)r.append(el('p',description,'muted'));$('#details').append(r);return r}
function renderSelected(){const f=D.files.find(f=>f.path===selected);$('#selected').textContent=selected;$('#metadata').textContent=f?f.lines+' líneas · '+f.parseStatus+' · SHA-256 '+f.sha256:'';draw();renderDetails()}
function renderDetails(){$('#details').replaceChildren();for(const b of document.querySelectorAll('[data-tab]'))b.classList.toggle('active',b.dataset.tab===tab);
if(tab==='symbols'){const symbols=D.symbols.filter(n=>n.file===selected);for(const n of symbols)row(n.name,n.kind+' · líneas '+n.start+'–'+n.end);if(!symbols.length)row('Sin símbolos Swift extraídos','Archivo de configuración/C o sin declaraciones indexadas.')}
if(tab==='relations'){const {edges}=neighborhood();for(const e of edges){const other=e.source===selected?e.target:e.source;const r=row((e.source===selected?'Salida → ':'Entrada ← ')+other,e.evidence+' · '+e.occurrences+' ocurrencias candidatas');r.append(fileButton(other,'Abrir archivo'))}if(!edges.length)row('Sin relaciones candidatas entre archivos','Esto no demuestra que el archivo esté sin uso.')}
if(tab==='audit'){const items=D.audit.filter(a=>a.evidence.some(e=>e.file===selected));for(const a of items){const r=row(a.id+' · '+a.title,a.priority+' · '+a.status);r.append(el('p',a.observation),el('p','Cambio propuesto: '+a.proposedChange),el('p','Aceptación: '+a.acceptanceTest));for(const e of a.evidence){r.append(el('div',e.file+':'+e.line+' · símbolo '+(e.symbol||'configuración')+' · rango '+e.startLine+'–'+e.endLine,'meta'));r.append(el('pre',e.excerpt))}}if(!items.length)row('Sin hallazgo registrado para este archivo','No significa que el archivo haya superado una auditoría semántica completa.')}
if(tab==='notifications'){const channels=D.channels.filter(c=>[...c.publishers,...c.subscribers,...c.declarations].some(e=>e.file===selected));for(const c of channels){const r=row(c.name,c.publishers.length+' publicaciones · '+c.subscribers.length+' suscriptores explícitos');for(const [label,rows]of [['Publica',c.publishers],['Suscribe',c.subscribers]])for(const e of rows){const line=el('div');line.append(el('span',label+' · ','pill'),fileButton(e.file,e.file+':'+e.line));r.append(line)}if(c.publishers.length&&!c.subscribers.length)r.append(el('p','Revisar wiring dinámico: ausencia de suscriptor explícito no prueba una acción muerta.','warning'))}if(!channels.length)row('Sin canal explícito registrado','Los nombres dinámicos y observadores generales no se resuelven aquí.')}
}
$('#search').addEventListener('input',renderFiles);$('#scope').addEventListener('change',renderFiles);for(const b of document.querySelectorAll('[data-tab]'))b.addEventListener('click',()=>{tab=b.dataset.tab;renderDetails()});renderFiles();renderSelected();
</script></html>`;
const output=current?html
 .replace('Snapshot verificable de fuentes, símbolos, referencias y notificaciones.','Worktree actual · '+graph.report.date+' · cambios aplicados y verificación acotada.')
 .replace('href="AUDIT.md"','href="../RESULTADOS.md"').replace('href="audit-changes.csv"','href="../changes.csv"')
 .replace(' · <a href="proposed-pagination.patch">Patch propuesto, sin aplicar</a>','')
 .replace('Cambio propuesto: ','Cambio aplicado: '):html;
await fs.writeFile(path.join(base,'graph.html'),output);
console.log(JSON.stringify({file:path.join(base,'graph.html'),bytes:Buffer.byteLength(output),renderedNodeLimit:21,externalDependencies:0,current}));
