# Guía para Publicar GitMac en la App Store

## 1. Inscripción en Apple Developer Program

1. Ir a https://developer.apple.com/programs/
2. Inscribirse como individuo o empresa ($99 USD/año)
3. Esperar aprobación (1-2 días para individuos)

## 2. Preparar la App

### 2.1 Configurar Bundle Identifier
En Xcode, actualizar `PRODUCT_BUNDLE_IDENTIFIER`:
```
com.tudominio.GitMac
```

### 2.2 Configurar Signing
1. Xcode > Signing & Capabilities
2. Seleccionar tu Team de desarrollo
3. Habilitar "Automatically manage signing"

### 2.3 Agregar Capacidades Necesarias
- App Sandbox: Required para Mac App Store
- Network Client: Para GitHub, Taiga, Planner APIs
- Keychain Sharing: Para guardar tokens seguros

### 2.4 Entitlements para App Store
Actualizar `GitMac.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

## 3. Configurar Suscripción en App Store Connect

### 3.1 Crear App en App Store Connect
1. Ir a https://appstoreconnect.apple.com
2. My Apps > + > New App
3. Completar información:
   - Platform: macOS
   - Name: GitMac
   - Primary Language: Spanish/English
   - Bundle ID: com.tudominio.GitMac
   - SKU: gitmac-2024

### 3.2 Configurar In-App Purchases (Suscripción)
1. App Store Connect > Tu App > In-App Purchases
2. Click "+" > Auto-Renewable Subscription
3. Crear grupo de suscripción: "GitMac Pro"

### 3.3 Configurar Precios de Suscripción

**Opción A: Suscripción Anual**
- Reference Name: GitMac Pro Annual
- Product ID: com.tudominio.gitmac.pro.annual
- Precio: $2.99 USD/año
- Tu ganancia: ~$2.09 (después de 30% Apple)

**Opción B: Suscripción Mensual**
- Reference Name: GitMac Pro Monthly
- Product ID: com.tudominio.gitmac.pro.monthly
- Precio: $0.99 USD/mes
- Tu ganancia: ~$0.69/mes (~$8.28/año)

### 3.4 Beneficios de Suscripción Sugeridos

**Versión Gratuita:**
- Repositorios locales ilimitados
- Git básico (commit, push, pull, branch)
- 1 integración (GitHub o Taiga)

**GitMac Pro ($2.99/año):**
- Todas las integraciones (GitHub, Taiga, Planner)
- AI Commit Messages (requiere tu API key)
- Temas personalizados
- Sin límite de repositorios en la nube
- Soporte prioritario

## 4. Implementar StoreKit 2 en la App

### 4.1 Crear archivo de productos

Crear `GitMac/Core/StoreKit/Products.storekit`:
```json
{
  "identifier" : "Products",
  "nonRenewingSubscriptions" : [],
  "products" : [],
  "settings" : {},
  "subscriptionGroups" : [
    {
      "id" : "gitmac_pro",
      "localizations" : [],
      "name" : "GitMac Pro",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "2.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "annual",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Full access to GitMac Pro features",
              "displayName" : "GitMac Pro Annual",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.tudominio.gitmac.pro.annual",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "GitMac Pro Annual",
          "subscriptionGroupID" : "gitmac_pro",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 2,
    "minor" : 0
  }
}
```

### 4.2 Crear StoreManager

```swift
// GitMac/Core/StoreKit/StoreManager.swift
import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isProUser = false

    private let productIDs = ["com.tudominio.gitmac.pro.annual"]

    init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
        isProUser = !purchasedProductIDs.isEmpty
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
```

## 5. Subir App para Revisión

### 5.1 Crear Archive
1. Xcode > Product > Archive
2. Esperar a que complete
3. Window > Organizer

### 5.2 Validar y Subir
1. En Organizer, seleccionar el archive
2. Click "Validate App" - corregir errores si hay
3. Click "Distribute App"
4. Seleccionar "App Store Connect"
5. Upload

### 5.3 Completar Información en App Store Connect
- Screenshots (1280x800, 1440x900, 2880x1800)
- App Description
- Keywords
- Privacy Policy URL (requerido para suscripciones)
- Support URL

### 5.4 Enviar para Review
1. En App Store Connect > Tu App
2. Seleccionar build subido
3. Completar toda la información requerida
4. Submit for Review

## 6. Tiempos y Consideraciones

### Tiempos Estimados:
- Revisión inicial: 24-48 horas (puede ser más para apps nuevas)
- Aprobación de IAP: incluido en la revisión

### Requisitos para Suscripciones:
- Privacy Policy obligatoria
- Términos de servicio claros
- Explicar qué incluye la suscripción
- Botón para restaurar compras
- Mostrar precio claramente antes de comprar

## 7. Calculadora de Ingresos

| Suscriptores | Precio | Comisión Apple | Tu Ganancia Anual |
|--------------|--------|----------------|-------------------|
| 100          | $2.99  | 30%            | $209.30           |
| 500          | $2.99  | 30%            | $1,046.50         |
| 1,000        | $2.99  | 30%            | $2,093.00         |
| 5,000        | $2.99  | 30%            | $10,465.00        |

*Después del primer año de suscripción de cada usuario, la comisión baja a 15%*

## 8. Alternativas de Distribución

### 8.1 Venta Directa (fuera de App Store)
- Sin comisión de Apple
- Pero: sin acceso a usuarios de App Store
- Necesitas tu propio sistema de pagos (Stripe, Paddle)

### 8.2 App Store + Sitio Web
- App gratuita en App Store
- Suscripción via tu sitio web (sin comisión)
- Apple permite esto para "reader apps" pero es zona gris

## Recursos

- App Store Connect: https://appstoreconnect.apple.com
- StoreKit 2 Documentation: https://developer.apple.com/storekit/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Pricing Reference: https://developer.apple.com/app-store/pricing/
