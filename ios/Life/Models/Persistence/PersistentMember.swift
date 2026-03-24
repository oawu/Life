import Foundation
import SwiftData

@Model
final class PersistentMember {
    var localId: UUID
    var serverId: Int?
    var name: String
    var isCurrentUser: Bool
    var syncStatus: String

    var ledger: PersistentLedger?

    init(
        localId: UUID = UUID(),
        serverId: Int? = nil,
        name: String,
        isCurrentUser: Bool = false,
        syncStatus: String = "pending",
        ledger: PersistentLedger? = nil
    ) {
        self.localId = localId
        self.serverId = serverId
        self.name = name
        self.isCurrentUser = isCurrentUser
        self.syncStatus = syncStatus
        self.ledger = ledger
    }

    func toViewModel() -> LedgerMember {
        LedgerMember(id: localId.uuidString, name: name, isCurrentUser: isCurrentUser)
    }
}
