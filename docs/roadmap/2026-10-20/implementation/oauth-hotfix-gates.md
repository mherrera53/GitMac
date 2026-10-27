# Gates: GitHub OAuth persistence hotfix

Scope: guardar credenciales nuevas sin importar ni borrar las antiguas, errores visibles y OAuth cancelable.

- [x] G1: Persistencia y reapertura de GitHub y Linear, borrado sin resurrección y errores de Keychain comprobados.
  CHECK: rg 'Test run with 85 tests.*passed' docs/roadmap/2026-10-20/implementation/oauth-production-tests.log
  EXPECT: passed
  EVIDENCE: 85 tests en 12 suites pasan; solo credenciales ficticias y un servicio Keychain único de prueba.
- [x] G2: El control negativo reproduce el bloqueo de la versión publicada.
  CHECK: rg 'Caught error: .migrationRequiresApproval' docs/roadmap/2026-10-20/implementation/oauth-legacy-negative.log
  EXPECT: migrationRequiresApproval
  EVIDENCE: Un test falla por el bloqueo real al sustituir solo KeychainManager por v4.1.0 en el módulo desechable; no es un fallo de compilación.
- [x] G3: Release compilada, firmada, notarizada e instalada con respaldo.
  EVIDENCE: oauth-release-build.log BUILD SUCCEEDED; oauth-installation.json confirma 4.1.1 (7), SHA f40772708a1471353def62f04e9d6dbfee6731ce9b9cfd8f21f61f4290bb20e6, Accepted f14d1201-e68e-4006-85ba-1254d62797e1, codesign/Gatekeeper/stapler y PID 24771. El fixture de 100000 commits alcanzó 126977104 bytes de pico; no certifica todos los flujos. Archivo antiguo conservado, 227 bytes y fecha de modificación original; no se afirma comparación criptográfica del antes/después.
- [x] G4: Distinguir validación aislada de autorización real.
  EVIDENCE: Pruebas URLProtocol sin tráfico real ni tokens personales. La autorización real queda a cargo del usuario en su navegador, después de guardar su Client ID. OAuth App debe tener Device Flow habilitado. No se certifica sesión real ni roadmap completo.
