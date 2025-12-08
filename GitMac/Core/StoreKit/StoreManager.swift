import Foundation
import StoreKit

// MARK: - Store Manager

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isProUser = false
    @Published var subscriptionStatus: SubscriptionStatus = .unknown

    // Product IDs - Update with your actual IDs from App Store Connect
    private let annualProductID = "com.gitmac.app.pro.annual"
    private let monthlyProductID = "com.gitmac.app.pro.monthly"

    private var productIDs: [String] {
        [annualProductID, monthlyProductID]
    }

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        var foundActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    purchasedProductIDs.insert(transaction.productID)
                    foundActiveSubscription = true

                    if let expirationDate = transaction.expirationDate {
                        subscriptionStatus = .active(expiresAt: expirationDate)
                    }
                }
            }
        }

        isProUser = foundActiveSubscription

        if !foundActiveSubscription {
            purchasedProductIDs.removeAll()
            subscriptionStatus = .inactive
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                do {
                    let transaction = try await self.handleTransactionResult(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    private func handleTransactionResult(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Computed Properties

    var annualProduct: Product? {
        products.first { $0.id == annualProductID }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == monthlyProductID }
    }

    var formattedAnnualPrice: String {
        annualProduct?.displayPrice ?? "$2.99"
    }

    var formattedMonthlyPrice: String {
        monthlyProduct?.displayPrice ?? "$0.99"
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus {
    case unknown
    case inactive
    case active(expiresAt: Date)

    var isActive: Bool {
        switch self {
        case .active:
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .inactive:
            return "Inactive"
        case .active(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Active until \(formatter.string(from: date))"
        }
    }
}

// MARK: - Store Errors

enum StoreError: Error, LocalizedError {
    case failedVerification
    case purchaseFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase could not be completed"
        case .productNotFound:
            return "Product not found"
        }
    }
}

// MARK: - Pro Features

extension StoreManager {
    /// Check if a feature requires Pro subscription
    func requiresPro(feature: ProFeature) -> Bool {
        !isProUser
    }

    /// Available features for Pro users
    enum ProFeature: String, CaseIterable {
        case unlimitedIntegrations = "Unlimited Integrations"
        case aiCommitMessages = "AI Commit Messages"
        case customThemes = "Custom Themes"
        case prioritySupport = "Priority Support"
        case advancedDiff = "Advanced Diff View"
        case multipleRemotes = "Multiple Remotes"

        var description: String {
            switch self {
            case .unlimitedIntegrations:
                return "Connect GitHub, Taiga, Planner, and more"
            case .aiCommitMessages:
                return "Generate commit messages with AI"
            case .customThemes:
                return "Personalize your GitMac experience"
            case .prioritySupport:
                return "Get help faster when you need it"
            case .advancedDiff:
                return "Enhanced diff visualization"
            case .multipleRemotes:
                return "Manage multiple remote repositories"
            }
        }

        var icon: String {
            switch self {
            case .unlimitedIntegrations: return "square.grid.2x2"
            case .aiCommitMessages: return "brain"
            case .customThemes: return "paintpalette"
            case .prioritySupport: return "star.fill"
            case .advancedDiff: return "doc.text.magnifyingglass"
            case .multipleRemotes: return "network"
            }
        }
    }
}
