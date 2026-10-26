# Incidencia: GitMac no cabe en la pantalla

El usuario precisó que el problema es de espacio, no necesariamente de nitidez. Se priorizó layout sin cambiar resolución, escala del sistema ni tamaño de fuente.

Entorno medido: Retina integrada 1512×982 puntos, área útil 1512×950, y LG HDR 4K 2560×1440 puntos, área útil 2560×1409; ambas a escala 2. No se copiaron títulos de ventanas ni contenido de repositorios. La sesión no tiene permisos de captura ni accesibilidad y no se han concedido automáticamente.

## Cambios de aplicación

- ContentView: fitting por ventana y monitor contenedor, no por la primera ventana global. Usa visibleFrame en puntos, preserva ventanas ya dentro del área, evita interferir con fullscreen y resize activo.
- MainLayout: mide espacio disponible, oculta/restaura paneles por ancho sin reemplazar elecciones manuales, y ofrece acciones secundarias en un menú compacto. Cambiar solo el alto no revoca una apertura manual del inspector.
- UnifiedBottomPanel: limita altura al espacio actual, reservando al menos 180 puntos al contenido central cuando hay ese espacio. No destruye la preferencia de altura grande al pasar a una ventana pequeña.
- UniversalResizer: actualiza callbacks en updateNSView. La implementación anterior conservaba el máximo inicial; una prueba con la misma instancia nativa reproduce el fallo (200 en lugar de 60) y verifica la corrección.
- DesignTokens.Layout.Responsive: concentra geometría y política de paneles usadas por producción y por las pruebas. No utiliza backingScaleFactor para dimensionar la ventana.

## Evidencia y límite

responsive-final-tests.log: 40 Swift Testing en seis suites más 11 XCTest, sin fallos. Se ejecuta código real; el tema de colores del módulo aislado es el único sustituto visual, no una copia de modelos o layout.

La revisión local está en local-responsive-review.json (pesos locales, remote:false). No se aceptaron como bugs las advertencias genéricas ni el supuesto deployment target inferior a macOS 14. La carencia de pruebas de estado de paneles se atendió con compactPanelsCollapseAndRestoreOnlyAutomaticChoices; el resizer tiene control negativo real antes/después.

Tras la autorización «hazlo», se abrió el candidato específico en la sesión del usuario. La inspección inmediatamente anterior no encontró ninguna instancia activa de com.gitmac.app, por lo que no fue necesario cerrar ni forzar procesos. No se sustituyó /Applications. La revisión visual del contenido y la interacción en Retina siguen pendientes; no declarar la incidencia visual cerrada. Ver gates/responsive.md.

## Candidato específico de esta corrección

ADVERTENCIA posterior: candidate-drgWMH se cerró al seleccionar un stash. Su marco exterior y notarización válidos no acreditan estabilidad funcional. Ver [stash-crash.md](stash-crash.md) para la evidencia, corrección y nuevas pruebas; no reutilizar este candidato como versión corregida del crash.

Release actual: responsive-release.log, BUILD SUCCEEDED. Copia separada: `build/DistributionCandidates/candidate-drgWMH/GitMac.app`. Envío Apple `c913187e-e430-4feb-ade7-e963e9c6d8be`, Accepted. distribution-responsive-final.log registra firma estricta, stapler validate y Gatekeeper accepted/source=Notarized Developer ID. ZIP final `GitMac-arm64-notarized.zip`, SHA-256 `b2adb3cfaf3950f7afecb5116556e9ef853818f3374c6104fd955e5677460ec2`.

Es un candidato técnico: no sustituye la aplicación instalada ni acredita el cierre funcional completo del roadmap. El relanzamiento autorizado ya se ejecutó; la revisión visual sigue pendiente.

## Comprobación de la instancia abierta

NSWorkspace confirmó PID 52533 y bundleURL exacto `build/DistributionCandidates/candidate-drgWMH/GitMac.app`. CGWindow confirmó ventana 117167, capa 0, de 1105×791 puntos, origen CG (306,249). Convertida a AppKit respecto a la pantalla principal de 1440 puntos de alto: (306,400,1105,791), contenida en visibleFrame del LG (0,0,2560,1409). Esto verifica el marco exterior actual, no que todo el contenido o todos los diálogos quepan. No se movió la ventana a Retina ni se simuló una revisión visual: screenCapture=false y accessibility=false. La firma estricta y Gatekeeper se verificaron de nuevo antes de abrir, con resultado accepted/source=Notarized Developer ID.

Referencias primarias: [visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe), [backingScaleFactor](https://developer.apple.com/documentation/appkit/nsscreen/backingscalefactor).
