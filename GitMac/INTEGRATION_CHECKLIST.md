# ✅ CHECKLIST DE INTEGRACIÓN PASO A PASO

## 🔧 FASE 1: ARREGLAR BUILD (5-10 minutos)

### Paso 1.1: Ejecutar script de limpieza
```bash
cd /path/to/GitMac
chmod +x fix_build.sh
./fix_build.sh
```

### Paso 1.2: Eliminar duplicados en Xcode
- [ ] Abrir Xcode
- [ ] Presionar ⌘1 (Project Navigator)
- [ ] Buscar "InteractiveRebaseView.swift"
  - [ ] Si hay 2 archivos, eliminar el más pequeño (Remove Reference)
- [ ] Buscar "ThemeManager.swift"
  - [ ] Si hay 2 archivos, eliminar el más pequeño (Remove Reference)
- [ ] Buscar "SearchView.swift"
  - [ ] Si hay 2 archivos, eliminar el más pequeño (Remove Reference)

### Paso 1.3: Clean Build
- [ ] Product → Clean Build Folder (⌘⇧K)
- [ ] Product → Build (⌘B)
- [ ] ✅ Build debe completar sin errores

---

## 🔗 FASE 2: INTEGRAR EXTENSIONES (5 minutos)

### Paso 2.1: Agregar IntegrationHelpers.swift
- [ ] Crear archivo "Extensions.swift" en tu proyecto
- [ ] Copiar contenido de `IntegrationHelpers.swift` (sección Notification Names)
- [ ] Agregar al target de GitMac
- [ ] Build para verificar (⌘B)

**Código a agregar en Extensions.swift:**
```swift
import Foundation

extension Notification.Name {
    static let showCommandPalette = Notification.Name("showCommandPalette")
    static let showFileFinder = Notification.Name("showFileFinder")
    static let openRepository = Notification.Name("openRepository")
    static let cloneRepository = Notification.Name("cloneRepository")
    static let toggleTerminal = Notification.Name("toggleTerminal")
    static let stageAll = Notification.Name("stageAll")
    static let unstageAll = Notification.Name("unstageAll")
    static let fetch = Notification.Name("fetch")
    static let pull = Notification.Name("pull")
    static let push = Notification.Name("push")
}
```

---

## 📱 FASE 3: INTEGRAR NOTIFICATIONMANAGER (10 minutos)

### Paso 3.1: Modificar ContentView.swift
- [ ] Abrir ContentView.swift
- [ ] Buscar el `body: some View`
- [ ] Al final del body, antes del último `}`, agregar:
```swift
.withToastNotifications()
```

### Paso 3.2: Testar
- [ ] Build y Run (⌘R)
- [ ] En cualquier acción Git, agregar:
```swift
NotificationManager.shared.success("Test notification")
```
- [ ] ✅ Debe aparecer toast en esquina superior derecha

---

## 🎨 FASE 4: INTEGRAR THEME MANAGER (15 minutos)

### Paso 4.1: Modificar GitMacApp.swift
- [ ] Abrir GitMacApp.swift
- [ ] Agregar después de `@StateObject private var appState`:
```swift
@StateObject private var themeManager = ThemeManager.shared
```

- [ ] En `ContentView()`, agregar después de `.environmentObject(appState)`:
```swift
.environmentObject(themeManager)
```

### Paso 4.2: Agregar Settings window
- [ ] En `GitMacApp`, agregar después de `WindowGroup { ... }`:
```swift
Settings {
    SettingsView()
        .environmentObject(appState)
        .environmentObject(themeManager)
}
```

### Paso 4.3: Modificar/Crear SettingsView.swift
- [ ] Si no existe, crear SettingsView.swift
- [ ] Agregar tabs:
```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            ThemeSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            
            ExternalToolsSettingsView()
                .tabItem {
                    Label("External Tools", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 600, height: 500)
    }
}
```

### Paso 4.4: Testar
- [ ] Build y Run (⌘R)
- [ ] GitMac → Settings (⌘,)
- [ ] ✅ Debe abrir ventana de settings con tabs

---

## ⌨️ FASE 5: INTEGRAR COMMAND PALETTE & FILE FINDER (20 minutos)

### Paso 5.1: Modificar ContentView.swift - Agregar estados
- [ ] Al inicio de ContentView, después de `@EnvironmentObject`, agregar:
```swift
@State private var showCommandPalette = false
@State private var showFileFinder = false
```

### Paso 5.2: Agregar sheets
- [ ] Después de `.withToastNotifications()`, agregar:
```swift
.sheet(isPresented: $showCommandPalette) {
    CommandPalette()
        .environmentObject(appState)
}
.sheet(isPresented: $showFileFinder) {
    FuzzyFileFinder()
        .environmentObject(appState)
}
```

### Paso 5.3: Agregar receivers
- [ ] Después de los sheets, agregar:
```swift
.onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
    showCommandPalette = true
}
.onReceive(NotificationCenter.default.publisher(for: .showFileFinder)) { _ in
    showFileFinder = true
}
```

### Paso 5.4: Agregar menu commands en GitMacApp.swift
- [ ] Después de `WindowGroup { ... }`, agregar:
```swift
.commands {
    CommandMenu("View") {
        Button("Command Palette") {
            NotificationCenter.default.post(name: .showCommandPalette, object: nil)
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        
        Button("Go to File") {
            NotificationCenter.default.post(name: .showFileFinder, object: nil)
        }
        .keyboardShortcut("p", modifiers: [.command])
    }
}
```

### Paso 5.5: Testar
- [ ] Build y Run (⌘R)
- [ ] Presionar Cmd+Shift+P
- [ ] ✅ Debe abrir Command Palette
- [ ] Presionar Cmd+P
- [ ] ✅ Debe abrir File Finder

---

## 🔧 FASE 6: INTEGRAR EXTERNAL TOOLS (5 minutos)

### Paso 6.1: Ya está en Settings
- [ ] External Tools ya se agregó en Fase 4
- [ ] Solo verificar que compile

### Paso 6.2: Testar
- [ ] Build y Run
- [ ] Settings → External Tools
- [ ] ✅ Debe mostrar herramientas detectadas

---

## 🐙 FASE 7: INTEGRAR GITHUB (OPCIONAL - 30 minutos)

### Paso 7.1: Configurar OAuth (si deseas usar GitHub)
- [ ] Ir a https://github.com/settings/developers
- [ ] "New OAuth App"
- [ ] Application name: "GitMac"
- [ ] Homepage URL: "https://github.com"
- [ ] Authorization callback URL: "gitmac://oauth-callback"
- [ ] Copiar Client ID y Client Secret

### Paso 7.2: Configurar en código
- [ ] Abrir GitHubIntegration.swift
- [ ] Reemplazar:
```swift
private let clientId = "TU_CLIENT_ID_AQUI"
private let clientSecret = "TU_SECRET_AQUI"
```

### Paso 7.3: Configurar Info.plist
- [ ] Abrir Info.plist
- [ ] Agregar:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>gitmac</string>
        </array>
    </dict>
</array>
```

### Paso 7.4: Agregar a UI
- [ ] En SettingsView, agregar tab:
```swift
GitHubIntegrationView()
    .tabItem {
        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
    }
```

---

## 💻 FASE 8: INTEGRAR TERMINAL (OPCIONAL - 15 minutos)

### Paso 8.1: Agregar estado en ContentView
```swift
@State private var showTerminal = false
@State private var terminalHeight: CGFloat = 200
```

### Paso 8.2: Modificar layout
- [ ] Envolver contenido principal en VStack
- [ ] Agregar terminal panel condicionalmente
- [ ] Agregar toolbar button

**Ver IntegrationHelpers.swift para ejemplo completo**

### Paso 8.3: Agregar menu command
```swift
Button("Toggle Terminal") {
    NotificationCenter.default.post(name: .toggleTerminal, object: nil)
}
.keyboardShortcut("`", modifiers: [.command])
```

---

## 🎯 FASE 9: VERIFICACIÓN FINAL (10 minutos)

### Tests Funcionales:
- [ ] ✅ App arranca sin crashes
- [ ] ✅ Cmd+Shift+P abre Command Palette
- [ ] ✅ Cmd+P abre File Finder
- [ ] ✅ Cmd+, abre Settings
- [ ] ✅ Settings tiene tabs (Appearance, Shortcuts, External Tools)
- [ ] ✅ Themes cambian correctamente
- [ ] ✅ Notifications aparecen en operaciones Git
- [ ] ✅ External tools se detectan
- [ ] ✅ No hay memory leaks obvios

### Tests Git Operations:
- [ ] ✅ Abrir repositorio funciona
- [ ] ✅ Stage/Unstage files funciona
- [ ] ✅ Commit con mensaje funciona
- [ ] ✅ Ver reflog funciona
- [ ] ✅ Interactive rebase funciona
- [ ] ✅ Branch comparison funciona
- [ ] ✅ Search funciona

---

## 📊 PROGRESO DE INTEGRACIÓN

```
Fase 1: Arreglar Build       [████████████████████] 100%
Fase 2: Extensions            [████████████████████] 100%
Fase 3: NotificationManager   [░░░░░░░░░░░░░░░░░░░░]   0%
Fase 4: Theme Manager         [░░░░░░░░░░░░░░░░░░░░]   0%
Fase 5: Command Palette       [░░░░░░░░░░░░░░░░░░░░]   0%
Fase 6: External Tools        [░░░░░░░░░░░░░░░░░░░░]   0%
Fase 7: GitHub (Opcional)     [░░░░░░░░░░░░░░░░░░░░]   0%
Fase 8: Terminal (Opcional)   [░░░░░░░░░░░░░░░░░░░░]   0%
Fase 9: Verificación          [░░░░░░░░░░░░░░░░░░░░]   0%

TOTAL: 0% completado
```

---

## 🚨 TROUBLESHOOTING

### Si Build falla:
1. Clean Build Folder (⌘⇧K)
2. Cerrar y reabrir Xcode
3. Eliminar DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
4. Rebuild

### Si App crashea al abrir:
1. Verificar todos los `@EnvironmentObject` están inyectados
2. Verificar no hay force unwraps (`!`) en código crítico
3. Revisar Console en Xcode para ver error exacto

### Si Shortcuts no funcionan:
1. Verificar Notification.Name extensions están agregadas
2. Verificar `.commands` está en GitMacApp.swift
3. Verificar `.onReceive` están en ContentView.swift

---

## 📝 NOTAS

- **Tiempo estimado total**: 2-3 horas
- **Fases obligatorias**: 1-6 (1.5 horas)
- **Fases opcionales**: 7-8 (45 min)
- **GitHub requiere**: OAuth setup externo
- **Terminal**: Funcionalidad avanzada, no crítica

---

## ✨ DESPUÉS DE COMPLETAR

Una vez todo integrado:
1. Hacer commit: "feat: integrate all Phase 1-3 features"
2. Crear tag: `git tag v1.0.0-beta`
3. Testar exhaustivamente
4. Reportar bugs encontrados
5. ¡Disfrutar tu cliente Git superior a GitKraken! 🎉

---

*Checklist creado: Diciembre 2025*
*Para GitMac v1.0.0-beta*
