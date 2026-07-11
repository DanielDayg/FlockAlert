import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct AlertsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlertEvent.timestamp, order: .reverse) private var events: [AlertEvent]
    @State private var showPaywall = false
    @State private var showMap = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Setup health check ──────────────────────────────
                    SetupHealthBanner(locationManager: appState.locationManager)

                    // ── Paywall banner for free users ───────────────────
                    if !subscriptionManager.isPro {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.flockPrimary)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Proximity Alerts")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.flockText)
                                    Text("Get notified before you reach a Flock camera. Tap to upgrade.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.flockTextSub)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.flockPrimary)
                            }
                            .padding(14)
                            .background(Color.flockPrimary.opacity(0.1))
                        }
                        .buttonStyle(.plain)
                    }

                    // ── List / Map toggle ───────────────────────────────
                    if !events.isEmpty && subscriptionManager.isPro {
                        Picker("View", selection: $showMap) {
                            Label("LIST", systemImage: "list.bullet").tag(false)
                            Label("FOOTPRINT", systemImage: "map.fill").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    if events.isEmpty {
                        EmptyAlertsView(isPro: subscriptionManager.isPro, showPaywall: $showPaywall)
                    } else if showMap && subscriptionManager.isPro {
                        AlertFootprintMap(events: events)
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
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
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

// MARK: - Setup Health Banner

struct SetupHealthBanner: View {
    let locationManager: LocationManager
    @State private var status: CLAuthorizationStatus = .notDetermined

    private var isAlways: Bool { status == .authorizedAlways }
    private var isDenied: Bool { status == .denied || status == .restricted }

    var body: some View {
        Group {
            if isDenied {
                BannerRow(
                    icon: "location.slash.fill",
                    color: .flockAlert,
                    title: "Location Blocked",
                    subtitle: "Alerts can't fire. Tap to open Settings → FlockAlert → Location → Always.",
                    action: { locationManager.openSettings() }
                )
            } else if !isAlways {
                BannerRow(
                    icon: "location.fill",
                    color: .flockCaution,
                    title: "Enable \"Always\" Location for Background Alerts",
                    subtitle: "Currently set to \"While Using\" — alerts won't fire when your screen is off. Tap to fix.",
                    action: { locationManager.openSettings() }
                )
            }
        }
        .onAppear { status = locationManager.authorizationStatus }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            status = locationManager.authorizationStatus
        }
    }
}

struct BannerRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.flockText)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.flockTextSub)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(color)
            }
            .padding(14)
            .background(color.opacity(0.12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyAlertsView: View {
    let isPro: Bool
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: isPro ? "bell.slash" : "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(isPro ? Color.flockTextSub.opacity(0.4) : Color.flockPrimary.opacity(0.6))

            Text(isPro ? "No Alerts Yet" : "Alerts are a Pro Feature")
                .font(.flockTitle)
                .foregroundStyle(Color.flockText)

            Text(isPro
                 ? "Drive near a known surveillance camera\nand you'll see alerts appear here."
                 : "Upgrade to Supporter or Guardian to get\nproximity alerts before you reach a Flock camera.")
                .font(.flockBody)
                .foregroundStyle(Color.flockTextSub)
                .multilineTextAlignment(.center)

            if !isPro {
                Button { showPaywall = true } label: {
                    Text("View Plans")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.flockBG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.flockPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 40)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Alert Footprint Map

struct AlertFootprintMap: View {
    let events: [AlertEvent]

    private var validEvents: [AlertEvent] {
        events.filter { $0.cameraLatitude != 0 || $0.cameraLongitude != 0 }
    }

    private var region: MapCameraPosition {
        guard let first = validEvents.first else {
            return .automatic
        }
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: first.cameraLatitude, longitude: first.cameraLongitude),
            latitudinalMeters: 5000, longitudinalMeters: 5000
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(initialPosition: region) {
                ForEach(validEvents) { event in
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: event.cameraLatitude,
                        longitude: event.cameraLongitude
                    )) {
                        AlertPin(event: event)
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea(edges: .bottom)

            // Header overlay
            VStack(spacing: 2) {
                Text("YOUR SURVEILLANCE FOOTPRINT")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.red)
                    .tracking(2)
                Text("\(validEvents.count) LOCATIONS LOGGED BY THE GRID")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .tracking(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 8)
        }
    }
}

struct AlertPin: View {
    let event: AlertEvent
    @State private var pulse = false

    private var pinColor: Color {
        switch event.alertType {
        case .entering:    return .red
        case .approaching: return .orange
        case .highDensity: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor.opacity(0.25))
                .frame(width: pulse ? 32 : 20)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(pinColor)
                .frame(width: 10)
            Image(systemName: "eye.fill")
                .font(.system(size: 5, weight: .black))
                .foregroundStyle(.white)
        }
        .onAppear { pulse = true }
    }
}
