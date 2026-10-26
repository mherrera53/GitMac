# Gates: credenciales y migración

Scope: T13, sustituir persistencia ligada al UUID por Keychain sin pérdida silenciosa. Las pruebas nunca leen credenciales reales ni lanzan la app con datos del usuario.

- [x] G1: Nuevos valores solo se persisten en Keychain; get/save/delete propagan fallo de acceso, corrupción y verificación.
  EVIDENCE: credentials-tests-hardened.log, newCredentialsNeverCreateALegacyFile, failedUpdateAndDeleteDoNotChangePersistedValuesOrCacheSuccess y corruptKeychainDataIsNotOverwritten PASS.
- [x] G2: Migración sintética conserva valores, verifica readback antes de retirar el archivo legado y puede repetirse después de una interrupción.
  EVIDENCE: credentials-tests-hardened.log, migratesAllSyntheticKeysAndVerifiesBeforeRetiringFile, failedReadbackDoesNotDeleteLegacyData e interruptionAfterPersistCanBeRetriedWithoutLosingNewerValues PASS.
- [x] G3: Denegación, bloqueo, escritura fallida y archivo ilegible/corrupto no se convierten en éxito ni borran la única copia.
  EVIDENCE: credentials-tests-hardened.log, tres OSStatus, fallo de escritura, archivo con permisos 000, corrupción, exceso de tamaño, symlink y cambio durante migración PASS.
- [x] G4: Ningún acceso real a credenciales del usuario durante la validación; pruebas de adaptador Security solo con servicio/valores sintéticos únicos.
  EVIDENCE: CredentialStorageTests utiliza URLs temporales y servicio com.gitmac.tests.credentials.<UUID>, elimina solo su cuenta sintética; no instancia el singleton con operaciones sobre datos reales. realSecurityAdapterRoundTripsOnlyUniqueSyntheticService PASS.
- [x] G5: Todos los consumidores compilan y las suites anteriores siguen pasando.
  EVIDENCE: credentials-debug-final.log y release-credentials.log BUILD SUCCEEDED; credentials-tests-hardened.log 32 Swift Testing más 11 XCTest sin fallos; contracts-git-process-current.log y contracts-core-current.log pasan.

Esta hoja valida el núcleo, no la totalidad de T13. Los pendientes de cuentas/entornos, UX y aprobación firmada están explícitos en credential-migration.md; migración real deshabilitada por defecto.
