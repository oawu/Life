import SwiftUI

struct ExpenseDetailFields: View {
  @Binding var memo: String
  @Binding var date: Date
  @Bindable var locationService: LocationService

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

    Divider().padding(.leading, 16 + 24)

      // 地點
      HStack {
        Label("地點", systemImage: "location")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(width: 72, alignment: .leading)

        if let address = locationService.currentAddress {
          Text(address)
            .font(.subheadline)
            .lineLimit(1)

          Spacer()

          Button {
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
            locationService.requestLocation()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.caption)
              Text("取得目前位置")
                .font(.subheadline)
            }
            .foregroundStyle(.blue)
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
