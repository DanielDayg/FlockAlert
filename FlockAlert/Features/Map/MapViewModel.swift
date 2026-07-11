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
    @Published var cityClusters: [CityCluster] = []
    @Published var isClusterMode: Bool = false
    @Published var activeFilters = CameraFilters()
    @Published var mapStyle: MapStyle = .standard(pointsOfInterest: .excludingAll)
    @Published var isHybridMap = false
    @Published var visibleCount: Int = 0

    // Sync / stats
    @Published var syncState: SyncState = .idle
    @Published var totalCameraCount: Int = 0

    // Pin display thresholds
    // ~40 km = 0.36° lat; above this, collapse to city cluster bubbles
    private let clusterModeThreshold: Double = 0.36
    private let maxVisiblePins = 100
    private let capPinsSpanThreshold: Double = 0.08   // ~9 km — start capping to nearest 100

    // Spatial grid — O(1) proximity lookups instead of scanning all cameras
    private var spatialGrid: SpatialGrid = SpatialGrid()
    private var allCameras: [Camera] = []

    private var modelContext: ModelContext?
    private weak var appState: AppState?
    private let syncManager = SyncManager()
    private var hasCenteredOnUser = false
    private var lastSyncCoord: CLLocationCoordinate2D?
    private var lastRegionSpan: Double = 0
    private var cancellables = Set<AnyCancellable>()
    private var prefetchedClusterIDs: Set<String> = []

    // Debounce region changes so Overpass isn't hit on every tiny pan
    private var regionSubject = PassthroughSubject<MKCoordinateRegion, Never>()
    // Fired immediately when user zooms INTO a city from cluster mode
    private var zoomInSubject  = PassthroughSubject<MKCoordinateRegion, Never>()
    private var wasInClusterMode = false

    func setup(appState: AppState, modelContext: ModelContext) {
        guard self.appState == nil else { return }
        self.appState  = appState
        self.modelContext = modelContext

        syncManager.configure(with: modelContext)
        bindSyncState()
        bindLocationUpdates(appState: appState)
        setupRegionDebounce()

        // Load cameras off main thread immediately
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadCamerasBackground(context: modelContext)
        }

        if let loc = appState.userLocation {
            centerOnUserIfNeeded(loc)
            Task { await syncAndReload(center: loc.coordinate, radiusKm: 10) }
        }
    }

    // MARK: - Camera Loading (background)

    private func loadCamerasBackground(context: ModelContext) async {
        var descriptor = FetchDescriptor<Camera>(predicate: #Predicate { $0.isActive })
        descriptor.fetchLimit = 10000
        let cameras = (try? context.fetch(descriptor)) ?? []

        // Build spatial grid off main thread
        let grid = SpatialGrid()
        grid.build(cameras: cameras)

        await MainActor.run {
            self.allCameras = cameras
            self.spatialGrid = grid
            self.totalCameraCount = cameras.count
            self.applyFilters()
        }
    }

    func refreshForRegion(_ region: MKCoordinateRegion) {
        let c = region.center
        let latSpan = region.span.latitudeDelta
        let lngSpan = region.span.longitudeDelta

        // ── Cluster mode: zoomed out past ~40 km ─────────────────────
        if latSpan >= clusterModeThreshold {
            isClusterMode = true
            wasInClusterMode = true
            visibleCameras = []
            cityClusters = buildClusters(near: c, latDelta: latSpan * 0.65, lngDelta: lngSpan * 0.65)
            visibleCount = 0  // count unknown — don't show inaccurate numbers
            regionSubject.send(region)
            prefetchClustersBackground(cityClusters)
            return
        }

        // ── Individual pin mode ───────────────────────────────────────
        let comingFromClusters = wasInClusterMode
        isClusterMode = false
        wasInClusterMode = false
        cityClusters = []

        let nearby = spatialGrid.cameras(
            near: c,
            latDelta: latSpan * 0.65,
            lngDelta: lngSpan * 0.65
        )
        let filtered = applyActiveFilters(to: nearby)

        // Cap to nearest 100 when the view is wide enough to have many cameras
        if latSpan > capPinsSpanThreshold && filtered.count > maxVisiblePins {
            let centerLoc = CLLocation(latitude: c.latitude, longitude: c.longitude)
            let capped = filtered
                .sorted { centerLoc.distance(from: $0.clLocation) < centerLoc.distance(from: $1.clLocation) }
                .prefix(maxVisiblePins)
            visibleCameras = Array(capped)
        } else {
            visibleCameras = filtered
        }

        visibleCount = nearby.count

        // Zoomed into a city from cluster view → fetch from Overpass immediately
        if comingFromClusters {
            zoomInSubject.send(region)
        } else {
            regionSubject.send(region)
        }
    }

    // Groups cameras by city and computes a centroid + count for each
    private func buildClusters(near center: CLLocationCoordinate2D, latDelta: Double, lngDelta: Double) -> [CityCluster] {
        // Use a wider window so cities near the edge still show
        let nearby = spatialGrid.cameras(near: center, latDelta: latDelta * 2.0, lngDelta: lngDelta * 2.0)
        let filtered = applyActiveFilters(to: nearby)

        // Group by city name (nil → use grid cell label)
        var groups: [String: [Camera]] = [:]
        for cam in filtered {
            let key = [cam.city, cam.state].compactMap { $0 }.joined(separator: ", ")
            let label = key.isEmpty ? "Unknown" : key
            groups[label, default: []].append(cam)
        }

        return groups.compactMap { label, cams -> CityCluster? in
            guard !cams.isEmpty else { return nil }
            let avgLat = cams.map(\.latitude).reduce(0, +) / Double(cams.count)
            let avgLng = cams.map(\.longitude).reduce(0, +) / Double(cams.count)
            let parts = label.components(separatedBy: ", ")
            return CityCluster(
                id: label,
                city: parts.first ?? label,
                state: parts.count > 1 ? parts.last! : "",
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng),
                count: cams.count
            )
        }.sorted { $0.count > $1.count }  // biggest cities on top
    }

    // MARK: - Background Prefetch

    private func prefetchClustersBackground(_ clusters: [CityCluster]) {
        let newClusters = clusters
            .filter { !prefetchedClusterIDs.contains($0.id) }
            .prefix(5)
        guard !newClusters.isEmpty else { return }

        for cluster in newClusters {
            prefetchedClusterIDs.insert(cluster.id)
        }

        Task.detached(priority: .background) { [weak self] in
            for (index, cluster) in newClusters.enumerated() {
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s stagger
                }
                await self?.syncAndReload(center: cluster.coordinate, radiusKm: 15)
            }
        }
    }

    private func setupRegionDebounce() {
        // Normal debounced sync for panning/zooming within pin mode
        regionSubject
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .filter { [weak self] region in
                guard let self else { return false }
                let span = region.span.latitudeDelta
                let moved = self.lastSyncCoord.map {
                    abs($0.latitude  - region.center.latitude)  > span * 0.3 ||
                    abs($0.longitude - region.center.longitude) > span * 0.3
                } ?? true
                let spanChanged = abs(span - self.lastRegionSpan) > self.lastRegionSpan * 0.5
                return moved || spanChanged
            }
            .sink { [weak self] region in
                guard let self else { return }
                self.lastSyncCoord  = region.center
                self.lastRegionSpan = region.span.latitudeDelta
                let radius = min(50, max(5, region.span.latitudeDelta * 111))
                Task { await self.syncAndReload(center: region.center, radiusKm: radius) }
            }
            .store(in: &cancellables)

        // Immediate sync when user zooms into a city from cluster view
        zoomInSubject
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] region in
                guard let self else { return }
                self.lastSyncCoord  = region.center
                self.lastRegionSpan = region.span.latitudeDelta
                let radius = min(50, max(5, region.span.latitudeDelta * 111))
                Task { await self.syncAndReload(center: region.center, radiusKm: radius) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Filters

    func applyFilters() {
        let filtered = applyActiveFilters(to: allCameras)
        if isClusterMode {
            // Rebuild clusters with new filters
            var groups: [String: [Camera]] = [:]
            for cam in filtered {
                let key = [cam.city, cam.state].compactMap { $0 }.joined(separator: ", ")
                let label = key.isEmpty ? "Unknown" : key
                groups[label, default: []].append(cam)
            }
            cityClusters = groups.compactMap { label, cams -> CityCluster? in
                guard !cams.isEmpty else { return nil }
                let avgLat = cams.map(\.latitude).reduce(0, +) / Double(cams.count)
                let avgLng = cams.map(\.longitude).reduce(0, +) / Double(cams.count)
                let parts = label.components(separatedBy: ", ")
                return CityCluster(id: label, city: parts.first ?? label, state: parts.count > 1 ? parts.last! : "",
                                   coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng), count: cams.count)
            }.sorted { $0.count > $1.count }
        } else {
            visibleCameras = filtered.count > maxVisiblePins ? Array(filtered.prefix(maxVisiblePins)) : filtered
        }
        visibleCount = filtered.count
    }

    private func applyActiveFilters(to cameras: [Camera]) -> [Camera] {
        guard activeFilters.isActive else { return cameras }
        return cameras.filter { cam in
            if !activeFilters.ownerTypes.isEmpty,
               !activeFilters.ownerTypes.contains(cam.ownerType) { return false }
            if let minConf = activeFilters.minimumConfidence,
               cam.confidenceScore < minConf { return false }
            if activeFilters.verifiedOnly,
               cam.verificationCount < 3 { return false }
            return true
        }
    }

    // MARK: - Center on User

    func centerOnUserIfNeeded(_ location: CLLocation) {
        guard !hasCenteredOnUser else { return }
        hasCenteredOnUser = true
        withAnimation(.easeInOut(duration: 0.7)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 2500,
                longitudinalMeters: 2500
            ))
        }
    }

    // MARK: - Map Style

    func cycleMapStyle() {
        isHybridMap.toggle()
        mapStyle = isHybridMap
            ? .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll)
            : .standard(pointsOfInterest: .excludingAll)
    }

    // MARK: - FOV Polygon

    func fovPolygon(for camera: Camera) -> [CLLocationCoordinate2D] {
        guard let facing = camera.facingDirection,
              let fov   = camera.fieldOfViewDegrees else { return [] }
        let centre = camera.coordinate
        let range: Double = 80
        var pts: [CLLocationCoordinate2D] = [centre]
        for i in 0...12 {
            let angle = facing - fov / 2 + (fov / 12) * Double(i)
            pts.append(offset(from: centre, bearing: angle, metres: range))
        }
        pts.append(centre)
        return pts
    }

    // MARK: - Location / Proximity

    private func bindLocationUpdates(appState: AppState) {
        appState.$userLocation
            .compactMap { $0 }
            // Throttle more aggressively — proximity check only every 5 seconds
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] loc in
                self?.centerOnUserIfNeeded(loc)
                // Run proximity check off main thread
                Task.detached(priority: .utility) { [weak self] in
                    await self?.updateProximityBackground(location: loc)
                }
            }
            .store(in: &cancellables)
    }

    private func updateProximityBackground(location: CLLocation) async {
        // Use spatial grid to get only nearby cameras — fast
        let radius = appState?.alertRadiusMetres ?? 152
        let nearby = spatialGrid.cameras(
            near: location.coordinate,
            latDelta: 0.05,   // ~5.5 km
            lngDelta: 0.05
        )

        var nearest: Camera?
        var minDist = Double.infinity
        for cam in nearby {
            let d = location.distance(from: cam.clLocation)
            if d < minDist { minDist = d; nearest = cam }
        }

        let showNearest  = minDist <= radius * 3 ? nearest  : nil
        let showDistance = minDist <= radius * 3 ? minDist  : nil

        // Sort only the nearby slice for geofencing (fast)
        let fenceList = nearby
            .sorted { location.distance(from: $0.clLocation) < location.distance(from: $1.clLocation) }

        await MainActor.run { [weak self] in
            guard let self, let appState = self.appState else { return }
            appState.updateNearestCamera(showNearest, distance: showDistance)
            appState.geofenceManager.refresh(with: Array(fenceList.prefix(20)), radius: radius)
        }
    }

    private func bindSyncState() {
        syncManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncState = state
                if case .done = state, let ctx = self?.modelContext {
                    Task.detached(priority: .background) { [weak self] in
                        await self?.loadCamerasBackground(context: ctx)
                    }
                }
            }
            .store(in: &cancellables)

        syncManager.$totalCameraCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$totalCameraCount)
    }

    private func syncAndReload(center: CLLocationCoordinate2D, radiusKm: Double) async {
        await syncManager.syncRegion(center: center, radiusKm: radiusKm)
        if let ctx = modelContext {
            await loadCamerasBackground(context: ctx)
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

// MARK: - City Cluster Model

struct CityCluster: Identifiable {
    let id: String
    let city: String
    let state: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
}

// MARK: - Spatial Grid (O(1) region lookups)

final class SpatialGrid {
    private var grid: [GridKey: [Camera]] = [:]
    private let cellSize: Double = 0.1  // ~11km cells

    struct GridKey: Hashable {
        let row: Int, col: Int
    }

    func build(cameras: [Camera]) {
        grid.removeAll()
        for cam in cameras {
            let key = GridKey(
                row: Int(cam.latitude  / cellSize),
                col: Int(cam.longitude / cellSize)
            )
            grid[key, default: []].append(cam)
        }
    }

    func cameras(near coord: CLLocationCoordinate2D, latDelta: Double, lngDelta: Double) -> [Camera] {
        let minRow = Int((coord.latitude  - latDelta) / cellSize)
        let maxRow = Int((coord.latitude  + latDelta) / cellSize)
        let minCol = Int((coord.longitude - lngDelta) / cellSize)
        let maxCol = Int((coord.longitude + lngDelta) / cellSize)

        var result: [Camera] = []
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                if let cells = grid[GridKey(row: row, col: col)] {
                    result.append(contentsOf: cells)
                }
            }
        }
        return result
    }
}

// MARK: - Filter Model
struct CameraFilters: Equatable {
    var ownerTypes: Set<OwnerType> = []
    var minimumConfidence: Double? = nil
    var verifiedOnly: Bool = false
    var isActive: Bool { !ownerTypes.isEmpty || minimumConfidence != nil || verifiedOnly }
}
