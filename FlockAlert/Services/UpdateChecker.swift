import Foundation
import UIKit
import UserNotifications

/// Checks the App Store for a newer version and nudges existing users to update.
/// Uses Apple's public iTunes lookup endpoint — no backend required.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable = false
    @Published var latestVersion: String?
    /// Dismissed for this launch only — reappears next launch until the user updates.
    @Published var dismissedThisSession = false

    private init() {}

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private let appStoreID = "6774017307"
    private let notifiedVersionKey = "lastUpdateNotifiedVersion"

    func check() async {
        // Cache-bust so we don't read a stale App Store response.
        let bust = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=com.flockalert.app&t=\(bust)") else { return }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let storeVersion = results.first?["version"] as? String else { return }
            latestVersion = storeVersion
            if isNewer(storeVersion, than: currentVersion) {
                updateAvailable = true
                await postUpdateNotificationIfNeeded(for: storeVersion)
            }
        } catch {
            // Silent — a failed check just means no nudge this launch.
        }
    }

    /// Posts a single local notification per new App Store version, so users who
    /// don't open the app often still get nudged from Notification Center. Local
    /// only — no push backend or APNs required. Complements the in-app banner.
    private func postUpdateNotificationIfNeeded(for version: String) async {
        let defaults = UserDefaults.standard
        // One notification per version — never nag on repeat launches.
        guard defaults.string(forKey: notifiedVersionKey) != version else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Flock Alert update available"
        content.body = "A new version is ready with fresh features. Tap to update."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "update-available-\(version)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
        do {
            try await center.add(request)
            defaults.set(version, forKey: notifiedVersionKey)
        } catch {
            // Silent — the in-app banner still covers the nudge.
        }
    }

    private func isNewer(_ a: String, than b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }

    func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)") {
            UIApplication.shared.open(url)
        }
    }
}
