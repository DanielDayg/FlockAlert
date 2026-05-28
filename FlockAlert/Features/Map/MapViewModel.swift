import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import Combine

@MainActor
final class MapViewModel: ObservableObject {
    // Map
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var visibleCameras: [Camera] = []
    @Published var selectedCamera: Camera?
    @Published var activeFilters = CameraFilters()
    @Published var isHybridMap = false
    @Published var mapStyle: MapStyle = .standard(pointsOfInterest: .excludingAll)

    // Sync / stats
    @Published var syncState: SyncState = .idle
    @Published var totalCameraCount: Int = 0

    private var allCameras: [Camera] = []
    private var modelContext: ModelContext?
    private weak var appState: AppState?
    private let syncManager = SyncManager()
    private var hasCenteredOnUser = false
    private var cancellables = Set<AnyCancellable>()

    // Called from MapView.onAppear — wires everything up
    func setup(appState: AppState, modelContext: ModelContext) {
        guard self.appState == nil else { return }   // only once
        self.appState = appState
        self.modelContext = modelContext

        syncManager.configure(with: modelContext)
        loadCameras(context: modelContext)
        bindSyncState()
        startLocationBinding(appState: appState)

        // If location is already known when view appears, center immediately
        if let loc = appState.userLocation {
            centerOnUserIfNeeded(loc)
            loadNearby(center: loc.coordinate)
        }
    }

    // MARK: - Camera Loading

    func loadCameras(context: ModelContext) {
        var descriptor = FetchDescriptor<Camera>(predicate: #Predicate { $0.isActive })
        descriptor.fetchLimit = 10000
        allCameras = (try? context.fetch(descriptor)) ?? []
        totalCameraCount = allCameras.count
        applyFilters()
    }

    func refreshForRegion(_ region: MKCoordinateRegion) {
        let c = region.center
        let span = region.span

        visibleCameras = allCameras.filter { cam in
            abs(cam.latitude  - c.latitude)  < span.latitudeDelta  * 0.65 &&
            abs(cam.longitude - c.longitude) < span.longitudeDelta * 0.65
        }
        applyFilters()

        // Sync Overpass for this region
        let radiusKm = min(50, max(5, span.latitudeDelta * 111))
        Task { await syncAndReload(center: c, radiusKm: radiusKm) }
    }

    func loadNearby(center: CLLocationCoordinate2D) {
        Task { await syncAndReload(center: center, radiusKm: 10) }
    }

    // MARK: - Center on User

    func centerOnUserIfNeeded(_ location: CLLocation) {
        guard !hasCenteredOnUser else { return }
        hasCenteredOnUser = true
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 3000,
                longitudinalMeters: 3000
            ))
        }
    }

    // MARK: - Filters

    func applyFilters() {
        var filtered = allCameras
        if !activeFilters.ownerTypes.isEmpty {
            filtered = filtered.filter { activeFilters.ownerTypes.contains($0.ownerType) }
        }
        if let minConf = activeFilters.minimumConfidence {
            filtered = filtered.filter { $0.confidenceScore >= minConf }
        }
        if activeFilters.verifiedOnly {
            filtered = filtered.filter { $0.verificationCount >= 3 }
        }
        visibleCameras = filtered
    }

    // MARK: - Map Style

    func cycleMapStyle() {
        withAnimation {
            isHybridMap.toggle()
            mapStyle = isHybridMap
                ? .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll)
                : .standard(pointsOfInterest: .excludingAll)
        }
    }

    // MARK: - FOV Polygon

    func fovPolygon(for camera: Camera) -> [CLLocationCoordinate2D] {
        guard let facing = camera.facingDirection,
              let fov = camera.fieldOfViewDegrees else { return [] }
        let centre = camera.coordinate
        let range: Double = 80
        var pts: [CLLocationCoordinate2D] = [centre]
        let steps = 12
        for i in 0...steps {
            let angle = facing - fov / 2 + (fov / Double(steps)) * Double(i)
            pts.append(offset(from: centre, bearing: angle, metres: range))
        }
        pts.append(centre)
        return pts
    }

    // MARK: - Private

    private func startLocationBinding(appState: AppState) {
        appState.$userLocation
            .compactMap { $0 }
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] loc in
                self?.centerOnUserIfNeeded(loc)
                self?.updateProximity(from: loc)
            }
            .store(in: &cancellables)
    }

    private func bindSyncState() {
        syncManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncState = state
                // After a sync completes, reload the local camera list
                if case .done = state, let ctx = self?.modelContext {
                    self?.loadCameras(context: ctx)
                }
            }
            .store(in: &cancellables)

        syncManager.$totalCameraCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$totalCameraCount)
    }

    private func syncAndReload(center: CLLocationCoordinate2D, radiusKm: Double) async {
        await syncManager.syncRegion(center: center, radiusKm: radiusKm)
        if let ctx = modelContext { loadCameras(context: ctx) }
    }

    private func updateProximity(from location: CLLocation) {
        guard !allCameras.isEmpty else { return }
        var nearest: Camera?
        var minDist = Double.infinity
        for cam in allCameras where cam.isActive {
            let d = location.distance(from: cam.clLocation)
            if d < minDist { minDist = d; nearest = cam }
        }
        let radius = appState?.alertRadiusMetres ?? 152
        appState?.updateNearestCamera(
            minDist <= radius * 3 ? nearest : nil,
            distance: minDist <= radius * 3 ? minDist : nil
        )
        if let sorted = Optional(allCameras
            .sorted { location.distance(from: $0.clLocation) < location.distance(from: $1.clLocation) }
        ) {
            appState?.geofenceManager.refresh(with: Array(sorted.prefix(20)), radius: radius)
        }
    }

    private func offset(from coord: CLLocationCoordinate2D, bearing: Double, metres: Double) -> CLLocationCoordinate2D {
        let R = 6371000.0
        let b = bearing.toRadians
        let d = metres / R
        let lat1 = coord.latitude.toRadians
        let lon1 = coord.longitude.toRadians
        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(b))
        let lon2 = lon1 + atan2(sin(b) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2.toDegrees, longitude: lon2.toDegrees)
    }
}

// MARK: - Filter Model

struct CameraFilters: Equatable {
    var ownerTypes: Set<OwnerType> = []
    var minimumConfidence: Double? = nil
    var verifiedOnly: Bool = false
    var isActive: Bool { !ownerTypes.isEmpty || minimumConfidence != nil || verifiedOnly }
}
