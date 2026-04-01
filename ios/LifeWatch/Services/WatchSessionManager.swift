import Foundation
import SwiftUI
import WatchConnectivity

@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    private let store: WatchExpenseStore
    private let session: WCSession
    var isReachable: Bool = false

    init(store: WatchExpenseStore) {
        self.store = store
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            print("[手錶連線] 初始化：啟動 session")
        } else {
            print("[手錶連線] 初始化：WCSession 不支援")
        }
    }

    // MARK: - Send Expense to iPhone

    func sendExpense(_ pending: WatchPendingExpense) {
        let data = pending.asDict

        guard session.activationState == .activated else {
            print("[手錶連線] 送出開銷：session 未啟動，保留在佇列")
            return
        }

        if session.isReachable {
            // iPhone 在前景 → sendMessage 即時送達
            session.sendMessage(["expense": data], replyHandler: nil) { error in
                print("[手錶連線] sendMessage 失敗：\(error.localizedDescription)，改用 transferUserInfo")
                self.session.transferUserInfo(["expense": data])
            }
            print("⬆️⬆️⬆️ [手錶連線] sendMessage 送出開銷：id=\(pending.id), 帳本=\(pending.ledgerId), 金額=\(pending.amount)")
        } else {
            // iPhone 不在前景 → transferUserInfo 排隊送達
            session.transferUserInfo(["expense": data])
            print("⬆️⬆️⬆️ [手錶連線] transferUserInfo 送出開銷：id=\(pending.id), 帳本=\(pending.ledgerId), 金額=\(pending.amount)")
        }
        store.removePendingExpense(id: pending.id)
    }

    /// 將所有 pending expenses 送出
    func flushPendingExpenses() {
        guard session.activationState == .activated else {
            print("[手錶連線] 清除佇列：session 未啟動，跳過")
            return
        }

        let pending = store.loadPendingExpenses()
        if pending.isEmpty {
            return
        }

        print("[手錶連線] 清除佇列：送出 \(pending.count) 筆，isReachable=\(session.isReachable)")
        for expense in pending {
            let data = expense.asDict
            if session.isReachable {
                session.sendMessage(["expense": data], replyHandler: nil) { error in
                    print("[手錶連線] 清除佇列 sendMessage 失敗：\(error.localizedDescription)，改用 transferUserInfo")
                    self.session.transferUserInfo(["expense": data])
                }
            } else {
                session.transferUserInfo(["expense": data])
            }
            store.removePendingExpense(id: expense.id)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[手錶連線] 啟動完成：state=\(activationState.rawValue), error=\(error?.localizedDescription ?? "無")")
        if activationState == .activated {
            DispatchQueue.main.async {
                self.isReachable = session.isReachable
            }
            let context = session.receivedApplicationContext
            print("[手錶連線] 已存 applicationContext：keys=\(context.keys.joined(separator: ", ")), 是否為空=\(context.isEmpty)")
            if !context.isEmpty {
                handleContext(context)
            }

            // Session 就緒 → 送出所有待傳開銷
            DispatchQueue.main.async {
                self.flushPendingExpenses()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("[手錶連線] 收到 applicationContext：keys=\(applicationContext.keys.joined(separator: ", "))")
        handleContext(applicationContext)
    }

    // iPhone 透過 sendMessage 即時推送帳本資料（模擬器上 applicationContext 可能失敗）
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["ledgers"] != nil {
            print("[手錶連線] 收到 sendMessage 帳本推送：keys=\(message.keys.joined(separator: ", "))")
            handleContext(message)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[手錶連線] 連線狀態變更：isReachable=\(session.isReachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    // MARK: - Private

    private func handleContext(_ context: [String: Any]) {
        let isLoggedIn = context["isLoggedIn"] as? Bool
        let isOnline = context["isOnline"] as? Bool
        let ledgersData = context["ledgers"] as? [[String: Any]]

        print("[手錶連線] 處理 context：isLoggedIn=\(isLoggedIn.map(String.init(describing:)) ?? "nil"), isOnline=\(isOnline.map(String.init(describing:)) ?? "nil"), 帳本數=\(ledgersData?.count ?? 0)")

        let ledgers = ledgersData?.compactMap { decodeLedger($0) }

        if let ledgersData, let ledgers, ledgersData.count != ledgers.count {
            print("[手錶連線] 解碼帳本：成功 \(ledgers.count)/\(ledgersData.count)（部分失敗）")
        }

        if let ledgers = ledgers {
            for ledger in ledgers {
                print("[手錶連線]   帳本：\(ledger.name) (id=\(ledger.id), 類型=\(ledger.type == .group ? "群組" : "個人"), 幣別=\(ledger.currency.code))")
                print("[手錶連線]     成員(\(ledger.members.count))：\(ledger.members.map { "\($0.name)\($0.isCurrentUser ? "*" : "")" }.joined(separator: ", "))")
                print("[手錶連線]     分類(\(ledger.categories.count))：\(ledger.categories.map { $0.name }.joined(separator: ", "))")
            }
        }

        DispatchQueue.main.async {
            if let isLoggedIn = isLoggedIn {
                self.store.isLoggedIn = isLoggedIn
            }
            if let isOnline = isOnline {
                self.store.isOnline = isOnline
            }
            if let ledgers = ledgers, !ledgers.isEmpty {
                self.store.updateFromPhone(ledgers: ledgers)
                print("[手錶連線] 已更新 store：\(ledgers.count) 本帳本")
            }
        }
    }

    // MARK: - Decoding

    private func decodeLedger(_ data: [String: Any]) -> Ledger? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let typeRaw = data["type"] as? String else {
            print("[手錶連線] 解碼帳本失敗：缺少必要欄位 \(data.keys.joined(separator: ", "))")
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
