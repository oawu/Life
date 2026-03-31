import Foundation
import SwiftData

@Model
final class CachedExpense {
    var localId: UUID = UUID()
    var serverId: Int?
    var categoryServerId: Int?
    var amount: Int
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var isSettled: Bool
    var paidByUserServerId: Int?
    var createdByUserServerId: Int?
    var isSynced: Bool
    var version: Int

    var ledger: CachedLedger?

    init(
        localId: UUID = UUID(),
        serverId: Int? = nil,
        categoryServerId: Int? = nil,
        amount: Int,
        memo: String = "",
        date: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        isSettled: Bool = false,
        paidByUserServerId: Int? = nil,
        createdByUserServerId: Int? = nil,
        isSynced: Bool = true,
        version: Int = 0,
        ledger: CachedLedger? = nil
    ) {
        self.localId = localId
        self.serverId = serverId
        self.categoryServerId = categoryServerId
        self.amount = amount
        self.memo = memo
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.isSettled = isSettled
        self.paidByUserServerId = paidByUserServerId
        self.createdByUserServerId = createdByUserServerId
        self.isSynced = isSynced
        self.version = version
        self.ledger = ledger
    }

    func toViewModel(ledgerId: String, categoryMap: [String: ExpenseCategory], memberMap: [String: LedgerMember]) -> Expense {
        let category: ExpenseCategory
        if let catId = categoryServerId {
            category = categoryMap[String(catId)] ?? ExpenseCategory.otherCategory
        } else {
            category = ExpenseCategory.otherCategory
        }

        let paidBy: LedgerMember?
        if let payerId = paidByUserServerId {
            paidBy = memberMap[String(payerId)]
        } else {
            paidBy = nil
        }

        return Expense(
            id: localId,
            serverId: serverId,
            amount: Double(amount),
            category: category,
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address,
            ledgerId: ledgerId,
            paidBy: paidBy,
            isSynced: isSynced
        )
    }
}
