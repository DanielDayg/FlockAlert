import SwiftUI
import MapKit
import SwiftData
import CoreLocation

// MARK: - Route Model

struct ScoredRoute: Identifiable {
    let id = UUID()
    let route: MKRoute
    let cameraCount: Int
    let isSafest: Bool
}

// MARK: - View Model

@MainActor
final class RouteViewModel: ObservableObject {

    @Published var destination: String = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var selectedDestination: MKMapItem?
    @Published var scoredRoutes: [ScoredRoute] = []
    @Published var selectedRouteID: UUID?
    @Published var isSearching: Bool = false
    @Published var isRouting: Bool = false
    @Published var errorMessage: String?
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var mapPolylines: [UUID: MKPolyline] = [:]

    private var searchTask: Task<Void, Never>?

    // MARK: - Search

    func searchDestination(query: String, userLocation: CLLocation?) {
        guard !query.isEmpty else { searchResults = []; return }
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            if let loc = userLocation {
                request.region = MKCoordinateRegion(
                    center: loc.coordinate,
                    latitudinalMeters: 80_000,
                    longitudinalMeters: 80_000
                )
            }

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                self.searchResults = Array(response.mapItems.prefix(6))
            } catch {
                guard !Task.isCancelled else { return }
                self.searchResults = []
            }
        }
    }

    // MARK: - Route Planning

    func planRoutes(to destination: MKMapItem, from userLocation: CLLocation?, cameras: [Camera]) async {
        guard let userLocation else {
            errorMessage = "LOCATION UNKNOWN — ENABLE GPS TO EVADE THE GRID"
            return
        }

        isRouting = true
        errorMessage = nil
        scoredRoutes = []

        let origin = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        let request = MKDirections.Request()
        request.source = origin
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            let routes = Array(response.routes.prefix(3))

            let scored = routes.enumerated().map { index, route -> ScoredRoute in
                let count = countCamerasAlongRoute(route, cameras: cameras, radiusMetres: 150)
                return ScoredRoute(route: route, cameraCount: count, isSafest: false)
            }
            .sorted { $0.cameraCount < $1.cameraCount }
            .enumerated()
            .map { index, sr -> ScoredRoute in
                ScoredRoute(route: sr.route, cameraCount: sr.cameraCount, isSafest: index == 0)
            }

            self.scoredRoutes = scored
            self.selectedRouteID = scored.first?.id

            // Fit map to show all routes
            if let firstRoute = scored.first?.route {
                let rect = firstRoute.polyline.boundingMapRect
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.cameraPosition = .rect(rect.insetBy(dx: -rect.size.width * 0.2,
                                                             dy: -rect.size.height * 0.2))
                }
            }
        } catch {
            errorMessage = "ROUTE CALCULATION FAILED — THE GRID PERSISTS"
        }

        isRouting = false
    }

    // MARK: - Route Scoring

    /// Counts cameras within `radiusMetres` of any step coordinate along the route.
    private func countCamerasAlongRoute(_ route: MKRoute, cameras: [Camera], radiusMetres: Double) -> Int {
        // Collect step coordinates from all polyline points
        let points = route.steps.flatMap { step -> [CLLocation] in
            let count = step.polyline.pointCount
            var coords = [CLLocationCoordinate2D](repeating: .init(), count: count)
            step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
            // Sample every 3rd point to avoid redundant checks on dense polylines
            return stride(from: 0, to: coords.count, by: max(1, coords.count / 30)).map {
                CLLocation(latitude: coords[$0].latitude, longitude: coords[$0].longitude)
            }
        }

        var hitCameraIDs = Set<UUID>()
        for camera in cameras {
            let camLoc = camera.clLocation
            for point in points {
                if camLoc.distance(from: point) <= radiusMetres {
                    hitCameraIDs.insert(camera.id)
                    break // no need to check other route points for this camera
                }
            }
        }
        return hitCameraIDs.count
    }

    func selectRoute(_ id: UUID) {
        selectedRouteID = id
    }

    var selectedRoute: ScoredRoute? {
        scoredRoutes.first { $0.id == selectedRouteID }
    }
}

// MARK: - Route View

struct RouteView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query private var cameras: [Camera]
    @StateObject private var vm = RouteViewModel()
    @FocusState private var searchFocused: Bool

    // Provide user location via AppState environment if available
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            if !subscriptionManager.isGuardian {
                RouteGuardianGateView()
            } else {
                routeContent
            }
        }
    }

    // MARK: - Main Route Content

    private var routeContent: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar
            if !vm.searchResults.isEmpty && vm.selectedDestination == nil {
                searchResultsList
            }
            mapSection
            if !vm.scoredRoutes.isEmpty {
                routeCards
                mapsExportBar
            }
        }
        // Reserve space for the floating FlockTabBar (overlaid by ContentView), so the
        // "Open route in" export buttons aren't hidden behind it. Matches the 100pt
        // clearance used by the other tab screens (ProfileView, MapView, etc.).
        .padding(.bottom, 100)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EVADE THE SURVEILLANCE GRID")
                    .font(.flockCaption)
                    .foregroundColor(Color.flockAlert)
                    .tracking(2)
                Text("Route Planner")
                    .font(.flockTitle)
                    .foregroundColor(Color.flockText)
            }
            Spacer()
            Image(systemName: "eye.slash.fill")
                .foregroundColor(Color.flockAlert)
                .font(.system(size: 22, weight: .bold))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.flockTextSub)
                .font(.system(size: 15, weight: .medium))

            TextField("", text: $vm.destination, prompt:
                Text("Enter destination...").foregroundColor(Color.flockTextSub)
            )
            .foregroundColor(Color.flockText)
            .font(.flockBody)
            .focused($searchFocused)
            .autocorrectionDisabled()
            .onChange(of: vm.destination) { _, newValue in
                vm.searchDestination(query: newValue, userLocation: appState.userLocation)
                if newValue.isEmpty { vm.selectedDestination = nil }
            }

            if !vm.destination.isEmpty {
                Button {
                    vm.destination = ""
                    vm.searchResults = []
                    vm.selectedDestination = nil
                    vm.scoredRoutes = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.flockTextSub)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.flockSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(searchFocused ? Color.flockPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(vm.searchResults, id: \.self) { item in
                    Button {
                        vm.selectedDestination = item
                        vm.destination = item.name ?? item.placemark.title ?? "Destination"
                        vm.searchResults = []
                        searchFocused = false
                        Task {
                            await vm.planRoutes(
                                to: item,
                                from: appState.userLocation,
                                cameras: cameras
                            )
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color.flockPrimary)
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Unknown")
                                    .font(.flockHeadline)
                                    .foregroundColor(Color.flockText)
                                    .lineLimit(1)
                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.flockCaption)
                                        .foregroundColor(Color.flockTextSub)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    Divider()
                        .background(Color.flockSurface)
                        .padding(.leading, 46)
                }
            }
        }
        .background(Color.flockSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .frame(maxHeight: 220)
        .padding(.bottom, 8)
    }

    // MARK: - Map

    private var mapSection: some View {
        ZStack {
            Map(position: $vm.cameraPosition) {
                // Active cameras as threat pins
                ForEach(nearbyMapCameras, id: \.id) { camera in
                    Annotation("", coordinate: camera.coordinate) {
                        CameraMapPin(isLawEnforcement: camera.ownerType == .municipalPolice
                                     || camera.ownerType == .sheriffDept
                                     || camera.ownerType == .statePolice
                                     || camera.ownerType == .federalAgency)
                    }
                }

                // Route polylines
                ForEach(vm.scoredRoutes) { scored in
                    let isSelected = scored.id == vm.selectedRouteID
                    MapPolyline(scored.route.polyline)
                        .stroke(
                            isSelected
                                ? (scored.isSafest ? Color.flockSafe : Color.flockAlert)
                                : Color.flockTextSub.opacity(0.4),
                            lineWidth: isSelected ? 5 : 2.5
                        )
                }

                // Destination pin
                if let dest = vm.selectedDestination {
                    Annotation("TARGET", coordinate: dest.placemark.coordinate) {
                        DestinationPin()
                    }
                }

                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
            }

            // Routing overlay
            if vm.isRouting {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.flockPrimary)
                    Text("CALCULATING EVASION ROUTES...")
                        .font(.flockCaption)
                        .foregroundColor(Color.flockPrimary)
                        .tracking(1.5)
                }
                .padding(20)
                .background(Color.flockBG.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Error overlay
            if let err = vm.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.flockAlert)
                    Text(err)
                        .font(.flockCaption)
                        .foregroundColor(Color.flockAlert)
                        .multilineTextAlignment(.center)
                        .tracking(1)
                }
                .padding(16)
                .background(Color.flockBG.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        // Flexible height: the map absorbs the leftover space, so when routes exist it
        // naturally shrinks to make room for the route cards and the Apple/Google Maps
        // export bar, which stay pinned above the tab bar.
        .frame(maxHeight: .infinity)
    }

    // Only show cameras near the visible route area to avoid pin overload
    private var nearbyMapCameras: [Camera] {
        guard let route = vm.selectedRoute?.route else { return [] }
        let rect = route.polyline.boundingMapRect
        let expandedRect = rect.insetBy(dx: -rect.size.width * 0.3, dy: -rect.size.height * 0.3)
        return cameras.filter { cam in
            let pt = MKMapPoint(cam.coordinate)
            return expandedRect.contains(pt)
        }
    }

    // MARK: - Maps Export

    private var mapsExportBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPEN ROUTE IN")
                .font(.flockCaption)
                .foregroundColor(Color.flockTextSub)
                .tracking(1.5)
                .padding(.horizontal, 16)
            HStack(spacing: 10) {
            Button {
                guard let dest = vm.selectedDestination else { return }
                let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                dest.openInMaps(launchOptions: launchOptions)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Apple Maps")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.flockText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.flockSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                guard let dest = vm.selectedDestination else { return }
                let coord = dest.placemark.coordinate
                let gmapsURL = URL(string: "comgooglemaps://?daddr=\(coord.latitude),\(coord.longitude)&directionsmode=driving")
                let webURL = URL(string: "https://maps.google.com/?daddr=\(coord.latitude),\(coord.longitude)&directionsmode=driving")!
                if let gmaps = gmapsURL, UIApplication.shared.canOpenURL(gmaps) {
                    UIApplication.shared.open(gmaps)
                } else {
                    UIApplication.shared.open(webURL)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Google Maps")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.flockText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.flockSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Color.flockBG)
    }

    // MARK: - Route Cards

    private var routeCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vm.scoredRoutes) { scored in
                    RouteCard(
                        scored: scored,
                        isSelected: scored.id == vm.selectedRouteID
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            vm.selectRoute(scored.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.flockSurface)
    }
}

// MARK: - Route Card

private struct RouteCard: View {
    let scored: ScoredRoute
    let isSelected: Bool
    let action: () -> Void

    private var travelTime: String {
        let mins = Int(scored.route.expectedTravelTime / 60)
        if mins < 60 { return "\(mins) MIN" }
        return "\(mins / 60)H \(mins % 60)M"
    }

    private var distanceString: String {
        let miles = scored.route.distance / 1609.34
        return String(format: "%.1f MI", miles)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Badge row
                HStack(spacing: 6) {
                    if scored.isSafest {
                        Label("SAFEST ROUTE", systemImage: "checkmark.shield.fill")
                            .font(.flockCaption)
                            .foregroundColor(Color.flockSafe)
                            .tracking(1)
                    } else {
                        Label("STANDARD ROUTE", systemImage: "arrow.triangle.turn.up.right.circle")
                            .font(.flockCaption)
                            .foregroundColor(Color.flockCaution)
                            .tracking(1)
                    }
                    Spacer()
                }

                // Camera count
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(scored.cameraCount)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(scored.cameraCount == 0
                                         ? Color.flockSafe
                                         : (scored.isSafest ? Color.flockCaution : Color.flockAlert))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(scored.cameraCount == 1 ? "CAMERA" : "CAMERAS")
                            .font(.flockCaption)
                            .foregroundColor(Color.flockTextSub)
                            .tracking(1.5)
                        Text(scored.isSafest
                             ? (scored.cameraCount == 0 ? "ROUTE CLEAR OF WATCHERS" : "EYES AVOIDED")
                             : "EXPOSED")
                            .font(.flockCaption)
                            .foregroundColor(scored.isSafest ? Color.flockSafe : Color.flockAlert)
                            .tracking(1.5)
                    }
                }

                Divider().background(Color.flockTextSub.opacity(0.2))

                // Travel info
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.flockTextSub)
                        Text(travelTime)
                            .font(.flockCaption)
                            .foregroundColor(Color.flockTextSub)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .font(.system(size: 11))
                            .foregroundColor(Color.flockTextSub)
                        Text(distanceString)
                            .font(.flockCaption)
                            .foregroundColor(Color.flockTextSub)
                    }
                }

                // Avoided count callout for safest non-zero route
                if scored.isSafest && !scored.cameraCount.isZero,
                   let worst = worstCount, worst > scored.cameraCount {
                    let avoided = worst - scored.cameraCount
                    Text("\(avoided) \(avoided == 1 ? "EYE" : "EYES") AVOIDED")
                        .font(.flockCaption)
                        .foregroundColor(Color.flockSafe)
                        .tracking(1.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.flockSafe.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .frame(width: 210)
            .background(isSelected ? Color.flockSurface2 : Color.flockSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected
                            ? (scored.isSafest ? Color.flockSafe : Color.flockAlert)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // Hack to show "X eyes avoided" — RouteCard needs context of worst route
    // We reach this value via the parent's sorted order: the last route is worst
    private var worstCount: Int? { nil } // resolved by caller context if needed
}

private extension Int {
    var isZero: Bool { self == 0 }
}

// MARK: - Map Pins

private struct CameraMapPin: View {
    let isLawEnforcement: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(isLawEnforcement ? Color.flockAlert : Color.flockCaution)
                .frame(width: 10, height: 10)
            Circle()
                .stroke(Color.flockBG, lineWidth: 1.5)
                .frame(width: 10, height: 10)
        }
    }
}

private struct DestinationPin: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.flockPrimary)
                    .frame(width: 28, height: 28)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.flockBG)
            }
            RouteTriangle()
                .fill(Color.flockPrimary)
                .frame(width: 10, height: 6)
        }
    }
}

private struct RouteTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Guardian Gate

private struct RouteGuardianGateView: View {
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.flockAlert.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Circle()
                        .stroke(Color.flockAlert.opacity(0.3), lineWidth: 1)
                        .frame(width: 100, height: 100)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(Color.flockAlert)
                }

                VStack(spacing: 10) {
                    Text("GUARDIAN EXCLUSIVE")
                        .font(.flockCaption)
                        .foregroundColor(Color.flockAlert)
                        .tracking(3)

                    Text("Surveillance-Free\nRoute Planner")
                        .font(.flockTitle)
                        .foregroundColor(Color.flockText)
                        .multilineTextAlignment(.center)

                    Text("They're mapping your life. We map the way out.")
                        .font(.flockBody)
                        .foregroundColor(Color.flockTextSub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    RouteFeatureRow(icon:"map.fill",         text: "Routes ranked by camera exposure")
                    RouteFeatureRow(icon:"eye.slash.fill",   text: "See exactly how many eyes you dodge")
                    RouteFeatureRow(icon:"shield.checkered", text: "Safest vs. standard route comparison")
                    RouteFeatureRow(icon:"bell.badge.slash",  text: "150m threat radius scoring")
                }
                .padding(18)
                .background(Color.flockSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

                // CTA
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 16, weight: .bold))
                        Text("BECOME A GUARDIAN")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .tracking(1.5)
                    }
                    .foregroundColor(Color.flockBG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.flockPrimary, Color.flockPrimary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
    }
}

private struct RouteFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.flockPrimary)
                .frame(width: 22)
            Text(text)
                .font(.flockBody)
                .foregroundColor(Color.flockText)
            Spacer()
        }
    }
}
