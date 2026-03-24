import SwiftUI
import WatchKit

struct WatchAddExpenseView: View {
    @Bindable var store: WatchExpenseStore
    let locationService: WatchLocationService
    let onSave: (Expense) -> Void

    @State private var amount: Int = 0
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedPayer: LedgerMember?
    @State private var memo: String = ""
    @State private var date: Date = Date()
    @State private var showSuccess: Bool = false

    private var canSave: Bool {
        amount > 0 && selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            List {
                // 帳本選擇
                NavigationLink {
                    WatchLedgerPickerView(
                        ledgers: store.ledgers,
                        selectedId: $store.selectedLedgerId
                    )
                } label: {
                    HStack {
                        Text("帳本")
                        Spacer()
                        Text(store.currentLedger?.name ?? "個人")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: store.selectedLedgerId) {
                    selectedCategory = nil
                    selectedPayer = store.isGroupLedger
                        ? store.currentMembers.first { $0.id == Ledger.defaultMemberId }
                        : nil
                }

                // 金額
                NavigationLink {
                    WatchAmountInputView(
                        amount: $amount,
                        currency: store.currentCurrency
                    )
                } label: {
                    HStack {
                        Spacer()
                        if amount > 0 {
                            Text(formatAmount(amount))
                                .font(.title2.bold())
                        } else {
                            Text("0 \(store.currentCurrency.unitLabel)")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                // 分類
                NavigationLink {
                    WatchCategoryPickerView(
                        categories: store.categories,
                        selected: $selectedCategory
                    )
                } label: {
                    HStack {
                        Text("分類")
                        Spacer()
                        if let category = selectedCategory {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                            Text(category.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("未選擇")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 付款人（群組帳本）
                if store.isGroupLedger {
                    NavigationLink {
                        WatchPayerPickerView(
                            members: store.currentMembers,
                            selected: $selectedPayer
                        )
                    } label: {
                        HStack {
                            Text("付款人")
                            Spacer()
                            Text(selectedPayer?.name ?? "我")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 備註
                NavigationLink {
                    WatchMemoInputView(memo: $memo)
                } label: {
                    HStack {
                        Text("備註")
                        Spacer()
                        Text(memo.isEmpty ? "無" : memo)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // 時間
                NavigationLink {
                    WatchDatePickerView(date: $date)
                } label: {
                    HStack {
                        Text("時間")
                        Spacer()
                        Text(date, style: .time)
                            .foregroundStyle(.secondary)
                    }
                }

                // 位置
                HStack {
                    Text("位置")
                    Spacer()
                    if locationService.isLoading {
                        ProgressView()
                    } else if let address = locationService.currentAddress {
                        Text(address)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("無定位")
                            .foregroundStyle(.secondary)
                    }
                }

                // 儲存按鈕
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        Text("儲存")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(!canSave)
                .listItemTint(canSave ? .blue : .gray)
            }
            .navigationTitle("記帳")
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }

    private var successOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("已儲存 \(store.currentCurrency.symbol)\(amount)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

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

        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccess = false
            resetForm()
        }
    }

    private func resetForm() {
        amount = 0
        selectedCategory = nil
        memo = ""
        date = Date()
        // 保留帳本選擇和付款人
    }

    private func formatAmount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) \(store.currentCurrency.unitLabel)"
    }
}

// MARK: - Memo Input View

struct WatchMemoInputView: View {
    @Binding var memo: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TextField("備註", text: $memo)
            .navigationTitle("備註")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
    }
}
