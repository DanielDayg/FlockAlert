import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat
import WidgetKit

// MARK: - Notification Delegate

/// Shows notifications with sound + banner even when the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // The update-available nudge is redundant while the app is already open
        // (the in-app banner covers that), so let it land quietly in Notification
        // Center instead of interrupting the session. Camera alerts still show fully.
        if notification.request.identifier.hasPrefix("update-available") {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Tapping the update nudge takes the user straight to the App Store page.
        if response.notification.request.identifier.hasPrefix("update-available") {
            Task { @MainActor in UpdateChecker.shared.openAppStore() }
        }
        completionHandler()
    }
}

// MARK: - App

@main
struct FlockAlertApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // Configure RevenueCat before any view appears so Purchases.shared is always safe
        SubscriptionManager.earlyInit()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Camera.self, AlertEvent.self, CameraReport.self, UserProfile.self, CameraVerification.self])
        // First attempt — normal persistent store
        if let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]) {
            return container
        }
        // Schema migration failed (e.g. user upgrading from v1.0). Wipe the local store and
        // start fresh — camera data reloads from SeedCameras.json on next launch.
        let fm = FileManager.default
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
           let files = try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil) {
            files.filter { $0.pathExtension == "store" || $0.lastPathComponent.contains("default") }
                 .forEach { try? fm.removeItem(at: $0) }
        }
        if let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]) {
            return container
        }
        // Last resort: in-memory only (no persistence, but no crash)
        return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(AuthManager.shared)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")
    @StateObject private var updateChecker = UpdateChecker.shared
    @StateObject private var donationPrompt = DonationPromptManager.shared

    var body: some View {
        ZStack {
            ContentView()

            if updateChecker.updateAvailable && !updateChecker.dismissedThisSession && !showOnboarding {
                UpdateBanner(
                    onUpdate: { updateChecker.openAppStore() },
                    onDismiss: {
                        withAnimation { updateChecker.dismissedThisSession = true }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }

            if showOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showOnboarding = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        // Auto-surface the donation screen after a couple of minutes, every
        // other session — so users don't have to dig through Settings to find it.
        .sheet(isPresented: $donationPrompt.shouldShow) {
            DonationView()
                .environmentObject(SubscriptionManager.shared)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Don't interrupt first-run onboarding.
                if !showOnboarding { donationPrompt.appBecameActive() }
            case .inactive, .background:
                donationPrompt.appResignedActive()
            @unknown default:
                break
            }
        }
        .task {
            await updateChecker.check()
        }
        .onAppear {
            AuthManager.shared.configure(context: modelContext)
            SubscriptionManager.shared.configure()
            appState.onAlertFired = { [modelContext] event in
                modelContext.insert(event)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                // Update shared widget data
                let defaults = UserDefaults(suiteName: "group.com.flockalert.app")
                let stored = defaults?.integer(forKey: "weeklyCameraCount") ?? 0
                defaults?.set(stored + 1, forKey: "weeklyCameraCount")
            }
            WeeklyReportManager.configure()
            // Kick off the donation-prompt timer on cold launch (scenePhase's
            // initial .active doesn't always trigger onChange).
            if !showOnboarding { donationPrompt.appBecameActive() }
        }
        .task {
            await requestNotificationPermission()
        }
        .task {
            // Reset weekly count every Monday
            let defaults = UserDefaults(suiteName: "group.com.flockalert.app")
            let lastReset = defaults?.double(forKey: "weeklyResetDate") ?? 0
            let weekAgo = Date().timeIntervalSince1970 - 7 * 24 * 3600
            if lastReset < weekAgo {
                defaults?.set(0, forKey: "weeklyCameraCount")
                defaults?.set(Date().timeIntervalSince1970, forKey: "weeklyResetDate")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        // Note: .criticalAlert requires the special com.apple.developer.usernotifications.critical-alerts
        // entitlement (manual Apple approval). We rely on the time-sensitive entitlement instead, so
        // requesting it here would be ignored by the system and can flag an App Store review issue.
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        // Categories must match the identifiers AlertDispatcher sets on each notification
        // ("CAMERA_APPROACH" / "CAMERA_IN_VIEW"). Registering a mismatched "CAMERA_ALERT"
        // meant the "View on Map" action button never appeared on real alerts.
        let viewAction = UNNotificationAction(identifier: "VIEW", title: "View on Map", options: .foreground)
        let approachCategory = UNNotificationCategory(
            identifier: "CAMERA_APPROACH",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        let inViewCategory = UNNotificationCategory(
            identifier: "CAMERA_IN_VIEW",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([approachCategory, inViewCategory])
    }
}

// MARK: - Update Banner

/// Top banner nudging existing users to update to the latest App Store version.
struct UpdateBanner: View {
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.flockPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Available")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.flockText)
                    Text("A new version of Flock Alert is here — it's now free.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.flockTextSub)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Button(action: onUpdate) {
                    Text("Update")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.flockBG)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.flockPrimary)
                        .clipShape(Capsule())
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.flockTextSub)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.flockSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.flockPrimary.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .padding(.horizontal, 14)
            .padding(.top, 8)

            Spacer()
        }
    }
}
