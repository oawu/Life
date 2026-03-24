import Foundation
import SwiftData

@Model
final class PersistentRecurringExpense {
    var localId: UUID
    var serverId: Int?
    var amount: Double
    var frequencyType: String
    var frequencyValue: String
    var memo: String
    var isEnabled: Bool
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var syncStatus: String
    var lastModified: Date

    var ledger: PersistentLedger?
    var category: PersistentCategory?
    var paidBy: PersistentMember?

    init(
        localId: UUID = UUID(),
        serverId: Int? = nil,
        amount: Double,
        frequencyType: String,
        frequencyValue: String = "",
        memo: String = "",
        isEnabled: Bool = true,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        syncStatus: String = "pending",
        lastModified: Date = Date(),
        ledger: PersistentLedger? = nil,
        category: PersistentCategory? = nil,
        paidBy: PersistentMember? = nil
    ) {
        self.localId = localId
        self.serverId = serverId
        self.amount = amount
        self.frequencyType = frequencyType
        self.frequencyValue = frequencyValue
        self.memo = memo
        self.isEnabled = isEnabled
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.syncStatus = syncStatus
        self.lastModified = lastModified
        self.ledger = ledger
        self.category = category
        self.paidBy = paidBy
    }

    var frequency: RecurringFrequency {
        get {
            switch frequencyType {
            case "daily":
                return .daily
            case "weekly":
                let dayOfWeek = Int(frequencyValue) ?? 1
                return .weekly(dayOfWeek: dayOfWeek)
            case "monthly":
                let dayOfMonth = Int(frequencyValue) ?? 1
                return .monthly(dayOfMonth: dayOfMonth)
            case "yearly":
                let parts = frequencyValue.split(separator: ",")
                let month = Int(parts.first ?? "1") ?? 1
                let day = Int(parts.last ?? "1") ?? 1
                return .yearly(month: month, day: day)
            default:
                return .daily
            }
        }
        set {
            switch newValue {
            case .daily:
                frequencyType = "daily"
                frequencyValue = ""
            case .weekly(let dayOfWeek):
                frequencyType = "weekly"
                frequencyValue = "\(dayOfWeek)"
            case .monthly(let dayOfMonth):
                frequencyType = "monthly"
                frequencyValue = "\(dayOfMonth)"
            case .yearly(let month, let day):
                frequencyType = "yearly"
                frequencyValue = "\(month),\(day)"
            }
        }
    }

    func toViewModel(ledgerId: String) -> RecurringExpense {
        RecurringExpense(
            id: localId,
            amount: amount,
            category: category?.toViewModel() ?? ExpenseCategory(id: "unknown", name: "?", icon: "questionmark", color: .gray),
            frequency: frequency,
            memo: memo,
            isEnabled: isEnabled,
            latitude: latitude,
            longitude: longitude,
            address: address,
            ledgerId: ledgerId,
            paidBy: paidBy?.toViewModel()
        )
    }
}
