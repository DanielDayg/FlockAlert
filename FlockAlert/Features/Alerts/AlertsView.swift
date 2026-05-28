import SwiftUI
import SwiftData

struct AlertsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlertEvent.timestamp, order: .reverse) private var events: [AlertEvent]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                if events.isEmpty {
                    EmptyAlertsView()
                } else {
                    List {
                        // Summary strip
                        Section {
                            SummaryStrip(events: events)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }

                        // Alert history
                        ForEach(groupedByDate, id: \.0) { date, group in
                            Section(header:
                                Text(date)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.flockTextSub)
                                    .tracking(1.5)
                            ) {
                                ForEach(group) { event in
                                    AlertRow(event: event)
                                        .listRowBackground(Color.flockSurface)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Alert History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AlertSettingsView()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(Color.flockPrimary)
                    }
                }
                if !events.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear All") {
                            events.forEach { modelContext.delete($0) }
                            try? modelContext.save()
                            appState.unreadAlertCount = 0
                        }
                        .foregroundStyle(Color.flockAlert)
                        .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .onAppear {
                markAllRead()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var groupedByDate: [(String, [AlertEvent])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let grouped = Dictionary(grouping: events) { event in
            formatter.string(from: event.timestamp)
        }
        return grouped.sorted { a, b in
            (events.first { formatter.string(from: $0.timestamp) == a.key }?.timestamp ?? .distantPast) >
            (events.first { formatter.string(from: $0.timestamp) == b.key }?.timestamp ?? .distantPast)
        }
    }

    private func markAllRead() {
        events.filter { !$0.wasRead }.forEach { $0.wasRead = true }
        try? modelContext.save()
        appState.unreadAlertCount = 0
    }
}

// MARK: - Summary Strip

struct SummaryStrip: View {
    let events: [AlertEvent]

    private var todayCount: Int {
        events.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }
    private var weekCount: Int {
        events.filter { Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.contains($0.timestamp) ?? false }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            StatPill(label: "TODAY", value: "\(todayCount)")
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            StatPill(label: "THIS WEEK", value: "\(weekCount)")
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            StatPill(label: "TOTAL", value: "\(events.count)")
        }
        .background(Color.flockSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct StatPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.flockPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.flockTextSub)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Alert Row

struct AlertRow: View {
    let event: AlertEvent

    private var alertColor: Color {
        switch event.alertType {
        case .approaching: return .flockCaution
        case .entering:    return .flockAlert
        case .highDensity: return .flockAlert
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(alertColor)
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.cameraOwnerLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.flockText)
                HStack(spacing: 6) {
                    if let city = event.cameraCity {
                        Text(city)
                            .font(.flockCaption)
                            .foregroundStyle(Color.flockTextSub)
                    }
                    Text("·")
                        .foregroundStyle(Color.flockTextSub)
                    Text("\(event.distanceFeet) ft")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(alertColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(event.timestamp, style: .time)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.flockTextSub)
                if !event.wasRead {
                    Circle()
                        .fill(Color.flockPrimary)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State

struct EmptyAlertsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.flockTextSub.opacity(0.4))
            Text("No Alerts Yet")
                .font(.flockTitle)
                .foregroundStyle(Color.flockText)
            Text("Move around near known camera locations\nand you'll see alerts appear here.")
                .font(.flockBody)
                .foregroundStyle(Color.flockTextSub)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
