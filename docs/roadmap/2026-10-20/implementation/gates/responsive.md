# Gates: contenido que cabe en Retina y ventanas pequeñas

Scope: incidencia del usuario «no cabe en la pantalla»; parte de T17/T19. Usar puntos de AppKit y espacio útil, no multiplicar dimensiones de ventana por escala Retina.

Incidencia abierta: el candidato relanzado sufrió SIGABRT al seleccionar un stash (PID 52533). Ver ../stash-crash.md. La nueva corrección tiene 43 Swift Testing + 11 XCTest y control negativo del mínimo nativo; no cerrar G4 sin comprobar la interacción real.

- [ ] G1: Ventana restaurada o movida entre monitores se limita a visibleFrame del monitor que la contiene, sin afectar otras ventanas.
  EVIDENCE: ContentView WindowScreenFittingNSView usa su propia window/screen, ignora fullscreen/live resize y escucha cambios de pantalla; política geométrica probada. Candidato abierto con autorización: marco real 1105×791 contenido en LG visibleFrame, PID 52533/bundleURL confirmado. Falta comprobar traslado y restauración en Retina.
- [ ] G2: Panel inferior no consume toda la altura; toolbar compacta mantiene todas las acciones accesibles y paneles se adaptan al ancho disponible.
  EVIDENCE: política real, menú compacto y restauración automática/manual implementados; NativeResizerTests falla en resizer-before.log y pasa en resizer-after.log. Falta revisar interacción completa y menú en app real.
- [x] G3: Pruebas geométricas sobre fuentes reales cubren 640×480, 1280×800, Retina 1512×982 y monitor externo, incluyendo coordenadas negativas.
  EVIDENCE: responsive-final-tests.log, 40 Swift Testing y 11 XCTest sin fallos; pantalla Retina real 1512×982/área útil 1512×950 a escala 2, monitor LG 2560×1440/área útil 2560×1409 a escala 2. Las pruebas incluyen áreas útiles, origen negativo, ventana restaurada fuera de pantalla, preferencias inválidas y política de paneles.
- [ ] G4: Build completo pasa y se revisa la salida visual de la app modificada antes de afirmar que la incidencia del usuario está resuelta.
  EVIDENCE: responsive-resizer-debug.log y responsive-release.log BUILD SUCCEEDED; candidato notarizado abierto tras autorización «hazlo», sin reemplazar la app instalada. No había instancia activa al comprobar antes de abrir. Validación visual pendiente: screenCaptureAllowed=false y accessibilityTrusted=false; no se concedieron permisos automáticamente. El marco exterior cabe en LG; eso no acredita contenido ni Retina.
