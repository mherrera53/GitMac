import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var service = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, detail: String)] = [
        ("sparkles", "AI-Powered Commits", "Smart commit messages, branch names & PR descriptions"),
        ("arrow.triangle.branch", "Unlimited Repositories", "Open and manage as many repos as you need"),
        ("terminal", "Integrated Terminal", "Full Ghostty terminal inside your Git workflow"),
        ("waveform.path", "Repo Health Monitor", "Automatic GC, conflict prevention & analytics"),
        ("person.2", "Team Activity", "See what your teammates are working on in real time"),
        ("cloud", "Cloud Sync", "Keep settings and preferences synced across Macs"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    featureList
                    priceCard
                    actionButtons
                    footer
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
        .frame(width: 460, height: 620)
        .background(AppTheme.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#F59E0B"), Color(hex: "#EF4444")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, DesignTokens.Spacing.xl)

            Text("GitMac Pro")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("The professional Git client for macOS")
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.bottom, DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(DesignTokens.Typography.callout)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(feature.detail)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                        .font(.system(size: 16))
                }
                .padding(.vertical, DesignTokens.Spacing.sm)

                if feature.title != features.last?.title {
                    Divider().opacity(0.5)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(AppTheme.backgroundSecondary)
        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.lg))
    }

    // MARK: - Price Card

    private var priceCard: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            if let product = service.product {
                Text(product.displayPrice)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("per year · billed annually")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Less than \(monthlyEquivalent(for: product)) / month")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(AppTheme.accent)
            } else {
                Text("$17.00")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("per year · billed annually")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Less than $1.42 / month")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.lg)
        .background(AppTheme.accent.opacity(0.08))
        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if service.isPro {
                Label("You're already a Pro member!", systemImage: "checkmark.seal.fill")
                    .font(DesignTokens.Typography.callout)
                    .foregroundStyle(AppTheme.success)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(AppTheme.success.opacity(0.1))
                    .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))

                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Button {
                    Task { await service.purchase() }
                } label: {
                    ZStack {
                        if service.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Subscribe for $17 / year")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
                .disabled(service.isLoading)

                Button("Restore Purchase") {
                    Task { await service.restore() }
                }
                .buttonStyle(.plain)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)

                if let error = service.purchaseError {
                    Text(error)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppTheme.error)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            Text("Cancel anytime from System Settings → Apple ID → Subscriptions")
                .font(DesignTokens.Typography.caption2)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Link("Privacy Policy", destination: URL(string: "https://gitmac.app/privacy")!)
                Text("·")
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(DesignTokens.Typography.caption2)
            .foregroundStyle(AppTheme.textMuted)
        }
    }

    // MARK: - Helpers

    private func monthlyEquivalent(for product: Product) -> String {
        guard let price = product.price as Decimal? else { return "" }
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: monthly as NSDecimalNumber) ?? ""
    }
}

// MARK: - Upgrade Button (for inline use throughout the app)

struct ProUpgradeButton: View {
    @StateObject private var service = SubscriptionService.shared
    @State private var showPaywall = false
    let label: String

    init(_ label: String = "Upgrade to Pro") {
        self.label = label
    }

    var body: some View {
        if !service.isPro {
            Button {
                showPaywall = true
            } label: {
                Label(label, systemImage: "crown.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color(hex: "#F59E0B"))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Pro Feature Gate

struct ProFeatureGate<Content: View>: View {
    @StateObject private var service = SubscriptionService.shared
    @State private var showPaywall = false
    let content: () -> Content

    var body: some View {
        if service.isPro {
            content()
        } else {
            Button {
                showPaywall = true
            } label: {
                Label("Pro Feature", systemImage: "crown.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color(hex: "#F59E0B"))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}
