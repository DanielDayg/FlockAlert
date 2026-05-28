import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat

@main
struct FlockAlertApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Camera.self, AlertEvent.self, CameraReport.self, UserProfile.self, CameraVerification.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")

    var body: some View {
        ZStack {
            ContentView()
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
        .onAppear {
            AuthManager.shared.configure(context: modelContext)
            SubscriptionManager.shared.configure()
        }
        .task {
            await requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])

        let cameraAlertCategory = UNNotificationCategory(
            identifier: "CAMERA_ALERT",
            actions: [
                UNNotificationAction(identifier: "VIEW", title: "View on Map", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([cameraAlertCategory])
    }
}
