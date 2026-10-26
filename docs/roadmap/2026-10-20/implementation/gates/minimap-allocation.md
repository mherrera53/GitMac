# Minimap: asignaciones temporales con historial completo

Contrato: reducir el pico medido en 100.000 commits sin truncar identidad, índices, padres ni geometría. No modificar el alcance Git ni sustituir la medición del producto por un microbenchmark.

- [ ] A1: Identificar asignaciones retenidas/transitorias de MinimapLayout.build; conservar baseline de producto y comparación de implementación real.
  EVIDENCE: experimento completo y baseline conservados en experiments/minimap-allocation; 130 casos equivalentes. La medición conflict-minimap-memory-100000.log alcanzó 184878232 bytes y no demostró ahorro: se retiró el experimento del producto. Falta atribuir el pico con instrumentos válidos.
- [x] A2: Preservar orden/deduplicación, cadenas, merges, padres ausentes, caracteres admitidos, lanes y navegación; verificar fixtures deterministas contra el grafo real y la implementación anterior.
  EVIDENCE: minimap-allocation-after.log: 130 comparaciones con el algoritmo anterior, incluidos 100k SHA completos; minimap-allocation-negative.log: alterar parentLanes reproduce 124 fallos. conflict-wip-production-fixed.log: 73 Swift Testing y 11 XCTest pasan, incluidos 80 DAGs contrastados con buildCommitGraph y geometría/navegación. No aprueba memoria ni arrastre UI.
- [ ] A3: Compilar inmediatamente, ejecutar regresiones proporcionales y medir el mismo Release en 1k/10k/100k con señales de carga y dibujo.
  EVIDENCE: conflict-minimap-release.log compila; su fixture 100k falla presupuesto. La matriz posterior del candidato sin el experimento se registra aparte; no acredita una mejora causal de tres pasadas.
- [ ] A4: Revisar diff, conservar cualquier incumplimiento, actualizar mapas/evidencias y T21/T36 sin cerrar sus demás criterios.
  EVIDENCE: pending
