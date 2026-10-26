# Gates: ejecución de procesos

Scope: T10/F13, unificar execute, callbacks y streaming con límites, cancelación y cleanup de procesos propios.

- [x] G1: Stdout/stderr simultáneos, UTF-8 partido y salida final no se pierden.
  EVIDENCE: contracts-git-process-current.log, F13 flood 262144 bytes por pipe, callbacks ñ/€ y final sin newline, PASS.
- [x] G2: Timeout/cancelación matan solo el grupo creado por la operación, incluidos hijos que heredan pipes e ignoran TERM.
  EVIDENCE: contracts-git-process-current.log, cancelación y descendiente que retiene pipes PASS; ShellExecutor crea grupo POSIX propio y mantiene waitid WNOWAIT hasta limpieza, sin búsqueda de PID.
- [x] G3: Streaming con búfer acotado aplica backpressure sin descartar líneas y termina con errores explícitos.
  EVIDENCE: contracts-git-process-current.log, productor bloqueado con consumidor lento, 30000 líneas en orden, fallo no cero y línea de 2 MiB rechazados, PASS.
- [x] G4: Límite de captura, arranque fallido y error no cero son observables; no se registran argumentos secretos.
  EVIDENCE: contracts-git-process-current.log, cap 4096 bytes y cwd inválido PASS; signposts de ShellExecutor solo contienen nombre fijo, sin argv ni paths.
- [x] G5: Integración Git, regresresiones anteriores y build Debug pasan.
  EVIDENCE: contracts-git-process-current.log, ambas suites PASSED; contracts-core-current.log 0 failures y 11 XCTest sin fallos; credentials-debug-final.log BUILD SUCCEEDED.

Límite: control de procesos de la operación, no sandbox para un programa hostil que deliberadamente abandone su grupo. Revisión independiente de propuestas locales: local-review-adjudication.md.
