import StoreKit
import SwiftUI

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // Replace with your actual Product ID from App Store Connect
    static let productID = "com.gitmac.pro.annual"

    @Published private(set) var isPro: Bool = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await refreshStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Product

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            Logger.debug("[Subscription] Failed to load product: \(error)")
        }
    }

    // MARK: - Check Status

    func refreshStatus() async {
        var hasActiveEntitlement = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                hasActiveEntitlement = true
                break
            }
        }
        isPro = hasActiveEntitlement
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
            purchaseError = "Product not available. Check your internet connection."
            return
        }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isPro = true
                } else {
                    purchaseError = "Purchase verification failed."
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            Logger.debug("[Subscription] Purchase error: \(error)")
        }
    }

    // MARK: - Restore

    func restore() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshStatus()
            if !isPro {
                purchaseError = "No active subscription found."
            }
        } catch {
            purchaseError = error.localizedDescription
            Logger.debug("[Subscription] Restore error: \(error)")
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if transaction.productID == Self.productID,
                       transaction.revocationDate == nil {
                        isPro = true
                    }
                    await transaction.finish()
                }
            }
        }
    }
}
