# Gates del plan específico

Scope: petición de plan primero; no ejecución ni aprobación integral del producto.

- [x] P1: Conservar los 40 tickets, aceptaciones, fases y archivos reales; desglosar cada ticket con pasos y pruebas.
  CHECK: node docs/roadmap/2026-10-20/tools/render-specific-plan.mjs
  EXPECT: "taskCount": 40
  EVIDENCE: specific-plan-validation.json: 40 tickets, 206 pasos, 89 archivos con hash, siete proveedores; execution-plan-validation.json: 28 specs, cero errores, estados 5/19/16 preservados.
- [x] P2: Cubrir ventanas, temas, componentes, repos/config/workflows, siete proveedores, comandos, conflictos, premium, drag & drop, IA Apple y presupuesto estricto.
  EVIDENCE: PLAN-DETALLADO-2026-10-25.md leído de vuelta; secciones T16–T22, T26, T29–T34, T36 y T40, más criterios apple-design nativos con accesibilidad y medición.
- [x] P3: Política híbrida elegida, paquetes revisados sin código/secretos, propuestas local/Cloud completas y adjudicación independiente.
  EVIDENCE: specific-plan-review-adjudication.json y ambos *-review-bounded.json; Cloud completo leído manualmente con fallo JSON preservado, sin autoaprobación; /api/ps models:[] al terminar.
- [x] P4: Control negativo rechaza una tarea omitida; documentación leída de vuelta, límites/estado actuales y aplicación pausada hasta seguir el plan.
  EVIDENCE: --missing-task-control exit 1 Expected 40 tasks; received 39; git diff --check exit 0. Producto no certificado; presupuesto de memoria sigue fallido y no se reanudaron cambios de aplicación durante el plan.
