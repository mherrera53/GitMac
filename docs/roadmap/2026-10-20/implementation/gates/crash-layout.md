# Gates: crash al seleccionar stash y abrir visor

Scope: corregir el bucle de restricciones nativas sin modificar stashes ni repositorios del usuario. Los dos primeros candidatos fallaron; las pruebas del componente no son aprobación funcional.

- [x] G1: Crash y disparadores identificados con evidencia real.
  EVIDENCE: GitMac-2026-10-20-213805.ips (PID 52533) y GitMac-2026-10-20-214650.ips (PID 62887), SIGABRT, SplitViewChildController/SizeConstraints; usuario confirmó stash y visor. Detalles en ../stash-crash.md.
- [x] G2: Debug y Release de las columnas completas compilan.
  CHECK: node -e 'const f=require("fs");for(const n of ["viewer-crash-debug.log","viewer-crash-release.log"]){if(!f.readFileSync("docs/roadmap/2026-10-20/implementation/"+n,"utf8").includes("** BUILD SUCCEEDED **"))process.exit(1)}console.log("BUILDS_PASS")'
  EXPECT: BUILDS_PASS
  EVIDENCE: BUILDS_PASS
- [x] G3: Auditoría de fuentes actuales y pruebas de regresión pasan; el control negativo falla por el mínimo inestable.
  CHECK: node -e 'const f=require("fs"),c=require("crypto"),v=JSON.parse(f.readFileSync("docs/roadmap/2026-10-20/implementation/verification.json"));if(!v.passed||!v.checks.some(x=>x.name==="stash-panel-negative-control"&&x.exitCode===1))process.exit(1);for(const x of v.changes){if(c.createHash("sha256").update(f.readFileSync(x.file)).digest("hex")!==x.afterSHA256)process.exit(1)}console.log("REGRESSIONS_PASS")'
  EXPECT: REGRESSIONS_PASS
  EVIDENCE: REGRESSIONS_PASS
- [x] G4: El candidato final permanece abierto al seleccionar el stash y abrir el visor real del usuario.
  EVIDENCE: Usuario confirmó «si permanece» después de probar candidate-lv8hVz; viewer-launch-monitor.log también confirma PID 69666 vivo durante 30 segundos. Aprobación acotada a ese recorrido, no certificación de todos los flujos de la app.
