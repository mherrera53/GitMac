# IA Apple: contraste oficial de octubre de 2026

Revisión fechada con el reloj del sistema el 25 de octubre de 2026 (26 de octubre UTC). T34 y Q4 permanecen abiertos: consultar documentación no implementa un proveedor ni mide inferencia.

| Frontera | Fuente verificada | Implicación para GitMac |
| --- | --- | --- |
| MLX Swift LM | La versión 3.32.3 incorpora mlx-swift 0.32.3 y añade MLXFoundationModels y MLXGuidedGeneration | Los pins actuales son mlx-swift 0.31.3 y mlx-swift-lm 3.31.3; no se actualizan durante la validación de otro lote |
| MLXFoundationModels | Es un adaptador de modelos MLX a LanguageModel/LanguageModelSession; requiere SDK 27 | Permite compartir API, pero sigue requiriendo pesos propios y su gestión de memoria |
| SystemLanguageModel | La interfaz oficial del SDK instalado declara macOS 26+, availability y motivos deviceNotEligible/appleIntelligenceNotEnabled/modelNotReady | Usar canImport y comprobación runtime conservando macOS mínimo; mostrar disponibilidad y fallback explícito |

Fuentes primarias: [release 3.32.3](https://github.com/ml-explore/mlx-swift-lm/releases/tag/3.32.3), [README del adaptador MLXFoundationModels](https://github.com/ml-explore/mlx-swift-lm/blob/main/Libraries/MLXFoundationModels/README.md) y [SystemLanguageModel de Apple](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel). La página Apple requiere JavaScript y su versión Markdown falló en el lector; las declaraciones se contrastaron además en `MacOSX27.0.sdk/System/Library/Frameworks/FoundationModels.framework/Versions/A/Modules/FoundationModels.swiftmodule/arm64e-apple-macos.swiftinterface`, entradas 260, 267 y 352–368.

## Código actual y presupuesto

`GitMac.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` fija versiones y revisiones. `GitMac/Core/Services/AI/MLXProvider.swift:29` ofrece modelos con etiquetas aproximadas de pesos de 400 MB a 4,5 GB; el predeterminado de la línea 40 es Qwen3 4B, etiquetado ~2,5 GB. Esas etiquetas no son mediciones de physical footprint ni justifican la recomendación de mejor equilibrio: falta un benchmark comparable por tarea.

`MLXProvider.generate` carga para la solicitud explícita y libera contenedor/caché en defer. Su disponibilidad actual solo comprueba arquitectura arm64. Deben probarse carga/cancelación/descarga reales, stream y fallos; los fixtures headless del backend no acreditan GPU ni memoria de pesos reales.

`apple-foundation-models-preflight.log` registró disponibilidad sin generar texto. No se presenta como una inferencia satisfactoria ni como consumo validado. Tampoco se atribuye al modelo del sistema el coste de un modelo propio MLX.

## Trabajo pendiente antes de aprobar

1. Implementar proveedor del sistema con guardas de compilación y runtime y errores visibles; no descargar ni generar al abrir Ajustes.
2. Preparar actualización MLX en lote aislado, revisando compatibilidad del SDK y API, pesos/tokenizadores y arquitectura mínima; repetir build y regresiones antes de cambiar pins.
3. Comparar propuestas de commits, explicación de conflictos y ayuda de terminal usando el mismo corpus sintético, exactitud revisada, latencia fría/caliente y cancelación. Nunca ejecutar comandos Git por una salida de IA sin preview y acción explícita.
4. Medir physical footprint y pico de la app y registrar por separado procesos auxiliares y pesos. No aprobar 150000000 bytes con un modelo que nunca se haya cargado; mover pesos a otro proceso tampoco convierte el coste total en cero.
5. Conservar política híbrida elegida: local por defecto; Cloud solo con los fragmentos revisados autorizados. La ejecución de este bloque utilizó únicamente modelos locales, descargados después de sus solicitudes.

La opción más eficiente sigue siendo una hipótesis por validar. El proveedor del sistema puede evitar que GitMac gestione pesos propios; eso no demuestra por sí solo calidad, disponibilidad universal ni cumplimiento del presupuesto.
