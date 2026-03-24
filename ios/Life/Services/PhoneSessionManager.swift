import Foundation
import WatchConnectivity
import SwiftUI

final class PhoneSessionManager: NSObject, WCSessionDelegate {
    private let expenseStore: ExpenseStore
    private let session: WCSession
    var isLoggedIn: Bool = false
    var isOnline: Bool = true

    init(expenseStore: ExpenseStore) {
        self.expenseStore = expenseStore
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Ledgers to Watch

    func syncLedgersToWatch() {
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            return
        }

        let context = encodeLedgers(expenseStore.ledgers)
        try? session.updateApplicationContext([
            "ledgers": context,
            "isLoggedIn": isLoggedIn,
            "isOnline": isOnline,
        ])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            syncLedgersToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // 即時訊息（Watch reachable 時）
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let expenseData = message["expense"] as? [String: Any] {
            handleExpense(expenseData)
        }
    }

    // 排隊訊息（Watch 不 reachable 時的 fallback）
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let expenseData = userInfo["expense"] as? [String: Any] {
            handleExpense(expenseData)
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        if session.isPaired && session.isWatchAppInstalled {
            syncLedgersToWatch()
        }
    }

    // MARK: - Private

    private func handleExpense(_ data: [String: Any]) {
        guard let ledgerId = data["ledgerId"] as? String,
              let amount = data["amount"] as? Double,
              let categoryId = data["categoryId"] as? String,
              let dateInterval = data["date"] as? TimeInterval else {
            return
        }

        let memo = data["memo"] as? String ?? ""
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let address = data["address"] as? String

        // 找到對應帳本中的分類
        guard let ledger = expenseStore.ledgers.first(where: { $0.id == ledgerId }),
              let category = ledger.categories.first(where: { $0.id == categoryId }) else {
            return
        }

        var paidBy: LedgerMember?
        if let paidById = data["paidById"] as? String,
           let paidByName = data["paidByName"] as? String {
            paidBy = LedgerMember(id: paidById, name: paidByName)
        }

        let previousLedgerId = expenseStore.currentLedgerId

        DispatchQueue.main.async {
            self.expenseStore.currentLedgerId = ledgerId
            self.expenseStore.addExpense(
                amount: amount,
                category: category,
                memo: memo,
                date: Date(timeIntervalSince1970: dateInterval),
                latitude: latitude,
                longitude: longitude,
                address: address,
                paidBy: paidBy
            )
            self.expenseStore.currentLedgerId = previousLedgerId
        }
    }

    // MARK: - Encoding

    private func encodeLedgers(_ ledgers: [Ledger]) -> [[String: Any]] {
        return ledgers.map { ledger in
            var data: [String: Any] = [
                "id":           ledger.id,
                "name":         ledger.name,
                "type":         ledger.type == .group ? "group" : "personal",
                "currencyCode": ledger.currency.code,
                "members":      ledger.members.map { ["id": $0.id, "name": $0.name, "isCurrentUser": $0.isCurrentUser] as [String: Any] },
                "categories":   ledger.categories.map { category in
                    [
                        "id":       category.id,
                        "name":     category.name,
                        "icon":     category.icon,
                        "colorHex": category.color.hexString,
                    ] as [String: Any]
                },
            ]

            if let inviteCode = ledger.inviteCode {
                data["inviteCode"] = inviteCode
            }

            return data
        }
    }

}
