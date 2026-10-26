# Experimento retirado: buffer versionado de entrada

El experimento separaba revisiones de reemplazo y edición nativa. Sus diez comprobaciones de estado pasaron y una mutación produjo siete fallos, pero no corrigió la pérdida observada en el test UI. Se conserva solo como investigación, fuera del producto y de las comprobaciones actuales.

El control de un TextField estándar perdió exactamente c y apóstrofos. El registro nativo del fixture muestra que esas teclas llegaron con Command en la entrada sintetizada. La hipótesis de clobber por Binding no quedó confirmada; se restauraron las tres fuentes del paquete local anterior, verificando sus hashes. No se presenta esta alternativa como optimización ni reparación entregada.

Los imports/rutas relativas del script conservado corresponden a su ubicación original en scripts; es un artefacto histórico, no un runner desde esta carpeta.
