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
                VStack(spacing: 24) {
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
        VStack(spacing: 8) {
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
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color.accentColor.opacity(0.1))
    }

    // MARK: - Pro Status

    private var proStatusCard: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundColor(.green)

            VStack(alignment: .leading) {
                Text("You're a Pro!")
                    .font(.headline)
                Text(storeManager.subscriptionStatus.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)

            ForEach(StoreManager.ProFeature.allCases, id: \.self) { feature in
                ProFeatureRow(feature: feature, isIncluded: true)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)

            HStack(spacing: 16) {
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
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading plans...")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .foregroundColor(.secondary)
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
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.rawValue)
                    .fontWeight(.medium)
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isIncluded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
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
        VStack(spacing: 12) {
            if isRecommended {
                Text("BEST VALUE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .cornerRadius(4)
            }

            Text(product.displayName)
                .font(.headline)

            Text(product.displayPrice)
                .font(.title)
                .fontWeight(.bold)

            Text(periodDescription)
                .font(.caption)
                .foregroundColor(.secondary)

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
        .background(isRecommended ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecommended ? Color.accentColor : Color.clear, lineWidth: 2)
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
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Pro Feature")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(feature.rawValue) requires GitMac Pro")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Maybe Later") {
                    dismiss()
                }

                Button("Upgrade to Pro") {
                    showSubscription = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
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
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(4)
    }
}

// #Preview {
//     SubscriptionView()
// }
