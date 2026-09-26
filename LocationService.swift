import CoreLocation
import SwiftUI

@MainActor final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var point: Point?
    @Published var message: String?
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters; status = manager.authorizationStatus }
    func request() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: message = "Геолокация выключена. Разрешите доступ в настройках iPhone или выберите район вручную."
        @unknown default: break
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways { manager.requestLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { if let last = locations.last { point = Point(last.coordinate); message = nil } }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { message = "Не удалось определить местоположение. Попробуйте снова или выберите район." }
}
