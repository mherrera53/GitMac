# Input Atoms - Guía de Uso

## 1. DSTextField - Text Input Básico

```swift
import SwiftUI

struct MyView: View {
    @State private var username = ""
    @State private var email = ""
    
    var body: some View {
        VStack {
            // Normal
            DSTextField(placeholder: "Username", text: $username)
            
            // Con error
            DSTextField(
                placeholder: "Email",
                text: $email,
                state: .error,
                errorMessage: "Invalid email format"
            )
        }
    }
}
```

## 2. DSSecureField - Password Input

```swift
@State private var password = ""

DSSecureField(
    placeholder: "Password",
    text: $password,
    state: .normal
)
// Incluye toggle automático para mostrar/ocultar
```

## 3. DSTextEditor - Multi-line Text

```swift
@State private var description = ""

DSTextEditor(
    placeholder: "Enter description...",
    text: $description,
    minHeight: 150
)
```

## 4. DSPicker - Auto-styled Picker

```swift
// Simple string picker
@State private var selectedOption: String? = "Option 1"

DSPicker(
    items: ["Option 1", "Option 2", "Option 3"],
    selection: $selectedOption
)
// ≤5 items = segmented control
// >5 items = menu picker

// Generic picker
struct Item: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

@State private var selectedItem: Item?
@State private var items = [Item(name: "One"), Item(name: "Two")]

DSPicker(
    items: items,
    selection: $selectedItem
) { item in
    Text(item.name)
}
```

## 5. DSToggle - 3 Estilos Automáticos

```swift
@State private var isEnabled = false

// Checkbox style
DSToggle("Enable feature", isOn: $isEnabled, style: .checkbox)

// Switch style (default)
DSToggle("Auto-save", isOn: $isEnabled, style: .switch)

// Button style
DSToggle("Premium mode", isOn: $isEnabled, style: .button)
```

## 6. DSSearchField - Search Input

```swift
@State private var searchText = ""

// Básico
DSSearchField(text: $searchText)

// Con submit action
DSSearchField(
    placeholder: "Search files...",
    text: $searchText,
    onSubmit: {
        performSearch()
    }
)
// Incluye lupa y botón X automático
```

## Estados Disponibles

### DSTextFieldState
- `.normal` - Estado por defecto
- `.focused` - Cuando tiene focus
- `.error` - Con mensaje de error
- `.disabled` - Deshabilitado

### DSToggleStyle
- `.checkbox` - Checkbox con checkmark
- `.switch` - Toggle nativo macOS
- `.button` - Botón toggle

## Design Tokens Utilizados

Todos los componentes usan:
- `DesignTokens.Typography.*`
- `DesignTokens.Spacing.*`
- `DesignTokens.CornerRadius.*`
- `DesignTokens.Sizing.Icon.*`
- `AppTheme.*` colores
