# Crash al seleccionar un stash

## Evidencia y causa acotada

El usuario confirmó el disparador: seleccionar un stash. DiagnosticReports/GitMac-2026-10-20-213805.ips identifica PID 52533, la copia candidate-drgWMH abierta en esta sesión, SIGABRT a las 21:38:02 -0600. La última excepción pasa por NSWindow._postWindowNeedsUpdateConstraints, NSHostingView.SizeConstraints.update y SplitViewChildController.hostingView(didUpdateMinSize:maxSize:). Unified log confirma NSGenericException por demasiadas pasadas Update Constraints in Window. No es un rechazo de firma ni de Gatekeeper.

No se atribuye todavía una línea única como origen exhaustivamente demostrado del abort: la traza nativa no la proporciona. Se comprobó una ruta de realimentación de tamaño en el panel y tres cargas concurrentes potenciales por selección (onChange y task del padre, task del hijo). El informe anterior de la app instalada presenta otra excepción de layout, pero no basta para afirmar identidad de causa.

## Cambios

- StashDetailPanel: GeometryReader delimita el contenido con el tamaño propuesto por el inspector; el cambio carga/lista y los textos largos dejan de exportar mínimos intrínsecos variables a su contenedor nativo. Rama limitada a una línea. repositoryPath explícito evita inicializar AppState al probar el componente.
- RightStagingPanel: pasa el repositorio y elimina sus dos cargas duplicadas. El hijo es el único propietario de task, identificado por repositorio y SHA; cambiar selección o repositorio vuelve a cargar.
- NativeStashPanelTests: usa panel y VM reales. Comprueba mínimo nativo estable, 30 transiciones con NavigationSplitView/inspector y ventanas de 640/1105/1512 puntos, y lectura mediante la task del panel desde un repositorio temporal con stash real. Confirma que inspeccionar no aplica, elimina ni extrae el stash.

## Verificación

stash-crash-debug.log: BUILD SUCCEEDED. stash-panel-tests.log: 43 Swift Testing en siete suites y 11 XCTest, sin fallos.

stash-panel-negative-control.log: se retira únicamente el contenedor geométrico de una copia temporal del componente. La prueba falla con exactamente un issue: fittingSize cambia de 1559×269 a 3934×2797. Producción no se modifica con este control. Esto detecta mínimos inestables; no equivale a reproducir determinísticamente el SIGABRT de la app completa.

Revisión qwen3-coder:30b local (remote:false), local-stash-crash-review.json. Su supuesto fallo por repositoryPath nil no es un crash demostrado: el nil se comprueba antes de cargar, se usa deliberadamente en pruebas sin I/O y el único llamador de producción pasa la ruta. La prueba con repositorio temporal cubre también la ruta no nil. La advertencia de dependencia explícita no es una regresión acreditada; permite probar el componente sin servicios globales. La truncación conserva el valor del modelo, aunque su revisión visual sigue pendiente.

No se ha sustituido /Applications, modificado stashes del usuario ni concedido permisos del sistema. El candidato anterior no debe presentarse como funcionalmente aprobado por estar notarizado. La reapertura del nuevo build y la selección del stash del usuario son la validación funcional pendiente.

## Segundo fallo real: abrir el visor de archivos

El primer intento candidate-nk5Qa2 fue aceptado por Apple (922f7679-b02e-4b5b-8761-087ebdb9bf84), con firma, stapling y Gatekeeper válidos; aun así se cerró después de abrirse como PID 62887. GitMac-2026-10-20-214650.ips y el informe aportado por el usuario registran SIGABRT a las 21:46:48 -0600, con el mismo ciclo SplitViewChildController/SizeConstraints. El usuario precisa que esta vez ocurrió al abrir el visor de archivos. La prueba de stash aislada no cubría el reemplazo completo del centro ni el cambio de modo del inspector y NO demuestra que el primer intento resolviera el crash.

Segundo cambio: MainLayout delimita ahora cada columna completa mediante GeometryReader y el tamaño propuesto por su contenedor. Incluye el centro al cambiar grafo/carga/visor y el inspector al cambiar staging/commit/stash. Conserva NavigationSplitView, inspector y anchos nativos; no deshabilita excepciones ni introduce sleeps como supuesto arreglo. El cierre funcional sigue pendiente de nueva compilación y comprobación real. No volver a abrir nk5Qa2 como build corregido.

viewer-crash-debug.log: BUILD SUCCEEDED. Auditoría regenerada tras modificar MainLayout: verification.json verifica hashes de 39 archivos y seis comprobaciones con sus salidas esperadas, incluidos ambos controles negativos. El mapa actual conserva 430 archivos; sus aristas siguen siendo candidatas de sintaxis, no llamadas acreditadas por compilador.

Segunda revisión local: local-viewer-crash-review.json, remote:false. Se descarta de nuevo la objeción de macOS 13 porque el deployment target es 14 y no se redujo. El nil de repositoryPath está protegido y tiene cobertura con/sin ruta. La observación genérica de rendimiento no acredita un defecto ni sustituye medición; no se afirma que el producto completo esté optimizado. El fitting ignora live resize/fullscreen y solo cambia el marco cuando sale del área útil. El informe del modelo no aprueba el cierre funcional.

viewer-crash-release.log: BUILD SUCCEEDED. Gate ejecutable [crash-layout.md](gates/crash-layout.md): 3/4 cumplidos (diagnóstico, ambos builds y regresiones/hashes); G4 exige seleccionar el stash y abrir su archivo en la app completa. No se marcará por inferencia a partir de los tests ni por ausencia breve de nuevos informes.

## Candidato actual de columnas completas

`build/DistributionCandidates/candidate-lv8hVz/GitMac.app`, envío Apple `5382d3a9-af10-4508-9354-bb011cd61b2b`, Accepted. distribution-viewer-final.log acredita firma estricta, stapling y Gatekeeper. ZIP final SHA-256 `144f557a06b215608487eec5157f8d485261de286d0b135e1a955f7cd4891c16`.

Abierto sin reemplazar la app instalada. NSWorkspace confirma bundleURL exacto y PID 69666; ventana 117424 de 1105×791 puntos en (306,249) CG. viewer-launch-monitor.log registra la vigilancia posterior. Se solicitó comprobar stash → archivo → visor en esta copia, no en nk5Qa2. La mera apertura no acredita G4.
