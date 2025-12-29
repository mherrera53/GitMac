# Plugin Template - GitMac Integration

Usa este template para crear nuevas integraciones en ~50 líneas de código.

## Arquitectura del Plugin System

El Plugin System de GitMac permite agregar integraciones de manera escalable y consistente:

- **IntegrationPlugin**: Protocol que define la interfaz del plugin
- **IntegrationViewModel**: Protocol base para ViewModels con autenticación y estado
- **PluginRegistry**: Registry singleton para gestionar plugins
- **Content Views**: Vistas SwiftUI específicas de cada integración

---

## Guía Paso a Paso

### 1. Crear ViewModel

Crea el ViewModel que manejará la lógica de negocio y el estado de tu integración.

**Ubicación:** `GitMac/Features/[ServiceName]/[ServiceName]ViewModel.swift`

```swift
import Foundation

/// ViewModel para la integración con [ServiceName]
@MainActor
class MyServiceViewModel: ObservableObject, IntegrationViewModel {
    // MARK: - IntegrationViewModel Requirements

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Service-Specific State

    @Published var items: [Item] = []
    @Published var selectedItem: Item?

    // MARK: - Authentication

    func authenticate() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // TODO: Implement authentication
            // Example: Get API token from Keychain
            // let token = try KeychainManager.shared.get(key: "myservice_token")

            // Verify token is valid
            // try await verifyToken(token)

            isAuthenticated = true
        } catch {
            self.error = "Authentication failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Data Fetching

    func refresh() async throws {
        guard isAuthenticated else {
            throw NSError(domain: "MyService", code: 401,
                         userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // TODO: Fetch items from API
            // items = try await fetchItemsFromAPI()

            // Placeholder
            items = []
        } catch {
            self.error = "Failed to refresh: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Service-Specific Methods

    func selectItem(_ item: Item) {
        selectedItem = item
    }

    func createItem(title: String) async throws {
        // TODO: Implement item creation
    }
}

// MARK: - Supporting Types

struct Item: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String?
    let createdAt: Date
}
```

---

### 2. Crear Plugin

Define el plugin que registrará tu integración en el sistema.

**Ubicación:** `GitMac/Features/[ServiceName]/[ServiceName]Plugin.swift`

```swift
import SwiftUI

/// Plugin para integración con [ServiceName]
struct MyServicePlugin: IntegrationPlugin {
    // MARK: - Plugin Metadata

    let id = "myservice"
    let name = "My Service"
    let icon = "star.fill"  // SF Symbol name
    let iconColor = Color.blue

    // MARK: - Factory Methods

    func makeViewModel() -> MyServiceViewModel {
        MyServiceViewModel()
    }

    func makeContentView(viewModel: MyServiceViewModel) -> some View {
        MyServiceContentView(viewModel: viewModel)
    }
}
```

---

### 3. Crear Content View

Implementa la vista SwiftUI que mostrará la interfaz de tu integración.

**Ubicación:** `GitMac/Features/[ServiceName]/[ServiceName]ContentView.swift`

```swift
import SwiftUI

/// Vista principal para la integración con [ServiceName]
struct MyServiceContentView: View {
    @ObservedObject var viewModel: MyServiceViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            content
        }
        .task {
            if viewModel.isAuthenticated {
                try? await viewModel.refresh()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("My Service", systemImage: "star.fill")
                .font(.headline)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Button(action: { Task { try? await viewModel.refresh() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading || !viewModel.isAuthenticated)
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !viewModel.isAuthenticated {
            notAuthenticatedView
        } else if viewModel.items.isEmpty {
            emptyStateView
        } else {
            itemListView
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Not Authenticated")
                .font(.headline)

            Text("Please authenticate to access My Service")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Authenticate") {
                Task { try? await viewModel.authenticate() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Items")
                .font(.headline)

            Text("No items to display.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemListView: some View {
        List(viewModel.items) { item in
            itemRow(item)
                .onTapGesture {
                    viewModel.selectItem(item)
                }
        }
    }

    private func itemRow(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(item.createdAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    MyServiceContentView(viewModel: MyServiceViewModel())
        .frame(width: 400, height: 600)
}
```

---

### 4. Registrar Plugin

Registra el plugin en la aplicación para que esté disponible globalmente.

**Ubicación:** `GitMac/App/GitMacApp.swift`

```swift
import SwiftUI

@main
struct GitMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Register plugins
                    registerPlugins()
                }
        }
    }

    private func registerPlugins() {
        // Register all integration plugins
        PluginRegistry.shared.register(MyServicePlugin())

        // Add more plugins as needed
        // PluginRegistry.shared.register(JiraPlugin())
        // PluginRegistry.shared.register(SlackPlugin())
    }
}
```

---

### 5. Usar el Plugin

Una vez registrado, puedes usar el plugin en cualquier parte de la aplicación.

#### Opción A: Acceso directo al plugin

```swift
struct IntegrationsView: View {
    var body: some View {
        List {
            ForEach(PluginRegistry.shared.allPlugins(), id: \.id) { plugin in
                NavigationLink(destination: pluginView(for: plugin)) {
                    Label(plugin.name, systemImage: plugin.icon)
                        .foregroundColor(plugin.iconColor)
                }
            }
        }
    }

    @ViewBuilder
    private func pluginView(for plugin: any IntegrationPlugin) -> some View {
        if let myServicePlugin = plugin as? MyServicePlugin {
            let viewModel = myServicePlugin.makeViewModel()
            myServicePlugin.makeContentView(viewModel: viewModel)
        } else {
            Text("Unknown plugin type")
        }
    }
}
```

#### Opción B: Vista genérica de plugins

```swift
struct PluginHostView: View {
    let pluginId: String

    var body: some View {
        if let plugin = PluginRegistry.shared.plugin(withId: pluginId) {
            if let myServicePlugin = plugin as? MyServicePlugin {
                let viewModel = myServicePlugin.makeViewModel()
                myServicePlugin.makeContentView(viewModel: viewModel)
            }
        } else {
            Text("Plugin not found")
        }
    }
}
```

---

## Mejores Prácticas

### 1. Gestión de Estado

- Usa `@Published` para propiedades que deben actualizar la UI
- Implementa `isLoading` para mostrar estados de carga
- Maneja errores con `error: String?` y muestra mensajes amigables

### 2. Autenticación

- Guarda tokens en Keychain, no en UserDefaults
- Verifica autenticación antes de hacer requests
- Implementa refresh de tokens cuando sea necesario

### 3. Networking

- Usa `async/await` para operaciones asíncronas
- Implementa retry logic para requests fallidos
- Cachea datos cuando sea apropiado

### 4. UI/UX

- Muestra estados vacíos informativos
- Implementa pull-to-refresh cuando sea apropiado
- Usa skeleton loaders para mejor UX

### 5. Testing

- Escribe tests unitarios para ViewModels
- Mockea servicios externos
- Prueba estados de error y edge cases

---

## Ejemplos de Integración

### Ejemplo 1: Jira

```swift
// JiraViewModel.swift
@MainActor
class JiraViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var tickets: [JiraTicket] = []

    func authenticate() async throws {
        // Implement Jira OAuth
    }

    func refresh() async throws {
        // Fetch tickets from Jira API
    }
}

// JiraPlugin.swift
struct JiraPlugin: IntegrationPlugin {
    let id = "jira"
    let name = "Jira"
    let icon = "checkmark.circle.fill"
    let iconColor = Color.blue

    func makeViewModel() -> JiraViewModel { JiraViewModel() }
    func makeContentView(viewModel: JiraViewModel) -> some View {
        JiraContentView(viewModel: viewModel)
    }
}
```

### Ejemplo 2: Slack

```swift
// SlackViewModel.swift
@MainActor
class SlackViewModel: ObservableObject, IntegrationViewModel {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var channels: [SlackChannel] = []

    func authenticate() async throws {
        // Implement Slack OAuth
    }

    func refresh() async throws {
        // Fetch channels from Slack API
    }
}

// SlackPlugin.swift
struct SlackPlugin: IntegrationPlugin {
    let id = "slack"
    let name = "Slack"
    let icon = "message.fill"
    let iconColor = Color.purple

    func makeViewModel() -> SlackViewModel { SlackViewModel() }
    func makeContentView(viewModel: SlackViewModel) -> some View {
        SlackContentView(viewModel: viewModel)
    }
}
```

---

## Checklist de Implementación

- [ ] Crear ViewModel que implemente `IntegrationViewModel`
- [ ] Implementar `authenticate()` con manejo de errores
- [ ] Implementar `refresh()` para obtener datos
- [ ] Crear Plugin que implemente `IntegrationPlugin`
- [ ] Definir metadata del plugin (id, name, icon, iconColor)
- [ ] Crear ContentView con estados: no autenticado, vacío, con datos, error
- [ ] Registrar plugin en `GitMacApp.swift`
- [ ] Probar autenticación
- [ ] Probar carga de datos
- [ ] Probar manejo de errores
- [ ] Agregar tests unitarios
- [ ] Documentar API específica del servicio

---

## Recursos

- **SF Symbols**: https://developer.apple.com/sf-symbols/
- **SwiftUI Documentation**: https://developer.apple.com/documentation/swiftui
- **Async/Await Guide**: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html

---

¡Listo! Con este template puedes crear nuevas integraciones en aproximadamente 50 líneas de código core, más la UI específica que necesites.
