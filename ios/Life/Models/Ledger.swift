import SwiftUI

enum LedgerType: Equatable {
    case personal
    case group
}

struct LedgerMember: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
}

struct Ledger: Identifiable, Equatable {
    let id: String
    var name: String
    var icon: String
    var type: LedgerType
    var members: [LedgerMember]
    var categories: [ExpenseCategory]
    var expenses: [Expense]
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
                icon: "person.fill",
                type: .personal,
                members: [me],
                categories: ExpenseCategory.defaults,
                expenses: []
            ),
            Ledger(
                id: "roommates",
                name: "室友",
                icon: "house.fill",
                type: .group,
                members: [me, alice, bob],
                categories: ExpenseCategory.groupDefaults,
                expenses: []
            ),
            Ledger(
                id: "dating",
                name: "約會",
                icon: "heart.fill",
                type: .group,
                members: [me, alice],
                categories: ExpenseCategory.groupDefaults,
                expenses: []
            ),
            Ledger(
                id: "family",
                name: "家人",
                icon: "heart.fill",
                type: .group,
                members: [me, alice],
                categories: ExpenseCategory.groupDefaults,
                expenses: []
            ),
            Ledger(
                id: "travel",
                name: "旅遊",
                icon: "heart.fill",
                type: .group,
                members: [me, alice],
                categories: ExpenseCategory.groupDefaults,
                expenses: []
            ),
        ]
    }()
}
