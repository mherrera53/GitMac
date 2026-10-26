# Migración de credenciales: implementación y límites

Nuevos valores: Keychain Services de macOS, servicio `com.gitmac.credentials`, cuenta `credential-store.v1`. Los nombres existentes de proveedor se conservan dentro de un snapshot JSON para no romper consumidores. No hay fallback a archivo ni caché global de secretos. Los errores de Security conservan OSStatus, sin valor del token. La sesión de autenticación no permite mostrar prompts automáticamente.

Archivo legado: solo se descifra para migración explícitamente habilitada mediante `GITMAC_MIGRATE_CREDENTIALS=1` en el proceso de GitMac. Está deshabilitada por defecto. El UUID solo se usa para compatibilidad de lectura, nunca para cifrar valores nuevos; la ausencia de UUID falla sin recurrir a una constante.

La migración valida archivo regular y tamaño, descifra, conserva claves desconocidas, fusiona sin reemplazar valores más recientes de Keychain, escribe y compara lectura completa. Solo entonces retira el archivo legado. Si la escritura, lectura de verificación o retirada falla, propaga error; una nueva instancia puede reintentar. Si el archivo cambió, no lo elimina. La migración no está diseñada para ejecutarse simultáneamente desde varios procesos.

Antes de activarla con datos reales: acordar una copia recuperable del archivo cifrado con el usuario, protegerla con permisos 0600 y un plazo de retirada, comprobar la identidad firmada y cerrar otras instancias de GitMac. No se ha creado ni leído esa copia en esta sesión. Si falla la validación, conservar origen y backup, desactivar la variable y diagnosticar OSStatus sin exportar secretos. Tras una migración confirmada, no volver a un binario que solo lea el formato anterior: usar una versión que mantenga el backend Keychain. No hay rollback automático a almacenamiento débil.

Pruebas: `node scripts/test-production-suites.mjs`; almacén inyectado para fallos y servicio Security único `com.gitmac.tests.credentials.<UUID>` con valores sintéticos y eliminación acotada. Los fallos de primer arranque descubiertos en credentials-tests.log se corrigieron y se conserva la regla en REGLAS-PREVENTIVAS.md.

T13 todavía no se considera cerrado: faltan aislamiento de múltiples cuentas/entornos en los consumidores, presentación de errores que actualmente algunos consumidores ocultan con `try?`, UI de aprobación de migración y validación del flujo completo con identidad firmada. La variable es una protección de activación, no una UI de migración final.
