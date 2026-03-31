import Foundation
import SwiftData

enum LifeSchema {
    static var models: [any PersistentModel.Type] = [
        GuestExpense.self,
        CachedLedger.self,
        CachedCategory.self,
        CachedExpense.self,
        CachedMember.self,
        CachedRecurringExpense.self,
        CachedSettlement.self,
    ]
}
