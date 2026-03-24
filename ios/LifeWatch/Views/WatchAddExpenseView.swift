import SwiftUI
import WatchKit

enum WatchStep: Hashable {
    case calculator
    case category
    case payer
    case memoOrSave
    case memo
    case timeOrSave
    case time
}

struct WatchAddExpenseView: View {
    @Bindable var store: WatchExpenseStore
    let locationService: WatchLocationService
    let onSave: (Expense) -> Void

    @State private var path: [WatchStep] = []
    @State private var amount: Int = 0
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedPayer: LedgerMember?
    @State private var memo: String = ""
    @State private var date: Date = Date()
    @State private var showSuccess: Bool = false
    @State private var savedAmountText: String = ""

    var body: some View {
        NavigationStack(path: $path) {
            // Root：帳本選擇
            WatchLedgerPickerView(
                ledgers: store.ledgers,
                selectedId: store.selectedLedgerId,
                onSelect: { ledger in
                    store.selectedLedgerId = ledger.id
                    amount = 0
                    selectedCategory = nil
                    selectedPayer = ledger.type == .group
                        ? ledger.members.first { $0.id == Ledger.defaultMemberId }
                        : nil
                    memo = ""
                    date = Date()
                    path.append(.calculator)
                }
            )
            .navigationTitle("記帳")
            .navigationDestination(for: WatchStep.self) { step in
                switch step {
                case .calculator:
                    WatchCalculatorView(
                        amount: $amount,
                        currency: store.currentCurrency,
                        onConfirm: {
                            path.append(.category)
                        }
                    )

                case .category:
                    WatchCategoryPickerView(
                        categories: store.categories,
                        onSelect: { category in
                            selectedCategory = category
                            if store.isGroupLedger {
                                path.append(.payer)
                            } else {
                                path.append(.memoOrSave)
                            }
                        }
                    )

                case .payer:
                    WatchPayerPickerView(
                        members: store.currentMembers,
                        onSelect: { member in
                            selectedPayer = member
                            path.append(.memoOrSave)
                        }
                    )

                case .memoOrSave:
                    WatchMemoOrSaveView(
                        onSave: { save() },
                        onMemo: { path.append(.memo) }
                    )

                case .memo:
                    WatchMemoInputView(
                        memo: $memo,
                        onNext: { path.append(.timeOrSave) }
                    )

                case .timeOrSave:
                    WatchTimeOrSaveView(
                        onSave: { save() },
                        onAdjustTime: { path.append(.time) }
                    )

                case .time:
                    WatchDatePickerView(
                        date: $date,
                        onSave: { save() }
                    )
                }
            }
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text(savedAmountText)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Save

    private func save() {
        guard let category = selectedCategory else {
            return
        }

        WKInterfaceDevice.current().play(.success)

        let expense = Expense(
            id: UUID(),
            amount: Double(amount),
            category: category,
            memo: memo,
            date: date,
            latitude: locationService.latitude,
            longitude: locationService.longitude,
            address: locationService.currentAddress,
            ledgerId: store.selectedLedgerId,
            paidBy: store.isGroupLedger ? selectedPayer : nil
        )

        onSave(expense)

        savedAmountText = "已儲存 \(store.currentCurrency.symbol)\(formatSaveAmount())"
        showSuccess = true
        path.removeAll()
        resetForm()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccess = false
        }
    }

    private func resetForm() {
        amount = 0
        selectedCategory = nil
        memo = ""
        date = Date()
    }

    private func formatSaveAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
