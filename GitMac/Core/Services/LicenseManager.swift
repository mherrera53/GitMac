//
//  LicenseManager.swift
//  GitMac
//
//  Pro version license manager
//

import Foundation
import SwiftUI

/// License tier for GitMac
enum LicenseTier: String, Codable {
    case free = "Free"
    case pro = "Pro"
    case enterprise = "Enterprise"

    var displayName: String { rawValue }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Basic Git operations",
                "Single repository",
                "Limited integrations"
            ]
        case .pro:
            return [
                "Unlimited repositories",
                "Workspace Manager",
                "Auto-discovery",
                "All integrations",
                "Templates & Groups",
                "Import/Export configs",
                "Priority support"
            ]
        case .enterprise:
            return [
                "Everything in Pro",
                "Team management",
                "Custom integrations",
                "SSO support",
                "Dedicated support"
            ]
        }
    }
}

/// License information
struct License: Codable {
    let tier: LicenseTier
    let activatedAt: Date
    let expiresAt: Date?
    let email: String?
    let key: String

    var isActive: Bool {
        if let expiresAt = expiresAt {
            return Date() < expiresAt
        }
        return true // Lifetime license
    }

    var daysRemaining: Int? {
        guard let expiresAt = expiresAt else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day
    }
}

/// License manager for GitMac
@MainActor
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var currentLicense: License?

    private let licenseKey = "gitmac_license"

    // Pro license key for user (hardcoded unlock)
    private let proLicenseKey = "GITMAC-PRO-2026-UNLIMITED"

    private init() {
        loadLicense()
        // Auto-activate Pro if no license exists
        if currentLicense == nil {
            activateProLicense()
        }
    }

    var currentTier: LicenseTier {
        currentLicense?.tier ?? .free
    }

    var isPro: Bool {
        guard let license = currentLicense, license.isActive else { return false }
        return license.tier == .pro || license.tier == .enterprise
    }

    var isEnterprise: Bool {
        guard let license = currentLicense, license.isActive else { return false }
        return license.tier == .enterprise
    }

    // MARK: - Activation

    func activateProLicense() {
        let license = License(
            tier: .pro,
            activatedAt: Date(),
            expiresAt: nil, // Lifetime
            email: nil,
            key: proLicenseKey
        )
        currentLicense = license
        saveLicense()
    }

    func activate(key: String, email: String? = nil) -> Bool {
        // Validate key format
        guard !key.isEmpty else { return false }

        // Check if it's the Pro key
        if key.uppercased() == proLicenseKey {
            activateProLicense()
            return true
        }

        // For demo: accept any key starting with "GITMAC-PRO"
        if key.uppercased().hasPrefix("GITMAC-PRO") {
            let license = License(
                tier: .pro,
                activatedAt: Date(),
                expiresAt: nil,
                email: email,
                key: key.uppercased()
            )
            currentLicense = license
            saveLicense()
            return true
        }

        // Enterprise keys
        if key.uppercased().hasPrefix("GITMAC-ENT") {
            let license = License(
                tier: .enterprise,
                activatedAt: Date(),
                expiresAt: nil,
                email: email,
                key: key.uppercased()
            )
            currentLicense = license
            saveLicense()
            return true
        }

        return false
    }

    func deactivate() {
        currentLicense = nil
        UserDefaults.standard.removeObject(forKey: licenseKey)
    }

    // MARK: - Feature Checks

    func canUse(_ feature: LicenseFeature) -> Bool {
        switch feature {
        case .workspaceManager, .autoDiscovery, .templates, .groups, .importExport, .bulkOperations:
            return isPro || isEnterprise
        case .teamManagement, .customIntegrations, .sso:
            return isEnterprise
        case .basicGit:
            return true
        }
    }

    func requiresPro(for feature: LicenseFeature, action: () -> Void) {
        if canUse(feature) {
            action()
        } else {
            // Show upgrade prompt
            print("⚠️ Feature '\(feature.displayName)' requires Pro license")
        }
    }

    // MARK: - Persistence

    private func saveLicense() {
        if let data = try? JSONEncoder().encode(currentLicense) {
            UserDefaults.standard.set(data, forKey: licenseKey)
        }
    }

    private func loadLicense() {
        if let data = UserDefaults.standard.data(forKey: licenseKey),
           let license = try? JSONDecoder().decode(License.self, from: data) {
            currentLicense = license
        }
    }
}

/// License features that require specific tiers
enum LicenseFeature {
    case basicGit
    case workspaceManager
    case autoDiscovery
    case templates
    case groups
    case importExport
    case bulkOperations
    case teamManagement
    case customIntegrations
    case sso

    var displayName: String {
        switch self {
        case .basicGit: return "Basic Git Operations"
        case .workspaceManager: return "Workspace Manager"
        case .autoDiscovery: return "Auto-Discovery"
        case .templates: return "Templates"
        case .groups: return "Groups"
        case .importExport: return "Import/Export"
        case .bulkOperations: return "Bulk Operations"
        case .teamManagement: return "Team Management"
        case .customIntegrations: return "Custom Integrations"
        case .sso: return "SSO Support"
        }
    }
}
