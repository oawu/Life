import Foundation
import SwiftUI
import WatchConnectivity

final class WatchSessionManager: NSObject, WCSessionDelegate {
    private let store: WatchExpenseStore
    private let session: WCSession

    init(store: WatchExpenseStore) {
        self.store = store
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Expense to iPhone

    func sendExpense(_ expense: Expense) {
        let data = encodeExpense(expense)

        // 優先即時傳送，失敗時 fallback 排隊保證送達
        if session.isReachable {
            session.sendMessage(["expense": data], replyHandler: nil) { [weak self] _ in
                self?.session.transferUserInfo(["expense": data])
            }
        } else {
            session.transferUserInfo(["expense": data])
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // 啟動完成，檢查是否有 applicationContext
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                handleContext(context)
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleContext(applicationContext)
    }

    // MARK: - Private

    private func handleContext(_ context: [String: Any]) {
        let isLoggedIn = context["isLoggedIn"] as? Bool
        let isOnline = context["isOnline"] as? Bool
        let ledgersData = context["ledgers"] as? [[String: Any]]

        let ledgers = ledgersData?.compactMap { decodeLedger($0) }

        DispatchQueue.main.async {
            if let isLoggedIn = isLoggedIn {
                self.store.isLoggedIn = isLoggedIn
            }
            if let isOnline = isOnline {
                self.store.isOnline = isOnline
            }
            if let ledgers = ledgers, !ledgers.isEmpty {
                self.store.updateFromPhone(ledgers: ledgers)
            }
        }
    }

    // MARK: - Encoding

    private func encodeExpense(_ expense: Expense) -> [String: Any] {
        var data: [String: Any] = [
            "id":         expense.id.uuidString,
            "amount":     expense.amount,
            "categoryId": expense.category.id,
            "memo":       expense.memo,
            "date":       expense.date.timeIntervalSince1970,
            "ledgerId":   expense.ledgerId,
        ]

        if let latitude = expense.latitude {
            data["latitude"] = latitude
        }
        if let longitude = expense.longitude {
            data["longitude"] = longitude
        }
        if let address = expense.address {
            data["address"] = address
        }
        if let paidBy = expense.paidBy {
            data["paidById"] = paidBy.id
            data["paidByName"] = paidBy.name
        }

        return data
    }

    // MARK: - Decoding

    private func decodeLedger(_ data: [String: Any]) -> Ledger? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let typeRaw = data["type"] as? String else {
            return nil
        }

        let type: LedgerType = typeRaw == "group" ? .group : .personal

        let members: [LedgerMember] = (data["members"] as? [[String: Any]])?.compactMap { memberData in
            guard let memberId = memberData["id"] as? String,
                  let memberName = memberData["name"] as? String else {
                return nil
            }
            let isCurrentUser = memberData["isCurrentUser"] as? Bool ?? false
            return LedgerMember(id: memberId, name: memberName, isCurrentUser: isCurrentUser)
        } ?? []

        let currencyCode = data["currencyCode"] as? String ?? "TWD"
        let currency = Currency.all.first { $0.code == currencyCode } ?? .twd

        let categories: [ExpenseCategory] = (data["categories"] as? [[String: Any]])?.compactMap { catData in
            guard let catId = catData["id"] as? String,
                  let catName = catData["name"] as? String,
                  let icon = catData["icon"] as? String else {
                return nil
            }
            let colorHex = catData["colorHex"] as? String
            let color = colorHex.map { Color(hex: $0) } ?? .gray
            return ExpenseCategory(id: catId, name: catName, icon: icon, color: color)
        } ?? []

        return Ledger(
            id: id,
            name: name,
            type: type,
            inviteCode: data["inviteCode"] as? String,
            members: members,
            currency: currency,
            categories: categories,
            expenses: [],
            recurringExpenses: []
        )
    }

}
