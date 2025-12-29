import SwiftUI
import StoreKit

// MARK: - Subscription View

struct SubscriptionView: View {
    @StateObject private var storeManager = StoreManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Status
                    if storeManager.isProUser {
                        proStatusCard
                    }

                    // Features
                    featuresSection

                    // Pricing
                    if !storeManager.isProUser {
                        pricingSection
                    }

                    // Restore
                    restoreButton
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("GitMac Pro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Unlock the full power of GitMac")
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppTheme.accent.opacity(0.1))
    }

    // MARK: - Pro Status

    private var proStatusCard: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundColor(AppTheme.success)

            VStack(alignment: .leading) {
                Text("You're a Pro!")
                    .font(.headline)
                Text(storeManager.subscriptionStatus.description)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.success.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.xl)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("What's Included")
                .font(.headline)

            ForEach(StoreManager.ProFeature.allCases, id: \.self) { feature in
                ProFeatureRow(feature: feature, isIncluded: true)
            }
        }
        .padding()
        .background(AppTheme.textSecondary.opacity(0.05))
        .cornerRadius(DesignTokens.CornerRadius.xl)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Choose Your Plan")
                .font(.headline)

            HStack(spacing: DesignTokens.Spacing.lg) {
                // Annual Plan
                if let annual = storeManager.annualProduct {
                    PlanCard(
                        product: annual,
                        isRecommended: true,
                        isPurchasing: $isPurchasing,
                        onPurchase: { await purchase(annual) }
                    )
                }

                // Monthly Plan
                if let monthly = storeManager.monthlyProduct {
                    PlanCard(
                        product: monthly,
                        isRecommended: false,
                        isPurchasing: $isPurchasing,
                        onPurchase: { await purchase(monthly) }
                    )
                }
            }

            if storeManager.products.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ProgressView()
                    Text("Loading plans...")
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding()
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                await storeManager.restorePurchases()
            }
        }
        .font(.caption)
        .foregroundColor(AppTheme.textPrimary)
    }

    // MARK: - Purchase

    private func purchase(_ product: Product) async {
        isPurchasing = true
        do {
            if let _ = try await storeManager.purchase(product) {
                // Purchase successful
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isPurchasing = false
    }
}

// MARK: - Pro Feature Row

struct ProFeatureRow: View {
    let feature: StoreManager.ProFeature
    let isIncluded: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(AppTheme.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(feature.rawValue)
                    .fontWeight(.medium)
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            if isIncluded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.success)
            }
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let product: Product
    let isRecommended: Bool
    @Binding var isPurchasing: Bool
    let onPurchase: () async -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            if isRecommended {
                Text("BEST VALUE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(AppTheme.warning)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }

            Text(product.displayName)
                .font(.headline)

            Text(product.displayPrice)
                .font(.title)
                .fontWeight(.bold)

            Text(periodDescription)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)

            Button {
                Task { await onPurchase() }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Subscribe")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(isRecommended ? AppTheme.accent.opacity(0.1) : AppTheme.textSecondary.opacity(0.05))
        .cornerRadius(DesignTokens.CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl)
                .stroke(isRecommended ? AppTheme.accent : Color.clear, lineWidth: 2)
        )
    }

    private var periodDescription: String {
        if product.id.contains("annual") {
            return "per year"
        } else {
            return "per month"
        }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    let feature: StoreManager.ProFeature
    @State private var showSubscription = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "lock.fill")
                .font(DesignTokens.Typography.iconXXXXL)
                .foregroundColor(AppTheme.textPrimary)

            Text("Pro Feature")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(feature.rawValue) requires GitMac Pro")
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: DesignTokens.Spacing.lg) {
                Button("Maybe Later") {
                    dismiss()
                }

                Button("Upgrade to Pro") {
                    showSubscription = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignTokens.Spacing.xxl)
        .frame(width: 350)
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}

// MARK: - Pro Badge

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

// #Preview {
//     SubscriptionView()
// }
