// MARK: - App Configuration
// RevenueCat public key is safe to commit — it is read-only.

enum AppConfiguration {

    // MARK: RevenueCat
    /// Public iOS SDK key — copy from RevenueCat → Project Settings → API Keys
    static let revenueCatAPIKey = "appl_OtHSvzchMSRGvDeYmwDnAaEUtdv"

    /// Must match the Entitlement identifier you created in the RevenueCat dashboard exactly.
    static let proEntitlement = "FlockAlert Pro"

    // MARK: Product IDs
    /// Must match the product identifiers in App Store Connect AND RevenueCat Products.
    static let proMonthlyID      = "com.flockalert.app.pro.monthly"
    static let proYearlyID       = "com.flockalert.app.pro.yearly"
    static let proLifetimeID     = "com.flockalert.app.pro.lifetime"

    // Pay-what-you-want monthly tiers — all grant the same pro entitlement
    static let proMonthlyTier1ID = "com.flockalert.app.pro.monthly.199"  // $1.99
    static let proMonthlyTier2ID = "com.flockalert.app.pro.monthly.499"  // $4.99 (default)
    static let proMonthlyTier3ID = "com.flockalert.app.pro.monthly.999"  // $9.99

    // MARK: RevenueCat Offering
    /// The offering identifier configured in the RevenueCat dashboard.
    static let defaultOffering = "default"
}
