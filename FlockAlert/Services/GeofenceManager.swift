import CoreLocation
import Foundation

// Manages up to 20 active CLCircularRegion geofences (iOS system limit).
// Dynamically re-registers the nearest cameras as the user moves.

final class GeofenceManager: NSObject {
    private let locationManager = CLLocationManager()
    private let maxFences = 20

    var onEntered: ((UUID) -> Void)?
    var onExited: ((UUID) -> Void)?

    private var registeredFences: [String: CLCircularRegion] = [:]  // [UUID string: region]

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // Call this whenever the user's location changes significantly or
    // after the camera list is refreshed. Pass the nearest N cameras.
    func refresh(with cameras: [Camera], radius: CLLocationDistance) {
        // Unregister all current fences
        registeredFences.values.forEach { locationManager.stopMonitoring(for: $0) }
        registeredFences.removeAll()

        // Register nearest cameras (up to limit)
        for camera in cameras.prefix(maxFences) {
            let identifier = camera.id.uuidString
            let region = CLCircularRegion(
                center: camera.coordinate,
                radius: max(50, radius),   // minimum 50m so we don't miss fast-moving vehicles
                identifier: identifier
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            locationManager.startMonitoring(for: region)
            registeredFences[identifier] = region
        }
    }

    func stopAll() {
        registeredFences.values.forEach { locationManager.stopMonitoring(for: $0) }
        registeredFences.removeAll()
    }
}

extension GeofenceManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        DispatchQueue.main.async { self.onEntered?(id) }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        DispatchQueue.main.async { self.onExited?(id) }
    }

    func locationManager(_ manager: CLLocationManager,
                         monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        // If we exceed system limits, quietly degrade — geofence count is already capped
    }
}
