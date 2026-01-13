import SwiftUI

struct SubscriptionSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var licenseValidator = GitMacLicenseValidator.shared
    @State private var showSubscriptionSheet = false

    var body: some View {
        Form {
            SettingsSection(title: "Current Plan") {
                if licenseValidator.hasProFeatures {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppTheme.warning)
                        VStack(alignment: .leading) {
                            Text("GitMac Pro")
                                .foregroundColor(AppTheme.textPrimary)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.textPrimary)
                            if let info = licenseValidator.licenseInfo {
                                Text(info.is_lifetime ? "Lifetime License" : "Active")
                                    .foregroundColor(AppTheme.textPrimary)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            } else {
                                Text("Pro Features Unlocked")
                                    .foregroundColor(AppTheme.textPrimary)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                        DSButton("Manage", variant: .secondary, size: .sm) {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(AppTheme.textSecondary)
                        VStack(alignment: .leading) {
                            Text("Free Plan")
                                .foregroundColor(AppTheme.textPrimary)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Limited features")
                                .foregroundColor(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        DSButton("Upgrade to Pro", variant: .primary, size: .sm) {
                            showSubscriptionSheet = true
                        }
                    }
                }
            }

            SettingsSection(title: "Pro Features") {
                ForEach(StoreManager.ProFeature.allCases, id: \.self) { feature in
                    HStack {
                        Image(systemName: feature.icon)
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(feature.rawValue)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(feature.description)
                                .foregroundColor(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        if licenseValidator.hasProFeatures {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.success)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
            }

            SettingsSection(title: "Pricing") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Annual")
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(storeManager.formattedAnnualPrice + "/year")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    HStack {
                        Text("Monthly")
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(storeManager.formattedMonthlyPrice + "/month")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Text("Subscriptions auto-renew unless cancelled 24 hours before the end of the current period.")
                    .foregroundColor(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Section {
                DSButton("Restore Purchases", variant: .secondary, size: .sm) {
                    await storeManager.restorePurchases()
                }

                Link("Terms of Service", destination: URL(string: "https://gitmac.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://gitmac.app/privacy")!)
            }
        }
        .padding()
        .background(AppTheme.background)
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionView()
        }
    }
}
