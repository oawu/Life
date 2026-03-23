import SwiftUI

struct ExpenseListView: View {
    @Bindable var store: ExpenseStore
    @State private var showSettleConfirmation = false
    @State private var showSettledToast = false
    @State private var toastTask: DispatchWorkItem?

    private var currencySymbol: String {
        store.currentCurrency.symbol
    }

    private func formatted(_ amount: Double) -> String {
        Int(amount.rounded(.up)).formatted()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd (E)"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()

    private enum TimelineEntry: Identifiable {
        case expenseGroup(date: String, expenses: [Expense], total: Double)
        case settlement(record: SettlementRecord, date: String)

        var id: String {
            switch self {
            case .expenseGroup(let date, _, _):
                return "expenses-\(date)"
            case .settlement(let record, _):
                return "settlement-\(record.id)"
            }
        }

        var sortDate: Date {
            switch self {
            case .expenseGroup(_, let expenses, _):
                return expenses.first?.date ?? .distantPast
            case .settlement(let record, _):
                return record.date
            }
        }
    }

    private var timeline: [TimelineEntry] {
        let formatter = Self.dateFormatter
        let calendar = Calendar.current

        // 開銷依日期分組
        let grouped = Dictionary(grouping: store.expenses) { expense in
            calendar.startOfDay(for: expense.date)
        }

        var entries: [TimelineEntry] = grouped.keys.map { dayStart in
            let expenses = grouped[dayStart]!.sorted { $0.date > $1.date }
            let total = expenses.reduce(0) { $0 + $1.amount }
            return .expenseGroup(date: formatter.string(from: dayStart), expenses: expenses, total: total)
        }

        // 群組帳本加入結算紀錄
        if let ledger = store.ledgers.first(where: { $0.id == store.currentLedgerId }),
           ledger.type == .group {
            for record in ledger.settlementRecords {
                let dateString = formatter.string(from: record.date)
                entries.append(.settlement(record: record, date: dateString))
            }
        }

        return entries.sorted { $0.sortDate > $1.sortDate }
    }

    // MARK: - Settlement

    private var settlements: [(from: LedgerMember, to: LedgerMember, amount: Double)] {
        guard let ledger = store.ledgers.first(where: { $0.id == store.currentLedgerId }),
              ledger.type == .group else {
            return []
        }

        let unsettledExpenses = ledger.expenses.filter { !ledger.settledExpenseIds.contains($0.id) }

        if unsettledExpenses.isEmpty {
            return []
        }

        // 計算每位成員的已付總額
        var paid: [String: Double] = [:]
        for member in ledger.members {
            paid[member.id] = 0
        }
        for expense in unsettledExpenses {
            if let payer = expense.paidBy {
                paid[payer.id, default: 0] += expense.amount
            }
        }

        // 人均應付額
        let total = paid.values.reduce(0, +)
        let share = total / Double(ledger.members.count)

        // 計算 balance
        var balances: [(member: LedgerMember, balance: Double)] = []
        for member in ledger.members {
            let balance = (paid[member.id] ?? 0) - share
            if abs(balance) > 0.01 {
                balances.append((member: member, balance: balance))
            }
        }

        // 貪婪配對
        var debtors = balances.filter { $0.balance < 0 }.sorted { $0.balance < $1.balance }
        var creditors = balances.filter { $0.balance > 0 }.sorted { $0.balance > $1.balance }
        var result: [(from: LedgerMember, to: LedgerMember, amount: Double)] = []

        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let amount = min(-debtors[debtorIndex].balance, creditors[creditorIndex].balance)
            result.append((from: debtors[debtorIndex].member, to: creditors[creditorIndex].member, amount: amount))

            debtors[debtorIndex].balance += amount
            creditors[creditorIndex].balance -= amount

            if abs(debtors[debtorIndex].balance) < 0.01 {
                debtorIndex += 1
            }
            if abs(creditors[creditorIndex].balance) < 0.01 {
                creditorIndex += 1
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            LedgerSwitcher(
                ledgers: store.ledgers,
                selectedId: $store.currentLedgerId
            )
            .padding(.vertical, 8)

            if timeline.isEmpty {
                emptyState
            } else {
                expenseList
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) {
            if showSettledToast {
                settledToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle("開銷紀錄")
        .confirmationDialog("確定已經結算清楚了嗎？", isPresented: $showSettleConfirmation, titleVisibility: .visible) {
            Button("重設", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                store.settleLedger(id: store.currentLedgerId)
                showSettleToast()
            }
        }
    }

    // MARK: - Toast

    private var settledToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
            Text("已完成結算")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.75))
        .clipShape(Capsule())
        .padding(.top, 8)
    }

    private func showSettleToast() {
        toastTask?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            showSettledToast = true
        }

        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSettledToast = false
            }
        }
        toastTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var settlementSection: some View {
        let items = settlements

        if !items.isEmpty {
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Text(item.from.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)

                        Text(item.to.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(store.currentCurrency.symbol)\(formatted(item.amount))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSettleConfirmation = true
                } label: {
                    Text("重設")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Text("拆帳")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("尚無開銷紀錄")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var expenseList: some View {
        List {
            if store.isGroupLedger {
                settlementSection
            }

            ForEach(timeline) { entry in
                switch entry {
                case .expenseGroup(let date, let expenses, let total):
                    Section {
                        ForEach(expenses) { expense in
                            ExpenseRow(expense: expense, showPayer: store.isGroupLedger, currencySymbol: currencySymbol)
                        }
                        .onDelete { offsets in
                            deleteExpenses(from: expenses, at: offsets)
                        }
                    } header: {
                        HStack {
                            Text(date)
                            Spacer()
                            Text("\(currencySymbol)\(formatted(total))")
                                .fontWeight(.medium)
                        }
                    }

                case .settlement(let record, let date):
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("已經由 \(record.settledBy.name) 結算拆帳！")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(date)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteExpenses(from expenses: [Expense], at offsets: IndexSet) {
        for index in offsets {
            store.deleteExpense(id: expenses[index].id)
        }
    }
}

// MARK: - Expense Row

private struct ExpenseRow: View {
    let expense: Expense
    var showPayer: Bool = false
    var currencySymbol: String = "$"

    var body: some View {
        HStack(spacing: 12) {
            // 分類圖示
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: expense.category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(expense.category.color)
            }

            // 分類名 + 備註 + 付款人
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !expense.memo.isEmpty {
                    Text(expense.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if showPayer, let payer = expense.paidBy {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))

                        Text(payer.name)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // 金額
            Text("\(currencySymbol)\(Int(expense.amount.rounded(.up)).formatted())")
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
