import SwiftUI

struct AddExpenseView: View {
  @Bindable var store: ExpenseStore

  @State private var engine = CalculatorEngine()
  @State private var selectedCategory: ExpenseCategory?
  @State private var memo: String = ""
  @State private var date: Date = Date()
  @State private var locationService = LocationService()
  @State private var showExpenseList = false
  @State private var showSaveConfirmation = false

  private var canSave: Bool {
    engine.currentValue > 0 && selectedCategory != nil
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 0) {
        CalculatorView(engine: engine)

        CategoryGridView(categories: store.categories, selected: $selectedCategory)
              .padding(.top, 32)
              
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          } else if locationService.isLoading {
            HStack {
              ProgressView()
              Text("定位中…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
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
              .background(Color(.systemBackground))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
          }
        }
        .padding(.horizontal, 16)
      }
      .padding(.vertical, 16)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color(.systemGroupedBackground))
    .navigationTitle("新增開銷")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          showExpenseList = true
        } label: {
          Label("紀錄", systemImage: "list.bullet")
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
    .overlay {
      if showSaveConfirmation {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(.green)

          Text("已儲存")
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.scale.combined(with: .opacity))
      }
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

    withAnimation(.easeInOut(duration: 0.2)) {
      showSaveConfirmation = true
      resetForm()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      withAnimation {
        showSaveConfirmation = false
      }
    }
  }

  private func resetForm() {
    engine = CalculatorEngine()
    selectedCategory = nil
    memo = ""
    date = Date()
    locationService.clear()
  }
}

#Preview {
  NavigationStack {
    AddExpenseView(store: ExpenseStore())
  }
}
