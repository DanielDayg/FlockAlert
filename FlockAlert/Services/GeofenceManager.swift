import CoreLocation
import Foundation

// Two-zone geofencing per camera:
//   Approach zone  —  3× alertRadius  →  bird chirp + "camera ahead" alert
//   Inner zone     —  1× alertRadius  →  "in camera view" alert (with FOV check)
//
// iOS limits total monitored regions to 20.
// We track up to 10 cameras × 2 zones = 20 fences.

final class GeofenceManager: NSObject {

    // Callbacks deliver the Camera directly so callers don't need a lookup table
    var onApproached: ((Camera) -> Void)?
    var onEntered:    ((Camera) -> Void)?
    var onExited:     ((Camera) -> Void)?

    private let locationManager = CLLocationManager()
    private let maxCameras = 10   // 10 × 2 zones = 20 fences (iOS limit)

    // identifier → Camera (stored so we can pass them back in callbacks)
    private var cameraByFenceID: [String: Camera] = [:]

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // Call whenever the nearby camera list changes.
    // Pass cameras sorted nearest-first; we'll take the first maxCameras.
    func refresh(with cameras: [Camera], radius: CLLocationDistance) {
        // Stop all current fences
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        cameraByFenceID.removeAll()

        let selected = Array(cameras.prefix(maxCameras))

        for camera in selected {
            let innerR    = max(50,  radius)
            let approachR = max(150, radius * 3)

            // ── Inner zone ─────────────────────────────────────────
            let innerID = "inner-\(camera.id)"
            let inner   = CLCircularRegion(
                center: camera.coordinate, radius: innerR, identifier: innerID
            )
            inner.notifyOnEntry = true
            inner.notifyOnExit  = true
            locationManager.startMonitoring(for: inner)
            cameraByFenceID[innerID] = camera

            // ── Approach zone ──────────────────────────────────────
            let approachID = "approach-\(camera.id)"
            let approach   = CLCircularRegion(
                center: camera.coordinate, radius: approachR, identifier: approachID
            )
            approach.notifyOnEntry = true
            approach.notifyOnExit  = false  // no need to callback on exit from approach
            locationManager.startMonitoring(for: approach)
            cameraByFenceID[approachID] = camera
        }
    }

    func stopAll() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        cameraByFenceID.removeAll()
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let camera = cameraByFenceID[region.identifier] else { return }

        DispatchQueue.main.async {
            if region.identifier.hasPrefix("approach-") {
                self.onApproached?(camera)
            } else {
                self.onEntered?(camera)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier.hasPrefix("inner-"),
              let camera = cameraByFenceID[region.identifier]
        else { return }
        DispatchQueue.main.async { self.onExited?(camera) }
    }

    func locationManager(_ manager: CLLocationManager,
                         monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        // Silently degrade — count is already capped at the iOS limit
    }
}
