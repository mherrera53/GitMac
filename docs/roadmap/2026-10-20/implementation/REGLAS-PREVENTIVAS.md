# Reglas preventivas de verificación

No hay herramienta de memory disponible en esta sesión. Se conserva aquí el aprendizaje aplicable al repo.

- Las capturas de XCTest incluyen un perfil ICC de pantalla. NSBitmapImageRep.colorAt convertido como RGB genérico produjo un falso fallo con Solarized: el PNG contenía (252,246,228) en perfil Display y corresponde a (253,246,227) sRGB. Dibujar CGImageSource en un CGContext sRGB antes de comparar, sin ampliar tolerancias para esconder diferencias.

- Selección y persistencia de un tema no prueban que se dibuje: comprobar tokens AppTheme reales y píxeles del candidato. Solarized Light mostraba blanco aunque el editor indicaba custom activo; ThemeManager pasaba 34 checks pero los getters compartidos ignoraban fondo/texto/accent custom. Conservar control UI negativo y prueba de restauración tras relanzar.
- Un modelo visual puede inventar solapamientos e incluso confundir claro/oscuro. Conservar respuesta, contrastar imagen original, geometría/estado UI y colores; nunca aprobar ni reescribir componentes solo por su diagnóstico.
- Aislar GIT_CONFIG_GLOBAL y demás entorno también en XCUIApplication.launchEnvironment; aislar solo la creación del repositorio no protege el panel Git global. La identidad visible debe ser sintética y sus escrituras quedar dentro del fixture.
- Las costuras de inyección de tests deben conservar el tipo no opcional del servicio real. Un singleton fixture IUO inferido mediante let se convirtió en ThemeManager?; usar un getter no opcional con precondición, sin modificar los getters de producción para arreglar el harness.

- En revisiones LLM, acotar también el número y longitud de hallazgos. Un límite de salida puede cortar JSON o consumirse en thinking sin respuesta final; registrar done_reason/bytes de thinking, conservar el intento fallido y nunca aceptar JSON reparado o vacío como revisión completa.

- En propuestas de código local, limitar el tamaño de cada fragmento old/new y rechazar sustituciones de archivo completo antes de integrar. Una instrucción de cambio quirúrgico no basta: un modelo intentó serializar WorkflowEngine completo y agotó 6000 tokens. Conservar raw/done_reason y volver a acotar el contrato; nunca completar manualmente un JSON truncado para aplicarlo.

- Para arrastrar en macOS, usar XCUICoordinate.click(forDuration:thenDragTo:), declarado en MouseEvents; press pertenece a TouchEvents. Un arrastre táctil sin cambio de frame no demuestra que NSWindow sea no redimensionable. Comprobar la API del SDK antes de añadir adaptadores AppKit y retirar los que no tengan causa real demostrada.

- En ventanas con sidebar y contenido desplazable, no usar app.scrollViews.firstMatch: puede desplazar la navegación. Acotar el scroll al grupo del panel activo y verificar que el último control sea hittable. Un accessibilityIdentifier en una raíz SwiftUI debe usar children:.contain si su propagación está sobrescribiendo IDs de descendientes.

- En NSHostingView, fittingSize puede expresar el tamaño ideal, no el mínimo permitido. Para una raíz de ventana con min/ideal/max, contrastar contentMinSize real de NSWindow y estabilidad de fittingSize por separado; el control negativo de frame fijo debe seguir fallando. Serializar pruebas nativas que abren ventanas con UI tests que usan el ratón.

- Antes de cerrar infraestructura de tests, verificar git check-ignore para cada fuente nueva. Un helper que compila localmente pero permanece excluido por GitMacUITests/ puede faltar en CI; permitir fuentes Swift explícitamente sin agregar archivos al index del usuario.

- En el runner de XCTest, /usr/bin/git puede resolver mediante xcrun y fallar bajo sandbox. Resolver un binario Git existente dentro del toolchain; no desactivar el sandbox. Retirar DYLD_* y GIT_* heredados de los fixtures.
- Ventana existente y grafo visible no prueban que la sesión haya cargado las ramas. Comprobar la rama en UI y exigir branches-loaded en el profiler antes de comparar memoria; el fixture debe configurar el mismo manager que la apertura normal.
- test-without-building requiere TEST EXECUTE SUCCEEDED; build-for-testing requiere TEST BUILD SUCCEEDED. Mantener separados ambos contratos del wrapper para no aprobar una compilación como ejecución de tests.

- Distinguir IDs de tareas T01–T40 de fixtures F01–F15: el checker del modelo de amenazas debe rechazar referencias inventadas como F30 aunque el texto parezca plausible.
- Un build-for-testing no sustituye test: usar el esquema que incluye el target solicitado y verificar firma del runner antes de atribuir un SIGKILL a la app. Si el output previamente lanzado impide escritura/firma, crear productos nuevos aislados; no desactivar protecciones de macOS ni tocar la app instalada.
- Git reemplaza HEAD/index mediante lock+rename. Mantener un watcher del ancestro existente y descender al crear directorios; comparar inode antes de rearmar evita señales falsas por archivos vecinos. Probar primer stash y sustituciones repetidas, no solo el archivo que ya existía al abrir.

- Desglosar categorías durante el pico antes de atribuir RAM al heap o a modelos: 169 MB de memoria gráfica no mapeada pueden dominar frente a 48 MB de Malloc Small. Esa categoría no identifica por sí sola el Canvas/driver responsable; una repetición menor tampoco demuestra causalidad.

- Un cancel handler debe capturar el descriptor que le pertenece, no leer el descriptor mutable del watcher al ejecutarse: un reinicio puede haber asignado otro. Verificar también deinit sin propietario vivo y no solo restart.
- Una medición de ventana abierta no acredita grafo cargado: exigir señales de repositorio, grafo y minimapa con los recuentos esperados antes del muestreo. Conservar mediciones anteriores como provisionales, no borrar sus fallos.
- Git y Foundation pueden representar Unicode con normalizaciones distintas además del alias /private. Contrastar dispositivo/inode del directorio real conservando saltos de línea internos; no normalizar rutas con trim indiscriminado.
- Los controles negativos deben validar el contrato real del runner, incluido su formato de salida. Un espacio ausente en la expectativa del audit no convierte seis fallos de comportamiento observados en un control no ejecutado; corregir el checker y repetirlo, sin rebajar el número requerido.

- execution-tasks.csv es generado: editar implementation/task-state.json como fuente de progreso y regenerar con validate-execution-plan.mjs. Editar únicamente el CSV pierde avances al validar. El validador comprueba estructura y evidencias declaradas, no ejecuta todas las funcionalidades.

- Serializar benchmark y revisión local, incluso si usan el mismo modelo: una revisión mantiene la residencia y contamina latencia/descarga. Se canceló solo el benchmark propio PID 21376 al detectar solapamiento; sus observaciones no se usan como comparación aislada. Esperar motor vacío antes de repetir.

- Ollama keep_alive=0 solicita liberar pesos, pero /api/ps puede seguir mostrando el modelo justo después del HTTP 200. Observar la descarga con polling acotado antes de medir el siguiente modelo; no atribuir memoria cero al instante ni forzar la parada de motores del usuario.
- RSS pequeño no demuestra cumplir el presupuesto de RAM en macOS: incluir physical footprint, memoria comprimida y pico de vida. El gate usa 150 000 000 bytes y falla si falta alguna observación o el pico.

- En tests con URLProtocol, Foundation puede mover httpBody a httpBodyStream. Capturar los bytes del stream antes de afirmar que se envió un body vacío o que no contiene un prompt. La prueba de confidencialidad debe inspeccionar el transporte real, no asumir que nil significa cero bytes.
- No compilar una referencia nueva sin sus tipos auxiliares en el mismo lote: el primer build de IA detectó LocalAIRequestPolicy/LocalAIRedirectGuard ausentes. Mantener el fallo original y recompilar el lote completo; no reinterpretarlo como fallo de toolchain.

- Generar el visor actual solo después de que termine audit-implementation: depende del verification.json con los hashes nuevos. Ejecutarlo en paralelo puede leer un snapshot anterior; su rechazo de hashes obsoletos es correcto y no debe desactivarse.
- En worktree --porcelain -z, conservar rutas y motivos literales, admitir bare sin HEAD y motivos opcionales. Probar el ciclo con Git real y no deducir seguridad solo del parser.
- Identificar destinos del minimapa por SHA; WIP/stashes y filtros no comparten el índice de commits. Limitar el dibujo no permite borrar identidades del índice ni confundir un fixture de 100k con un benchmark completo.
- Un formulario asíncrono debe conservar el repositorio de origen, evitar doble envío y cerrarse solo tras éxito; los errores deben conservar entrada y ofrecer recuperación sin force implícito.

- Comparar identidad de directorios (dispositivo e inode), no igualdad literal de rutas, para pruebas de cwd en macOS: rutas /var, /private/var y aliases del volumen pueden identificar el mismo directorio. No relajar una prueba de cwd a comprobar solo el exit code.
- Mantener el líder de un grupo POSIX sin reap hasta completar limpieza de hijos/pipes; así el PID no puede reutilizarse mientras todavía se envían señales al grupo.
- Para porcelain/numstat NUL, no separar rutas por tab/newline ni interpretar ` -> ` como delimitador. NUL no puede formar parte de un nombre de archivo POSIX; rechazar como falso positivo cualquier recomendación de probarlo como filename válido.
- Al distinguir archivo inexistente de un fallo de almacenamiento, Foundation puede devolver NSFileNoSuchFileError (4) o NSFileReadNoSuchFileError (260). Comprobar dominio y ambos códigos; no convertir otros errores de lectura/permisos en almacén vacío. Mantener una prueba de primer arranque y otra de acceso posterior a la migración.
- El empaquetado debe exigir explícitamente un log de build finalizado, no solo que exista un .app. Un producto de una compilación anterior puede estar presente mientras Xcode sigue compilando. No encadenar una comprobación de marcador con separadores que permitan seguir tras fallo; el script de preparación también rechaza un log sin BUILD SUCCEEDED.
- Los callbacks de NSViewRepresentable no deben conservar límites/bindings capturados solo en makeNSView si cambian con el tamaño de ventana. Actualizarlos en updateNSView y verificar que la misma instancia nativa respeta un límite nuevo; NativeResizerTests reproduce el fallo antes de la corrección.
- Con XcodeGen settingPresets:none, un target nuevo debe declarar PRODUCT_NAME/PRODUCT_MODULE_NAME y los search paths que necesita para importar el bridging header de la app. No basta con que las fuentes Swift de tests sean válidas: build-for-testing debe comprobar también el módulo importado y el enlace.
- Un inspector con contenido que cambia entre carga/lista/detalle debe mantener estable su mínimo nativo: probar NSHostingView.fittingSize además del marco exterior. Aislar propuestas con un contenedor geométrico y comprobar transiciones en NavigationSplitView/inspector. Un build, notarización y ventana que cabe no acreditan estabilidad al seleccionar un stash. La carga debe tener un único propietario estructurado, con identidad de repositorio y stash.
- Aislar un hijo (por ejemplo StashDetailPanel) no estabiliza el contrato del padre que reemplaza staging/commit/stash, ni el centro que reemplaza grafo/carga/visor. La validación debe cubrir el límite de columna completo y la interacción real; si el siguiente candidato falla, registrar el fallo aunque el componente y el control negativo pasen.
