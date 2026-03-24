import Foundation
import SwiftData

@Model
final class PersistentLedger {
    var localId: UUID
    var serverId: Int?
    var name: String
    var type: String
    var currencyCode: String
    var inviteCode: String?
    var sortOrder: Int
    var syncStatus: String
    var lastModified: Date

    @Relationship(deleteRule: .cascade, inverse: \PersistentExpense.ledger)
    var expenses: [PersistentExpense] = []

    @Relationship(deleteRule: .cascade, inverse: \PersistentCategory.ledger)
    var categories: [PersistentCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \PersistentMember.ledger)
    var members: [PersistentMember] = []

    @Relationship(deleteRule: .cascade, inverse: \PersistentRecurringExpense.ledger)
    var recurringExpenses: [PersistentRecurringExpense] = []

    @Relationship(deleteRule: .cascade, inverse: \PersistentSettlement.ledger)
    var settlements: [PersistentSettlement] = []

    init(
        localId: UUID = UUID(),
        serverId: Int? = nil,
        name: String,
        type: String = "personal",
        currencyCode: String = "TWD",
        inviteCode: String? = nil,
        sortOrder: Int = 0,
        syncStatus: String = "pending",
        lastModified: Date = Date()
    ) {
        self.localId = localId
        self.serverId = serverId
        self.name = name
        self.type = type
        self.currencyCode = currencyCode
        self.inviteCode = inviteCode
        self.sortOrder = sortOrder
        self.syncStatus = syncStatus
        self.lastModified = lastModified
    }

    var isGroup: Bool {
        type == "group"
    }

    var ledgerType: LedgerType {
        isGroup ? .group : .personal
    }

    var currency: Currency {
        Currency.all.first { $0.code == currencyCode } ?? .twd
    }

    func toViewModel() -> Ledger {
        let sortedCategories = categories.sorted { $0.sortOrder < $1.sortOrder }
        let sortedExpenses = expenses.sorted { $0.date > $1.date }
        let sortedRecurring = recurringExpenses.sorted { $0.lastModified > $1.lastModified }
        let sortedSettlements = settlements.sorted { $0.date > $1.date }

        let ledgerId = localId.uuidString
        let memberViewModels = members.map { $0.toViewModel() }
        let categoryViewModels = sortedCategories.map { $0.toViewModel() }

        let settledExpenseIds = Set(expenses.filter { $0.isSettled }.map { $0.localId })

        let settlementViewModels = sortedSettlements.map { $0.toViewModel(members: members) }

        return Ledger(
            id: ledgerId,
            name: name,
            type: ledgerType,
            inviteCode: inviteCode,
            members: memberViewModels,
            currency: currency,
            categories: categoryViewModels,
            expenses: sortedExpenses.map { $0.toViewModel(ledgerId: ledgerId) },
            recurringExpenses: sortedRecurring.map { $0.toViewModel(ledgerId: ledgerId) },
            settledExpenseIds: settledExpenseIds,
            settlementRecords: settlementViewModels
        )
    }
}
