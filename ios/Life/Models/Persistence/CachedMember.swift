import Foundation
import SwiftData

@Model
final class CachedMember {
    @Attribute(.unique) var serverId: Int
    var userId: Int
    var name: String
    var role: String
    var isCurrentUser: Bool

    var ledger: CachedLedger?

    init(
        serverId: Int,
        userId: Int,
        name: String,
        role: String = "member",
        isCurrentUser: Bool = false,
        ledger: CachedLedger? = nil
    ) {
        self.serverId = serverId
        self.userId = userId
        self.name = name
        self.role = role
        self.isCurrentUser = isCurrentUser
        self.ledger = ledger
    }

    func toViewModel() -> LedgerMember {
        LedgerMember(id: String(userId), name: name, isCurrentUser: isCurrentUser)
    }
}
