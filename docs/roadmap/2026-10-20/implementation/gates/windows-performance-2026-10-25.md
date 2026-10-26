# Gates: ventanas y rendimiento, continuación 2026-10-25

Scope: inventario de ventanas/presentaciones, Ajustes adaptable y medición Release con carga completa. No cierra las 40 tareas ni atribuye mejoras sin medición.

- [ ] G1: Registrar todas las declaraciones de ventanas y presentaciones encontradas, con archivo/línea y límites de la inspección; preservar las columnas que corrigieron el crash.
  EVIDENCE: pending
- [ ] G2: Ajustes permite redimensionar, mantiene todas las categorías accesibles y crea únicamente el contenido seleccionado; selección persistida inválida se recupera.
  EVIDENCE: pending
- [ ] G3: Pruebas de regresión y UI real verifican navegación de Ajustes, scroll y ausencia de crash; capturas exportadas y leídas.
  EVIDENCE: pending
- [ ] G4: Release compila; medir physical footprint y pico con repositorio/ramas/grafo/minimapa cargados, sin modelos precargados y sin tocar la sesión instalada. Conservar el fallo si supera 150000000 bytes.
  EVIDENCE: pending
- [ ] G5: Regenerar mapa y auditoría de archivos/líneas; controles negativos detectan regresión y git diff --check pasa.
  EVIDENCE: pending
- [ ] G6: Reducir contenedores duplicados reutilizando componentes existentes; General, IA y Atajos comparten SettingsPage, basado en DSScrollView/DSVStack. No anidar ScrollView en Form ni duplicar gestores de estado.
  EVIDENCE: pending
- [ ] G7: Jerarquía simple y colores semánticos del tema activo; comprobar selección de tema claro/oscuro/sistema y reapertura mediante el atajo nativo de macOS. Temas custom claros no se fuerzan a oscuro; no declarar VoiceOver/contraste integral sin pruebas.
  EVIDENCE: pending
