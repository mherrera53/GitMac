# Resolver robusto y conservación de cambios locales

Prioridad explícita del usuario: detectar conflictos reales, preservar trabajo local y completar resolución/continuación de forma robusta. Conservar los 206 pasos y los demás gates abiertos; esta hoja concreta T23/T26/T28 y depende de identidad/procesos/recuperación.

- [ ] F1: Reproducir detección sobre Git real con status de UI obsoleto; distinguir etapas del index y operación activa, incluyendo worktrees y merge/rebase/cherry-pick/stash.
  EVIDENCE: conflict-empty-choice-after.log incluye status obsoleto y merge/rebase/cherry-pick/revert/stash reales; matriz de worktrees aún pendiente. conflict-current-negative.log reproduce 16 fallos de comportamiento anteriores.
- [ ] F2: Una resolución queda vinculada a repositorio, archivo y snapshot; rechazar contenido/index obsoleto, cambios de repo y doble ejecución. Conservar archivos del usuario y errores visibles.
  EVIDENCE: pending
- [ ] F3: Preservar originales y propuesta recuperables antes de escribir, bytes/newlines/modos; errores de staging no se muestran como éxito. Probar index.lock, ediciones concurrentes, nombres difíciles y rutas/symlinks inseguras.
  EVIDENCE: conflict-preservation-audit.md; originales/propuesta/tres etapas exactas, CRLF, índice bloqueado, snapshot obsoleto, symlink y ruta fuera del worktree probados. ACL/xattrs, tipos especiales y carrera externa completa pendientes.
- [ ] F4: Guardar/preparar/continuar/abortar corresponden a la operación actual, revalidan conflictos en Git y conservan recuperación. No elegir ours/theirs automáticamente; indicar su semántica durante rebase. Binarios/delete/rename tienen controles explícitos o fallback visible.
  EVIDENCE: pending
- [ ] F5: UI muestra fallos, opciones, preview, recarga y recuperación; probar flujo real/teclado/temas y controles negativos. Actualizar archivo/línea/hash, mapas y roadmap sin aprobar escenarios no ejecutados.
  EVIDENCE: conflict-live-ui.xcresult pasa flujo real de ambas → staging → merge de dos padres con nota local preservada. Detalles visuales posteriores requieren conflict-theme-final-ui.xcresult; teclado/VoiceOver y todos los estados siguen abiertos.
