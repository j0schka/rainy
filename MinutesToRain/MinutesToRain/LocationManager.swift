import CoreLocation
import Observation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        if let lat = UserDefaults.standard.object(forKey: "loc.lat") as? Double,
           let lon = UserDefaults.standard.object(forKey: "loc.lon") as? Double {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        coordinate = loc.coordinate
        UserDefaults.standard.set(loc.coordinate.latitude,  forKey: "loc.lat")
        UserDefaults.standard.set(loc.coordinate.longitude, forKey: "loc.lon")
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location errors are surfaced via coordinate remaining nil
    }

    func refresh() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }
}
