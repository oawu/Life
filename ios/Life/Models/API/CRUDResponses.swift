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

struct SuccessResponse: Decodable {
    let success: Bool
}
