import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
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

enum LifeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self]
    static var stages: [MigrationStage] = []
}
