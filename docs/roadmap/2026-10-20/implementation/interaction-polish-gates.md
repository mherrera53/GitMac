# Gates: legibilidad y manejo de acciones

Scope: toasts legibles en temas claros/oscuros/custom, terminal y worktrees con acciones descubribles, estados fiables y protección de cambios locales. No certifica el roadmap completo.

- [x] G1: Ambos sistemas de toast usan superficie opaca, contraste y texto legible; cerrar y recuperar funcionan.
  CHECK: rg -F '145 checks, 0 failures' docs/roadmap/2026-10-20/implementation/interaction-toast.log
  EXPECT: exit 0
  EVIDENCE: 145 comprobaciones aprobadas; 36 tarjetas y tres hojas de contacto inspeccionadas; revisión visual local descargada al finalizar.
- [x] G2: Revisar flujos activos de terminal y worktrees, corregir bloqueos encontrados y verificar sus acciones principales sin tocar repositorios personales.
  CHECK: rg -F 'Executed 1 test, with 0 failures' docs/roadmap/2026-10-20/implementation/interaction-native-ui.log
  EXPECT: exit 0
  EVIDENCE: UI nativa 61,799 segundos; dos sesiones conservan estado y ejecutan por Run/Enter. 13 worktree, 11 coordinación, 35 contratos y 18 wire checks pasan; remoto bare real prueba staged y divergencia.
- [x] G3: Pruebas visuales y funcionales relevantes, Release y presupuesto de memoria de la candidata comprobados.
  CHECK: rg -F '89 tests in 14 suites passed' docs/roadmap/2026-10-20/implementation/interaction-production.log
  EXPECT: exit 0
  EVIDENCE: Release aprobado; 1145 casos equivalentes; control negativo produce 124 fallos. Perfil sin instrumentar: pico 144114864 bytes, 21 muestras, 100000 commits, grafo/minimapa cargados. SHA exacto en interaction-memory.json.
- [x] G4: Instalar la versión verificada con respaldo y documentar alcance y límites.
  CHECK: python3 -c "import json; p=json.load(open('docs/roadmap/2026-10-20/implementation/interaction-installation.json')); assert p['version']=='4.1.2' and p['legacyFileUnchanged'] and p['signatureVerified'] and p['gatekeeperAccepted']"
  EXPECT: exit 0
  EVIDENCE: 4.1.2 build 12 reinstalada, respaldo completo, credenciales cifradas intactas; Apple Accepted 9f3c5e2b-8063-4f53-aa92-64f66f6da27a, ticket válido, mismo ejecutable perfilado. Ver interaction-polish-report.md.
