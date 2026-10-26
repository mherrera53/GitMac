# Gates: fuente de verdad de build y tests

Scope: T03/T04, reconciliar configuraciones sin perder fuentes, productos, targets, bridging o paquetes existentes.

- [ ] G1: Especificación XcodeGen conserva fuentes/recursos/dependencias/settings del producto actual y añade tests reales con esquema compartido.
  EVIDENCE: project-generation-fixed.json confirma 394 fuentes y 11 recursos preservados y tres targets; falta resolver dependencia ScreenshotEngine de los UI tests heredados antes de adoptar el proyecto generado.
- [x] G2: Regeneración en directorio aislado preserva semántica de los targets; repetir generación no introduce drift.
  EVIDENCE: check-project-generation.rb genera proyecto de nombre único sin sobrescribir el original; project-generation-fixed.json passed/originalPreserved/deterministic true. Los proyectos generados se archivaron en build/ProjectReconciliation/retained tras las comprobaciones; para repetir, generar una copia nueva.
- [ ] G3: Debug y Release del proyecto generado compilan usando dependencias ya resueltas.
  EVIDENCE: app actual sí compila en responsive-release.log; proyecto generado build-for-testing falla en project-checked-test-build-fixed.log por ScreenshotEngine inexistente en UI tests. No se oculta ese fallo como éxito de tests.
- [ ] G4: Tests enlazados a la app real ejecutan las suites actuales sin mocks de modelos; separación SPM/app documentada y comprobada.
  EVIDENCE: pending
- [ ] G5: CI ejecuta esas rutas con permisos mínimos y sigue rechazando fallos deliberados y resultados incompletos.
  EVIDENCE: pending
