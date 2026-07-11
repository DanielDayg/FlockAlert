// MARK: - App Configuration
// RevenueCat public key is safe to commit — it is read-only.

enum AppConfiguration {

    // MARK: RevenueCat
    static let revenueCatAPIKey = "appl_OtHSvzchMSRGvDeYmwDnAaEUtdv"

    // MARK: Entitlements (must match RevenueCat dashboard exactly)
    static let supporterEntitlement = "flockalert_supporter"  // $3.99 — alerts + notifications
    static let guardianEntitlement  = "flockalert_guardian"   // $5.99 — everything + photos + leaderboard

    // MARK: Product IDs (must match App Store Connect AND RevenueCat)
    static let supporterMonthlyID = "com.flockalert.app.supporter.monthly"  // $3.99
    static let guardianMonthlyID  = "com.flockalert.app.guardian.monthly"   // $5.99

    // MARK: RevenueCat Offering
    static let defaultOffering = "default"

    // MARK: Donations (voluntary support — app is 100% free)
    // RevenueCat offering that holds the monthly donation tiers ($1/$3/$5/$10/…).
    static let donationOffering = "donations"
    // Entitlement granted by ANY donation product — drives the Supporter badge only.
    static let supporterBadgeEntitlement = "supporter"

    // External "donate on the web" fallback (Ko-fi / Open Collective / Buy Me a Coffee).
    // Guaranteed to work with zero Apple review and 0% platform cut. Leave empty to hide
    // the web-donation option; set the URL once the page exists to switch it on instantly.
    static let webDonationURL = "https://buymeacoffee.com/kyrad"
}

// MARK: - Subscription Tier

enum SubscriptionTier: Int, Comparable {
    case free      = 0
    case supporter = 1   // $3.99 — alerts, notifications, in-view detection
    case guardian  = 2   // $5.99 — everything + photos, leaderboard, priority

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .free:      return "Free"
        case .supporter: return "Supporter"
        case .guardian:  return "Guardian"
        }
    }

    var badge: String {
        switch self {
        case .free:      return ""
        case .supporter: return "🟦"
        case .guardian:  return "🔷"
        }
    }

    // Feature gates
    var hasAlerts: Bool          { self >= .supporter }
    var hasCommunityPhotos: Bool { self >= .guardian  }
    var hasLeaderboard: Bool     { self >= .guardian  }
    var hasPrioritySubmit: Bool  { self >= .guardian  }
}
