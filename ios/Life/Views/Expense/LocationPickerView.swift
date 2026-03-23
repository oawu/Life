import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    let initialLatitude: Double?
    let initialLongitude: Double?
    let onConfirm: (Double, Double, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var centerCoordinate: CLLocationCoordinate2D
    @State private var address: String?
    @State private var isGeocoding = false

    private let geocoder = CLGeocoder()
    private let locationManager = CLLocationManager()

    private static let defaultLatitude = 25.033
    private static let defaultLongitude = 121.565

    init(
        initialLatitude: Double?,
        initialLongitude: Double?,
        onConfirm: @escaping (Double, Double, String?) -> Void
    ) {
        self.initialLatitude = initialLatitude
        self.initialLongitude = initialLongitude
        self.onConfirm = onConfirm

        let currentLocation = CLLocationManager().location?.coordinate
        let latitude = initialLatitude ?? currentLocation?.latitude ?? Self.defaultLatitude
        let longitude = initialLongitude ?? currentLocation?.longitude ?? Self.defaultLongitude
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )

        _cameraPosition = State(initialValue: .region(region))
        _centerCoordinate = State(initialValue: coordinate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    centerCoordinate = context.camera.centerCoordinate
                    reverseGeocode(coordinate: centerCoordinate)
                }

                Image(systemName: "mappin")
                    .font(.system(size: 32))
                    .foregroundStyle(.red)
                    .shadow(radius: 3)
                    .offset(y: -16)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    moveToCurrentLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 80)
            }
            .overlay(alignment: .bottom) {
                addressBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .navigationTitle("選擇位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確認") {
                        onConfirm(centerCoordinate.latitude, centerCoordinate.longitude, address)
                        dismiss()
                    }
                }
            }
            .onAppear {
                reverseGeocode(coordinate: centerCoordinate)
            }
        }
    }

    private var addressBar: some View {
        HStack {
            if isGeocoding {
                ProgressView()
                    .controlSize(.small)
                Text("取得地址中…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let address = address {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                Text(address)
                    .font(.subheadline)
                    .lineLimit(2)
            } else {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                Text("移動地圖以選擇位置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func moveToCurrentLocation() {
        guard let coordinate = locationManager.location?.coordinate else {
            return
        }

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )

        withAnimation {
            cameraPosition = .region(region)
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        geocoder.cancelGeocode()
        isGeocoding = true

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            isGeocoding = false

            guard error == nil, let placemark = placemarks?.first else {
                address = nil
                return
            }

            let components = [
                placemark.administrativeArea,
                placemark.locality,
                placemark.subLocality,
                placemark.thoroughfare,
                placemark.subThoroughfare,
            ].compactMap { $0 }

            address = components.isEmpty ? nil : components.joined()
        }
    }
}
