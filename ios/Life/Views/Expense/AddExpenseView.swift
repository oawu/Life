import SwiftUI

struct AddExpenseView: View {
    @Bindable var store: ExpenseStore

    @State private var engine = CalculatorEngine()
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedPayer: LedgerMember?
    @State private var memo: String = ""
    @State private var date: Date = Date()
    @State private var locationService = LocationService()
    @State private var showExpenseList = false
    @State private var showCategorySettings = false
    @State private var showLedgerSettings = false
    @State private var showSaveConfirmation = false
    @State private var scrollOpacity: Double = 0

    private var headerOpacity: Double {
        if #available(iOS 18, *) {
            return scrollOpacity
        }
        return 1
    }

    private var canSave: Bool {
        guard engine.currentValue > 0 && selectedCategory != nil else {
            return false
        }
        if store.isGroupLedger {
            return selectedPayer != nil
        }
        return true
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                CalculatorView(engine: engine, currency: store.currentCurrency)

                CategoryGridView(
                    categories: store.categories,
                    selected: $selectedCategory,
                    onSettingsTapped: { showCategorySettings = true }
                )

                if store.isGroupLedger {
                    PayerChips(
                        members: store.currentMembers,
                        selected: $selectedPayer
                    )
                }

                ExpenseDetailFields(memo: $memo, date: $date, locationService: locationService)
            }
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollHeaderOpacity($scrollOpacity)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                LedgerSwitcher(
                    ledgers: store.ledgers,
                    selectedId: $store.currentLedgerId,
                    onSettingsTapped: { showLedgerSettings = true }
                )
                .padding(.vertical, 8)
                Divider()
                    .opacity(headerOpacity)
            }
            .background {
                Rectangle()
                    .fill(.bar)
                    .opacity(headerOpacity)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("新增開銷")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showExpenseList = true
                } label: {
                    Text("紀錄")
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
        .navigationDestination(isPresented: $showLedgerSettings) {
            LedgerSettingsView(store: store)
        }
        .onChange(of: store.categories) {
            if let selected = selectedCategory,
               !store.categories.contains(where: { $0.id == selected.id }) {
                selectedCategory = nil
            }
        }
        .onChange(of: store.currentLedgerId) {
            selectedCategory = nil
            if store.isGroupLedger {
                selectedPayer = store.currentMembers.first
            } else {
                selectedPayer = nil
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
            address: locationService.currentAddress,
            paidBy: selectedPayer
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
        if store.isGroupLedger {
            selectedPayer = store.currentMembers.first
        } else {
            selectedPayer = nil
        }
    }
}

// MARK: - Scroll Header Opacity

private extension View {
    @ViewBuilder
    func scrollHeaderOpacity(_ opacity: Binding<Double>) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: Double.self) { geo in
                let offset = geo.contentOffset.y + geo.contentInsets.top
                return min(max(offset / 40, 0), 1)
            } action: { _, newValue in
                opacity.wrappedValue = newValue
            }
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        AddExpenseView(store: ExpenseStore())
    }
}
