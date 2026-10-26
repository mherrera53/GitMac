# Roadmap de ejecución

## Supuestos de planificación

El plan toma macOS 14 como mínimo observado y Apple Silicon como plataforma inicialmente probada por CI. Antes de prometer Intel, fijar una matriz explícita de arquitectura para MLX, Ghostty y el resto de dependencias. Los esfuerzos son rangos iniciales en días-persona de ingeniería, no un calendario comprometido. QA y diseño participan durante cada hito; reservar capacidad adicional para migración de credenciales, fixtures y fallos descubiertos en runtime.

Responsabilidades: `macOS` diseña interacción/estado y UI; `Git` implementa motor y seguridad de operaciones; `QA` mantiene fixtures y evidencia; `UX` valida composición y accesibilidad; `Release` mantiene build, firma y entrega. Una persona puede cubrir más de un rol, pero cada spec necesita un responsable nominal antes de arrancar.

## Hitos y puertas de salida

| Hito | Objetivo | Specs | Entrada | Salida obligatoria |
| --- | --- | --- | --- | --- |
| M0 | Poder confiar en la validación | GM-001, GM-002 | Checkout y herramientas identificados | Build limpio reproducible; una rotura deliberada de compilación, enlace y test hace fallar CI; tests de producción y fixtures operativos |
| M1 | Motor y operaciones confiables | GM-003 a GM-008 | M0 | Rutas/XY correctos; sin estado cruzado; rebase respeta plan; undo seguro o deshabilitado con explicación; migración de secretos probada |
| M2 | Base nativa de interacción | GM-009 a GM-012 | M0; contratos de contexto de M1 | Menús/atajos consistentes, ventanas aisladas según diseño, flujos de teclado y VoiceOver centrales aprobados, baseline visual |
| M3 | Experiencia diaria comparable | GM-013 a GM-017 | M1, base M2 | Grafo, staging, diff, commit y conflictos completan escenarios equivalentes a GitKraken sin salir a CLI |
| M4 | Gestión completa del repositorio | GM-018 a GM-020, GM-023 | M1/M3 según spec | Remotos, branches/stash, worktrees/submodules/LFS y firma/hooks con recuperación y casos de error |
| M5 | Plataforma profesional e integraciones | GM-021, GM-022, GM-024 a GM-026 | Contratos M1/M2 y proveedor validado | Capacidades por proveedor, launchpad útil, terminal soportado, IA local y sharing con límites claros |
| M6 | Candidato de entrega | GM-027, GM-028 | Gates anteriores y presupuesto de rendimiento ya instrumentado | Rendimiento medido, instalación limpia, firma/notarización según canal, migración/rollback y documentación coherentes |

GM-027 empieza a instrumentarse en M0; su aprobación final ocurre en M6. Accesibilidad se prueba en cada feature después de M2. M2 puede avanzar en paralelo a M1 cuando los límites de contexto estén acordados; no conectar undo ni comandos destructivos a una UI nueva antes de aprobar sus precondiciones.

## Orden dentro de cada hito

1. M0: fijar entrypoint y toolchain; reparar el criterio de fallo; conectar tipos reales; establecer fixtures y resultados `xcresult`.
2. M1: GM-003 y GM-004 definen datos/procesos. GM-005 consume esos contratos. GM-006/007 esperan esas bases. GM-008 puede avanzar por carril independiente con una app de pruebas firmada.
3. M2: GM-009/010 establecen acción y foco. GM-011/012 definen semántica y componentes, revisados con prototipos de flujos reales.
4. M3: GM-013 antes de GM-014. GM-015 depende de parser/patch y GM-016 de modelo de diff. GM-017 comparte estado de operación con GM-007; probar juntos continue/abort.
5. M4: estabilizar auth y progreso en GM-018 antes de ampliar operaciones remotas. GM-020 debe usar identidad de worktree/common-dir de GM-005.
6. M5: GitHub como primer vertical validado; los demás proveedores se habilitan por capacidad comprobada. Terminal e IA son carriles independientes sujetos al presupuesto de recursos.
7. M6: congelar alcance funcional, cerrar fallos de datos, ejecutar matriz de regresión y probar el artefacto distribuido, no solo el build de desarrollo.

## Gestión profesional de las specs

Cada spec sigue `propuesta → lista → en curso → en revisión → verificada → entregada`. Para pasar a lista debe tener dueño, fuente del problema, contratos de entrada/salida, casos de aceptación, dependencias y evidencia esperada. Para verificada debe enlazar la ejecución y sus resultados, además del diff revisado. Ninguna de las specs de este documento está implementada por esta auditoría.

Dividir una spec si supera una semana de trabajo sin un resultado revisable. Ejemplo GM-013: alcance de refs; pruebas de topología; paginación/anclas; asociación de múltiples refs. Cada parte conserva el criterio de salida del conjunto.

Un PR de código debe indicar escenario antes/después y evidencia de prueba. No mezclar modernización completa del DS, migración de concurrencia y corrección de un parser en el mismo cambio. Los cambios de contrato se habilitan por feature flag cuando hay datos/sesiones que migrar.

## Priorización y control de alcance

P0 bloquea confianza o puede producir operaciones distintas de las elegidas. P1 afecta un flujo central o una convención de interacción frecuente. P2 amplía paridad o calidad profesional después del núcleo.

El orden no es una autorización para publicar ni para cambiar repositorios de clientes. El roadmap entrega el trabajo de ingeniería hasta un candidato verificable. Instalación, publicación, conexiones externas y migraciones reales se ejecutan dentro del flujo autorizado para cada entrega.

Si falta capacidad, conservar M0/M1 y el vertical abrir→grafo→stage→commit→push→recuperación de M2/M3/M4. Posponer IA, presencia y agregación multihost antes de reducir pruebas de operaciones o accesibilidad de los flujos principales. Se mantiene la aspiración de paridad amplia; se organiza su llegada por incrementos útiles.

## Estimaciones y seguimiento

Los rangos por spec están en [05-specs.md](05-specs.md); su suma se exporta al validar el paquete. No equivalen a fechas de entrega: incluyen incertidumbre técnica inicial, pero no soporte continuo, vacaciones ni capacidad compartida. Para calendarizar, medir throughput de M0/M1 y calcular con capacidad efectiva, no dividir automáticamente por el número de desarrolladores.

En cada revisión de hito reportar: escenarios aplicables/pasados, fallos P0/P1 abiertos, flujos que aún requieren CLI, regresiones de estado y recursos, deuda aceptada con dueño y evidencia de experiencia visual/teclado. Medir progreso por escenarios completos, no por líneas escritas o número de pantallas.
