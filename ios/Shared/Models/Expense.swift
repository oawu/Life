import Foundation

struct Expense: Identifiable, Equatable {
    let id: UUID
    var serverId: Int?
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
