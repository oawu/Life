import Foundation
import SwiftData

@Model
final class PersistentExpense {
    var localId: UUID
    var serverId: Int?
    var amount: Double
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var isSettled: Bool
    var syncStatus: String
    var lastModified: Date

    var ledger: PersistentLedger?
    var category: PersistentCategory?
    var paidBy: PersistentMember?

    init(
        localId: UUID = UUID(),
        serverId: Int? = nil,
        amount: Double,
        memo: String = "",
        date: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        isSettled: Bool = false,
        syncStatus: String = "pending",
        lastModified: Date = Date(),
        ledger: PersistentLedger? = nil,
        category: PersistentCategory? = nil,
        paidBy: PersistentMember? = nil
    ) {
        self.localId = localId
        self.serverId = serverId
        self.amount = amount
        self.memo = memo
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.isSettled = isSettled
        self.syncStatus = syncStatus
        self.lastModified = lastModified
        self.ledger = ledger
        self.category = category
        self.paidBy = paidBy
    }

    func toViewModel(ledgerId: String) -> Expense {
        Expense(
            id: localId,
            amount: amount,
            category: category?.toViewModel() ?? ExpenseCategory(id: "unknown", name: "?", icon: "questionmark", color: .gray),
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address,
            ledgerId: ledgerId,
            paidBy: paidBy?.toViewModel()
        )
    }
}
