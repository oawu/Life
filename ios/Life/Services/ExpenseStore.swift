import Foundation
import SwiftUI

struct Expense: Identifiable, Equatable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var ledgerId: String
    var paidBy: LedgerMember?
}

@Observable
final class ExpenseStore {
    var ledgers: [Ledger] = []
    var currentLedgerId: String = "personal"

    var categories: [ExpenseCategory] {
        get { currentLedger?.categories ?? [] }
        set {
            guard let index = currentLedgerIndex else {
                return
            }
            ledgers[index].categories = newValue
        }
    }

    var expenses: [Expense] {
        get { currentLedger?.expenses ?? [] }
        set {
            guard let index = currentLedgerIndex else {
                return
            }
            ledgers[index].expenses = newValue
        }
    }

    var recurringExpenses: [RecurringExpense] {
        get { currentLedger?.recurringExpenses ?? [] }
        set {
            guard let index = currentLedgerIndex else {
                return
            }
            ledgers[index].recurringExpenses = newValue
        }
    }

    var isGroupLedger: Bool {
        currentLedger?.type == .group
    }

    var currentMembers: [LedgerMember] {
        currentLedger?.members ?? []
    }

    private var currentLedger: Ledger? {
        ledgers.first { $0.id == currentLedgerId }
    }

    private var currentLedgerIndex: Int? {
        ledgers.firstIndex { $0.id == currentLedgerId }
    }

    init() {
        ledgers = Ledger.defaults
        loadSampleData()
    }

    func addExpense(amount: Double, category: ExpenseCategory, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?, paidBy: LedgerMember? = nil) {
        let expense = Expense(
            id: UUID(),
            amount: amount,
            category: category,
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address,
            ledgerId: currentLedgerId,
            paidBy: paidBy
        )
        expenses.insert(expense, at: 0)
    }

    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
    }

    func addCategory(id: String, name: String, icon: String, color: Color) {
        let category = ExpenseCategory(id: id, name: name, icon: icon, color: color)
        categories.append(category)
    }

    func updateCategory(_ category: ExpenseCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }
        categories[index] = category

        var updated = expenses
        for i in updated.indices {
            if updated[i].category.id == category.id {
                updated[i].category = category
            }
        }
        expenses = updated
    }

    func deleteCategory(id: String) {
        categories.removeAll { $0.id == id }
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Recurring Expense CRUD

    func addRecurringExpense(_ recurring: RecurringExpense) {
        guard let index = ledgers.firstIndex(where: { $0.id == recurring.ledgerId }) else {
            return
        }
        ledgers[index].recurringExpenses.append(recurring)
    }

    func updateRecurringExpense(_ recurring: RecurringExpense) {
        guard let ledgerIndex = ledgers.firstIndex(where: { $0.id == recurring.ledgerId }) else {
            return
        }
        guard let itemIndex = ledgers[ledgerIndex].recurringExpenses.firstIndex(where: { $0.id == recurring.id }) else {
            return
        }
        ledgers[ledgerIndex].recurringExpenses[itemIndex] = recurring
    }

    func deleteRecurringExpense(id: UUID) {
        for i in ledgers.indices {
            ledgers[i].recurringExpenses.removeAll { $0.id == id }
        }
    }

    func recurringExpenseCount(forLedger ledgerId: String) -> Int {
        ledgers.first { $0.id == ledgerId }?.recurringExpenses.count ?? 0
    }

    // MARK: - Ledger CRUD

    func addLedger(_ ledger: Ledger) {
        ledgers.append(ledger)
    }

    func updateLedger(_ ledger: Ledger) {
        guard let index = ledgers.firstIndex(where: { $0.id == ledger.id }) else {
            return
        }

        // 級聯刪除：移除的成員其 paidBy 對應的固定開銷一併刪除
        let oldMembers = ledgers[index].members
        let newMemberIds = Set(ledger.members.map { $0.id })
        let removedMemberIds = Set(oldMembers.map { $0.id }).subtracting(newMemberIds)

        var updated = ledger
        if !removedMemberIds.isEmpty {
            updated.recurringExpenses.removeAll { recurring in
                if let paidBy = recurring.paidBy {
                    return removedMemberIds.contains(paidBy.id)
                }
                return false
            }
        }

        ledgers[index] = updated
    }

    func deleteLedger(id: String) {
        ledgers.removeAll { $0.id == id }
        if currentLedgerId == id {
            currentLedgerId = "personal"
        }
    }

    func moveLedger(from source: IndexSet, to destination: Int) {
        var group = ledgers.filter { $0.type == .group }
        group.move(fromOffsets: source, toOffset: destination)

        let personal = ledgers.filter { $0.type == .personal }
        ledgers = personal + group
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        guard let personalIndex = ledgers.firstIndex(where: { $0.id == "personal" }) else {
            return
        }
        let personalCategories = ledgers[personalIndex].categories

        ledgers[personalIndex].expenses = [
            Expense(id: UUID(), amount: 85,   category: personalCategories[0],  memo: "蛋餅 + 豆漿",   date: today,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 150,  category: personalCategories[1],  memo: "便當",           date: today,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 55,   category: personalCategories[4],  memo: "拿鐵",           date: today,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 350,  category: personalCategories[2],  memo: "火鍋",           date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 33,   category: personalCategories[10], memo: "捷運",           date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 1200, category: personalCategories[9],  memo: "UNIQLO 外套",   date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
        ]

        ledgers[personalIndex].recurringExpenses = [
            RecurringExpense(id: UUID(), amount: 15000, category: personalCategories[5], frequency: .monthly(dayOfMonth: 1),  memo: "房租",    latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            RecurringExpense(id: UUID(), amount: 390,   category: personalCategories[24], frequency: .monthly(dayOfMonth: 15), memo: "Netflix", latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
        ]

        guard let roommatesIndex = ledgers.firstIndex(where: { $0.id == "roommates" }) else {
            return
        }
        let roommatesCategories = ledgers[roommatesIndex].categories
        let me = LedgerMember(id: Ledger.defaultMemberId, name: "我")
        let alice = LedgerMember(id: "alice", name: "Alice")

        ledgers[roommatesIndex].expenses = [
            Expense(id: UUID(), amount: 1800, category: roommatesCategories[0], memo: "火鍋聚餐",     date: today,     latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: me),
            Expense(id: UUID(), amount: 520,  category: roommatesCategories[1], memo: "全聯採買",     date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: alice),
        ]
    }
}
