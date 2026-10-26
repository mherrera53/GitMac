# Preflight de notarización

Comprobado: 2026-10-21T01:55:52Z (20 de octubre en Guatemala).

- Perfil existente localizado: `GITMAC_NOTARY`. Se extrajo únicamente el nombre de perfil de referencias locales; no se volcaron líneas completas del historial ni credenciales.
- `security find-identity -v -p codesigning` confirma una identidad válida `Developer ID Application: Mario Herrera (SRVK53YUSF)`.
- Consulta de solo lectura: `xcrun notarytool history --keychain-profile GITMAC_NOTARY --output-format json`.
- Resultado: código de salida 1, HTTP 403. Apple indica: “A required agreement is missing or has expired.”

La existencia del perfil no implica que el equipo tenga habilitado actualmente el servicio. Esta comprobación no permite certificar que la notarización funcione ni que un artefacto esté listo para distribución. No se enviaron binarios, no se cambiaron credenciales ni se aceptaron acuerdos.

Acción externa necesaria: el titular del equipo debe revisar y aceptar los acuerdos pendientes en Apple Developer y, si Apple lo indica, App Store Connect. Después se debe repetir la consulta, verificar el equipo efectivo y continuar con firma, envío, consulta del resultado y stapling del artefacto concreto. La tarea de distribución sigue sin verificarse; tampoco se considera terminado el resto del roadmap.

## Reintento después de la confirmación del usuario

2026-10-21T02:00:50Z: tras indicar el usuario que había completado la acción, se repitió la consulta de solo lectura. `GITMAC_NOTARY` volvió a devolver HTTP 403 por acuerdo ausente o caducado. También se comprobó el perfil existente `AC_PASSWORD`, con el mismo resultado. No se consultaron valores de credenciales ni se enviaron artefactos.

No está confirmado si falta otro acuerdo, si se aceptó para otro equipo o si el servicio aún no refleja el cambio. El certificado Developer ID localizado pertenece al equipo `SRVK53YUSF`; no se ha confirmado el equipo efectivo de las credenciales de notarización. No atribuir la causa a propagación sin evidencia.

Referencia oficial: https://developer.apple.com/help/account/access/resolving-access-issues (Apple documenta que los acuerdos pendientes pueden suspender el servicio de notarización).

## Segundo reintento confirmado

2026-10-21T02:02:24Z: `GITMAC_NOTARY` sigue devolviendo el mismo HTTP 403 mediante la selección predeterminada del llavero. Como diagnóstico adicional se consultó explícitamente `login.keychain-db`: ni `GITMAC_NOTARY` ni `AC_PASSWORD` aparecen en ese llavero (salida 69). Esto no invalida los perfiles encontrados por la selección predeterminada ni permite concluir dónde están almacenados. No se recrearon perfiles ni se modificaron llaveros.

Para resolver la discrepancia hace falta comprobar el aviso y el equipo mostrados en el portal del titular, o escalar a Apple Developer Support si el portal confirma que los acuerdos correspondientes ya están aceptados. La respuesta del servicio no permite determinar qué acuerdo concreto falta.

## Acceso restablecido

2026-10-21T02:03:55.017Z: después de recibir la confirmación de Apple que aportó el usuario (acuerdo firmado para `SRVK53YUSF`), la consulta `notarytool history --keychain-profile GITMAC_NOTARY --output-format json` terminó con código 0. El bloqueo por acuerdo ya no se reproduce. Solo se registró disponibilidad e historial accesible; no se volcaron los datos de envíos anteriores. Este éxito no equivale a firma, aceptación de un nuevo binario ni stapling.
