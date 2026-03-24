import Foundation
import SwiftData
import SwiftUI

@Model
final class CachedCategory {
    @Attribute(.unique) var serverId: Int
    var key: String?
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int

    var ledger: CachedLedger?

    init(
        serverId: Int,
        key: String? = nil,
        name: String,
        icon: String,
        colorHex: String,
        sortOrder: Int,
        ledger: CachedLedger? = nil
    ) {
        self.serverId = serverId
        self.key = key
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.ledger = ledger
    }

    func toViewModel() -> ExpenseCategory {
        ExpenseCategory(
            id: String(serverId),
            key: key,
            name: name,
            icon: icon,
            color: Color(hex: colorHex)
        )
    }
}
