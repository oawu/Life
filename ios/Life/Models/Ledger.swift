import SwiftUI

enum LedgerType: Equatable {
    case personal
    case group
}

struct LedgerMember: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
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
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

extension Ledger {
    static let defaultMemberId = "me"

    static let defaults: [Ledger] = {
        let me = LedgerMember(id: defaultMemberId, name: "我")
        let alice = LedgerMember(id: "alice", name: "Alice")
        let bob = LedgerMember(id: "bob", name: "Bob")

        return [
            Ledger(
                id: "personal",
                name: "個人",
                type: .personal,
                inviteCode: nil,
                members: [me],
                currency: .twd,
                categories: ExpenseCategory.defaults,
                expenses: [],
                recurringExpenses: []
            ),
            Ledger(
                id: "roommates",
                name: "室友",
                type: .group,
                inviteCode: "K3XR7N",
                members: [me, alice, bob],
                currency: .twd,
                categories: ExpenseCategory.groupDefaults,
                expenses: [],
                recurringExpenses: []
            ),
            Ledger(
                id: "dating",
                name: "約會",
                type: .group,
                inviteCode: "D4YGWP",
                members: [me, alice],
                currency: .twd,
                categories: ExpenseCategory.groupDefaults,
                expenses: [],
                recurringExpenses: []
            ),
            Ledger(
                id: "family",
                name: "家人",
                type: .group,
                inviteCode: "F7HJMC",
                members: [me, alice],
                currency: .twd,
                categories: ExpenseCategory.groupDefaults,
                expenses: [],
                recurringExpenses: []
            ),
            Ledger(
                id: "travel",
                name: "旅遊",
                type: .group,
                inviteCode: "T9QRVX",
                members: [me, alice],
                currency: .jpy,
                categories: ExpenseCategory.groupDefaults,
                expenses: [],
                recurringExpenses: []
            ),
        ]
    }()
}
