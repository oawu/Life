import Foundation

struct CategoryResponse: Decodable {
    let category: StateCategory
}

struct ExpenseResponse: Decodable {
    let expense: StateExpense
}

struct ExpenseBatchResponse: Decodable {
    let expenses: [StateExpense]
}

struct RecurringExpenseResponse: Decodable {
    let recurringExpense: StateRecurringExpense
}

struct LedgerCreateResponse: Decodable {
    let ledger: StateLedger
}

struct LedgerJoinResponse: Decodable {
    let ledger: StateLedger
}

struct LedgerLeaveResponse: Decodable {
    let success: Bool
}

struct SettleResponse: Decodable {
    let settlement: StateSettlement
}

struct ExpenseFetchResponse: Decodable {
    let expenses: [StateExpense]
}

struct InitResponse: Decodable {
    let ledgers: [StateLedger]
    var uploadedExpenses: [StateExpense] = []

    enum CodingKeys: String, CodingKey {
        case ledgers, uploadedExpenses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ledgers = try container.decode([StateLedger].self, forKey: .ledgers)
        uploadedExpenses = try container.decodeIfPresent([StateExpense].self, forKey: .uploadedExpenses) ?? []
    }
}

struct SuccessResponse: Decodable {
    let success: Bool
}
