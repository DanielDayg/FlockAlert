import SwiftUI
import CoreLocation
import Combine

@MainActor
final class AppState: ObservableObject {
    // Location & alerts
    @Published var userLocation: CLLocation?
    @Published var userHeading: CLLocationDirection = 0
    @Published var nearestCamera: Camera?
    @Published var distanceToNearest: Double?       // metres
    @Published var visibilityStatus: String = "—"
    @Published var activeAlertCameraIDs: Set<UUID> = []

    // UI state
    @Published var unreadAlertCount: Int = 0
    @Published var selectedTab: Tab = .map
    @Published var isLocationAuthorized: Bool = false
    @Published var syncState: SyncState = .idle

    // Settings (mirrored from UserDefaults for reactive binding)
    @Published var alertRadiusMetres: Double = UserDefaults.standard.double(forKey: "alertRadius").nonZero ?? 152
    @Published var alertMode: AlertMode = AlertMode(rawValue: UserDefaults.standard.string(forKey: "alertMode") ?? "") ?? .banner
    @Published var voiceEnabled: Bool = UserDefaults.standard.bool(forKey: "voiceEnabled")
    @Published var showHeatmap: Bool = UserDefaults.standard.bool(forKey: "showHeatmap")

    let locationManager = LocationManager()
    let geofenceManager = GeofenceManager()
    let alertDispatcher = AlertDispatcher()

    private var cancellables = Set<AnyCancellable>()

    init() {
        bindLocationManager()
        bindSettings()
    }

    private func bindLocationManager() {
        locationManager.$location
            .receive(on: DispatchQueue.main)
            .assign(to: &$userLocation)

        locationManager.$heading
            .receive(on: DispatchQueue.main)
            .assign(to: &$userHeading)

        locationManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocationAuthorized)
    }

    private func bindSettings() {
        $alertRadiusMetres
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "alertRadius") }
            .store(in: &cancellables)

        $alertMode
            .dropFirst()
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "alertMode") }
            .store(in: &cancellables)

        $voiceEnabled
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "voiceEnabled") }
            .store(in: &cancellables)
    }

    func updateNearestCamera(_ camera: Camera?, distance: Double?) {
        nearestCamera = camera
        distanceToNearest = distance
        if let cam = camera, let dist = distance {
            visibilityStatus = estimateVisibility(camera: cam, distance: dist)
        } else {
            visibilityStatus = "—"
        }
    }

    private func estimateVisibility(camera: Camera, distance: Double) -> String {
        guard let facing = camera.facingDirection,
              let fov = camera.fieldOfViewDegrees,
              let userLoc = userLocation else { return "Unknown" }

        let bearingToCamera = userLoc.bearing(to: camera.coordinate)
        let relAngle = abs(facing - bearingToCamera).normalised360
        let halfFOV = fov / 2.0

        if relAngle < halfFOV * 0.5 { return "HIGH" }
        if relAngle < halfFOV { return "LIKELY" }
        if relAngle < halfFOV * 1.5 { return "POSSIBLE" }
        return "LOW"
    }

    func cameraEntered(_ camera: Camera) {
        activeAlertCameraIDs.insert(camera.id)
        alertDispatcher.dispatch(camera: camera, distance: distanceToNearest ?? alertRadiusMetres, mode: alertMode, voice: voiceEnabled)
        unreadAlertCount += 1
    }

    func cameraExited(_ camera: Camera) {
        activeAlertCameraIDs.remove(camera.id)
    }
}

enum Tab: CaseIterable { case map, alerts, report, learn, settings }

enum AlertMode: String, CaseIterable {
    case banner = "banner"
    case silent = "silent"
    case hapticOnly = "hapticOnly"
    case voice = "voice"

    var label: String {
        switch self {
        case .banner: return "Banner + Sound"
        case .silent: return "Silent + Haptic"
        case .hapticOnly: return "Haptic Only"
        case .voice: return "Voice Alerts"
        }
    }
}

enum SyncState: Equatable {
    case idle
    case syncing
    case done(count: Int)
    case failed(String)
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
    var normalised360: Double {
        var v = truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return min(v, 360 - v)
    }
}
