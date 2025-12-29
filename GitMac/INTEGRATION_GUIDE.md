# 🔗 GUÍA DE INTEGRACIÓN COMPLETA
## Cómo Integrar Todas las Funcionalidades en GitMac

---

## 📋 TABLA DE CONTENIDOS

1. [Arreglar Problemas de Build](#1-arreglar-problemas-de-build)
2. [Integrar NotificationManager](#2-integrar-notificationmanager)
3. [Integrar Command Palette](#3-integrar-command-palette)
4. [Integrar File Finder](#4-integrar-file-finder)
5. [Integrar Theme Manager](#5-integrar-theme-manager)
6. [Integrar Keyboard Shortcuts](#6-integrar-keyboard-shortcuts)
7. [Integrar External Tools](#7-integrar-external-tools)
8. [Integrar GitHub](#8-integrar-github)
9. [Integrar Terminal](#9-integrar-terminal)
10. [Configurar Menu Bar](#10-configurar-menu-bar)
11. [Testing](#11-testing)

---

## 1. ARREGLAR PROBLEMAS DE BUILD

### Paso 1: Abrir Xcode Project Navigator
```
⌘1 para abrir el navegador
```

### Paso 2: Buscar Archivos Duplicados
En Xcode, busca estos archivos y elimina los **DUPLICADOS ANTIGUOS**:

```
❌ Eliminar (versiones antiguas):
- InteractiveRebaseView.swift (520 líneas)
- ThemeManager.swift (627 líneas)
- SearchView.swift (si hay duplicado más pequeño)

✅ Mantener (versiones nuevas):
- InteractiveRebaseView.swift (594 líneas)
- ThemeManager.swift (685 líneas)
- SearchView.swift (645 líneas)
```

**Cómo eliminar en Xcode:**
1. Click derecho en el archivo duplicado
2. "Delete" → "Remove Reference" (NO "Move to Trash")
3. Repetir para cada duplicado

### Paso 3: Clean Build
```
Product → Clean Build Folder (⌘⇧K)
Product → Build (⌘B)
```

---

## 2. INTEGRAR NOTIFICATIONMANAGER

### En `ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recentReposManager: RecentRepositoriesManager
    
    var body: some View {
        VStack(spacing: 0) {
            // ... tu contenido existente ...
        }
        .withToastNotifications() // 👈 AGREGAR ESTO
    }
}
```

### Uso en cualquier lugar:

```swift
// Success
NotificationManager.shared.success("Operation completed")

// Error
NotificationManager.shared.error("Failed to push", detail: "Check network")

// Warning
NotificationManager.shared.warning("Uncommitted changes")

// Info
NotificationManager.shared.info("Fetching updates")
```

---

## 3. INTEGRAR COMMAND PALETTE

### En `ContentView.swift`:

```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCommandPalette = false // 👈 AGREGAR
    
    var body: some View {
        VStack(spacing: 0) {
            // ... contenido ...
        }
        .sheet(isPresented: $showCommandPalette) { // 👈 AGREGAR
            CommandPalette()
                .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            showCommandPalette = true
        }
    }
}
```

### En `GitMacApp.swift`:

Agregar keyboard shortcut global:

```swift
import SwiftUI

@main
struct GitMacApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Command Palette") {
                    NotificationCenter.default.post(name: .showCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
```

### Agregar Notification Name:

```swift
// En algún archivo de extensiones (o crear Extensions.swift)
extension Notification.Name {
    static let showCommandPalette = Notification.Name("showCommandPalette")
    static let showFileFinder = Notification.Name("showFileFinder")
}
```

---

## 4. INTEGRAR FILE FINDER

### En `ContentView.swift`:

```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCommandPalette = false
    @State private var showFileFinder = false // 👈 AGREGAR
    
    var body: some View {
        VStack(spacing: 0) {
            // ... contenido ...
        }
        .sheet(isPresented: $showFileFinder) { // 👈 AGREGAR
            FuzzyFileFinder()
                .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFileFinder)) { _ in
            showFileFinder = true
        }
    }
}
```

### En `GitMacApp.swift`:

```swift
.commands {
    CommandGroup(after: .newItem) {
        // ... Command Palette ...
        
        Button("Go to File") {
            NotificationCenter.default.post(name: .showFileFinder, object: nil)
        }
        .keyboardShortcut("p", modifiers: [.command])
    }
}
```

---

## 5. INTEGRAR THEME MANAGER

### En `GitMacApp.swift`:

```swift
@main
struct GitMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager.shared // 👈 AGREGAR
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager) // 👈 AGREGAR
        }
    }
}
```

### En `SettingsView.swift`:

```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            // ... tabs existentes ...
            
            ThemeSettingsView() // 👈 AGREGAR
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
        }
    }
}
```

### Usar colores del theme:

```swift
@EnvironmentObject var themeManager: ThemeManager

// En cualquier vista:
.foregroundColor(themeManager.colors.text.color)
.background(themeManager.colors.background.color)
```

---

## 6. INTEGRAR KEYBOARD SHORTCUTS

### En `GitMacApp.swift`:

```swift
@StateObject private var shortcutManager = KeyboardShortcutManager.shared // 👈 AGREGAR

// Configurar event monitor
.onAppear {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if shortcutManager.handle(event) {
            return nil // Consumed
        }
        return event
    }
}
```

### En `SettingsView.swift`:

```swift
ShortcutSettingsView() // 👈 AGREGAR
    .tabItem {
        Label("Shortcuts", systemImage: "keyboard")
    }
```

---

## 7. INTEGRAR EXTERNAL TOOLS

### En `SettingsView.swift`:

```swift
ExternalToolsSettingsView() // 👈 AGREGAR
    .tabItem {
        Label("External Tools", systemImage: "wrench.and.screwdriver")
    }
```

### Usar en context menus:

```swift
// En cualquier FileRow o vista de archivo:
.contextMenu {
    // ... menú existente ...
    
    Divider()
    
    Menu("Open with...") {
        ForEach(ExternalToolsManager.shared.availableTools) { tool in
            Button {
                ExternalToolsManager.shared.openFile(filePath, with: tool)
            } label: {
                Label(tool.name, systemImage: tool.icon)
            }
        }
    }
}
```

---

## 8. INTEGRAR GITHUB

### Paso 1: Configurar OAuth

En `GitHubIntegration.swift`, reemplaza:

```swift
private let clientId = "YOUR_GITHUB_CLIENT_ID" // 👈 Tu GitHub OAuth App Client ID
private let clientSecret = "YOUR_GITHUB_CLIENT_SECRET" // 👈 Tu Secret
```

**Cómo obtener credenciales:**
1. Ir a https://github.com/settings/developers
2. "New OAuth App"
3. Application name: "GitMac"
4. Homepage URL: "https://github.com"
5. Authorization callback URL: "gitmac://oauth-callback"
6. Copiar Client ID y Client Secret

### Paso 2: Configurar URL Scheme

En `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>gitmac</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.gitmac.oauth</string>
    </dict>
</array>
```

### Paso 3: Agregar a UI

En `ContentView.swift` o crear nueva vista:

```swift
// Agregar tab o sidebar item
TabView {
    // ... tabs existentes ...
    
    GitHubIntegrationView()
        .tabItem {
            Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
        }
}
```

---

## 9. INTEGRAR TERMINAL

### Opción A: Panel Inferior

En `ContentView.swift`:

```swift
struct ContentView: View {
    @State private var showTerminal = false
    @State private var terminalHeight: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 0) {
            // Contenido principal
            mainContent
            
            if showTerminal {
                Divider()
                
                TerminalView()
                    .frame(height: terminalHeight)
                    .environmentObject(appState)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showTerminal.toggle()
                } label: {
                    Image(systemName: "terminal")
                }
                .help("Toggle Terminal")
            }
        }
    }
}
```

### Opción B: Tab Separado

```swift
TabView {
    // ... tabs existentes ...
    
    AdvancedTerminalView()
        .tabItem {
            Label("Terminal", systemImage: "terminal")
        }
}
```

---

## 10. CONFIGURAR MENU BAR

### En `GitMacApp.swift`:

```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .environmentObject(appState)
    }
    .commands {
        // File menu
        CommandGroup(replacing: .newItem) {
            Button("Open Repository...") {
                NotificationCenter.default.post(name: .openRepository, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command])
            
            Button("Clone Repository...") {
                NotificationCenter.default.post(name: .cloneRepository, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        
        // View menu
        CommandMenu("View") {
            Button("Command Palette") {
                NotificationCenter.default.post(name: .showCommandPalette, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            
            Button("Go to File") {
                NotificationCenter.default.post(name: .showFileFinder, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command])
            
            Divider()
            
            Button("Toggle Terminal") {
                NotificationCenter.default.post(name: .toggleTerminal, object: nil)
            }
            .keyboardShortcut("`", modifiers: [.command])
        }
        
        // Git menu
        CommandMenu("Git") {
            Button("Commit") {
                // Focus commit message
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(appState.currentRepository == nil)
            
            Button("Stage All") {
                NotificationCenter.default.post(name: .stageAll, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            
            Button("Unstage All") {
                NotificationCenter.default.post(name: .unstageAll, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Fetch") {
                NotificationCenter.default.post(name: .fetch, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            
            Button("Pull") {
                NotificationCenter.default.post(name: .pull, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            
            Button("Push") {
                NotificationCenter.default.post(name: .push, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}
```

---

## 11. TESTING

### Checklist de Funcionalidades:

#### Git Operations
- [ ] Reset (Soft/Mixed/Hard) funciona
- [ ] Revert crea commits inversos
- [ ] Reflog muestra historial
- [ ] Interactive Rebase permite reordenar

#### Navigation
- [ ] Command Palette abre con Cmd+Shift+P
- [ ] File Finder abre con Cmd+P
- [ ] Fuzzy search funciona
- [ ] Shortcuts ejecutan acciones

#### UI/UX
- [ ] Themes cambian correctamente
- [ ] Dark/Light mode funcionan
- [ ] Custom colors se guardan
- [ ] Minimap muestra en diffs
- [ ] Search encuentra commits/files

#### Integrations
- [ ] Notifications aparecen
- [ ] External tools detectados
- [ ] Diff tools funcionan
- [ ] GitHub auth funciona (si configurado)
- [ ] Terminal ejecuta comandos

### Tests Manuales:

```bash
# 1. Build
xcodebuild -project GitMac.xcodeproj -scheme GitMac -configuration Debug

# 2. Abrir app y verificar:
# - No hay crashes al inicio
# - Todas las vistas cargan
# - Shortcuts funcionan
# - Themes cambian
# - Notifications aparecen

# 3. Testar cada feature:
# - Abrir repo
# - Stage/Unstage files
# - Commit
# - Ver reflog
# - Cambiar theme
# - Usar command palette
# - Buscar archivos
```

---

## 📊 ORDEN RECOMENDADO DE INTEGRACIÓN

### Prioridad Alta (Integrar primero):
1. ✅ NotificationManager (base para otras features)
2. ✅ ThemeManager (UX)
3. ✅ Command Palette (productividad)
4. ✅ File Finder (productividad)

### Prioridad Media:
5. ✅ Keyboard Shortcuts
6. ✅ External Tools
7. ✅ Search View

### Prioridad Baja (opcional):
8. ⚪ GitHub Integration (requiere OAuth setup)
9. ⚪ Terminal (funcionalidad avanzada)

---

## 🐛 TROUBLESHOOTING

### Build Errors:
```
Error: Multiple commands produce...
Solución: Ver BUILD_FIX.md
```

### Crash al abrir:
```
Verificar:
- Todos los @EnvironmentObject están inyectados
- No hay force unwraps nil
- Archivos duplicados eliminados
```

### Features no funcionan:
```
Verificar:
- NotificationCenter observers registrados
- Shortcuts configurados en GitMacApp
- Environment objects pasados correctamente
```

---

## ✅ VERIFICACIÓN FINAL

Después de integrar todo:

```swift
// Checklist final en código:
✅ NotificationManager.shared.success("Test") muestra toast
✅ Cmd+Shift+P abre Command Palette
✅ Cmd+P abre File Finder
✅ Theme cambia en Settings
✅ Shortcuts personalizables en Settings
✅ External tools detectados en Settings
✅ Search encuentra commits
✅ Todas las vistas compilan sin warnings
```

---

*Guía creada: Diciembre 2025*
*Para GitMac v1.0.0-beta*
