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
    @Published var tier: SubscriptionTier = .free
    @Published var customerInfo: CustomerInfo?
    @Published var currentOffering: Offering?
    @Published var donationOffering: Offering?
    @Published var isLoading: Bool = false
    @Published var purchaseError: PurchaseError?

    /// True once the user has voluntarily donated — drives the Supporter badge only.
    /// It never gates any feature.
    @Published var isSupporter: Bool = UserDefaults.standard.bool(forKey: SubscriptionManager.donorKey)

    static let donorKey = "supporter_donated"

    // Convenience checks — every feature in Flock Alert is free for everyone, so these
    // stay `true` and all former "Pro"/"Guardian" gates simply pass through.
    var isPro: Bool { true }
    var isGuardian: Bool { true }

    private init() {}

    // MARK: - Early Init (call from FlockAlertApp.init BEFORE any view appears)

    /// Configures the RevenueCat SDK synchronously so Purchases.shared is safe
    /// to use anywhere in the app, including on the first rendered frame.
    nonisolated static func earlyInit() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppConfiguration.revenueCatAPIKey)
    }

    // MARK: - Configure (call from RootView.onAppear — starts async work)

    func configure() {
        guard Purchases.isConfigured else { return }
        if let appleUserID = UserDefaults.standard.string(forKey: "appleUserID") {
            Task { await loginRevenueCat(appleUserID: appleUserID) }
        }
        Task { await observeCustomerInfo() }
        Task { await fetchOffering() }
        Task { await fetchDonationOffering() }
    }

    // MARK: - Link RevenueCat to Apple User ID

    func loginRevenueCat(appleUserID: String) async {
        do {
            let (_, _) = try await Purchases.shared.logIn(appleUserID)
            await fetchOffering()
        } catch {
            print("RevenueCat login error: \(error)")
        }
    }

    // MARK: - Real-time CustomerInfo Stream (SDK v5 AsyncStream)

    private func observeCustomerInfo() async {
        guard Purchases.isConfigured else { return }
        for await info in Purchases.shared.customerInfoStream {
            applyCustomerInfo(info)
        }
    }

    // MARK: - Manual Refresh (call after app foreground, login, etc.)

    func refreshStatus() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            // Non-fatal — cached value remains valid
        }
    }

    // MARK: - Fetch Offering

    func fetchOffering() async {
        guard Purchases.isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.offering(identifier: AppConfiguration.defaultOffering)
                           ?? offerings.current
        } catch {
            // Paywall will show empty/error state via productsLoaded = false
        }
    }

    // MARK: - Donations (voluntary support)

    /// Loads the monthly donation tiers from the "donations" offering.
    func fetchDonationOffering() async {
        guard Purchases.isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            donationOffering = offerings.offering(identifier: AppConfiguration.donationOffering)
        } catch {
            // Slider will show a graceful "not available yet" state.
        }
    }

    /// The donation tiers, sorted cheapest → most expensive.
    var donationPackages: [Package] {
        (donationOffering?.availablePackages ?? [])
            .sorted { $0.storeProduct.price < $1.storeProduct.price }
    }

    /// Make a voluntary donation. On success, grants the Supporter badge locally.
    @discardableResult
    func donate(package: Package) async throws -> Bool {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { throw PurchaseError.purchaseCancelled }
            applyCustomerInfo(result.customerInfo)
            UserDefaults.standard.set(true, forKey: SubscriptionManager.donorKey)
            isSupporter = true
            return true
        } catch let err as PurchaseError {
            purchaseError = err
            throw err
        } catch {
            let mapped = mapError(error)
            purchaseError = mapped
            throw mapped
        }
    }

    // MARK: - Purchase

    /// Purchase a RevenueCat `Package`. Throws `PurchaseError` on failure.
    /// Times out after 20 seconds so StoreKit hangs never spin forever.
    @discardableResult
    func purchase(package: Package) async throws -> CustomerInfo {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await withThrowingTaskGroup(of: PurchaseResultData.self) { group in
                group.addTask {
                    try await Purchases.shared.purchase(package: package)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20s timeout
                    throw PurchaseError.networkError(
                        NSError(domain: "FlockAlert", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Purchase timed out. Please try again."])
                    )
                }
                let first = try await group.next()!
                group.cancelAll()
                return first
            }
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
        let entitlements = info.entitlements
        if entitlements[AppConfiguration.guardianEntitlement]?.isActive == true {
            tier = .guardian
        } else if entitlements[AppConfiguration.supporterEntitlement]?.isActive == true {
            tier = .supporter
        } else {
            tier = .free
        }
        // Supporter badge: granted by any active donation entitlement (or a prior local grant).
        if entitlements[AppConfiguration.supporterBadgeEntitlement]?.isActive == true {
            isSupporter = true
            UserDefaults.standard.set(true, forKey: SubscriptionManager.donorKey)
        }
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
