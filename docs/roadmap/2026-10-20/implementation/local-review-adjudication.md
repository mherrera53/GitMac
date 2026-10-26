# Adjudicación de revisiones locales

Las respuestas se conservan crudas. `remote:false` y los digests están en los JSON; ninguna propuesta se convierte por sí sola en fallo confirmado o aprobación.

- `local-status-review.json`: propuestas sobre NUL dentro de un filename son imposibles en POSIX. Nombres con newline, tab, flecha y rename real están probados por GitIntegrationMain. Unstage en rama unborn también está probado. La cobertura binaria general sigue pendiente en T24.
- `local-process-review.log`: devstral emitió riesgos genéricos (“could introduce issues”) y mezcló workflows en la revisión del executor. No identifica un escenario de fallo concreto que haya sobrevivido a F13. Las 20 pruebas reales de procesos y la lectura del executor son la evidencia, no el juicio del modelo. Se corrigió review-local.mjs para adjuntar únicamente el diff de los archivos solicitados, sin workflows ajenos a la revisión.
- `local-credentials-review.json`: las afirmaciones de ausencia de guard de archivo regular, detección de cambio, propagación de escritura y guard de UUID vacío contradicen la implementación y las pruebas. No se aceptan como defectos reproducidos. Sí permanece un límite real de concurrencia entre procesos y TOCTOU del archivo legado: no se presenta esta migración como resistente a un atacante local que pueda cambiar el directorio en paralelo. Activación explícita deshabilitada por defecto; no migrar datos reales antes de la validación y recuperación acordada.

El fallo real de primer arranque se encontró ejecutando las pruebas: Foundation devuelve código 260, no solo 4. Se conserva la salida fallida credentials-tests.log y la corregida credentials-tests-final.log. La regla se añadió a REGLAS-PREVENTIVAS.md.
