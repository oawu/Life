import Foundation

struct ManifestResponse: Decodable {
    let ledgers: [String: ManifestLedger]
}

struct ManifestLedger: Decodable {
    let version: Int
    let expenses: String
    let name: String
    let type: String
    let currency: String
    let inviteCode: String?
    let members: [StateMember]
    let categories: [StateCategory]
    var recurringExpenses: [StateRecurringExpense] = []
    var settlements: [StateSettlement] = []

    enum CodingKeys: String, CodingKey {
        case version, expenses, name, type, currency, inviteCode
        case members, categories, recurringExpenses, settlements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        expenses = try container.decode(String.self, forKey: .expenses)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        currency = try container.decode(String.self, forKey: .currency)
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        members = try container.decode([StateMember].self, forKey: .members)
        categories = try container.decode([StateCategory].self, forKey: .categories)
        recurringExpenses = try container.decodeIfPresent([StateRecurringExpense].self, forKey: .recurringExpenses) ?? []
        settlements = try container.decodeIfPresent([StateSettlement].self, forKey: .settlements) ?? []
    }
}
