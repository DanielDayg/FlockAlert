import StoreKit
import UIKit
import Foundation

/// Tracks proximity-alert triggers and shows the App Store review prompt
/// after the user has had 3 real camera alerts — a natural "aha moment."
///
/// After the prompt is shown, `isReviewGranted` returns true, which
/// SubscriptionManager uses to grant free Supporter-level access.
@MainActor
final class ReviewPromptManager {

    static let shared = ReviewPromptManager()
    private init() {}

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let alertsFired   = "rp_alertsFired"
        static let hasPrompted   = "rp_hasPrompted"
        static let reviewGranted = "rp_granted"
    }

    /// Number of alerts before the prompt fires.
    private let promptThreshold = 3

    // MARK: - Public API

    /// True after the review prompt has been shown (regardless of whether
    /// the user actually left a review — Apple doesn't tell us).
    var isReviewGranted: Bool {
        UserDefaults.standard.bool(forKey: Keys.reviewGranted)
    }

    /// Call each time a proximity alert fires.
    /// Automatically shows the review prompt once the threshold is reached.
    func recordAlertFired() {
        guard !UserDefaults.standard.bool(forKey: Keys.hasPrompted) else { return }

        let count = UserDefaults.standard.integer(forKey: Keys.alertsFired) + 1
        UserDefaults.standard.set(count, forKey: Keys.alertsFired)

        if count >= promptThreshold {
            showReviewPrompt()
        }
    }

    /// Called from the paywall — grants free access immediately then shows the review prompt.
    func requestReviewFromPaywall() {
        UserDefaults.standard.set(true, forKey: Keys.hasPrompted)
        UserDefaults.standard.set(true, forKey: Keys.reviewGranted)
        showReviewPromptUI()
    }

    // MARK: - Private

    private func showReviewPrompt() {
        UserDefaults.standard.set(true, forKey: Keys.hasPrompted)
        UserDefaults.standard.set(true, forKey: Keys.reviewGranted)
        showReviewPromptUI()
    }

    private func showReviewPromptUI() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        SKStoreReviewController.requestReview(in: scene)
    }
}
