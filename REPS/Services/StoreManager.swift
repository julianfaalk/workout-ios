import StoreKit
import SwiftUI

typealias WorkoutTransaction = StoreKit.Transaction

enum PremiumTier: String, CaseIterable, Identifiable {
    case yearly
    case monthly
    case lifetime

    var id: String { rawValue }
}

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var isPremium = false
    @Published var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var errorMessage: String?
    @Published var showSuccess = false

    private let api = WorkoutAPIService.shared
    private let productIDs = AppConfig.premiumProductIDs
    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = startTransactionListener()
        Task {
            await loadProducts()
            await checkEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Set(productIDs))
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            errorMessage = nil
        }
    }

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await processTransaction(transaction)
                await transaction.finish()
                showSuccess = true
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = LocalizationService.shared.localized("paywall.error.purchase")
        }

        purchaseInProgress = false
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    func checkEntitlements() async {
        var hasActiveEntitlement = false

        for await result in WorkoutTransaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.revocationDate == nil {
                hasActiveEntitlement = true
                await syncToServer(transaction)
            }
        }

        isPremium = hasActiveEntitlement

        if !hasActiveEntitlement {
            await checkServerStatus()
        }
    }

    private func startTransactionListener() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in WorkoutTransaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = result {
                    await self.processTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    private func processTransaction(_ transaction: WorkoutTransaction) async {
        isPremium = transaction.revocationDate == nil
        await syncToServer(transaction)
    }

    private func syncToServer(_ transaction: WorkoutTransaction) async {
        try? await api.syncSubscription(
            originalTransactionId: "\(transaction.originalID)",
            productId: transaction.productID,
            expiresDate: transaction.expirationDate
        )
    }

    private func checkServerStatus() async {
        if let status = try? await api.fetchSubscriptionStatus() {
            isPremium = status.isActive
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.unverified
        }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == AppConfig.premiumMonthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == AppConfig.premiumYearlyProductID }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == AppConfig.premiumLifetimeProductID }
    }

    var recommendedProduct: Product? {
        yearlyProduct ?? monthlyProduct ?? lifetimeProduct
    }

    func product(for tier: PremiumTier) -> Product? {
        switch tier {
        case .yearly:
            return yearlyProduct
        case .monthly:
            return monthlyProduct
        case .lifetime:
            return lifetimeProduct
        }
    }

    var yearlySavingsPercent: Int {
        guard let monthlyProduct, let yearlyProduct else { return 0 }
        let monthlyAnnualPrice = monthlyProduct.price * 12
        let savings = (monthlyAnnualPrice - yearlyProduct.price) / monthlyAnnualPrice * 100
        return max(0, Int(NSDecimalNumber(decimal: savings).doubleValue.rounded()))
    }

    func formattedMonthlyEquivalent(for yearlyProduct: Product) -> String {
        let monthlyEquivalent = yearlyProduct.price / 12
        return monthlyEquivalent.formatted(yearlyProduct.priceFormatStyle)
    }

    func consumeSuccess() {
        showSuccess = false
    }
}

enum StoreError: Error {
    case unverified
}
