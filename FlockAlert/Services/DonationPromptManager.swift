import SwiftUI
import Foundation

/// Surfaces the "Support Flock Alert" donation screen on its own, so users don't
/// have to dig through Settings to find it. Rules that keep it helpful, not naggy:
///   - only fires after ~2 minutes of foreground use in a session
///   - only on roughly every other app launch (never every time)
///   - at most once per session
///   - never once the user has already donated (they have the Supporter badge)
@MainActor
final class DonationPromptManager: ObservableObject {

    static let shared = DonationPromptManager()
    private init() {}

    /// Drives the auto-presented donation sheet in RootView.
    @Published var shouldShow = false

    private enum Keys {
        static let sessionCount = "dp_sessionCount"
    }

    /// Foreground time before the prompt appears.
    private let delay: TimeInterval = 120          // 2 minutes
    /// Fire on every Nth launch (2 = every other time the app is opened).
    private let everyNLaunches = 2

    private var pending: Task<Void, Never>?
    private var countedThisLaunch = false
    private var qualifiesThisLaunch = false
    private var shownThisSession = false

    /// Call whenever the app becomes active (foreground). Safe to call repeatedly —
    /// the launch is counted only once, and the 2-minute timer measures foreground time.
    func appBecameActive() {
        guard !shownThisSession else { return }
        // Already a supporter → never prompt.
        guard !SubscriptionManager.shared.isSupporter else { return }

        // Count the launch once, and decide if this launch qualifies.
        if !countedThisLaunch {
            countedThisLaunch = true
            let count = UserDefaults.standard.integer(forKey: Keys.sessionCount) + 1
            UserDefaults.standard.set(count, forKey: Keys.sessionCount)
            qualifiesThisLaunch = (count % everyNLaunches == 0)
        }
        guard qualifiesThisLaunch else { return }

        // (Re)start the timer so the delay reflects continuous foreground time.
        pending?.cancel()
        pending = Task { [weak self] in
            let seconds = self?.delay ?? 120
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            guard !SubscriptionManager.shared.isSupporter, !self.shownThisSession else { return }
            self.shownThisSession = true
            self.shouldShow = true
        }
    }

    /// Call when the app leaves the foreground — cancels a pending prompt so it
    /// doesn't pop the instant the user returns.
    func appResignedActive() {
        pending?.cancel()
        pending = nil
    }
}
