# Worktrees: detectar, entender y publicar la rama

Petición explícita: que los worktrees sean fáciles de detectar, usar y publicar. Extiende T29 y depende de T11/T12/T27/T28; no sustituye el roadmap completo.

Hallazgo de fuente: WorktreeListView ofrece crear/abrir/proteger/retirar y ayuda; WorktreeSidebarSection enumera los worktrees registrados al cambiar repositorio. No existe acción de publicación en esas interfaces. El manager es compartido y su aislamiento debe comprobarse antes de añadir efectos de red.

Semántica: el worktree es una carpeta local; se publica su rama y sus commits mediante push, con remoto y upstream explícitos. Referencias oficiales consultadas: https://git-scm.com/docs/git-worktree y https://git-scm.com/docs/git-push. No publicar nada del usuario como parte de los tests.

- [ ] P1: Detectar worktrees registrados y cambios externos; indicar carpeta activa, rama, destino remoto, dirty/locked/missing/detached con estados que correspondan al worktree correcto.
  EVIDENCE: pending
- [ ] P2: Crear/abrir/cambiar de tarea sin perder WIP, con validación inline, nombres claros y ayuda contextual; recorrido UI y teclado sobre fixtures propios.
  EVIDENCE: pending
- [ ] P3: Publicar rama con preview de remoto/ref/upstream y revalidación de identidad; no force implícito, doble envío ni comandos sobre el worktree equivocado. Detached necesita crear rama antes.
  EVIDENCE: pending
- [ ] P4: Probar push y tracking con bare local, fallos y concurrencia; UI de resultado/reintento y temas; documentación de límites de red/auth sin aprobarlos mediante el bare local.
  EVIDENCE: pending
