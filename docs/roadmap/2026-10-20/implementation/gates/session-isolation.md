# Gates: aislamiento de sesión y pestañas

Scope: ruta vertical AppState → GitService; no dar por verificados todos los servicios, ventanas o journal.

- [x] G1: Refresh de A que termina después de seleccionar B no reemplaza B ni activa watchers de A; refresh anterior no gana a otro más nuevo de la misma pestaña.
  EVIDENCE: session-isolation-current.log; AppState completo de producción, frontera de GitService explícitamente simulada; el control anterior produce seis fallos de comportamiento.
- [x] G2: Cerrar pestaña invalida publicaciones tardías y elimina destinos muertos del historial. Seleccionar un UUID inexistente no deja la ventana vacía.
  EVIDENCE: session-isolation-current.log; cierre durante refresh, historial, UUID desconocido y eliminación de ruta persistida al cerrar la última pestaña.
- [ ] G3: La carga de snapshots no activa otra sesión; servicio y watcher activos siguen la pestaña seleccionada. Cachés no se comparten entre rutas.
  EVIDENCE: GitService implementa readRepository sin activación, activateRepository invalida cachés por ruta y watcher con identidad capturada. Prueba AppState positiva; falta integración de la sesión completa y todos los recursos/servicios.
- [x] G4: Las regresiones ejercitan métodos de producción con I/O controlado, detectan el comportamiento anterior y el build real pasa.
  EVIDENCE: session-isolation-current.log (12 checks), session-isolation-current-negative.log (6 fallos esperados), repository-scope-tests-debug.log (BUILD SUCCEEDED). No equivale a UI/multiventana.
