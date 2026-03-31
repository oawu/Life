import SwiftUI

enum LedgerType: Equatable {
    case personal
    case group
}

struct LedgerMember: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var isCurrentUser: Bool = false
}

struct SettlementTransfer: Identifiable, Equatable {
    let id: UUID
    var from: LedgerMember
    var to: LedgerMember
    var amount: Double
}

struct SettlementRecord: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var settledBy: LedgerMember
    var transfers: [SettlementTransfer]
    var currencySymbol: String
}

struct Ledger: Identifiable, Equatable {
    let id: String
    var name: String
    var type: LedgerType
    var inviteCode: String?
    var members: [LedgerMember]
    var currency: Currency
    var categories: [ExpenseCategory]
    var expenses: [Expense]
    var recurringExpenses: [RecurringExpense]
    var settledExpenseIds: Set<UUID> = []
    var settlementRecords: [SettlementRecord] = []

    var formattedInviteCode: String? {
        guard let inviteCode else {
            return nil
        }
        return "#\(inviteCode)"
    }

    static func generateInviteCode() -> String {
        let characters = Array("ACDEFGHJKMNPQRTUVWXY34679")
        return String((0..<8).map { _ in characters.randomElement()! })
    }
}

extension Ledger {
    /// Watch 初始預設資料（尚未從 iPhone 同步前的 fallback）
    static let watchDefaults: [Ledger] = [
        Ledger(
            id: "watch-default",
            name: "個人",
            type: .personal,
            inviteCode: nil,
            members: [LedgerMember(id: "me", name: "我", isCurrentUser: true)],
            currency: .twd,
            categories: ExpenseCategory.defaults,
            expenses: [],
            recurringExpenses: []
        ),
    ]

    /// 找到當前使用者成員
    var currentUserMember: LedgerMember? {
        members.first { $0.isCurrentUser }
    }
}
