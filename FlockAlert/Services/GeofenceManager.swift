import CoreLocation
import Foundation

// Two-zone geofencing per camera:
//   Approach zone  —  3× alertRadius  →  "camera ahead" alert
//   Inner zone     —  1× alertRadius  →  "in camera view" alert
//
// iOS limits total monitored regions to 20.
// We track up to 10 cameras × 2 zones = 20 fences.
//
// IMPORTANT: Uses diff-based refresh — never drops all fences at once,
// which prevents missed entry events during the gap.

final class GeofenceManager: NSObject {

    var onApproached: ((Camera) -> Void)?
    var onEntered:    ((Camera) -> Void)?
    var onExited:     ((Camera) -> Void)?
    /// Called when a geofence fires in background — use to refresh fences for new location
    var onNeedsRefresh: (() -> Void)?

    private let locationManager = CLLocationManager()
    private let maxCameras = 10   // 10 × 2 zones = 20 fences (iOS limit)

    private var cameraByFenceID: [String: Camera] = [:]
    private var currentCameraIDs: Set<UUID> = []

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // MARK: - Diff-based refresh (never drops all fences at once)

    func refresh(with cameras: [Camera], radius: CLLocationDistance) {
        let selected = Array(cameras.prefix(maxCameras))
        let newIDs = Set(selected.map { $0.id })

        // 1. Remove fences for cameras no longer in range
        let toRemove = currentCameraIDs.subtracting(newIDs)
        for region in locationManager.monitoredRegions {
            let camIDStr = region.identifier
                .replacingOccurrences(of: "inner-", with: "")
                .replacingOccurrences(of: "approach-", with: "")
            if let id = UUID(uuidString: camIDStr), toRemove.contains(id) {
                locationManager.stopMonitoring(for: region)
                cameraByFenceID.removeValue(forKey: region.identifier)
            }
        }

        // 2. Add fences for new cameras only
        let toAdd = selected.filter { !currentCameraIDs.contains($0.id) }
        for camera in toAdd {
            let innerR    = max(80,  radius)
            let approachR = max(250, radius * 3)

            let innerID = "inner-\(camera.id)"
            let inner   = CLCircularRegion(
                center: camera.coordinate, radius: innerR, identifier: innerID
            )
            inner.notifyOnEntry = true
            inner.notifyOnExit  = true
            locationManager.startMonitoring(for: inner)
            cameraByFenceID[innerID] = camera

            let approachID = "approach-\(camera.id)"
            let approach   = CLCircularRegion(
                center: camera.coordinate, radius: approachR, identifier: approachID
            )
            approach.notifyOnEntry = true
            approach.notifyOnExit  = false
            locationManager.startMonitoring(for: approach)
            cameraByFenceID[approachID] = camera
        }

        currentCameraIDs = newIDs
    }

    func stopAll() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        cameraByFenceID.removeAll()
        currentCameraIDs.removeAll()
    }

    var monitoredCount: Int { locationManager.monitoredRegions.count }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let camera = cameraByFenceID[region.identifier] else { return }

        // Wake the app and ask AppState to refresh nearby fences
        DispatchQueue.main.async {
            self.onNeedsRefresh?()
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
        // Silently degrade
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Re-request state if needed — the primary CLLocationManager handles actual auth prompts
    }
}
