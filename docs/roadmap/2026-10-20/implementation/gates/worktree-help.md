# Gates: worktrees y ayuda contextual

Scope: flujos de worktrees sin force implícito y ayuda offline para operaciones principales. No aprobación de todas las acciones Git o de concurrencia multiventana.

- [x] G1: Parser conserva rutas NUL y estados de Git; ciclo aislado de creación/protección/retirada preserva datos.
  EVIDENCE: WorktreeHelpTests en production-suites-current.log, con Git real, branch retenida, rechazo de carpeta sucia y bloqueada.
- [x] G2: Catálogo offline buscable y sin ejecución implícita, con riesgos y enlaces oficiales por tema.
  EVIDENCE: 31 GitHelpTopic únicos y matching probados en WorktreeHelpTests; GitHelpSheet solo usa texto, búsqueda y Link. Compila en contextual-final-debug.log.
- [ ] G3: Crear, corregir errores, abrir y cancelar resultan comprensibles en interacción real; ayudas se abren/cierran con teclado y caben en Retina/LG.
  EVIDENCE: Implementación completada; pendiente revisión visual/teclado/VoiceOver. No hay permisos de automatización UI.
