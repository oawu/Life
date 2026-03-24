import Foundation
import SwiftData
import SwiftUI

@Model
final class PersistentCategory {
    var localId: UUID
    var serverId: Int?
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int
    var isSystemDefault: Bool
    var syncStatus: String
    var lastModified: Date

    var ledger: PersistentLedger?

    init(
        localId: UUID = UUID(),
        serverId: Int? = nil,
        name: String,
        icon: String,
        colorHex: String,
        sortOrder: Int,
        isSystemDefault: Bool = false,
        syncStatus: String = "pending",
        lastModified: Date = Date(),
        ledger: PersistentLedger? = nil
    ) {
        self.localId = localId
        self.serverId = serverId
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isSystemDefault = isSystemDefault
        self.syncStatus = syncStatus
        self.lastModified = lastModified
        self.ledger = ledger
    }

    func toViewModel() -> ExpenseCategory {
        ExpenseCategory(
            id: localId.uuidString,
            name: name,
            icon: icon,
            color: Color(hex: colorHex)
        )
    }
}
