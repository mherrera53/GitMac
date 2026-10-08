---
description: "Jev — lógica Git fuera del render de las Views — STANDARDS.md (Component Architecture, anti-pattern 4)"
scope: ["tool:edit", "tool:write"]
globs: ["*.swift"]
condition: '(?i)(GitEngine|gitEngine|gitService|shellExecutor|\.execute\s*\(|Process\s*\()'
question: "¿Las líneas añadidas muestran claramente una operación Git o ejecución de comandos implementada directamente en el body de una View SwiftUI o en una propiedad de render de esa View, en lugar de delegarla a su ViewModel? Responde sí solo si las propias líneas muestran tanto el contexto de render como la operación. No son infracciones las llamadas de la UI al ViewModel, las implementaciones dentro de un ViewModel/servicio ni una mera declaración o importación."
---
STANDARDS.md prohíbe poner lógica de negocio en Views y muestra que la carga de ramas pertenece al ViewModel. Mueve la operación Git al ViewModel correspondiente y delega la ejecución en GitService/GitEngine; la View debe consumir estado y enviar acciones al ViewModel, no ejecutar comandos al renderizar. Sigue GitMac/Features/Branches/BranchListView.swift: la View usa viewModel y BranchListViewModel concentra las operaciones Git.
