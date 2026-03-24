import Foundation

// MARK: - Sync API Models

struct SyncPushResponse: Decodable {
    let mappings: SyncMappings
}

struct SyncMappings: Decodable {
    let ledgers: [SyncIdMapping]
    let categories: [SyncIdMapping]
    let expenses: [SyncIdMapping]
    let recurringExpenses: [SyncIdMapping]
}

struct SyncIdMapping: Decodable {
    let localId: String
    let serverId: Int
}

struct SyncPullResponse: Decodable {
    let ledgers: [SyncLedger]
    let serverTime: String
}

struct SyncLedger: Decodable {
    let serverId: Int
    let name: String
    let type: String
    let currency: String
    let inviteCode: String?
    let members: [SyncMember]
    let categories: [SyncCategory]
    let expenses: [SyncExpense]
    let recurringExpenses: [SyncRecurringExpense]
    let settlements: [SyncSettlement]
}

struct SyncMember: Decodable {
    let serverId: Int
    let userId: Int
    let name: String
    let role: String
    let isCurrentUser: Bool
}

struct SyncCategory: Decodable {
    let serverId: Int
    let localId: String
    let name: String
    let icon: String
    let color: String
    let sort: Int
    let isSystemDefault: Bool
}

struct SyncExpense: Decodable {
    let serverId: Int
    let localId: String
    let categoryId: Int
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

struct SyncRecurringExpense: Decodable {
    let serverId: Int
    let localId: String
    let categoryId: Int
    let amount: Int
    let frequencyType: String
    let frequencyValue: AnyCodable?
    let memo: String
    let isEnabled: Bool
    let paidByUserId: Int?
}

struct SyncSettlement: Decodable {
    let serverId: Int
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
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = NSNull()
        }
    }
}

// MARK: - SyncEngine

@Observable
final class SyncEngine {
    var isSyncing = false

    private let dataManager: DataManager
    private let networkMonitor: NetworkMonitor

    private let lastSyncAtKey = "SyncEngine.lastSyncAt"

    var lastSyncAt: String? {
        get { UserDefaults.standard.string(forKey: lastSyncAtKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncAtKey) }
    }

    init(dataManager: DataManager, networkMonitor: NetworkMonitor) {
        self.dataManager = dataManager
        self.networkMonitor = networkMonitor
    }

    func fullSync() async {
        guard networkMonitor.isOnline else {
            return
        }
        guard !isSyncing else {
            return
        }

        await MainActor.run {
            isSyncing = true
        }

        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }

        await push()
        await pull()
    }

    /// 登入同步：先 pull 再 push，避免將空白預設帳本推送到 Server 造成重複
    func loginSync() async {
        guard networkMonitor.isOnline else {
            return
        }
        guard !isSyncing else {
            return
        }

        await MainActor.run {
            isSyncing = true
        }

        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }

        await pull()
        await MainActor.run {
            dataManager.removeUnsyncedEmptyPersonalLedgers()
        }
        await push()
    }

    // MARK: - Push

    private func push() async {
        let payload = await MainActor.run {
            dataManager.buildSyncPushPayload()
        }

        guard !payload.isEmpty else {
            return
        }

        do {
            let response = try await APIClient.shared.post(
                path: "/api/sync/push",
                body: ["ledgers": payload],
                responseType: SyncPushResponse.self
            )

            await MainActor.run {
                dataManager.applySyncMappings(response.mappings)
            }
        } catch {
            print("[SyncEngine] push error: \(error)")
        }
    }

    // MARK: - Pull

    private func pull() async {
        let body: [String: Any] = lastSyncAt != nil ? ["lastSyncAt": lastSyncAt!] : [:]

        do {
            let response = try await APIClient.shared.post(
                path: "/api/sync/pull",
                body: body.isEmpty ? nil : body,
                responseType: SyncPullResponse.self
            )

            await MainActor.run {
                dataManager.mergeRemoteData(response.ledgers)
                lastSyncAt = response.serverTime
            }
        } catch {
            print("[SyncEngine] pull error: \(error)")
        }
    }
}
