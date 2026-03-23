import SwiftUI

struct ExpenseDetailFields: View {
    @Binding var memo: String
    @Binding var date: Date
    @Bindable var locationService: LocationService
    var showDate: Bool = true

    @State private var showLocationPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 備註
            HStack {
                Label("備註", systemImage: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)

                TextField("輸入備註", text: $memo)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if showDate {
                Divider().padding(.leading, 16 + 24)

                // 時間
                HStack {
                    Label("時間", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)

                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider().padding(.leading, 16 + 24)

            // 地點
            HStack {
                Label("地點", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)

                if let address = locationService.currentAddress {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showLocationPicker = true
                    } label: {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        locationService.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                } else if locationService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("定位中…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        locationService.requestLocation()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text("取得目前位置")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showLocationPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                                .font(.caption)
                            Text("選擇位置")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                initialLatitude: locationService.latitude,
                initialLongitude: locationService.longitude
            ) { latitude, longitude, address in
                locationService.set(latitude: latitude, longitude: longitude, address: address)
            }
        }
    }
}

#Preview {
    ExpenseDetailFields(
        memo: .constant("午餐"),
        date: .constant(Date()),
        locationService: LocationService()
    )
    .background(Color(.systemGroupedBackground))
}
