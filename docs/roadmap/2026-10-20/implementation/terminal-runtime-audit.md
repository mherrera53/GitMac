# Terminal: entrega real y límites

El comando del fixture se ejecuta y conserva bytes y directorio. `terminal-wire-ui.xcresult` pasa una prueba firmada en un bundle separado; `terminal-wire-ui-candidate.json` fija fuentes y binarios. No es aprobación de todos los comandos ni de la distribución.

| Archivo y línea | Cambio comprobado | Evidencia |
| --- | --- | --- |
| BottomPanelContent.swift:234 | Rechazar surface ausente/proceso terminado/NUL; escribir antes de devolver éxito | `terminal-wire-checks.log`: ocho escenarios; retorno prematuro reproduce cinco fallos en `terminal-wire-negative.log` |
| BottomPanelContent.swift:335 | Convertir tamaño lógico a backing pixels al cambiar geometría/monitor | Contratos de escala 1/1.5/2/3 y cinco fallos al retirar escala; falta recorrido completo entre monitores |
| BottomPanelContent.swift:478 | Despachar wakeup de Ghostty al tick en main | Build firmado y ejecución real del fixture; no certifica todas las sesiones |
| TerminalInputBar.swift:185/369 | Solicitud de IA explícita, resultados acotados, cancelación y generación/contexto vigentes | 35 contratos y controles negativos de 3/6/5 fallos; transporte AI inyectado en el harness |
| TerminalInputBar.swift:402 | Quote de directorios como argumentos literales, sin interpolar nombres | zsh real en seis rutas adversarias privadas |
| TerminalSharedTypes.swift:60 | Respetar composición marcada y actualizar coordinator/colores sin reescritura innecesaria | Build y texto literal UI; IME completo sigue pendiente |
| SnapshotHelper.swift:172 | Entrada de fixture con modificadores explícitos para c/C/apóstrofo y teclado dead-key detectado en lectura | Campo estándar y terminal conservan el texto exacto; no se cambió el teclado del usuario |
| GitMacUITests.swift:473 | Comando escribe exclusivamente en rutas absolutas del fixture; valida bytes y device/inode del cwd | `terminal-wire-ui.log`: una prueba, cero fallos; captura de salida inspeccionada |

Se identificaron dos fallos independientes. La síntesis de XCTest introducía Command en c/apóstrofo, también en un campo estándar. Después de corregir solo el helper, la entrega todavía fallaba: un retorno prematuro introducido durante esta ejecución comunicaba éxito sin escribir. Se movió al final del método y se añadió un harness de su cuerpo real con la frontera C simulada; la ejecución UI posterior comprueba el shell real.

El buffer experimental no corregía la pérdida de teclas y fue retirado; permanece en `experiments/terminal-input-buffer`. La revisión qwen3-coder local no detectó el retorno prematuro. Sus propuestas no se aplicaron automáticamente y no sustituyen estas pruebas. No se usó Cloud; el modelo fue descargado después de la revisión.

La captura muestra `terminal fixture` y prompt recuperado; el input queda vacío después de la entrega. El contenido anterior del scrollback puede quedar fuera de la región visible. Siguen abiertos IME completo, clipboard, interrupciones, ownership/cwd tras cambios de repositorio, atajos, otros editores terminal y restauración/multiventana. Los checks de color/escala no certifican accesibilidad ni todos los themes del terminal.

La app instalada permanece intacta y respaldada. Los gates de memoria, funcionalidad y distribución del candidato vigente siguen siendo condición de sustitución.
