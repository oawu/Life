import Foundation
import SwiftData

@Model
final class CachedSettlement {
    @Attribute(.unique) var serverId: Int
    var date: Date
    var settledByUserId: Int
    var transfersJson: String
    var currencySymbol: String

    var ledger: CachedLedger?

    init(
        serverId: Int,
        date: Date = Date(),
        settledByUserId: Int,
        transfersJson: String = "[]",
        currencySymbol: String = "$",
        ledger: CachedLedger? = nil
    ) {
        self.serverId = serverId
        self.date = date
        self.settledByUserId = settledByUserId
        self.transfersJson = transfersJson
        self.currencySymbol = currencySymbol
        self.ledger = ledger
    }

    func toViewModel(memberMap: [String: LedgerMember]) -> SettlementRecord {
        let settledBy = memberMap[String(settledByUserId)]
            ?? LedgerMember(id: String(settledByUserId), name: "?")

        let transfers = decodeTransfers(memberMap: memberMap)

        return SettlementRecord(
            id: UUID(uuidString: "00000000-0000-0000-0001-\(String(format: "%012d", serverId))") ?? UUID(),
            date: date,
            settledBy: settledBy,
            transfers: transfers,
            currencySymbol: currencySymbol
        )
    }

    private func decodeTransfers(memberMap: [String: LedgerMember]) -> [SettlementTransfer] {
        guard let data = transfersJson.data(using: .utf8),
              let items = try? JSONDecoder().decode([CachedTransferDTO].self, from: data) else {
            return []
        }

        return items.enumerated().map { index, item in
            let from = memberMap[item.fromUserId] ?? LedgerMember(id: item.fromUserId, name: "?")
            let to = memberMap[item.toUserId] ?? LedgerMember(id: item.toUserId, name: "?")
            let combined = serverId * 1000 + index
            let transferId = UUID(uuidString: "00000000-0000-0000-0002-\(String(format: "%012d", combined))") ?? UUID()
            return SettlementTransfer(id: transferId, from: from, to: to, amount: item.amount)
        }
    }
}

struct CachedTransferDTO: Codable {
    let fromUserId: String
    let toUserId: String
    let amount: Double

    static func encode(transfers: [SettlementTransfer]) -> String {
        let dtos = transfers.map { transfer in
            CachedTransferDTO(
                fromUserId: transfer.from.id,
                toUserId: transfer.to.id,
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
