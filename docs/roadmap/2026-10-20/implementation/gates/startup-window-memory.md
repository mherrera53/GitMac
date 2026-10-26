# Pico de arranque y geometría de ventana

Hipótesis por comprobar: una ventana inicialmente sobredimensionada podría reservar superficies gráficas antes del ajuste al monitor. No cambiar el layout ni atribuir el pico a esa causa sin registrar la geometría real.

- [x] M1: Registrar dimensiones de las ventanas del PID privado desde el arranque, sin Accesibilidad, capturar otras apps ni modificar la sesión instalada.
  EVIDENCE: startup-window-memory.log y su windowGeometry: helper compilado antes del lanzamiento, PID exacto, muestreo 50 ms, sin títulos ni geometría de otros procesos; ventana visible 900×450 y ventana oculta 500×500.
- [x] M2: Contrastar geometría, categorías y physical footprint/pico del mismo Release; aceptar o rechazar la hipótesis con datos.
  EVIDENCE: ambos runs usan SHA f3a12218092a207da782845adab144ef0021657d88e8005c7ceaac76e97d99cc; pico normal 362202216 y diagnóstico 362447976. Los datos observados no respaldan una ventana enorme. El intervalo no excluye cambios de menos de 50 ms. Primera muestra: 168509440 bytes gráficos no mapeados, después 737280.
- [x] M3: Si hay corrección, repetir build/corrección/presupuesto; si la hipótesis se rechaza, conservar el incumplimiento de 150000000 bytes y la siguiente causa a investigar.
  EVIDENCE: no se aplicó una corrección especulativa de tamaño. T36 continúa abierta y falla 150000000; siguiente contraste: Canvas de filas/minimapa frente a dibujo equivalente. No se desactivó ninguna función ni se presenta este diagnóstico como optimización aceptada.
