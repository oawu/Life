import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        PersistentLedger.self,
        PersistentExpense.self,
        PersistentCategory.self,
        PersistentMember.self,
        PersistentRecurringExpense.self,
        PersistentSettlement.self,
    ]
}

enum LifeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self]
    static var stages: [MigrationStage] = []
}
