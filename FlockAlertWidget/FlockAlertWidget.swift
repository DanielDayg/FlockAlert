import WidgetKit
import SwiftUI

// MARK: - Shared Data

struct WidgetData {
    static func load() -> (nearbyCount: Int, weeklyCount: Int) {
        let defaults = UserDefaults(suiteName: "group.com.flockalert.app")
        let nearby  = defaults?.integer(forKey: "nearbyCameraCount") ?? 0
        let weekly  = defaults?.integer(forKey: "weeklyCameraCount") ?? 0
        return (nearby, weekly)
    }
}

// MARK: - Timeline Entry

struct FlockEntry: TimelineEntry {
    let date: Date
    let nearbyCount: Int
    let weeklyCount: Int
}

// MARK: - Timeline Provider

struct FlockProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlockEntry {
        FlockEntry(date: Date(), nearbyCount: 3, weeklyCount: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlockEntry) -> Void) {
        let data = WidgetData.load()
        completion(FlockEntry(date: Date(), nearbyCount: data.nearbyCount, weeklyCount: data.weeklyCount))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlockEntry>) -> Void) {
        let data = WidgetData.load()
        let entry = FlockEntry(date: Date(), nearbyCount: data.nearbyCount, weeklyCount: data.weeklyCount)
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: FlockEntry

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 4) {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(entry.nearbyCount > 0 ? Color.red : Color(white: 0.4))

                Text("\(entry.nearbyCount)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(entry.nearbyCount > 0 ? Color.red : Color.white)

                Text("EYES NEARBY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(white: 0.5))
                    .tracking(2)
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: FlockEntry

    var body: some View {
        ZStack {
            Color.black
            HStack(spacing: 0) {
                // Left — nearby
                VStack(spacing: 4) {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(entry.nearbyCount > 0 ? Color.red : Color(white: 0.4))
                    Text("\(entry.nearbyCount)")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundStyle(entry.nearbyCount > 0 ? Color.red : Color.white)
                    Text("EYES NEARBY")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(white: 0.45))
                        .tracking(1.5)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(width: 1)

                // Right — weekly
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color.orange)
                    Text("\(entry.weeklyCount)")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.orange)
                    Text("THIS WEEK")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(white: 0.45))
                        .tracking(1.5)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
        }
    }
}

// MARK: - Widget Configuration

struct FlockAlertWidget: Widget {
    let kind: String = "FlockAlertWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlockProvider()) { entry in
            if #available(iOS 17.0, *) {
                SmallWidgetView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                SmallWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Surveillance Watch")
        .description("Track how many Flock cameras are watching you right now.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FlockAlertWidgetMedium: Widget {
    let kind: String = "FlockAlertWidgetMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlockProvider()) { entry in
            if #available(iOS 17.0, *) {
                MediumWidgetView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                MediumWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Weekly Footprint")
        .description("Your surveillance footprint — nearby cameras and your weekly count.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct FlockWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlockAlertWidget()
        FlockAlertWidgetMedium()
    }
}
