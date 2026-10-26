# Fuentes primarias y alcance

Consulta: 20 de octubre de 2026, con fecha del sistema. Las páginas pueden cambiar. Las rutas de código de la auditoría corresponden a la base local `33bcb57`, y sus líneas deben revisarse después de editar.

## Apple

| Fuente | Uso en las specs |
| --- | --- |
| [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Inspector, ayudas del sistema, percepción, adaptación, texto y color |
| [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) | Atajos estándar, foco y alternativas por teclado |
| [Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo) | Edición, nombres de operación y shortcuts de Mac |
| [Windows](https://developer.apple.com/design/human-interface-guidelines/windows) | Comportamiento y adaptación de ventanas |
| [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | Acciones principales, espacio y controles |
| [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) | Navegación, jerarquía y espacio |
| [Keychain Services](https://developer.apple.com/documentation/security/keychain-services) | Mecanismo del sistema para guardar secretos |
| [Using the keychain to manage user secrets](https://developer.apple.com/documentation/security/using-the-keychain-to-manage-user-secrets) | Flujo de credenciales con interacción mínima |

El lector web devolvió la cubierta JavaScript de varias HIG. Se leyó además el Markdown oficial de Accessibility, Keyboards y Undo and redo con HTTP directo, y se obtuvieron resultados indexados oficiales para Windows/Toolbars/Sidebars. No se atribuyen a Apple los tamaños o presupuestos de rendimiento propuestos por este roadmap.

## GitKraken Desktop

| Fuente | Capacidad contrastada |
| --- | --- |
| [Interface guide](https://help.gitkraken.com/gitkraken-desktop/interface/) | Toolbar, paneles, grafo, tabs y contexto |
| [Interactive rebase](https://help.gitkraken.com/gitkraken-desktop/interactive-rebase/) | Edición visual del plan de historia |
| [Undo and redo](https://help.gitkraken.com/gitkraken-desktop/undo-and-redo/) | Operaciones soportadas y límites de recuperación |
| [Worktrees](https://help.gitkraken.com/gitkraken-desktop/worktrees/) | Gestión y representación de contextos paralelos |
| [Staging](https://help.gitkraken.com/gitkraken-desktop/staging/) | Archivo, hunks/líneas y discard |
| [Branching and merging](https://help.gitkraken.com/gitkraken-desktop/branching-and-merging/) | Estrategias y resolución de conflictos |
| [Pushing and pulling](https://help.gitkraken.com/gitkraken-desktop/pushing-and-pulling/) | Fetch/pull/push y políticas de integración |
| [Pull requests](https://help.gitkraken.com/gitkraken-desktop/pull-requests/) | Flujos y diferencias por proveedor |
| [Conflict prevention](https://help.gitkraken.com/gitkraken-desktop/conflict-prevention/) | Avisos y contexto de conflictos potenciales |
| [Git flow](https://help.gitkraken.com/gitkraken-desktop/git-flow/) | Feature/release/hotfix y configuración |

Se usan resúmenes funcionales breves, no una reproducción del manual. Las propuestas avanzadas que amplían esos resúmenes son requisitos deseados de GitMac, no afirmaciones de que GitKraken tenga idéntico comportamiento en cada caso. Las capacidades dependientes de proveedor/licencia requieren comprobación durante refinamiento.

## Evidencia local

`Package.swift`, `project.yml`, proyecto Xcode, workflows de CI/release, engine/servicios/viewmodels/componentes citados, tests existentes y grafo `graphify-out/graph.json`. El grafo estaba generado en junio y sirve para encontrar relaciones, no para probar estado actual. La consulta expandió a vocabulario real `git repository graph undo keyboard staging`; se contrastaron las referencias pertinentes contra archivos actuales. No se reconstruyó ni se modificó ese grafo del usuario.

El resultado de inferencia local se conserva con entradas, métricas y fecha. Su campo `confirmed` pertenece a la salida sin revisar del modelo y no tiene la validez de la clasificación de [auditoría](01-auditoria.md).
