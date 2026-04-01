import Foundation
import WatchConnectivity
import SwiftUI

final class PhoneSessionManager: NSObject, WCSessionDelegate {
    private let expenseStore: ExpenseStore
    private let session: WCSession
    var isLoggedIn: Bool = false
    var isOnline: Bool = true

    private static let pendingKey = "phone_watch_pending_expenses"

    init(expenseStore: ExpenseStore) {
        self.expenseStore = expenseStore
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            print("[手機連線] 初始化：啟動 session")
        } else {
            print("[手機連線] 初始化：WCSession 不支援")
        }
    }

    // MARK: - Send Ledgers to Watch

    func syncLedgersToWatch() {
        guard session.activationState == .activated else {
            print("[手機連線] 同步帳本到手錶：跳過 — session 未啟動")
            return
        }

        let isLoggedIn = self.isLoggedIn
        let isOnline = self.isOnline
        let session = self.session

        Task { @MainActor [expenseStore] in
            let ledgers = expenseStore.ledgers
            let context = PhoneSessionManager.encodeLedgers(ledgers)

            for ledger in ledgers {
                print("[手機連線]   送出帳本：\(ledger.name) (id=\(ledger.id), 類型=\(ledger.type == .group ? "群組" : "個人"))")
            }
            print("[手機連線] 同步帳本到手錶：送出 \(ledgers.count) 本帳本，isLoggedIn=\(isLoggedIn), isOnline=\(isOnline)")

            let appContext: [String: Any] = [
                "ledgers": context,
                "isLoggedIn": isLoggedIn,
                "isOnline": isOnline,
            ]

            // 嘗試 updateApplicationContext（持久化，Watch 下次開啟時可用）
            do {
                try session.updateApplicationContext(appContext)
                print("[手機連線] 同步帳本到手錶（applicationContext）：成功")
            } catch {
                print("[手機連線] 同步帳本到手錶（applicationContext）：失敗 — \(error.localizedDescription)")
            }

            // 同時用 sendMessage 即時推送（模擬器上 applicationContext 可能失敗）
            if session.isReachable {
                session.sendMessage(appContext, replyHandler: nil) { error in
                    print("[手機連線] 同步帳本到手錶（sendMessage）：失敗 — \(error.localizedDescription)")
                }
                print("[手機連線] 同步帳本到手錶（sendMessage）：已送出")
            }
        }
    }

    // MARK: - Sync Watch Expenses to Backend

    /// 將 Watch 傳來的 pending 開銷透過 ExpenseStore 同步到後端
    func syncWatchExpenses() {
        let pending = loadPendingExpenses()
        if pending.isEmpty {
            return
        }

        print("[手機連線] 同步手錶開銷：\(pending.count) 筆待處理")

        Task { @MainActor [expenseStore] in
            for expense in pending {
                // 帳本已移除 → 丟棄
                guard let ledger = expenseStore.ledgers.first(where: { $0.id == expense.ledgerId }) else {
                    print("[手機連線] 同步手錶開銷：帳本 \(expense.ledgerId) 已移除，丟棄 \(expense.id)")
                    self.removePendingExpense(id: expense.id)
                    continue
                }

                // 群組帳本 + 付款人不存在 → 丟棄
                if ledger.type == .group, let paidById = expense.paidById {
                    if !ledger.members.contains(where: { $0.id == paidById }) {
                        print("[手機連線] 同步手錶開銷：付款人 \(paidById) 不在群組中，丟棄 \(expense.id)")
                        self.removePendingExpense(id: expense.id)
                        continue
                    }
                }

                // 分類不存在 → 歸為「其他」
                let category: ExpenseCategory
                if let found = ledger.categories.first(where: { $0.id == expense.categoryId }) {
                    category = found
                } else {
                    category = ExpenseCategory.otherCategory
                }

                let paidBy: LedgerMember?
                if let paidById = expense.paidById, let paidByName = expense.paidByName {
                    paidBy = LedgerMember(id: paidById, name: paidByName)
                } else {
                    paidBy = nil
                }

                let previousLedgerId = expenseStore.currentLedgerId
                expenseStore.currentLedgerId = expense.ledgerId
                await expenseStore.addExpense(
                    amount: expense.amount,
                    category: category,
                    memo: expense.memo,
                    date: Date(timeIntervalSince1970: expense.date),
                    latitude: expense.latitude,
                    longitude: expense.longitude,
                    address: expense.address,
                    paidBy: paidBy
                )
                expenseStore.currentLedgerId = previousLedgerId

                // addExpense 會打 API（在線時）或建立離線紀錄（離線時），無論哪種都從 pending 移除
                self.removePendingExpense(id: expense.id)
                print("✅ [手機連線] 手錶開銷已處理：id=\(expense.id), 帳本=\(ledger.name), 金額=\(expense.amount)")
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[手機連線] 啟動完成：state=\(activationState.rawValue), isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled), error=\(error?.localizedDescription ?? "無")")
        if activationState == .activated {
            syncLedgersToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[手機連線] session 變為非作用中")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[手機連線] session 已停用 — 重新啟動")
        session.activate()
    }

    // Watch 透過 sendMessage 即時傳送的開銷
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let expenseData = message["expense"] as? [String: Any] {
            print("⬇️⬇️⬇️ [手機連線] 收到手錶開銷（sendMessage）：id=\(expenseData["id"] ?? "nil"), 帳本=\(expenseData["ledgerId"] ?? "nil"), 金額=\(expenseData["amount"] ?? "nil")")
            queueExpense(expenseData)
            syncWatchExpenses()
        }
    }

    // Watch 透過 transferUserInfo 排隊傳送的開銷（iPhone 不在前景時）
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let expenseData = userInfo["expense"] as? [String: Any] {
            print("⬇️⬇️⬇️ [手機連線] 收到手錶開銷（transferUserInfo）：id=\(expenseData["id"] ?? "nil"), 帳本=\(expenseData["ledgerId"] ?? "nil"), 金額=\(expenseData["amount"] ?? "nil")")
            queueExpense(expenseData)
            syncWatchExpenses()
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("[手機連線] 手錶狀態變更：isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled)")
        if session.isPaired && session.isWatchAppInstalled {
            syncLedgersToWatch()
        }
    }

    // MARK: - Pending Queue

    private func queueExpense(_ data: [String: Any]) {
        guard let id = data["id"] as? String,
              let ledgerId = data["ledgerId"] as? String,
              let amount = data["amount"] as? Double,
              let categoryId = data["categoryId"] as? String,
              let dateInterval = data["date"] as? TimeInterval else {
            print("[手機連線] 佇列開銷：資料無效 — 缺少必要欄位")
            return
        }

        // UUID 去重
        var pending = loadPendingExpenses()
        if pending.contains(where: { $0.id == id }) {
            print("[手機連線] 佇列開銷：重複 id=\(id)，跳過")
            return
        }

        let expense = PhonePendingWatchExpense(
            id: id,
            ledgerId: ledgerId,
            amount: amount,
            categoryId: categoryId,
            memo: data["memo"] as? String ?? "",
            date: dateInterval,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            address: data["address"] as? String,
            paidById: data["paidById"] as? String,
            paidByName: data["paidByName"] as? String
        )

        pending.append(expense)
        savePendingExpenses(pending)
        print("[手機連線] 佇列開銷：已加入 id=\(id), 總計=\(pending.count)")
    }

    private func removePendingExpense(id: String) {
        var pending = loadPendingExpenses()
        pending.removeAll { $0.id == id }
        savePendingExpenses(pending)
    }

    private func loadPendingExpenses() -> [PhonePendingWatchExpense] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingKey) else {
            return []
        }
        return (try? JSONDecoder().decode([PhonePendingWatchExpense].self, from: data)) ?? []
    }

    private func savePendingExpenses(_ expenses: [PhonePendingWatchExpense]) {
        if expenses.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.pendingKey)
        } else if let data = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(data, forKey: Self.pendingKey)
        }
    }

    // MARK: - Encoding

    private static func encodeLedgers(_ ledgers: [Ledger]) -> [[String: Any]] {
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

// MARK: - Phone Pending Watch Expense

struct PhonePendingWatchExpense: Codable {
    let id: String
    let ledgerId: String
    let amount: Double
    let categoryId: String
    let memo: String
    let date: TimeInterval
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let paidById: String?
    let paidByName: String?
}
