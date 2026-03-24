import Foundation
import SwiftData

@Model
final class CachedRecurringExpense {
    @Attribute(.unique) var serverId: Int
    var categoryServerId: Int?
    var amount: Int
    var frequencyType: String
    var frequencyValue: String
    var memo: String
    var isEnabled: Bool
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var paidByUserServerId: Int?
    var createdByUserServerId: Int?

    var ledger: CachedLedger?

    init(
        serverId: Int,
        categoryServerId: Int? = nil,
        amount: Int,
        frequencyType: String,
        frequencyValue: String = "",
        memo: String = "",
        isEnabled: Bool = true,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        paidByUserServerId: Int? = nil,
        createdByUserServerId: Int? = nil,
        ledger: CachedLedger? = nil
    ) {
        self.serverId = serverId
        self.categoryServerId = categoryServerId
        self.amount = amount
        self.frequencyType = frequencyType
        self.frequencyValue = frequencyValue
        self.memo = memo
        self.isEnabled = isEnabled
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.paidByUserServerId = paidByUserServerId
        self.createdByUserServerId = createdByUserServerId
        self.ledger = ledger
    }

    var frequency: RecurringFrequency {
        get {
            switch frequencyType {
            case "daily":
                return .daily
            case "weekly":
                return .weekly(dayOfWeek: Int(frequencyValue) ?? 1)
            case "monthly":
                return .monthly(dayOfMonth: Int(frequencyValue) ?? 1)
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

    func toViewModel(ledgerId: String, categoryMap: [String: ExpenseCategory], memberMap: [String: LedgerMember]) -> RecurringExpense {
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

        return RecurringExpense(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", serverId))") ?? UUID(),
            serverId: serverId,
            amount: Double(amount),
            category: category,
            frequency: frequency,
            memo: memo,
            isEnabled: isEnabled,
            latitude: latitude,
            longitude: longitude,
            address: address,
            ledgerId: ledgerId,
            paidBy: paidBy
        )
    }
}
