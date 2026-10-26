# Gates: modelo de amenazas

Scope: T07, inventario y asignación de controles; no certifica que todos los controles estén implementados.

- [x] G1: Cada frontera tiene entrada, activo, amenaza, mitigación, prueba y responsable técnico, sin confundir planificación con verificación.
  CHECK: node scripts/check-threat-model.mjs
  EXPECT: THREAT_MODEL_CHECKS_PASSED
  EVIDENCE: threat-model-check.log, 16 fronteras; threat-model-negative.log rechaza omitir red remota. El primer checker detectó F30 inexistente y luego se corrigió la referencia a T30.
- [x] G2: Cubrir repositorio malicioso, shell, tokens, red, IA, patches, terminal, pruebas y distribución con referencias reales del proyecto.
  EVIDENCE: threat-model.md TM01–TM16; nombres de archivos de pruebas verificados por checker, responsables por componente y estado parcial/pendiente explícito.
- [x] G3: Revisar riesgos residuales y reglas de aceptación; no retirar P0 porque una firma o un test de componente pase.
  EVIDENCE: threat-model.md mantiene TM07 y A02/A03 abiertos, distingue permisos de terminal y consentimiento de IA, no equipara notarización con corrección. T07 cierra el inventario y controles asignados, no el hardening del producto.
