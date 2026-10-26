# Workflows: confirmación, cancelación y ejecución exclusiva

Contrato: una ejecución activa por motor; una decisión consume exactamente una continuación; cancelar una espera libera el motor y no ejecuta pasos posteriores. No completa Gitflow, persistencia por repositorio ni la UI de workflows.

- [x] W1: Pruebas de producción reproducen la reanudación doble, la cancelación y la ejecución simultánea sin bloquear el runner.
  EVIDENCE: workflow-confirmations-before.log: seis escenarios, cuatro fallos; workflow-decisions-negative.log amplía a siete escenarios y cinco fallos originales, incluidos dos SIGTRAP. Cada caso corre en proceso aislado con timeout.
- [x] W2: Cada espera consume una sola decisión y las decisiones repetidas no afectan la siguiente espera.
  EVIDENCE: workflow-decisions-after.log: siete escenarios pasan. workflow-stale-decision-before.log reproduce la respuesta tardía que aceptaba una pregunta posterior. La API final exige el UUID capturado por pregunta y rechaza tanto confirm como cancel antiguos.
- [x] W3: Cancelación de la tarea y rechazo de ejecución simultánea preservan estado, efectos y recuperación.
  EVIDENCE: workflow-decisions-after.log; producción consume/limpia antes de resume, cancellation handler valida UUID dentro de MainActor; no hay pasos/notificaciones posteriores al cancelar.
- [x] W4: Regresión Git existente, build firmado y revisión local contrastada pasan; T30 permanece abierta por sus demás criterios.
  EVIDENCE: workflow-confirmations-git.log: 37 checks pasan; workflow-decision-build.log: TEST BUILD SUCCEEDED; verification.json registra la regresión final y controles. workflow-confirmations-adjudication.json conserva tres contextos de revisión, propuestas e integración supervisada, rechazando afirmaciones incorrectas sin aprobación automática.
