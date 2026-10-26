# Temas custom: motor, componentes y pantalla real

Contrato: colores elegidos efectivamente dibujados, controles nativos coherentes, persistencia y JSON preservados. Preferencias/Git de prueba aislados. No certifica todos los componentes, diálogos de archivos, VoiceOver o el roadmap completo.

- [ ] C1: Los nueve presets preservan colores y apariencia nativa; reset y JSON conservan el contrato de persistencia.
  CHECK: node scripts/test-custom-themes.mjs
  EVIDENCE: pending
- [ ] C2: AppTheme usa la paleta custom en fondos, texto, accent, estado Git y ramas; los fallos previos se reproducen.
  EVIDENCE: pending
- [ ] C3: UI real aplica y restaura Solarized Light y GitHub Dark; los píxeles coinciden con la paleta, no solo el indicador de selección.
  EVIDENCE: pending
- [ ] C4: Build firmado, capturas inspeccionadas, modelos visuales locales contrastados y estado del roadmap actualizado sin cierre falso.
  EVIDENCE: pending
