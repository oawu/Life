import Foundation
import SwiftData
import SwiftUI

@Observable
final class ExpenseStore {
    private let dataManager: DataManager
    var ledgers: [Ledger] = []
    var currentLedgerId: String = ""

    var categories: [ExpenseCategory] {
        currentLedger?.categories ?? []
    }

    var expenses: [Expense] {
        currentLedger?.expenses ?? []
    }

    var recurringExpenses: [RecurringExpense] {
        currentLedger?.recurringExpenses ?? []
    }

    var isGroupLedger: Bool {
        currentLedger?.type == .group
    }

    var currentMembers: [LedgerMember] {
        currentLedger?.members ?? []
    }

    var currentCurrency: Currency {
        currentLedger?.currency ?? .twd
    }

    private var currentLedger: Ledger? {
        ledgers.first { $0.id == currentLedgerId }
    }

    init(dataManager: DataManager) {
        self.dataManager = dataManager
        reload()
        currentLedgerId = ledgers.first { $0.type == .personal }?.id ?? ledgers.first?.id ?? ""
    }

    func reload() {
        ledgers = dataManager.fetchLedgers()
    }

    // MARK: - Expense CRUD

    func addExpense(amount: Double, category: ExpenseCategory, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?, paidBy: LedgerMember? = nil) {
        dataManager.addExpense(
            ledgerId: currentLedgerId,
            amount: amount,
            categoryId: category.id,
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address,
            paidByMemberId: paidBy?.id
        )
        reload()
    }

    func deleteExpense(id: UUID) {
        dataManager.deleteExpense(id: id)
        reload()
    }

    func updateExpense(_ expense: Expense) {
        dataManager.updateExpense(expense)
        reload()
    }

    // MARK: - Category CRUD

    func addCategory(id: String, name: String, icon: String, color: Color) {
        _ = dataManager.addCategory(ledgerId: currentLedgerId, name: name, icon: icon, color: color)
        reload()
    }

    func updateCategory(_ category: ExpenseCategory) {
        dataManager.updateCategory(id: category.id, name: category.name, icon: category.icon, color: category.color)
        reload()
    }

    func deleteCategory(id: String) {
        dataManager.deleteCategory(id: id)
        reload()
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        dataManager.moveCategory(ledgerId: currentLedgerId, fromOffsets: source, toOffset: destination)
        reload()
    }

    // MARK: - Recurring Expense CRUD

    func addRecurringExpense(_ recurring: RecurringExpense) {
        dataManager.addRecurringExpense(
            ledgerId: recurring.ledgerId,
            amount: recurring.amount,
            categoryId: recurring.category.id,
            frequency: recurring.frequency,
            memo: recurring.memo,
            isEnabled: recurring.isEnabled,
            latitude: recurring.latitude,
            longitude: recurring.longitude,
            address: recurring.address,
            paidByMemberId: recurring.paidBy?.id
        )
        reload()
    }

    func updateRecurringExpense(_ recurring: RecurringExpense) {
        dataManager.updateRecurringExpense(recurring)
        reload()
    }

    func deleteRecurringExpense(id: UUID) {
        dataManager.deleteRecurringExpense(id: id)
        reload()
    }

    func recurringExpenseCount(forLedger ledgerId: String) -> Int {
        dataManager.recurringExpenseCount(forLedger: ledgerId)
    }

    // MARK: - Settlement

    func settleLedger(id: String) {
        guard let ledger = ledgers.first(where: { $0.id == id }) else {
            return
        }

        let transfers = Self.calculateTransfers(
            expenses: ledger.expenses.filter { !ledger.settledExpenseIds.contains($0.id) },
            members: ledger.members
        )

        dataManager.settleLedger(id: id, transfers: transfers)
        reload()
    }

    static func calculateTransfers(expenses: [Expense], members: [LedgerMember]) -> [SettlementTransfer] {
        if expenses.isEmpty || members.isEmpty {
            return []
        }

        var paid: [String: Double] = [:]
        for member in members {
            paid[member.id] = 0
        }
        for expense in expenses {
            if let payer = expense.paidBy {
                paid[payer.id, default: 0] += expense.amount
            }
        }

        let total = paid.values.reduce(0, +)
        let share = total / Double(members.count)

        var balances: [(member: LedgerMember, balance: Double)] = []
        for member in members {
            let balance = (paid[member.id] ?? 0) - share
            if abs(balance) > 0.01 {
                balances.append((member: member, balance: balance))
            }
        }

        var debtors = balances.filter { $0.balance < 0 }.sorted { $0.balance < $1.balance }
        var creditors = balances.filter { $0.balance > 0 }.sorted { $0.balance > $1.balance }
        var result: [SettlementTransfer] = []

        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let amount = min(-debtors[debtorIndex].balance, creditors[creditorIndex].balance)
            result.append(SettlementTransfer(
                id: UUID(),
                from: debtors[debtorIndex].member,
                to: creditors[creditorIndex].member,
                amount: amount
            ))

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

    // MARK: - Ledger CRUD

    func addLedger(_ ledger: Ledger) {
        dataManager.addLedger(
            name: ledger.name,
            type: ledger.type,
            currency: ledger.currency,
            inviteCode: ledger.inviteCode,
            categories: ledger.categories
        )
        reload()
    }

    func updateLedger(_ ledger: Ledger) {
        dataManager.updateLedgerFull(ledger)
        reload()
    }

    func deleteLedger(id: String) {
        dataManager.deleteLedger(id: id)
        if currentLedgerId == id {
            currentLedgerId = ledgers.first { $0.type == .personal }?.id ?? ledgers.first?.id ?? ""
        }
        reload()
    }

    func moveLedger(from source: IndexSet, to destination: Int) {
        dataManager.moveLedger(fromOffsets: source, toOffset: destination)
        reload()
    }

    // MARK: - Preview

    static func preview() -> ExpenseStore {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let manager = DataManager(modelContainer: container)
        return ExpenseStore(dataManager: manager)
    }
}
