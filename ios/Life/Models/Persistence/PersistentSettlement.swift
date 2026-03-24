import Foundation
import SwiftData

@Model
final class PersistentSettlement {
    var localId: UUID
    var serverId: Int?
    var date: Date
    var settledByMemberId: UUID
    var transfersJson: String
    var currencySymbol: String
    var syncStatus: String

    var ledger: PersistentLedger?

    init(
        localId: UUID = UUID(),
        serverId: Int? = nil,
        date: Date = Date(),
        settledByMemberId: UUID,
        transfersJson: String = "[]",
        currencySymbol: String = "$",
        syncStatus: String = "pending",
        ledger: PersistentLedger? = nil
    ) {
        self.localId = localId
        self.serverId = serverId
        self.date = date
        self.settledByMemberId = settledByMemberId
        self.transfersJson = transfersJson
        self.currencySymbol = currencySymbol
        self.syncStatus = syncStatus
        self.ledger = ledger
    }

    func toViewModel(members: [PersistentMember]) -> SettlementRecord {
        let settledBy = members.first { $0.localId == settledByMemberId }?.toViewModel()
            ?? LedgerMember(id: settledByMemberId.uuidString, name: "?")

        let transfers = decodeTransfers(members: members)

        return SettlementRecord(
            id: localId,
            date: date,
            settledBy: settledBy,
            transfers: transfers,
            currencySymbol: currencySymbol
        )
    }

    private func decodeTransfers(members: [PersistentMember]) -> [SettlementTransfer] {
        guard let data = transfersJson.data(using: .utf8),
              let items = try? JSONDecoder().decode([TransferDTO].self, from: data) else {
            return []
        }

        let memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.localId, $0.toViewModel()) })

        return items.map { item in
            let from = memberMap[item.fromId] ?? LedgerMember(id: item.fromId.uuidString, name: "?")
            let to = memberMap[item.toId] ?? LedgerMember(id: item.toId.uuidString, name: "?")
            return SettlementTransfer(id: item.id, from: from, to: to, amount: item.amount)
        }
    }
}

struct TransferDTO: Codable {
    let id: UUID
    let fromId: UUID
    let toId: UUID
    let amount: Double

    static func encode(transfers: [SettlementTransfer]) -> String {
        let dtos = transfers.map { transfer in
            TransferDTO(
                id: transfer.id,
                fromId: UUID(uuidString: transfer.from.id) ?? UUID(),
                toId: UUID(uuidString: transfer.to.id) ?? UUID(),
                amount: transfer.amount
            )
        }
        guard let data = try? JSONEncoder().encode(dtos),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
