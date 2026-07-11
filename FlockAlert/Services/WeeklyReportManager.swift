import BackgroundTasks
import UserNotifications
import SwiftData
import Foundation

/// Fires a "surveillance footprint" push every Sunday morning.
/// The state never forgets. We make sure you don't either.
final class WeeklyReportManager {

    static let bgTaskID = "com.flockalert.app.weeklyreport"

    // MARK: - Setup (call once at app launch)

    static func configure() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskID, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false); return
            }
            Self.handleReport(task: processingTask)
        }
        scheduleNext()
    }

    // MARK: - Schedule

    static func scheduleNext() {
        let request = BGProcessingTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = nextSundayAt9AM()
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func nextSundayAt9AM() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let now = Date()
        // Find next Sunday (weekday == 1)
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: now)
        let todayWeekday = components.weekday ?? 1
        let daysUntilSunday = todayWeekday == 1 ? 7 : (8 - todayWeekday)
        guard let nextSunday = cal.date(byAdding: .day, value: daysUntilSunday, to: now) else { return now }
        var fireComponents = cal.dateComponents([.year, .month, .day], from: nextSunday)
        fireComponents.hour = 9; fireComponents.minute = 0; fireComponents.second = 0
        return cal.date(from: fireComponents) ?? nextSunday
    }

    // MARK: - Background Task Handler

    private static func handleReport(task: BGProcessingTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        let schema = Schema([AlertEvent.self, Camera.self, CameraReport.self,
                             UserProfile.self, CameraVerification.self])
        guard let container = try? ModelContainer(for: schema,
              configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)) else {
            task.setTaskCompleted(success: false); return
        }

        let context = ModelContext(container)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<AlertEvent>(
            predicate: #Predicate { $0.timestamp > weekAgo }
        )
        let events = (try? context.fetch(descriptor)) ?? []

        scheduleNext()
        sendReport(events: events)
        task.setTaskCompleted(success: true)
    }

    // MARK: - Send Notification

    /// Call with the current week's events to fire the report notification immediately.
    static func sendReport(events: [AlertEvent]) {
        let count = events.count
        let cities = Set(events.compactMap { $0.cameraCity }).count

        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound(named: UNNotificationSoundName("tweet.caf"))
        content.interruptionLevel = .timeSensitive

        if count == 0 {
            content.title = "⚡ WEEKLY SURVEILLANCE REPORT"
            content.body  = "No cameras logged this week. Stay sharp — the grid never sleeps."
        } else if count < 5 {
            content.title = "🔴 SURVEILLANCE FOOTPRINT — WEEK \(currentWeekNumber())"
            content.body  = "You passed \(count) Flock cameras in \(cities) \(cities == 1 ? "city" : "cities"). They logged your plate. Every. Single. Time."
        } else if count < 15 {
            content.title = "🚨 \(count) EYES TRACKED YOU THIS WEEK"
            content.body  = "Across \(cities) \(cities == 1 ? "city" : "cities"), \(count) Flock ALPRs scanned your plate. This is the surveillance state in action."
        } else {
            content.title = "🛑 THEY'RE BUILDING A MAP OF YOUR LIFE"
            content.body  = "\(count) Flock cameras in \(cities) cities logged your movements this week. Your route is their data."
        }

        let req = UNNotificationRequest(
            identifier: "weekly-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(req)
    }

    private static func currentWeekNumber() -> Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }
}
