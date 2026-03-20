import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject {
  var currentAddress: String?
  var latitude: Double?
  var longitude: Double?
  var authorizationStatus: CLAuthorizationStatus = .notDetermined

  private let locationManager = CLLocationManager()
  private let geocoder = CLGeocoder()

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    authorizationStatus = locationManager.authorizationStatus
  }

  func requestLocation() {
    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      locationManager.requestLocation()
    default:
      break
    }
  }

  func clear() {
    currentAddress = nil
    latitude = nil
    longitude = nil
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
      guard let self = self, error == nil, let placemark = placemarks?.first else {
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
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // 定位失敗，靜默處理
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus

    if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
      locationManager.requestLocation()
    }
  }
}
