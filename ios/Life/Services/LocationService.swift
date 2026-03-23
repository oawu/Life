import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject {
    var currentAddress: String?
    var latitude: Double?
    var longitude: Double?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLoading: Bool = false

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let autoRequest: Bool
    private var pendingRequest = false

    init(autoRequest: Bool = true) {
        self.autoRequest = autoRequest
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            pendingRequest = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLoading = true
            locationManager.requestLocation()
        default:
            break
        }
    }

    func set(latitude: Double, longitude: Double, address: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.currentAddress = address
        self.isLoading = false
    }

    func clear() {
        currentAddress = nil
        latitude = nil
        longitude = nil
        isLoading = false
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else {
                return
            }

            guard error == nil, let placemark = placemarks?.first else {
                self.isLoading = false
                return
            }

            let components = [
                placemark.administrativeArea,
                placemark.locality,
                placemark.subLocality,
                placemark.thoroughfare,
                placemark.subThoroughfare,
            ].compactMap { $0 }

            self.currentAddress = components.joined()
            self.isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        let shouldRequest = autoRequest || pendingRequest
        pendingRequest = false

        if shouldRequest && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
            isLoading = true
            locationManager.requestLocation()
        }
    }
}
