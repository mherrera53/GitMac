---
description: "Jev — cachear transformaciones de listas durante el render — STANDARDS.md (Computed Properties, anti-pattern 6)"
scope: ["tool:edit", "tool:write"]
globs: ["*.swift"]
condition: '\.(?:filter|sorted|sort)\s*(?:\(|\{)|Dictionary\s*\(\s*grouping:'
question: "¿Las líneas añadidas muestran claramente filtrado, ordenación o agrupación de listas de ramas, commits, archivos o pull requests de un repositorio ejecutados en el body de una View SwiftUI o en una propiedad calculada de render, de modo que se recalculan en cada render en vez de leer una caché? Responde sí solo si ese contexto y la transformación se ven en las propias líneas. No son infracciones las transformaciones dentro de funciones que actualizan una caché, onChange/onAppear, ViewModels o servicios, ni listas pequeñas de opciones estáticas."
---
STANDARDS.md exige cachear propiedades calculadas costosas y desaconseja filtrar listas grandes en cada render. Para listas de datos del repositorio, conserva el resultado en estado/caché y actualízalo cuando cambien la búsqueda o los datos; el render debe leer ese resultado. Reutiliza el patrón de GitMac/Features/Branches/BranchListView.swift: cachedFilteredLocalBranches/cachedFilteredRemoteBranches/cachedGroupedRemoteBranches y updateFilterCache invocado desde onChange/onAppear.
