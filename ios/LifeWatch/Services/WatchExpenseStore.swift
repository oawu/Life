import Foundation
import SwiftUI

@Observable @MainActor
final class WatchExpenseStore {
    var ledgers: [Ledger] = Ledger.watchDefaults
    var selectedLedgerId: String = "watch-default"
    var hasSyncedFromPhone: Bool = false
    var isLoggedIn: Bool = false
    var isOnline: Bool = true
    var isFetching: Bool = false

    var token: String? {
        didSet { UserDefaults.standard.set(token, forKey: Self.tokenKey) }
    }

    private static let tokenKey = "watch_auth_token"
    private static let ledgerCacheKey = "watch_cached_ledgers"
    private static let maxOfflineSize = 50

    init() {
        self.token = UserDefaults.standard.string(forKey: Self.tokenKey)
        loadCachedLedgers()
    }

    // MARK: - Computed Properties

    var availableLedgers: [Ledger] {
        ledgers
    }

    var currentLedger: Ledger? {
        ledgers.first { $0.id == selectedLedgerId }
    }

    var categories: [ExpenseCategory] {
        currentLedger?.categories ?? []
    }

    var isGroupLedger: Bool {
        currentLedger?.type == .group
    }

    var currentMembers: [LedgerMember] {
        currentLedger?.members ?? []
    }

    var currentCurrency: Currency {
        currentLedger?.currency ?? .twd
    }

    // MARK: - Sync from iPhone

    func updateFromPhone(ledgers: [Ledger]) {
        self.ledgers = ledgers
        hasSyncedFromPhone = true
        cacheLedgers(ledgers)

        if !availableLedgers.contains(where: { $0.id == selectedLedgerId }) {
            selectedLedgerId = availableLedgers.first?.id ?? "personal"
        }
    }

    // MARK: - API Fetch Ledgers

    func fetchLedgers() async {
        guard let token = token else {
            return
        }

        isFetching = true

        do {
            let response = try await WatchAPIClient.shared.get(
                path: "/api/state",
                token: token,
                responseType: StateResponse.self
            )
            let newLedgers = response.ledgers.map { convertStateLedger($0) }
            if !newLedgers.isEmpty {
                self.ledgers = newLedgers
                self.hasSyncedFromPhone = true
                cacheLedgers(newLedgers)
            }
            print("[手錶 API] fetchLedgers 成功：\(newLedgers.count) 本帳本")
        } catch let error as WatchAPIError where error.isUnauthorized {
            print("[手錶 API] fetchLedgers 失敗：token 過期")
            self.token = nil
            self.isLoggedIn = false
        } catch {
            print("[手錶 API] fetchLedgers 失敗：\(error.localizedDescription)")
            loadCachedLedgers()
        }

        isFetching = false
    }

    // MARK: - API Create Expense

    enum SaveResult {
        case success
        case queued
    }

    func createExpense(
        amount: Int,
        categoryId: String,
        memo: String,
        date: Date,
        latitude: Double?,
        longitude: Double?,
        address: String?,
        paidByUserId: String?,
        ledgerId: String
    ) async -> SaveResult {
        guard let token = token else {
            print("[手錶 API] createExpense 失敗：無 token")
            return .queued
        }

        // 找出帳本的 serverId（Ledger.id 格式為 String(serverId)）
        guard let ledgerServerId = Int(ledgerId) else {
            print("[手錶 API] createExpense 失敗：無效的帳本 ID=\(ledgerId)")
            return .queued
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var body: [String: Any] = [
            "amount": amount,
            "memo":   memo,
            "date":   dateFormatter.string(from: date),
        ]
        if let catId = Int(categoryId) {
            body["categoryId"] = catId
        }
        if let lat = latitude {
            body["latitude"] = lat
        }
        if let lng = longitude {
            body["longitude"] = lng
        }
        if let addr = address {
            body["address"] = addr
        }
        if let pid = paidByUserId, let uid = Int(pid) {
            body["paidByUserId"] = uid
        }

        do {
            _ = try await WatchAPIClient.shared.post(
                path: "/api/ledgers/\(ledgerServerId)/expenses",
                body: body,
                token: token,
                responseType: ExpenseResponse.self
            )
            print("[手錶 API] createExpense 成功：金額=\(amount), 帳本=\(ledgerServerId)")

            // 成功後背景清除離線佇列（不阻塞 UI）
            Task { await flushPendingExpenses() }

            return .success
        } catch let error as WatchAPIError where error.isUnauthorized {
            print("[手錶 API] createExpense 失敗：token 過期")
            self.token = nil
            self.isLoggedIn = false
            queueOfflineExpense(body: body, ledgerServerId: ledgerServerId)
            return .queued
        } catch {
            print("[手錶 API] createExpense 失敗：\(error)")
            queueOfflineExpense(body: body, ledgerServerId: ledgerServerId)
            return .queued
        }
    }

    // MARK: - Offline Queue

    private static let offlineQueueKey = "watch_offline_expenses"

    var offlinePendingCount: Int {
        loadOfflineQueue().count
    }

    func queueOfflineExpense(body: [String: Any], ledgerServerId: Int) {
        var queue = loadOfflineQueue()

        let entry = OfflineExpense(
            id: UUID().uuidString,
            ledgerServerId: ledgerServerId,
            body: body.compactMapValues { AnyCodableValue($0) },
            queuedAt: Date()
        )
        queue.append(entry)

        if queue.count > Self.maxOfflineSize {
            queue = Array(queue.suffix(Self.maxOfflineSize))
        }

        saveOfflineQueue(queue)
        print("[手錶離線] 加入離線佇列：總計=\(queue.count)")
    }

    func flushPendingExpenses() async {
        guard let token = token else {
            return
        }

        let queue = loadOfflineQueue()
        if queue.isEmpty {
            return
        }

        print("[手錶離線] 清除佇列：\(queue.count) 筆")
        var remaining: [OfflineExpense] = []

        for expense in queue {
            do {
                _ = try await WatchAPIClient.shared.post(
                    path: "/api/ledgers/\(expense.ledgerServerId)/expenses",
                    body: expense.bodyAsDict,
                    token: token,
                    responseType: ExpenseResponse.self
                )
                print("[手錶離線] 佇列開銷上傳成功：id=\(expense.id)")
            } catch let error as WatchAPIError where error.isUnauthorized {
                print("[手錶離線] token 過期，停止清除佇列")
                self.token = nil
                self.isLoggedIn = false
                remaining.append(contentsOf: queue.suffix(from: queue.firstIndex(where: { $0.id == expense.id })!))
                break
            } catch {
                print("[手錶離線] 佇列開銷上傳失敗：\(error)")
                print("[手錶離線] 佇列內容：ledgerServerId=\(expense.ledgerServerId), body=\(expense.bodyAsDict)")
                remaining.append(expense)
            }
        }

        saveOfflineQueue(remaining)
    }

    private func loadOfflineQueue() -> [OfflineExpense] {
        guard let data = UserDefaults.standard.data(forKey: Self.offlineQueueKey) else {
            return []
        }
        return (try? JSONDecoder().decode([OfflineExpense].self, from: data)) ?? []
    }

    private func saveOfflineQueue(_ queue: [OfflineExpense]) {
        if queue.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.offlineQueueKey)
        } else if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: Self.offlineQueueKey)
        }
    }

    // MARK: - Ledger Cache

    private func cacheLedgers(_ ledgers: [Ledger]) {
        let cacheData = ledgers.map { CachedWatchLedger(from: $0) }
        if let data = try? JSONEncoder().encode(cacheData) {
            UserDefaults.standard.set(data, forKey: Self.ledgerCacheKey)
        }
    }

    private func loadCachedLedgers() {
        guard let data = UserDefaults.standard.data(forKey: Self.ledgerCacheKey),
              let cached = try? JSONDecoder().decode([CachedWatchLedger].self, from: data) else {
            return
        }
        let restored = cached.map { $0.toLedger() }
        if !restored.isEmpty {
            self.ledgers = restored
            self.hasSyncedFromPhone = true
            print("[手錶快取] 讀取本地帳本：\(restored.count) 本")
        }
    }

    // MARK: - StateLedger → Ledger

    private func convertStateLedger(_ state: StateLedger) -> Ledger {
        let type: LedgerType = state.type == "group" ? .group : .personal
        let currency = Currency.all.first { $0.code == state.currency } ?? .twd

        let members = state.members.map { member in
            LedgerMember(
                id: String(member.id),
                name: member.name,
                isCurrentUser: member.isCurrentUser
            )
        }

        let categories = state.categories.sorted { $0.sort < $1.sort }.map { cat in
            ExpenseCategory(
                id: String(cat.id),
                name: cat.name,
                icon: cat.icon,
                color: Color(hex: cat.color)
            )
        }

        return Ledger(
            id: String(state.id),
            name: state.name,
            type: type,
            inviteCode: state.inviteCode,
            members: members,
            currency: currency,
            categories: categories,
            expenses: [],
            recurringExpenses: []
        )
    }
}

// MARK: - Offline Expense

struct OfflineExpense: Codable {
    let id: String
    let ledgerServerId: Int
    let body: [String: AnyCodableValue]
    let queuedAt: Date

    var bodyAsDict: [String: Any] {
        body.mapValues { $0.value }
    }
}

enum AnyCodableValue: Codable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)

    init?(_ value: Any) {
        if let intVal = value as? Int {
            self = .int(intVal)
        } else if let doubleVal = value as? Double {
            self = .double(doubleVal)
        } else if let stringVal = value as? String {
            self = .string(stringVal)
        } else if let boolVal = value as? Bool {
            self = .bool(boolVal)
        } else {
            return nil
        }
    }

    var value: Any {
        switch self {
        case .int(let val):
            return val
        case .double(let val):
            return val
        case .string(let val):
            return val
        case .bool(let val):
            return val
        }
    }
}

// MARK: - Cached Watch Ledger (for UserDefaults persistence)

struct CachedWatchLedger: Codable {
    let id: String
    let name: String
    let type: String
    let inviteCode: String?
    let currencyCode: String
    let members: [CachedWatchMember]
    let categories: [CachedWatchCategory]

    init(from ledger: Ledger) {
        id = ledger.id
        name = ledger.name
        type = ledger.type == .group ? "group" : "personal"
        inviteCode = ledger.inviteCode
        currencyCode = ledger.currency.code
        members = ledger.members.map { CachedWatchMember(from: $0) }
        categories = ledger.categories.map { CachedWatchCategory(from: $0) }
    }

    func toLedger() -> Ledger {
        let ledgerType: LedgerType = type == "group" ? .group : .personal
        let currency = Currency.all.first { $0.code == currencyCode } ?? .twd

        return Ledger(
            id: id,
            name: name,
            type: ledgerType,
            inviteCode: inviteCode,
            members: members.map { $0.toMember() },
            currency: currency,
            categories: categories.map { $0.toCategory() },
            expenses: [],
            recurringExpenses: []
        )
    }
}

struct CachedWatchMember: Codable {
    let id: String
    let name: String
    let isCurrentUser: Bool

    init(from member: LedgerMember) {
        id = member.id
        name = member.name
        isCurrentUser = member.isCurrentUser
    }

    func toMember() -> LedgerMember {
        LedgerMember(id: id, name: name, isCurrentUser: isCurrentUser)
    }
}

struct CachedWatchCategory: Codable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String

    init(from category: ExpenseCategory) {
        id = category.id
        name = category.name
        icon = category.icon
        colorHex = category.color.hexString
    }

    func toCategory() -> ExpenseCategory {
        ExpenseCategory(id: id, name: name, icon: icon, color: Color(hex: colorHex))
    }
}

