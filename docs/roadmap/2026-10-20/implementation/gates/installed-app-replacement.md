# Reemplazo de la aplicación instalada

Autorización explícita del usuario: «y cuando estes 100% seguro que funciona reemplazar la app que esta instalada pls». Es una autorización condicionada al cierre validado, no permiso para instalar un candidato con fallos conocidos. Conservar la versión anterior para rollback; no publicar ni modificar repositorios/remotos del usuario.

Autorización posterior: «commit y deploy pls release version» y destino «GitHub Release y app del Mac», con versión propuesta 4.1.0. La entrega acotada actual se verifica en gates/release-4.1.0.md; esa instrucción permite publicar/instalar la versión comprobada sin declarar cerrados los 206 pasos ni estos criterios generales aún pendientes. Las referencias anteriores a no publicar corresponden al alcance previo.

- [x] I1: Identificar ruta/bundle/versión/firma/proceso de la app que usa el usuario y preparar un backup verificable, sin cerrar su trabajo ni sobrescribir candidatos por inferencia de nombre.
  EVIDENCE: installed-app-backup.json: /Applications/GitMac.app, com.gitmac.app 1.0 (1), firma ad hoc existente descrita, consulta exacta de proceso y copia en build/InstalledAppBackups con ejecutable SHA256 idéntico antes/después; codesign --verify --deep --strict pasa para el backup. No se cerró ningún proceso ni se sustituyó la instalada. Preferencias/credenciales/datos no forman parte de esta copia del bundle.
- [ ] I2: Candidato final Release con fuentes/hash fijados; regresiones, escenarios funcionales, temas/ventanas y conservación de datos aprobados. Mantener abiertos los criterios que no se hayan ejecutado; no certificar ausencia absoluta de errores por una suite parcial.
  EVIDENCE: terminal-wire-build.log y terminal-wire-release.log pasan. verification.json pasa 45 verificaciones de 115 archivos, no las 40 aceptaciones completas. terminal-wire-ui.xcresult pasa ejecución literal, bytes/cwd y captura inspeccionada; las matrices anteriores mantienen alcance/hash propios. AX/VoiceOver y otros flujos siguen abiertos.
- [ ] I3: Presupuesto de 150000000 bytes de physical footprint y pico validado en la matriz requerida; no sustituirlo por RSS, steady state o inferencia/modelos sin cargar.
  EVIDENCE: el candidato anterior b55fa41 fallaba en 100k y no se instaló. ram-2026-10-26-measurements.json fija ahora e83478e93d3e23182130d191bc4589955bd0e0b85405e229010ffb43c5a8a15b: picos 1k 76448824, 10k 85836904 y 100k 127894632/127910992 pasan 150000000, con carga/dibujo real y sin modelos/builds/audits concurrentes. La matriz de todos los flujos/inferencia conserva este criterio general abierto; la Release acotada tiene evidencia propia.
- [ ] I4: Developer ID, hardened runtime, notarización, stapling y Gatekeeper del candidato actual, con instalación/rollback y migración preservando preferencias/credenciales/datos.
  EVIDENCE: pending
- [ ] I5: Sustituir solo tras cumplir los gates; salida normal, nunca force-kill de trabajo del usuario. Verificar la copia instalada y su lanzamiento; conservar backup y registrar ruta/versión/hash y resultado real.
  EVIDENCE: pending
