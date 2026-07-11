import Foundation
import StoreKit
import UIKit

enum PromoReward {
    case guardianFree  // grants Guardian locally, no charge
    case offerCode     // opens Apple's code redemption sheet (50% off set up in App Store Connect)
}

enum PromoResult {
    case success(PromoReward)
    case alreadyRedeemed
    case invalid
}

@MainActor
final class PromoCodeManager {

    static let shared = PromoCodeManager()
    private init() {}

    private enum Keys {
        static let guardianGranted = "promo_guardian_granted"
        static let redeemedCodes   = "promo_redeemed_codes"
    }

    // ─── Codes ────────────────────────────────────────────────────────────────
    // guardianFree → grants Guardian locally, no charge (one-time per device)
    // offerCode    → opens Apple's offer code sheet; 50% discount configured in
    //               App Store Connect → Subscriptions → Guardian Monthly →
    //               Promotional Offers. Generate code batches there and give them
    //               to influencers to share with their audience.
    //
    // Influencer codes (named): track which creator drove downloads
    // CREATOR / PRESS: generic codes for unlisted creators / journalists
    // FLOCK50: audience-facing 50% off code (share alongside influencer content)
    private let validCodes: [String: PromoReward] = [
        // ── General access ──────────────────────────────────────────────────
        "WHATTHEFLOCK": .guardianFree,
        "BETAUSER":     .guardianFree,
        "EARLYBIRD":    .guardianFree,
        "FLOCK2025":    .guardianFree,
        "FOUNDING":     .guardianFree,
        // ── Named influencer codes ───────────────────────────────────────────
        "NBTV":         .guardianFree,
        "BRAXMAN":      .guardianFree,
        "THEHATEDONE":  .guardianFree,
        "NAOMI":        .guardianFree,
        // ── Generic influencer / press codes ────────────────────────────────
        "CREATOR":      .guardianFree,
        "PRESS":        .guardianFree,
        // ── Audience discount (opens Apple's 50% offer code sheet) ──────────
        "FLOCK50":      .offerCode,
    ]

    var isGuardianGranted: Bool {
        UserDefaults.standard.bool(forKey: Keys.guardianGranted)
    }

    func redeemCode(_ raw: String) -> PromoResult {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let reward = validCodes[code] else { return .invalid }

        let redeemed = UserDefaults.standard.stringArray(forKey: Keys.redeemedCodes) ?? []

        switch reward {
        case .guardianFree:
            if redeemed.contains(code) { return .alreadyRedeemed }
            UserDefaults.standard.set(redeemed + [code], forKey: Keys.redeemedCodes)
            UserDefaults.standard.set(true, forKey: Keys.guardianGranted)
        case .offerCode:
            // Apple's sheet enforces one-time use of the actual offer code — no local block
            break
        }

        return .success(reward)
    }

    func presentOfferCodeSheet() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        if #available(iOS 16.0, *) {
            Task { try? await AppStore.presentOfferCodeRedeemSheet(in: scene) }
        } else {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
    }
}
