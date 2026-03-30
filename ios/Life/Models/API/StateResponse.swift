import Foundation

struct StateResponse: Decodable {
    let ledgers: [StateLedger]
}

struct StateLedger: Decodable {
    let id: Int
    let name: String
    let type: String
    let currency: String
    let inviteCode: String?
    let members: [StateMember]
    let categories: [StateCategory]
    var expenses: [StateExpense] = []
    var recurringExpenses: [StateRecurringExpense] = []
    var settlements: [StateSettlement] = []

    enum CodingKeys: String, CodingKey {
        case id, name, type, currency, inviteCode, members, categories
        case expenses, recurringExpenses, settlements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        currency = try container.decode(String.self, forKey: .currency)
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        members = try container.decode([StateMember].self, forKey: .members)
        categories = try container.decode([StateCategory].self, forKey: .categories)
        expenses = try container.decodeIfPresent([StateExpense].self, forKey: .expenses) ?? []
        recurringExpenses = try container.decodeIfPresent([StateRecurringExpense].self, forKey: .recurringExpenses) ?? []
        settlements = try container.decodeIfPresent([StateSettlement].self, forKey: .settlements) ?? []
    }
}

struct StateMember: Decodable {
    let id: Int
    let userId: Int
    let name: String
    let role: String
    let isCurrentUser: Bool
}

struct StateCategory: Decodable {
    let id: Int
    let key: String?
    let name: String
    let icon: String
    let color: String
    let sort: Int
}

struct StateExpense: Decodable {
    let id: Int
    let categoryId: Int?
    let amount: Int
    let memo: String
    let date: String
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let isSettled: Bool
    let paidByUserId: Int?
    let createdByUserId: Int
}

struct StateRecurringExpense: Decodable {
    let id: Int
    let categoryId: Int?
    let amount: Int
    let frequencyType: String
    let frequencyValue: AnyCodable?
    let memo: String
    let isEnabled: Bool
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let paidByUserId: Int?
    let lastTriggeredDate: String?
}

struct StateSettlement: Decodable {
    let id: Int
    let settledByUserId: Int
    let transfers: AnyCodable?
    let currencySymbol: String
    let createAt: String
}

// 用於解碼任意 JSON 值
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = NSNull()
        }
    }
}
