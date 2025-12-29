import Foundation

// MARK: - License Models

struct LicenseValidationRequest: Codable {
    let license_key: String
    let device_id: String
    let device_name: String
}

struct LicenseValidationResponse: Codable {
    let valid: Bool
    let license: LicenseInfo?
    let error: String?
}

struct LicenseInfo: Codable {
    let key: String
    let email: String
    let product: String
    let status: String
    let expires_at: String?
    let is_lifetime: Bool
}

// MARK: - License Validator

class GitMacLicenseValidator: ObservableObject {
    @Published var isLicenseValid: Bool = false
    @Published var licenseInfo: LicenseInfo?
    @Published var errorMessage: String?

    // Production License Server
    private let serverURL = "https://gitmac-license-server-production.up.railway.app"

    // Development bypass (set to true for personal use)
    private let isDevelopmentMode = false

    // Hardcoded developer license for offline use
    private let developerLicenseKey = "DEV-PERSONAL-LICENSE-KEY"

    // Singleton
    static let shared = GitMacLicenseValidator()

    private init() {
        // Load cached license on init
        loadCachedLicense()
    }

    // MARK: - Device ID

    /// Get unique device identifier
    private func getDeviceID() -> String {
        // Use hardware UUID as device ID
        if let uuid = getMacSerialNumber() {
            return uuid
        }

        // Fallback to system identifier
        return getSystemIdentifier()
    }

    private func getMacSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert != 0 else { return nil }

        defer { IOObjectRelease(platformExpert) }

        guard let serialNumber = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as? String else {
            return nil
        }

        return serialNumber
    }

    private func getSystemIdentifier() -> String {
        var size = 0
        sysctlbyname("kern.uuid", nil, &size, nil, 0)
        var uuid = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.uuid", &uuid, &size, nil, 0)
        return String(cString: uuid)
    }

    private func getDeviceName() -> String {
        return Host.current().localizedName ?? "Mac"
    }

    // MARK: - License Validation

    /// Validate license key
    func validateLicense(_ licenseKey: String) async -> Bool {
        // Development bypass for personal use
        if isDevelopmentMode || licenseKey == developerLicenseKey {
            await MainActor.run {
                self.isLicenseValid = true
                self.licenseInfo = LicenseInfo(
                    key: licenseKey,
                    email: "developer@local",
                    product: "GitMac Pro",
                    status: "active",
                    expires_at: nil,
                    is_lifetime: true
                )
                self.errorMessage = nil
            }
            cacheLicense(licenseKey)
            return true
        }

        let deviceID = getDeviceID()
        let deviceName = getDeviceName()

        let request = LicenseValidationRequest(
            license_key: licenseKey,
            device_id: deviceID,
            device_name: deviceName
        )

        guard let url = URL(string: "\(serverURL)/api/validate") else {
            await MainActor.run {
                self.errorMessage = "Invalid server URL"
                self.isLicenseValid = false
            }
            return false
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.errorMessage = "Server error"
                    self.isLicenseValid = false
                }
                return false
            }

            let validationResponse = try JSONDecoder().decode(
                LicenseValidationResponse.self,
                from: data
            )

            await MainActor.run {
                self.isLicenseValid = validationResponse.valid
                self.licenseInfo = validationResponse.license
                self.errorMessage = validationResponse.error

                if validationResponse.valid {
                    // Cache license locally
                    self.cacheLicense(licenseKey)
                }
            }

            return validationResponse.valid

        } catch {
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)"
                self.isLicenseValid = false
            }
            return false
        }
    }

    // MARK: - License Caching

    private func cacheLicense(_ licenseKey: String) {
        UserDefaults.standard.set(licenseKey, forKey: "cached_license_key")
        UserDefaults.standard.set(Date(), forKey: "license_validated_at")
    }

    private func loadCachedLicense() {
        guard let cachedKey = UserDefaults.standard.string(forKey: "cached_license_key"),
              let validatedAt = UserDefaults.standard.object(forKey: "license_validated_at") as? Date else {
            return
        }

        // Development bypass always works
        if isDevelopmentMode || cachedKey == developerLicenseKey {
            isLicenseValid = true
            return
        }

        // Revalidate if cache is older than 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        if validatedAt < sevenDaysAgo {
            Task {
                // Try to revalidate, but keep cached state if offline
                let result = await validateLicense(cachedKey)
                if !result {
                    // If revalidation fails, trust the cache for offline use
                    await MainActor.run {
                        self.isLicenseValid = true
                        self.errorMessage = "Using cached license (offline mode)"
                    }
                }
            }
        } else {
            // Use cached validation
            isLicenseValid = true
        }
    }

    func clearLicense() {
        UserDefaults.standard.removeObject(forKey: "cached_license_key")
        UserDefaults.standard.removeObject(forKey: "license_validated_at")
        isLicenseValid = false
        licenseInfo = nil
    }

    // MARK: - Feature Checks

    /// Check if user has Pro features
    var hasProFeatures: Bool {
        return isLicenseValid
    }
}

// MARK: - Usage Example in SwiftUI

/*
import SwiftUI

struct LicenseActivationView: View {
    @StateObject private var validator = GitMacLicenseValidator.shared
    @State private var licenseKey = ""
    @State private var isValidating = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Activate GitMac Pro")
                .font(.title)

            DSTextField(placeholder: "License Key (XXXX-XXXX-XXXX-XXXX)", text: $licenseKey)
                .frame(width: 300)

            if let error = validator.errorMessage {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    isValidating = true
                    await validator.validateLicense(licenseKey)
                    isValidating = false
                }
            }) {
                if isValidating {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                } else {
                    Text("Activate License")
                }
            }
            .disabled(licenseKey.isEmpty || isValidating)

            if validator.isLicenseValid {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                        .font(.system(size: 48))

                    Text("License Activated!")
                        .font(.headline)

                    if let info = validator.licenseInfo {
                        Text(info.email)
                            .font(.caption)

                        if info.is_lifetime {
                            Text("Lifetime License")
                                .font(.caption2)
                                .foregroundColor(AppTheme.success)
                        } else if let expiresAt = info.expires_at {
                            Text("Expires: \(expiresAt)")
                                .font(.caption2)
                        }
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}

// Usage in App:
struct ContentView: View {
    @StateObject private var validator = GitMacLicenseValidator.shared

    var body: some View {
        VStack {
            if validator.hasProFeatures {
                // Show Pro UI
                Text("Welcome to GitMac Pro!")
                    .font(.title)
            } else {
                // Show Free UI with upgrade prompt
                VStack {
                    Text("GitMac Free")
                        .font(.title)

                    Button("Upgrade to Pro") {
                        // Show license activation view
                    }
                }
            }
        }
    }
}

// Check feature availability:
if GitMacLicenseValidator.shared.canUseFeature(.aiCommits) {
    // Show AI commit button
} else {
    // Show upgrade prompt
}
*/
