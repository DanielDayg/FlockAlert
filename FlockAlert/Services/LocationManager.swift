import CoreLocation
import Combine
import UIKit

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var heading: CLLocationDirection = 0
    @Published var isAuthorized: Bool = false
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        // Battery: the geofences in GeofenceManager do the precise alert triggering,
        // so the live location only needs to be good enough for the map dot and the
        // proximity distance banner. Ten-metre accuracy instead of best-for-navigation,
        // and letting iOS pause updates while the user is stationary (e.g. parked),
        // cuts GPS power draw dramatically without affecting alert reliability.
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 20           // metres between location updates
        manager.headingFilter = 5             // degrees between heading updates
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        manager.showsBackgroundLocationIndicator = true
        manager.activityType = .automotiveNavigation
        updateAuthState(manager.authorizationStatus)
        // Start updating immediately if already authorized
        if manager.authorizationStatus == .authorizedAlways ||
           manager.authorizationStatus == .authorizedWhenInUse {
            startUpdating()
        }
        // The compass/heading sensor only feeds the on-screen map arrow, so it's
        // useless once the app is backgrounded — keeping the magnetometer alive
        // there just wastes battery. Stop it in the background, resume in foreground.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidEnterBackground() {
        // Compass only feeds the on-screen map arrow — no point running it hidden.
        manager.stopUpdatingHeading()
        // Drop to low-power location while backgrounded. The live map isn't visible,
        // and camera alerts fire from geofences (which are independent of this
        // accuracy), so coarse tracking here is plenty for refreshing nearby fences
        // and saves significant battery vs. ten-metre precision.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }

    @objc private func appWillEnterForeground() {
        guard isAuthorized else { return }
        manager.startUpdatingHeading()
        // Back to precise for the live map + "camera ahead" distance readout.
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 20
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var isAlwaysAuthorized: Bool { manager.authorizationStatus == .authorizedAlways }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        // Significant location changes wake the app even when iOS suspends it
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.stopMonitoringSignificantLocationChanges()
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func updateAuthState(_ status: CLAuthorizationStatus) {
        authStatus = status
        isAuthorized = (status == .authorizedAlways || status == .authorizedWhenInUse)
        if isAuthorized { startUpdating() }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.updateAuthState(manager.authorizationStatus) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy < 50 else { return }
        DispatchQueue.main.async { self.location = loc }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        DispatchQueue.main.async { self.heading = newHeading.trueHeading }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently handle — UI shows "location unavailable" state via nil location
    }
}
