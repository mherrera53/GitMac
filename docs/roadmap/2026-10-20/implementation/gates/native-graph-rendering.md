# Render de grafo y pico gráfico: contraste causal

Contrato: conservar geometría, paths, colores, dash, zoom, hit-testing y accesibilidad. Comparar implementaciones que dibujan el mismo grafo; nunca aprobar memoria ocultando nodos/conexiones. Preservar Canvas como control solo para el fixture de rendimiento. Revertir el cambio del producto si no aporta una mejora comprobada o introduce regresión.

- [x] R1: Renderer reutilizable con CGContext; curvas, alpha, dash/caps y tamaño nativo probados contra oracles independientes.
  EVIDENCE: scripts/test-native-graph-rendering.mjs; 37 comprobaciones de píxeles/geometría a escalas 1x/2x; omitir dash reproduce cuatro fallos. Esto no certifica interacciones ni todas las capturas del producto.
- [ ] R2: Filas commit/stash/WIP y minimapa mantienen dibujo, clipping, selección/arrastre y colores; build y UI sobre Git real pasan.
  EVIDENCE: pending
- [ ] R3: Comparar el mismo Release/fixture con backend nativo y Canvas, procesos nuevos, modelos vacíos y señales de carga completas. Conservar todas las muestras y el incumplimiento si existe.
  EVIDENCE: native-graph-memory-comparison.json conserva seis perfiles del mismo binario, señal de dibujo incluida: nativo 1k ~76 MB frente a Canvas ~368 MB; 10k ~88 MB; 100k ~168 MB, falla. El candidato posterior con resolver/minimapa optimizado necesita medición nueva.
- [ ] R4: Revisión de diff, matriz visual de temas y regresiones; actualizar mapas y T21/T36 sin cerrar sus demás criterios.
  EVIDENCE: pending
