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

    var currentCurrency: Currency {
        currentLedger?.currency ?? .twd
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

    func updateExpense(_ expense: Expense) {
        guard let ledgerIndex = ledgers.firstIndex(where: { $0.id == expense.ledgerId }) else {
            return
        }
        guard let expenseIndex = ledgers[ledgerIndex].expenses.firstIndex(where: { $0.id == expense.id }) else {
            return
        }
        ledgers[ledgerIndex].expenses[expenseIndex] = expense
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
        guard let otherCategory = categories.first(where: { $0.isSystemOther }) else {
            return
        }

        // 將所屬開銷重新指派到「其他」
        var updatedExpenses = expenses
        for i in updatedExpenses.indices {
            if updatedExpenses[i].category.id == id {
                updatedExpenses[i].category = otherCategory
            }
        }
        expenses = updatedExpenses

        // 將所屬固定開銷重新指派到「其他」
        var updatedRecurring = recurringExpenses
        for i in updatedRecurring.indices {
            if updatedRecurring[i].category.id == id {
                updatedRecurring[i].category = otherCategory
            }
        }
        recurringExpenses = updatedRecurring

        categories.removeAll { $0.id == id }
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        // 排序只作用於非「其他」的分類，保持「其他」永遠在最後
        var sortable = categories.filter { !$0.isSystemOther }
        let other = categories.first { $0.isSystemOther }
        sortable.move(fromOffsets: source, toOffset: destination)
        if let other {
            sortable.append(other)
        }
        categories = sortable
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

    // MARK: - Settlement

    func settleLedger(id: String) {
        guard let index = ledgers.firstIndex(where: { $0.id == id }) else {
            return
        }
        let ledger = ledgers[index]

        // 計算當前轉帳明細快照
        let transfers = Self.calculateTransfers(
            expenses: ledger.expenses.filter { !ledger.settledExpenseIds.contains($0.id) },
            members: ledger.members
        )

        let expenseIds = Set(ledger.expenses.map { $0.id })
        ledgers[index].settledExpenseIds.formUnion(expenseIds)

        let me = ledger.members.first { $0.id == Ledger.defaultMemberId }
            ?? LedgerMember(id: Ledger.defaultMemberId, name: "我")
        let record = SettlementRecord(
            id: UUID(),
            date: Date(),
            settledBy: me,
            transfers: transfers,
            currencySymbol: ledger.currency.symbol
        )
        ledgers[index].settlementRecords.append(record)
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
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!

        // 歷史月份日期
        let lastMonth1 = calendar.date(byAdding: .month, value: -1, to: today)!
        let lastMonth2 = calendar.date(byAdding: .day, value: -5, to: lastMonth1)!
        let lastMonth3 = calendar.date(byAdding: .day, value: -10, to: lastMonth1)!
        let twoMonthsAgo1 = calendar.date(byAdding: .month, value: -2, to: today)!
        let twoMonthsAgo2 = calendar.date(byAdding: .day, value: -7, to: twoMonthsAgo1)!
        let threeMonthsAgo1 = calendar.date(byAdding: .month, value: -3, to: today)!
        let threeMonthsAgo2 = calendar.date(byAdding: .day, value: -3, to: threeMonthsAgo1)!
        let lastYear1 = calendar.date(byAdding: .year, value: -1, to: today)!
        let lastYear2 = calendar.date(byAdding: .day, value: -15, to: lastYear1)!

        guard let personalIndex = ledgers.firstIndex(where: { $0.id == "personal" }) else {
            return
        }
        let personalCategories = ledgers[personalIndex].categories

        ledgers[personalIndex].expenses = [
            // 本月
            Expense(id: UUID(), amount: 85,   category: personalCategories[0],  memo: "蛋餅 + 豆漿",   date: today,          latitude: 25.0330, longitude: 121.5654, address: "台北市大安區忠孝東路四段", ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 150,  category: personalCategories[1],  memo: "便當",           date: today,          latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 55,   category: personalCategories[4],  memo: "拿鐵",           date: today,          latitude: 25.0418, longitude: 121.5075, address: "台北市中正區重慶南路一段", ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 350,  category: personalCategories[2],  memo: "火鍋",           date: yesterday,      latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 33,   category: personalCategories[10], memo: "捷運",           date: yesterday,      latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 1200, category: personalCategories[9],  memo: "UNIQLO 外套",   date: yesterday,      latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            // 上個月
            Expense(id: UUID(), amount: 15000, category: personalCategories[5],  memo: "房租",          date: lastMonth1,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 420,   category: personalCategories[2],  memo: "壽司",          date: lastMonth1,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 89,    category: personalCategories[0],  memo: "蘿蔔糕 + 紅茶", date: lastMonth2,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 650,   category: personalCategories[15], memo: "KTV",           date: lastMonth2,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 1680,  category: personalCategories[6],  memo: "GU 牛仔褲 × 2", date: lastMonth3,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 280,   category: personalCategories[7],  memo: "洗衣精 + 衛生紙", date: lastMonth3,   latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 66,    category: personalCategories[10], memo: "高鐵來回",       date: lastMonth2,     latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            // 兩個月前
            Expense(id: UUID(), amount: 15000, category: personalCategories[5],  memo: "房租",          date: twoMonthsAgo1,  latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 520,   category: personalCategories[1],  memo: "牛排",          date: twoMonthsAgo1,  latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 3200,  category: personalCategories[8],  memo: "牙醫自費",      date: twoMonthsAgo2,  latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 390,   category: personalCategories[24], memo: "Netflix",       date: twoMonthsAgo2,  latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 75,    category: personalCategories[4],  memo: "星巴克",        date: twoMonthsAgo1,  latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            // 三個月前
            Expense(id: UUID(), amount: 15000, category: personalCategories[5],  memo: "房租",          date: threeMonthsAgo1, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 4500,  category: personalCategories[25], memo: "AirPods Pro",   date: threeMonthsAgo1, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 180,   category: personalCategories[3],  memo: "千層蛋糕",      date: threeMonthsAgo2, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 1200,  category: personalCategories[16], memo: "健身房月費",     date: threeMonthsAgo2, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            // 去年
            Expense(id: UUID(), amount: 8900,  category: personalCategories[6],  memo: "冬季外套",      date: lastYear1,      latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 2600,  category: personalCategories[21], memo: "聖誕禮物",      date: lastYear1,      latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 560,   category: personalCategories[2],  memo: "聖誕大餐",      date: lastYear2,      latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            Expense(id: UUID(), amount: 15000, category: personalCategories[5],  memo: "房租",          date: lastYear2,      latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
        ]

        ledgers[personalIndex].recurringExpenses = [
            RecurringExpense(id: UUID(), amount: 15000, category: personalCategories[5], frequency: .monthly(dayOfMonth: 1),  memo: "房租",    isEnabled: true, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
            RecurringExpense(id: UUID(), amount: 390,   category: personalCategories[24], frequency: .monthly(dayOfMonth: 15), memo: "Netflix", isEnabled: true, latitude: nil, longitude: nil, address: nil, ledgerId: "personal", paidBy: nil),
        ]

        // MARK: 室友帳本（群組）

        guard let roommatesIndex = ledgers.firstIndex(where: { $0.id == "roommates" }) else {
            return
        }
        let roommatesCategories = ledgers[roommatesIndex].categories
        let me = LedgerMember(id: Ledger.defaultMemberId, name: "我")
        let alice = LedgerMember(id: "alice", name: "Alice")
        let bob = LedgerMember(id: "bob", name: "Bob")

        // 上一輪已結算的開銷（5 天前 & 3 天前）
        let settledExpenses = [
            Expense(id: UUID(), amount: 2400, category: roommatesCategories[0], memo: "燒肉聚餐",     date: fiveDaysAgo,  latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: me),
            Expense(id: UUID(), amount: 350,  category: roommatesCategories[1], memo: "全聯日用品",   date: fiveDaysAgo,  latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: alice),
            Expense(id: UUID(), amount: 180,  category: roommatesCategories[4], memo: "飲料",         date: threeDaysAgo, latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: bob),
        ]
        let settledIds = Set(settledExpenses.map { $0.id })

        // 歷史結算紀錄
        var settlementDate = calendar.date(byAdding: .day, value: -2, to: today)!
        settlementDate = calendar.date(bySettingHour: 16, minute: 22, second: 0, of: settlementDate)!
        let pastTransfers = Self.calculateTransfers(expenses: settledExpenses, members: [me, alice, bob])

        ledgers[roommatesIndex].settledExpenseIds = settledIds
        ledgers[roommatesIndex].settlementRecords = [
            SettlementRecord(
                id: UUID(),
                date: settlementDate,
                settledBy: me,
                transfers: pastTransfers,
                currencySymbol: "$"
            ),
        ]

        // 本輪未結算的開銷
        ledgers[roommatesIndex].expenses = settledExpenses + [
            Expense(id: UUID(), amount: 1800, category: roommatesCategories[0], memo: "火鍋聚餐",     date: today,     latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: me),
            Expense(id: UUID(), amount: 520,  category: roommatesCategories[1], memo: "全聯採買",     date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: alice),
            Expense(id: UUID(), amount: 75,   category: roommatesCategories[4], memo: "超商咖啡",     date: today,     latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: bob),
            Expense(id: UUID(), amount: 1200, category: roommatesCategories[3], memo: "衛生紙 + 洗衣精", date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "roommates", paidBy: me),
        ]

        // MARK: 約會帳本（群組）

        guard let datingIndex = ledgers.firstIndex(where: { $0.id == "dating" }) else {
            return
        }
        let datingCategories = ledgers[datingIndex].categories

        ledgers[datingIndex].expenses = [
            Expense(id: UUID(), amount: 1580, category: datingCategories[0], memo: "義式餐廳",     date: today,     latitude: nil, longitude: nil, address: nil, ledgerId: "dating", paidBy: me),
            Expense(id: UUID(), amount: 680,  category: datingCategories[5], memo: "電影票 × 2",   date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "dating", paidBy: alice),
            Expense(id: UUID(), amount: 220,  category: datingCategories[4], memo: "星巴克",       date: yesterday, latitude: nil, longitude: nil, address: nil, ledgerId: "dating", paidBy: me),
        ]
    }
}
