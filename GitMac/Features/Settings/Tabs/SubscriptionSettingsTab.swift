import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @StateObject private var storeManager = StoreManager.shared
    @State private var showSubscriptionSheet = false

    var body: some View {
        Form {
            SettingsSection(title: "Current Plan") {
                if storeManager.isProUser {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(AppTheme.warning)
                        VStack(alignment: .leading) {
                            Text("GitMac Pro")
                                .foregroundStyle(AppTheme.textPrimary)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(storeManager.subscriptionStatus.description)
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.textSecondary)
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
                            .foregroundStyle(AppTheme.textSecondary)
                        VStack(alignment: .leading) {
                            Text("Free Plan")
                                .foregroundStyle(AppTheme.textPrimary)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Limited features")
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.textSecondary)
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
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(feature.rawValue)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(feature.description)
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if storeManager.isProUser {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }

            SettingsSection(title: "Pricing") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Annual")
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(storeManager.formattedAnnualPrice + "/year")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    HStack {
                        Text("Monthly")
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(storeManager.formattedMonthlyPrice + "/month")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Text("Subscriptions auto-renew unless cancelled 24 hours before the end of the current period.")
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
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
