import RevenueCat
import Foundation
import SwiftUI

// MARK: - Purchase Error

enum PurchaseError: LocalizedError {
    case purchaseCancelled
    case productNotFound
    case networkError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .purchaseCancelled:    return "Purchase was cancelled."
        case .productNotFound:      return "Product not found. Please try again later."
        case .networkError(let e):  return "Network error: \(e.localizedDescription)"
        case .unknown(let e):       return e.localizedDescription
        }
    }
}

// MARK: - SubscriptionManager

/// Central subscription state — singleton, @MainActor.
/// Keeps `isPro` in real-time sync via the SDK's `customerInfoStream`.
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: Singleton
    static let shared = SubscriptionManager()

    // MARK: Published State
    @Published var isPro: Bool = false
    @Published var customerInfo: CustomerInfo?
    @Published var currentOffering: Offering?
    @Published var isLoading: Bool = false
    @Published var purchaseError: PurchaseError?

    private init() {}

    // MARK: - Configure (call once at app launch)

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppConfiguration.revenueCatAPIKey)
        // Real-time stream — replaces PurchasesDelegate
        Task { await observeCustomerInfo() }
        Task { await fetchOffering() }
    }

    // MARK: - Real-time CustomerInfo Stream (SDK v5 AsyncStream)

    private func observeCustomerInfo() async {
        for await info in Purchases.shared.customerInfoStream {
            applyCustomerInfo(info)
        }
    }

    // MARK: - Manual Refresh (call after app foreground, login, etc.)

    func refreshStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            // Non-fatal — cached value remains valid
        }
    }

    // MARK: - Fetch Offering

    func fetchOffering() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            // Prefer named default offering; fall back to current
            currentOffering = offerings.offering(identifier: AppConfiguration.defaultOffering)
                           ?? offerings.current
        } catch {
            // Paywall will show an empty / error state automatically
        }
    }

    // MARK: - Purchase

    /// Purchase a RevenueCat `Package`. Throws `PurchaseError` on failure.
    @discardableResult
    func purchase(package: Package) async throws -> CustomerInfo {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { throw PurchaseError.purchaseCancelled }
            applyCustomerInfo(result.customerInfo)
            return result.customerInfo
        } catch let err as PurchaseError {
            purchaseError = err
            throw err
        } catch {
            let mapped = mapError(error)
            purchaseError = mapped
            throw mapped
        }
    }

    // MARK: - Restore

    /// Restore previous purchases. Returns `true` if Pro is now active.
    @discardableResult
    func restorePurchases() async throws -> Bool {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            return isPro
        } catch {
            let mapped = mapError(error)
            purchaseError = mapped
            throw mapped
        }
    }

    // MARK: - Helpers

    private func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        isPro = info.entitlements[AppConfiguration.proEntitlement]?.isActive == true
    }

    private func mapError(_ error: Error) -> PurchaseError {
        if let rc = error as? RevenueCat.ErrorCode {
            switch rc {
            case .purchaseCancelledError:
                return .purchaseCancelled
            case .productNotAvailableForPurchaseError,
                 .productAlreadyPurchasedError:
                return .productNotFound
            case .networkError:
                return .networkError(error)
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }
}
