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
        wireGeofenceCallbacks()  // ← critical: connect geofences to alerts
    }

    // MARK: - Geofence Wiring

    private func wireGeofenceCallbacks() {
        // Stage 1 — Approaching (~3× radius out): bird chirp + "camera ahead" notification
        geofenceManager.onApproached = { [weak self] camera in
            guard let self else { return }
            let dist = self.distanceToNearest ?? self.alertRadiusMetres * 3
            self.alertDispatcher.dispatchApproach(
                camera: camera,
                distance: dist,
                mode: self.alertMode,
                voice: self.voiceEnabled
            )
            self.unreadAlertCount += 1
        }

        // Stage 2 — Entered inner radius: check FOV, fire in-view or entered alert
        geofenceManager.onEntered = { [weak self] camera in
            guard let self else { return }
            self.activeAlertCameraIDs.insert(camera.id)

            let inFOV = self.isUserInCameraFOV(camera)
            if inFOV {
                // User is actually being scanned right now
                self.alertDispatcher.dispatchInView(
                    camera: camera,
                    mode: self.alertMode,
                    voice: self.voiceEnabled
                )
            } else {
                // Within range but not directly in the arc — still warn
                self.alertDispatcher.dispatchApproach(
                    camera: camera,
                    distance: self.alertRadiusMetres,
                    mode: self.alertMode,
                    voice: self.voiceEnabled
                )
            }
            self.unreadAlertCount += 1
        }

        geofenceManager.onExited = { [weak self] camera in
            self?.activeAlertCameraIDs.remove(camera.id)
        }
    }

    // MARK: - FOV Check

    /// Returns true if the user is currently inside the camera's field of view arc.
    func isUserInCameraFOV(_ camera: Camera) -> Bool {
        guard let facing = camera.facingDirection,
              let fov    = camera.fieldOfViewDegrees,
              let userLoc = userLocation
        else { return false }

        // Bearing FROM camera TO user
        let bearingCamToUser = CLLocation(latitude: camera.latitude, longitude: camera.longitude)
            .bearing(to: userLoc.coordinate)

        // Angle between camera's facing direction and line to user
        let diff = abs(facing - bearingCamToUser).normalised360
        return diff <= fov / 2.0
    }

    // MARK: - Nearest Camera Updates (called from MapViewModel proximity check)

    func updateNearestCamera(_ camera: Camera?, distance: Double?) {
        nearestCamera = camera
        distanceToNearest = distance
        if let cam = camera, let dist = distance {
            visibilityStatus = visibilityLabel(camera: cam, distance: dist)
        } else {
            visibilityStatus = "—"
        }
    }

    private func visibilityLabel(camera: Camera, distance: Double) -> String {
        guard let facing = camera.facingDirection,
              let fov    = camera.fieldOfViewDegrees,
              let userLoc = userLocation else { return "Unknown" }

        let bearingToCamera = userLoc.bearing(to: camera.coordinate)
        let relAngle = abs(facing - bearingToCamera).normalised360
        let halfFOV  = fov / 2.0

        if relAngle < halfFOV * 0.5  { return "HIGH" }
        if relAngle < halfFOV        { return "LIKELY" }
        if relAngle < halfFOV * 1.5  { return "POSSIBLE" }
        return "LOW"
    }

    // MARK: - Legacy helpers (kept for compatibility)

    func cameraEntered(_ camera: Camera) {
        // Now handled by geofence callbacks — this is a fallback
        activeAlertCameraIDs.insert(camera.id)
        unreadAlertCount += 1
    }

    func cameraExited(_ camera: Camera) {
        activeAlertCameraIDs.remove(camera.id)
    }

    // MARK: - Settings Persistence

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
}

// MARK: - Enums & Extensions

enum Tab: CaseIterable { case map, alerts, report, learn, profile }

enum AlertMode: String, CaseIterable {
    case banner     = "banner"
    case silent     = "silent"
    case hapticOnly = "hapticOnly"
    case voice      = "voice"

    var label: String {
        switch self {
        case .banner:     return "Banner + Sound"
        case .silent:     return "Silent + Haptic"
        case .hapticOnly: return "Haptic Only"
        case .voice:      return "Voice Alerts"
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
