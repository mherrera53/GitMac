---
description: "Colores de interfaz mediante AppTheme — STANDARDS.md (Design System Rules), DESIGN_SYSTEM.md (Core Principles)"
scope: ["tool:edit", "tool:write"]
globs: ["GitMac/Features/**/*.swift", "GitMac/App/**/*.swift"]
condition: '\.(?:foregroundColor|foregroundStyle)\s*\(\s*(?:Color)?\.(?:blue|red|green|orange|purple|yellow|pink|cyan|mint|indigo|brown|teal)\s*(?:\)|\.opacity\s*\()'
---
STANDARDS.md exige usar AppTheme para los colores de interfaz; DESIGN_SYSTEM.md centraliza los colores para que respondan al tema. No añadas colores nominales de SwiftUI directamente a foregroundColor/foregroundStyle en las pantallas de GitMac. Usa el token semántico correspondiente (AppTheme.textPrimary, AppTheme.accent, AppTheme.success, AppTheme.error, AppTheme.gitAdded, etc.) o los tokens AppTheme.accentRed y AppTheme.accentGreen disponibles en GitMac/UI/Components/AppTheme.swift. La definición de la paleta pertenece al sistema de temas, no a las Features ni a App.
