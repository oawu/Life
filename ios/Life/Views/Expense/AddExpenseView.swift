import SwiftUI

struct AddExpenseView: View {
  @Bindable var store: ExpenseStore

  @State private var engine = CalculatorEngine()
  @State private var selectedCategory: ExpenseCategory?
  @State private var memo: String = ""
  @State private var date: Date = Date()
  @State private var locationService = LocationService()
  @State private var showExpenseList = false

  private var canSave: Bool {
    engine.currentValue > 0 && selectedCategory != nil
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        CalculatorView(engine: engine)

        CategoryGridView(categories: store.categories, selected: $selectedCategory)

        // 備註
        VStack(alignment: .leading, spacing: 8) {
          Label("備註", systemImage: "pencil")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          TextField("輸入備註", text: $memo)
            .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 16)

        // 時間
        VStack(alignment: .leading, spacing: 8) {
          Label("時間", systemImage: "clock")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)

        // 地點
        VStack(alignment: .leading, spacing: 8) {
          Label("地點", systemImage: "location")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          if let address = locationService.currentAddress {
            HStack {
              Text(address)
                .font(.subheadline)

              Spacer()

              Button {
                locationService.clear()
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .foregroundStyle(.secondary)
              }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            Button {
              locationService.requestLocation()
            } label: {
              HStack {
                Image(systemName: "location.fill")
                Text("取得目前位置")
              }
              .font(.subheadline)
              .padding(12)
              .frame(maxWidth: .infinity)
              .background(Color(.secondarySystemBackground))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
          }
        }
        .padding(.horizontal, 16)
      }
      .padding(.vertical, 16)
    }
    .navigationTitle("新增開銷")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("紀錄") {
          showExpenseList = true
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("儲存") {
          save()
        }
        .fontWeight(.semibold)
        .disabled(!canSave)
      }
    }
    .navigationDestination(isPresented: $showExpenseList) {
      ExpenseListView(store: store)
    }
  }

  private func save() {
    let amount = engine.evaluateIfNeeded()

    guard amount > 0, let category = selectedCategory else {
      return
    }

    store.addExpense(
      amount: Double(amount),
      category: category,
      memo: memo,
      date: date,
      latitude: locationService.latitude,
      longitude: locationService.longitude,
      address: locationService.currentAddress
    )

    UINotificationFeedbackGenerator().notificationOccurred(.success)
    resetForm()
  }

  private func resetForm() {
    engine = CalculatorEngine()
    selectedCategory = nil
    memo = ""
    date = Date()
    locationService.clear()
  }
}
