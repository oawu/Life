import Foundation
import SwiftData

@Model
final class GuestExpense {
    var id: UUID = UUID()
    var categoryKey: String
    var amount: Int
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?

    init(
        id: UUID = UUID(),
        categoryKey: String,
        amount: Int,
        memo: String = "",
        date: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.categoryKey = categoryKey
        self.amount = amount
        self.memo = memo
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
}
