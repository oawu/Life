import SwiftUI

struct ExpenseEditView: View {
    let expense: Expense
    let ledger: Ledger
    @Bindable var store: ExpenseStore

    @Environment(\.dismiss) private var dismiss

    @State private var engine = CalculatorEngine()
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedPayer: LedgerMember?
    @State private var memo: String = ""
    @State private var date: Date = Date()
    @State private var locationService = LocationService(autoRequest: false)
    @State private var errorMessage = ""
    @State private var showErrorAlert = false

    private var isGroup: Bool {
        ledger.type == .group
    }

    private var canSave: Bool {
        guard engine.currentValue > 0 && selectedCategory != nil else {
            return false
        }
        if isGroup {
            return selectedPayer != nil
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    CalculatorView(engine: engine, currency: ledger.currency)

                    CategoryGridView(
                        categories: ledger.categories,
                        selected: $selectedCategory
                    )

                    if isGroup {
                        PayerChips(
                            members: ledger.members,
                            selected: $selectedPayer
                        )
                    }

                    ExpenseDetailFields(
                        memo: $memo,
                        date: $date,
                        locationService: locationService
                    )
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("編輯開銷")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .accessibilityIdentifier(AID.btnCancelEdit)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier(AID.btnSaveEdit)
                }
            }
            .onAppear {
                loadExpense()
            }
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Actions

    private func loadExpense() {
        engine.setInitialValue(UInt64(expense.amount))
        selectedCategory = expense.category
        memo = expense.memo
        date = expense.date
        if let paidBy = expense.paidBy {
            selectedPayer = paidBy
        }
        if let latitude = expense.latitude, let longitude = expense.longitude {
            locationService.set(latitude: latitude, longitude: longitude, address: expense.address)
        }
    }

    private func save() {
        let amount = engine.evaluateIfNeeded()

        guard amount > 0, let category = selectedCategory else {
            return
        }

        let updated = Expense(
            id: expense.id,
            serverId: expense.serverId,
            amount: Double(amount),
            category: category,
            memo: memo,
            date: date,
            latitude: locationService.latitude,
            longitude: locationService.longitude,
            address: locationService.currentAddress,
            ledgerId: expense.ledgerId,
            paidBy: isGroup ? selectedPayer : nil
        )

        Task {
            do {
                try await store.updateExpense(updated)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}
