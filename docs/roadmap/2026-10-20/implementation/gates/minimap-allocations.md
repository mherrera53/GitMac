# Gates: asignaciones del minimapa

- [x] G1: Conservar identidad completa, parent indices/lanes y equivalencia con el grafo en DAGs deterministas, incluyendo merges/octopus y padres ausentes.
  EVIDENCE: minimap-allocations-tests.log, 67 Swift Testing + 11 XCTest; 80 DAGs adicionales con SHA de 40 caracteres, oracle de carriles y parents verificados.
- [x] G2: Reducir copias temporales sin truncar el historial ni aumentar el límite de dibujo de 4096.
  EVIDENCE: GraphNode.swift conserva Substring solo durante construcción, copia SHA retenidos una vez; VM elimina arrays intermedios al construir índice y máximo. Tests mantienen 100k identidades y 4096 nodos de dibujo. No implica mejora cuantitativa aprobada.
- [x] G3: Repetir Release y mediciones con carga confirmada en 1k/100k; registrar el pico aunque el consumo posterior baje. No aprobar 150 MB si falla.
  EVIDENCE: minimap-allocations-debug.log y performance-fixture-release.log BUILD SUCCEEDED; performance-memory-1000-optimized-run.log pico 364725328 bytes y performance-memory-100000-optimized-run.log pico 374670488. Ambos passed:false. La variación entre ejecuciones impide atribuir ganancia causal o p95.

Este gate acredita la modificación acotada y su evaluación, no cumplimiento de presupuesto, paridad completa ni cierre de T21/T36. Pendiente localizar el pico y validar la matriz completa de flujos.
