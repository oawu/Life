import Foundation
import SwiftData

@Model
final class CachedLedger {
    @Attribute(.unique) var serverId: Int
    var name: String
    var type: String
    var currencyCode: String
    var inviteCode: String?
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \CachedMember.ledger)
    var members: [CachedMember] = []

    @Relationship(deleteRule: .cascade, inverse: \CachedCategory.ledger)
    var categories: [CachedCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \CachedExpense.ledger)
    var expenses: [CachedExpense] = []

    @Relationship(deleteRule: .cascade, inverse: \CachedRecurringExpense.ledger)
    var recurringExpenses: [CachedRecurringExpense] = []

    @Relationship(deleteRule: .cascade, inverse: \CachedSettlement.ledger)
    var settlements: [CachedSettlement] = []

    init(
        serverId: Int,
        name: String,
        type: String = "personal",
        currencyCode: String = "TWD",
        inviteCode: String? = nil,
        sortOrder: Int = 0
    ) {
        self.serverId = serverId
        self.name = name
        self.type = type
        self.currencyCode = currencyCode
        self.inviteCode = inviteCode
        self.sortOrder = sortOrder
    }

    var isGroup: Bool {
        type == "group"
    }

    var currency: Currency {
        Currency.all.first { $0.code == currencyCode } ?? .twd
    }

    func toViewModel() -> Ledger {
        let sortedCategories = categories.sorted { $0.sortOrder < $1.sortOrder }
        let sortedExpenses = expenses.sorted { $0.date > $1.date }
        let sortedRecurring = recurringExpenses.sorted { $0.serverId < $1.serverId }
        let sortedSettlements = settlements.sorted { $0.date > $1.date }

        let ledgerId = String(serverId)
        let memberViewModels = members.map { $0.toViewModel() }
        var categoryViewModels = sortedCategories.map { $0.toViewModel() }
        categoryViewModels.append(ExpenseCategory.otherCategory)

        let categoryMap = Dictionary(categoryViewModels.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let memberMap = Dictionary(memberViewModels.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        let settledExpenseIds = Set(expenses.filter { $0.isSettled }.map { $0.localId })

        return Ledger(
            id: ledgerId,
            name: name,
            type: isGroup ? .group : .personal,
            inviteCode: inviteCode,
            members: memberViewModels,
            currency: currency,
            categories: categoryViewModels,
            expenses: sortedExpenses.map { $0.toViewModel(ledgerId: ledgerId, categoryMap: categoryMap, memberMap: memberMap) },
            recurringExpenses: sortedRecurring.map { $0.toViewModel(ledgerId: ledgerId, categoryMap: categoryMap, memberMap: memberMap) },
            settledExpenseIds: settledExpenseIds,
            settlementRecords: sortedSettlements.map { $0.toViewModel(memberMap: memberMap) }
        )
    }
}
