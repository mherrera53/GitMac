import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const base = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.resolve(base, '../../..');
const plan = JSON.parse(await fs.readFile(path.join(base, 'implementation/specific-plan-2026-10-25.json'), 'utf8'));
const canonical = await fs.readFile(path.join(base, '10-plan-trabajo-auditado.md'), 'utf8');
const ledger = JSON.parse(await fs.readFile(path.join(base, 'implementation/task-state.json'), 'utf8'));
const parents = new Map([...canonical.matchAll(/^\| (T\d{2}) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$/gm)]
  .map(match => [match[1], { title: match[2].trim(), specs: match[3].trim(), dependencies: match[4].trim(), acceptance: match[5].trim() }]));
if (process.argv.includes('--missing-task-control')) plan.tasks = plan.tasks.filter(task => task.id !== 'T32');
assert.equal(plan.tasks.length, 40, `Expected 40 tasks; received ${plan.tasks.length}`);
assert.equal(new Set(plan.tasks.map(task => task.id)).size, 40);
assert.deepEqual([...parents.keys()].sort(), plan.tasks.map(task => task.id).sort());
const phaseIDs = plan.phases.flatMap(phase => phase.tasks);
assert.equal(phaseIDs.length, 40); assert.equal(new Set(phaseIDs).size, 40);
assert.deepEqual(phaseIDs.sort(), [...parents.keys()].sort());
const files = new Map();
for (const task of plan.tasks) {
  assert(plan.modelRoles[task.model], `${task.id}: unknown model role`);
  assert(task.steps.length >= 4 && task.tests.length >= 2, `${task.id}: insufficient actionable detail`);
  assert(task.files.length > 0, `${task.id}: no source anchors`);
  for (const file of task.files) {
    assert(!file.startsWith('/') && !file.split('/').includes('..'), 'Source outside repository');
    const content = await fs.readFile(path.join(root, file));
    files.set(file, crypto.createHash('sha256').update(content).digest('hex'));
  }
}
const ticketTask = plan.tasks.find(task => task.id === 'T32');
for (const provider of ['Linear', 'Jira', 'Microsoft Planner', 'Asana', 'Trello', 'Notion', 'custom']) {
  assert(ticketTask.steps.join(' ').includes(provider), `Missing provider ${provider}`);
}
for (const [id, text] of [['T22', 'payload'], ['T34', 'Foundation Models'], ['T36', '150000000'], ['T40', 'premium']]) {
  assert(plan.tasks.find(task => task.id === id).steps.join(' ').includes(text), `Missing requested scope: ${id}/${text}`);
}
let execution;
try { execution = JSON.parse(await fs.readFile(path.join(base, 'implementation/local-agent-execution.json'), 'utf8')); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
let output = `# ${plan.title}\n\nFecha: ${plan.date}. ${execution?.currentMode ?? plan.executionMode}\n\n`;
if (execution) output += 'Estado de ejecución: [primer bloque local verificado](local-agent-execution.json), [gates](gates/local-agents-workflows.md) y [adjudicación de propuestas](local-agent-review-adjudication.json). Esta evidencia no certifica todo el roadmap ni el presupuesto de memoria.\n\n';
output += 'Este desglose conserva los 40 tickets y sus aceptaciones originales. Las subtareas siguientes son trabajo concreto; no cambian el estado de ejecución por estar planificadas.\n\n';
output += `## Política de modelos\n\n${plan.defaultModelPolicy}\n\n`;
for (const [role, detail] of Object.entries(plan.modelRoles)) output += `- ${role}: ${detail}\n`;
output += '\n## Contratos de implementación\n\n';
for (const item of plan.contracts) output += `- ${item}\n`;
output += '\n## Criterios apple-design para GitMac nativo\n\n';
output += 'Aplicar [apple-design](https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md), leído el 25 de octubre de 2026. Es una guía comunitaria orientada a web; adaptar sus principios a SwiftUI/AppKit y contrastar APIs con documentación oficial Apple.\n\n';
output += '- T16/T17/T18: componentes compartidos, tipografía del sistema, jerarquía clara y navegación predecible; materiales medidos, compatibles con temas y preferencias de accesibilidad.\n';
output += '- T19/T20/T22: feedback inmediato al presionar, arrastre continuo desde el punto de agarre y transiciones interrumpibles. Conservar controles y gestos nativos; no introducir librerías web.\n';
output += '- T17/T18/T38: probar movimiento reducido, transparencia reducida, contraste aumentado, teclado y VoiceOver; revisar estados claro/oscuro/custom y Retina.\n';
output += '- T22/T36: medir latencia y hitches al arrastrar pestañas, ramas y minimapa; cancelar o invertir durante la transición sin saltos ni acciones Git accidentales.\n';
output += '- Evidencia: prototipo funcional, capturas inspeccionadas y recorrido grabado por interacción; ningún efecto visual exime del presupuesto de memoria.\n';
output += '\n## Resolución de las revisiones de modelos\n\n';
output += 'Las propuestas locales y Cloud revisaron el paquete previo a incorporar apple-design. La revisión Cloud completa llegó cercada como Markdown y falló el parser JSON: se conserva como tal y sus observaciones se valoran manualmente; no se considera una aprobación automática. Ver [adjudicación](specific-plan-review-adjudication.json).\n\n';
output += 'Antes de implementar restricciones comerciales de T32, elaborar una matriz proveedor × capacidad × nivel propuesto y mantenerla sin activar hasta resolver la decisión comercial de T40. Medir cada backend IA y sus procesos auxiliares en T34/T36, conservando el límite principal. Para cerrar T40, cada P1 debe tener prueba de corrección o exclusión explícita del candidato con alcance y responsable; una excepción no cierra una tarea ni permite declarar todo terminado.\n';
output += '\n## Cómo genera y valida cambios el modelo\n\n';
plan.localPatchPipeline.forEach((step, index) => { output += `${index + 1}. ${step}\n`; });
output += execution
  ? '\nRunner disponible: scripts/local-agents.mjs, con roles/contextos separados, fuentes completas dentro del límite del paquete, rutas/hashes comprobados, propuestas conservadas e inferencias locales en serie. Propone cambios sobre archivos existentes; la integración es supervisada y exige pruebas. No aplica diffs automáticamente.\n\n'
  : '\nEl runner de propuestas y sus validaciones se implementarán como infraestructura antes del primer lote delegado. No existe todavía una autorización para aplicar automáticamente cualquier diff que devuelva el modelo.\n\n';
output += '## Orden de trabajo\n\nLas fases agrupan trabajo; las dependencias de cada ticket son las condiciones de cierre. Correcciones P0 acotadas pueden adelantarse con sus pruebas sin declarar cerrado su ticket padre.\n\n';
for (const phase of plan.phases) output += `- ${phase.id} ${phase.name}: ${phase.tasks.join(', ')}.\n`;
output += '\n## Desglose de los 40 tickets\n\n';
let leafCount = 0;
for (const task of plan.tasks) {
  const parent = parents.get(task.id);
  output += `### ${task.id} ${parent.title}\n\n`;
  output += `Estado del registro: ${ledger[task.id]?.state ?? 'pendiente'}. Specs: ${parent.specs}. Depende de: ${parent.dependencies}.\n\n`;
  output += `Modelo para el borrador: ${task.model}; revisión e integración independientes.\n\nArchivos existentes que revisar:\n\n`;
  for (const file of task.files) output += `- [${file}](../../../../${file}) — SHA256 ${files.get(file)}.\n`;
  output += '\nPasos y entregables:\n\n';
  task.steps.forEach((step, index) => { output += `- [ ] ${task.id}.${String(index + 1).padStart(2, '0')} ${step}\n`; leafCount++; });
  output += '\nPruebas que deben demostrar el resultado:\n\n';
  for (const test of task.tests) output += `- ${test}\n`;
  output += `\nCierre del ticket: ${parent.acceptance}.\n\n`;
}
output += '## Estado al preparar el plan\n\n';
for (const [name, detail] of Object.entries(plan.evidenceAtPlanning)) output += `- ${name}: ${detail}\n`;
output += '\n## Fuentes oficiales\n\n';
for (const reference of plan.references) output += `- [${reference.subject}](${reference.url}).\n`;
output += '\n## Puerta para empezar la implementación\n\n';
output += execution
  ? 'Ejecución autorizada por el usuario con modelos locales. Preparar el paquete de la siguiente subtarea y comprobar sus hashes. Cada lote termina con diff revisado, build, pruebas positivas/negativas y evidencia. El primer bloque no cierra T30; confirmaciones/concurrencia y configuración por repositorio permanecen pendientes.\n'
  : 'Confirmar orden y política híbrida, preparar runner/paquete de una subtarea y volver a comprobar sus hashes. Cada lote termina con diff revisado, build, pruebas positivas/negativas y evidencia. Firma, publicación, cobro y permisos de macOS conservan su autorización propia.\n';
const destination = path.join(base, 'implementation/PLAN-DETALLADO-2026-10-25.md');
await fs.writeFile(destination, output);
const report = { date: new Date().toISOString(), taskCount: 40, actionableSteps: leafCount, sourceFilesChecked: files.size,
  requestedProviders: 7, parentAcceptancesPreserved: true, productCompletionCertified: false, passed: true };
await fs.writeFile(path.join(base, 'implementation/specific-plan-validation.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
