# Gates: pestañas, configuración y minimapa

Scope: pulir pestañas de repositorios, distinguir Ajustes de opciones del grafo y navegar el historial local de la consulta actual mediante minimapa. No incluir fetch implícito, cambios en repositorios del usuario ni supuesta paridad completa con GitKraken.

- [ ] G1: Pestaña activa visible, nombres acotados, cierre independiente y menú de repositorios abiertos/recientes funcional.
  EVIDENCE: Implementación en RepositoryTabsView.swift y compilación contextual-final-debug.log; pendiente comprobación interactiva/visual del usuario.
- [ ] G2: Configuración accesible con controles nativos y toolbar del grafo que cabe en ventanas pequeñas sin perder acciones.
  EVIDENCE: SettingsLink nativo y menú compacto en ContentView/CommitGraphView; Debug pasa. Pendiente validación en ambas pantallas.
- [x] G3: Minimapa identifica commits por SHA, limita el coste de dibujo y representa el viewport sin confundir filas WIP/stash con commits.
  EVIDENCE: production-suites-current.log pasa MinimapLayoutTests (incluido fixture 100k); core-regressions-and-models.log prueba lotes y cursor. verification.json: passed=true y hashes vigentes. No certifica latencia/UX completa.
- [ ] G4: Build, pruebas de producción, auditoría por archivo/línea y candidato separado pasan; revisión visual/funcional del usuario registrada por separado.
  EVIDENCE: Debug/Release, siete checks del audit, mapping vigente y candidato separado candidate-Yn60GL pasan; Apple Accepted 67ad2724-6299-4c4a-b21e-6e5514d7849d con stapling/Gatekeeper. Revisión visual/funcional del usuario aún pendiente, sin cerrar este gate.
