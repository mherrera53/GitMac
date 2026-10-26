# Ejecución local por agentes: infraestructura y primera hoja

Contrato: autorización de ejecución recibida. Agentes con contextos nuevos y roles separados, inferencia local en serie, ninguna aplicación automática de propuestas. Hoja T30.03: errores Git, pathspec y recuperación de rebase. El resto del roadmap permanece abierto.

- [x] L1: Runner valida pesos locales, ownership, rutas/hashes y respuestas; rechaza Cloud, colisiones, rutas externas y propuestas obsoletas.
  CHECK: node scripts/test-local-agents.mjs
  EVIDENCE: scripts/test-local-agents.mjs: 16 controles positivos/adversarios pasan. Ninguna propuesta se aplica automáticamente; los intentos truncados están conservados.
- [x] L2: Implementador, diseñador de pruebas y revisor ejecutados con contexto independiente; conservar paquetes, resultados, digest y unload.
  EVIDENCE: local-agents/*-proposal.json y *-packet.json de workflow-failfast-anchored, workflow-test-designer-final, workflow-reviewer-final; digest 06c1097efce0431c2045fe7b2e5108366e43bee1b4603a7aded8f21689e90bca y targetUnloaded:true en los tres *-unload.json. Adjudicación independiente en local-agent-review-adjudication.json.
- [x] L3: Workflows detienen la secuencia tras errores Git; no emiten éxito ni abortan un rebase conflictivo automáticamente; pathspec admite guion inicial.
  CHECK: node scripts/test-workflow-safety.mjs
  EVIDENCE: workflow-safety-after.log: WORKFLOW_SAFETY_CHECKS: 37 checks, 0 failures. Fuentes de WorkflowEngine, GitWorkflow y ShellExecutor reales; fronteras AI/UI/branch manager explícitas.
- [x] L4: Control anterior falla por comportamiento, Debug compila, revisión independiente y diff final sin errores.
  EVIDENCE: workflow-safety-negative-final.log: 37 checks, 22 failures; local-agent-workflow-debug.log: BUILD SUCCEEDED con firma; local-agent-review-adjudication.json; git diff --check exit 0. Release/UX completa/presupuesto no certificados.
