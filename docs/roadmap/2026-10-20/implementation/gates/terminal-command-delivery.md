# Terminal utilizada: IA explícita, rutas y entrega de comandos

Hoja de Q3/T16/T34. No sustituye los 206 pasos. El recorrido real es BottomPanelContent → GhosttyWithAIInput → AIInputBar → AITextEditor/GhosttyConnector. No se da por reparado cambiando una vista sin caller encontrado.

- [x] D1: Identificar implementaciones y el caller real antes de editar; leer archivos completos y relacionados.
  EVIDENCE: mapping/source-graph.json y búsquedas de constructores; BottomPanelContent.swift abre GhosttyWithAIInput/AIInputBar. Las otras implementaciones se mantienen pendientes de reconciliación, no eliminadas por inferencia.
- [x] D2: Controlador bajo demanda con exclusión, cancelación, contexto vigente, límites y error visible; escribir/cambiar repo/cerrar solo invalida. Usar AIService compartido sin un transporte Ollama paralelo.
  EVIDENCE: terminal-command-final-checks.log: 35 checks pasan; terminal-stale-result-negative.log reproduce tres fallos al retirar la guarda. El test inyecta el proveedor; no acredita GPU ni todo el producto.
- [x] D3: Citar rutas/metacaracteres como argumentos literales; no ejecutar comandos inyectados por nombres de carpetas y no borrar input si no hay surface lista.
  EVIDENCE: zsh -f real en seis carpetas sintéticas; el control sin quote falla seis checks y crea solo el sentinel privado. La guardia de entrega conserva input ante surface ausente; el recorrido UI sigue pendiente.
- [ ] D4: Usar píxeles de backing y actualizar cambios de monitor; conectar wakeup al tick; demostrar salida visible y sesiones/IME/clipboard/cancelación apropiadas.
  EVIDENCE: controles geométricos a 1x/1.5x/2x/3x pasan; ignorar escala produce cinco fallos. Se añadieron updateSurfaceSize y wakeup_cb. terminal-wire-ui.xcresult pasa el comando real con salida y cwd comprobados. IME, clipboard, cancelación y matriz entre monitores siguen abiertos; no hay aprobación integral.
- [ ] D5: Prueba UI escribe y comprueba bytes solo en fixture, verifica input literal y captura el resultado; repetir fuentes/hash, mapas y memoria del candidato final.
  EVIDENCE: terminal-wire-ui.xcresult pasa una prueba firmada, con input exacto, bytes y device/inode del cwd. terminal-wire-ui-candidate.json fija fuentes/binarios y la captura fue inspeccionada. test-native-terminal-wire reproduce cinco fallos al devolver éxito sin escribir; se corrigió ese retorno. Mapas/auditoría y memoria final se registran aparte; los fallos históricos se conservan y no se sustituye la app instalada.
