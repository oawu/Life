import SwiftUI

struct AddExpenseView: View {
  @Bindable var store: ExpenseStore

  @State private var engine = CalculatorEngine()
  @State private var selectedCategory: ExpenseCategory?
  @State private var memo: String = ""
  @State private var date: Date = Date()
  @State private var locationService = LocationService()
  @State private var showExpenseList = false
  @State private var showCategorySettings = false
  @State private var showSaveConfirmation = false

  private var canSave: Bool {
    engine.currentValue > 0 && selectedCategory != nil
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 32) {
        CalculatorView(engine: engine)

        CategoryGridView(
          categories: store.categories,
          selected: $selectedCategory,
          onSettingsTapped: { showCategorySettings = true }
        )

        ExpenseDetailFields(memo: $memo, date: $date, locationService: locationService)
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
    .navigationDestination(isPresented: $showCategorySettings) {
      CategorySettingsView(store: store)
    }
    .onChange(of: store.categories) {
      if let selected = selectedCategory,
         !store.categories.contains(where: { $0.id == selected.id }) {
        selectedCategory = nil
      }
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
