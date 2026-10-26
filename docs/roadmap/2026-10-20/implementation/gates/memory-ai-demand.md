# Gates: memoria e IA bajo demanda

Scope: objetivo exigido de 150 000 000 bytes de memoria física para GitMac; IA local pesada necesita un presupuesto explícito aparte durante inferencia. No reinterpretar MB como MiB ni RSS bajo como cumplimiento si hay memoria comprimida.

- [x] G1: Las rutas de arranque, activación y selección de proveedor no cargan modelos ni inician motores de IA.
  EVIDENCE: Inspección completa de GitMacApp.swift y AIService.setProvider; búsqueda global: startIfNeeded solo conserva su definición, MLX.generate solo se invoca en sendMLXMessage. ai-demand-tests-final-debug.log y ai-demand-release.log pasan. No es un recorrido UI general.
- [ ] G2: Inferencia local usa límites de contexto/salida, no cambia silenciosamente a modelo cloud y libera pesos tras completar/fallar/cancelar.
  EVIDENCE: AIService real pasa pruebas de cloud preflight, exact model, loopback, límites, lease y error; benchmark Ollama observa descarga tras éxito. Pendientes GPU real y terminación/cancelación del servidor. No cerrar el gate completo.
- [ ] G3: Modelo recomendado se justifica con fuentes primarias y mediciones locales comparables, no solo un ranking genérico.
  EVIDENCE: local-model-comparison-isolated.json: tres casos por modelo instalado, descarga observada, errores de calidad explícitos. Qwen3.5-4B es candidato documental aún no medido; no hay modelo universal aprobado.
- [ ] G4: Release se mide en repos pequeño/grande, navegación/diff y cierre de tabs; ningún pico de GitMac supera 150 000 000 bytes para declararlo cumplido.
  EVIDENCE: Baseline de la app instalada PID 84387: phys_footprint 242435464 bytes y peak 690128336 bytes. No cumple. memory-installed-baseline.json/log. No es medición del candidato nuevo.
- [ ] G5: Pruebas y audit final recorren cada T01–T40; ninguna tarea pendiente se transforma en verificada por un build o por validar el CSV.
  EVIDENCE: task-closure-audit.json enumera los 40 criterios pero no ejecuta cada escenario. Estado vigente 4 verificadas, 17 en curso y 19 pendientes. Sigue abierto el cierre funcional completo.
