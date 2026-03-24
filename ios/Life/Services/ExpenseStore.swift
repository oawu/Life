import Foundation
import SwiftData
import SwiftUI

enum OfflineError: LocalizedError {
    case noConnection

    var errorDescription: String? {
        "目前無法連線，請稍後再試"
    }
}

@MainActor
@Observable
final class ExpenseStore {
    private let dataManager: DataManager
    private let authManager: AuthManager
    private let networkMonitor: NetworkMonitor
    var ledgers: [Ledger] = []
    var currentLedgerId: String = ""

    var categories: [ExpenseCategory] {
        currentLedger?.categories ?? []
    }

    var expenses: [Expense] {
        currentLedger?.expenses ?? []
    }

    var recurringExpenses: [RecurringExpense] {
        currentLedger?.recurringExpenses ?? []
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

    private var currentLedger: Ledger? {
        ledgers.first { $0.id == currentLedgerId }
    }

    init(dataManager: DataManager, authManager: AuthManager, networkMonitor: NetworkMonitor) {
        self.dataManager = dataManager
        self.authManager = authManager
        self.networkMonitor = networkMonitor
        reload()
        currentLedgerId = ledgers.first { $0.type == .personal }?.id ?? ledgers.first?.id ?? ""
    }

    func reload() {
        if authManager.isAuthenticated {
            ledgers = dataManager.fetchCachedLedgers()
        } else {
            ledgers = [buildGuestLedger()]
        }
    }

    // MARK: - Guest Ledger Builder

    private func buildGuestLedger() -> Ledger {
        let guestExpenses = dataManager.fetchGuestExpenses()
        var categories = ExpenseCategory.defaults
        categories.append(ExpenseCategory.otherCategory)
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.compactMap { cat -> (String, ExpenseCategory)? in
            guard let key = cat.key else {
                return nil
            }
            return (key, cat)
        })

        let expenses = guestExpenses.map { guest -> Expense in
            let category = categoryMap[guest.categoryKey] ?? ExpenseCategory.otherCategory
            return Expense(
                id: guest.id,
                amount: Double(guest.amount),
                category: category,
                memo: guest.memo,
                date: guest.date,
                latitude: guest.latitude,
                longitude: guest.longitude,
                address: guest.address,
                ledgerId: "guest",
                paidBy: nil
            )
        }

        return Ledger(
            id: "guest",
            name: "個人",
            type: .personal,
            members: [LedgerMember(id: "me", name: "我", isCurrentUser: true)],
            currency: .twd,
            categories: categories,
            expenses: expenses,
            recurringExpenses: []
        )
    }

    // MARK: - Expense CRUD

    func addExpense(amount: Double, category: ExpenseCategory, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?, paidBy: LedgerMember? = nil) async {
        if !authManager.isAuthenticated {
            print("[ExpenseStore] addExpense: mode=guest")
            dataManager.addGuestExpense(
                categoryKey: category.key ?? category.id,
                amount: Int(amount),
                memo: memo,
                date: date,
                latitude: latitude,
                longitude: longitude,
                address: address
            )
            reload()
            return
        }

        guard let ledgerServerId = Int(currentLedgerId) else {
            return
        }

        let categoryServerId = Int(category.id)
        print("[ExpenseStore] addExpense: mode=auth, online=\(networkMonitor.isOnline)")

        if networkMonitor.isOnline {
            var body: [String: Any] = [
                "amount": Int(amount),
                "memo": memo,
                "date": DataManager.formatDate(date),
            ]
            if let catId = categoryServerId {
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
            if let payerId = paidBy?.id, let paidByUserId = Int(payerId) {
                body["paidByUserId"] = paidByUserId
            }

            do {
                let response = try await APIClient.shared.post(
                    path: "/api/ledgers/\(ledgerServerId)/expenses",
                    body: body,
                    responseType: ExpenseResponse.self
                )
                dataManager.cacheExpense(from: response.expense, ledgerServerId: ledgerServerId)
                reload()
                return
            } catch {
                // API 失敗 → 降級為離線新增
                print("[ExpenseStore] addExpense API failed, falling back to offline: \(error)")
            }
        }

        // 離線或 API 失敗 → 本地新增
        _ = dataManager.addUnsyncedExpense(
            ledgerServerId: ledgerServerId,
            categoryServerId: categoryServerId,
            amount: Int(amount),
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address,
            paidByUserServerId: paidBy.flatMap { Int($0.id) }
        )
        reload()
    }

    func updateExpense(_ expense: Expense) async throws {
        if !authManager.isAuthenticated {
            dataManager.updateGuestExpense(
                id: expense.id,
                categoryKey: expense.category.key ?? expense.category.id,
                amount: Int(expense.amount),
                memo: expense.memo,
                date: expense.date,
                latitude: expense.latitude,
                longitude: expense.longitude,
                address: expense.address
            )
            reload()
            return
        }

        if let serverId = expense.serverId {
            guard networkMonitor.isOnline else {
                throw OfflineError.noConnection
            }

            var body: [String: Any] = [
                "amount": Int(expense.amount),
                "memo": expense.memo,
                "date": DataManager.formatDate(expense.date),
            ]
            if let catId = Int(expense.category.id) {
                body["categoryId"] = catId
            }
            if let lat = expense.latitude {
                body["latitude"] = lat
            }
            if let lng = expense.longitude {
                body["longitude"] = lng
            }
            if let addr = expense.address {
                body["address"] = addr
            }
            if let payerId = expense.paidBy?.id, let paidByUserId = Int(payerId) {
                body["paidByUserId"] = paidByUserId
            }

            let response = try await APIClient.shared.put(
                path: "/api/expenses/\(serverId)",
                body: body,
                responseType: ExpenseResponse.self
            )
            dataManager.updateCachedExpense(serverId: serverId, from: response.expense)
            reload()
        } else {
            // 未同步的離線開銷 → 本地更新
            dataManager.updateUnsyncedExpense(
                localId: expense.id,
                categoryServerId: Int(expense.category.id),
                amount: Int(expense.amount),
                memo: expense.memo,
                date: expense.date,
                latitude: expense.latitude,
                longitude: expense.longitude,
                address: expense.address,
                paidByUserServerId: expense.paidBy.flatMap { Int($0.id) }
            )
            reload()
        }
    }

    func deleteExpense(id: UUID) async throws {
        if !authManager.isAuthenticated {
            dataManager.deleteGuestExpense(id: id)
            reload()
            return
        }

        // 從 ledgers 中找到這筆開銷
        let expense = ledgers.flatMap { $0.expenses }.first { $0.id == id }

        if let serverId = expense?.serverId {
            guard networkMonitor.isOnline else {
                throw OfflineError.noConnection
            }
            _ = try await APIClient.shared.delete(
                path: "/api/expenses/\(serverId)",
                responseType: SuccessResponse.self
            )
            dataManager.deleteCachedExpense(serverId: serverId)
            reload()
        } else {
            // 未同步的離線開銷 → 本地刪除
            dataManager.deleteUnsyncedExpense(localId: id)
            reload()
        }
    }

    // MARK: - Category CRUD

    func addCategory(name: String, icon: String, color: Color) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let ledgerServerId = Int(currentLedgerId) else {
            return
        }

        let response = try await APIClient.shared.post(
            path: "/api/ledgers/\(ledgerServerId)/categories",
            body: [
                "name": name,
                "icon": icon,
                "color": color.hexString,
            ],
            responseType: CategoryResponse.self
        )

        dataManager.cacheCategory(from: response.category, ledgerServerId: ledgerServerId)
        reload()
    }

    func updateCategory(_ category: ExpenseCategory) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let serverId = Int(category.id) else {
            return
        }

        let response = try await APIClient.shared.put(
            path: "/api/categories/\(serverId)",
            body: [
                "name": category.name,
                "icon": category.icon,
                "color": category.color.hexString,
            ],
            responseType: CategoryResponse.self
        )

        dataManager.updateCachedCategory(serverId: serverId, from: response.category)
        reload()
    }

    func deleteCategory(id: String) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let serverId = Int(id) else {
            return
        }

        _ = try await APIClient.shared.delete(
            path: "/api/categories/\(serverId)",
            responseType: SuccessResponse.self
        )

        dataManager.deleteCachedCategory(serverId: serverId)
        reload()
    }

    func moveCategory(from source: IndexSet, to destination: Int) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let ledger = currentLedger, let ledgerServerId = Int(ledger.id) else {
            return
        }

        // 計算新排序
        var sortable = ledger.categories.filter { Int($0.id) != nil }
        sortable.move(fromOffsets: source, toOffset: destination)
        let categoryIds = sortable.compactMap { Int($0.id) }

        // 先本地更新（樂觀 UI）
        dataManager.updateCategorySortOrder(ledgerServerId: ledgerServerId, categoryServerIds: categoryIds)
        reload()

        // API 同步
        _ = try await APIClient.shared.put(
            path: "/api/ledgers/\(ledgerServerId)/categories/sort",
            body: ["categoryIds": categoryIds],
            responseType: SuccessResponse.self
        )
    }

    // MARK: - Recurring Expense CRUD

    func addRecurringExpense(_ recurring: RecurringExpense) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let ledgerServerId = Int(recurring.ledgerId) else {
            return
        }

        var body: [String: Any] = [
            "amount": Int(recurring.amount),
            "frequencyType": frequencyTypeString(recurring.frequency),
            "memo": recurring.memo,
            "isEnabled": recurring.isEnabled,
        ]
        if let catId = Int(recurring.category.id) {
            body["categoryId"] = catId
        }
        let freqValue = frequencyValuePayload(recurring.frequency)
        if let fv = freqValue {
            body["frequencyValue"] = fv
        }
        if let lat = recurring.latitude {
            body["latitude"] = lat
        }
        if let lng = recurring.longitude {
            body["longitude"] = lng
        }
        if let addr = recurring.address {
            body["address"] = addr
        }
        if let payerId = recurring.paidBy?.id, let paidByUserId = Int(payerId) {
            body["paidByUserId"] = paidByUserId
        }

        let response = try await APIClient.shared.post(
            path: "/api/ledgers/\(ledgerServerId)/recurring-expenses",
            body: body,
            responseType: RecurringExpenseResponse.self
        )

        dataManager.cacheRecurringExpense(from: response.recurringExpense, ledgerServerId: ledgerServerId)
        reload()
    }

    func updateRecurringExpense(_ recurring: RecurringExpense) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let serverId = recurring.serverId else {
            return
        }

        var body: [String: Any] = [
            "amount": Int(recurring.amount),
            "frequencyType": frequencyTypeString(recurring.frequency),
            "memo": recurring.memo,
            "isEnabled": recurring.isEnabled,
        ]
        if let catId = Int(recurring.category.id) {
            body["categoryId"] = catId
        }
        let freqValue = frequencyValuePayload(recurring.frequency)
        if let fv = freqValue {
            body["frequencyValue"] = fv
        }
        if let lat = recurring.latitude {
            body["latitude"] = lat
        }
        if let lng = recurring.longitude {
            body["longitude"] = lng
        }
        if let addr = recurring.address {
            body["address"] = addr
        }
        if let payerId = recurring.paidBy?.id, let paidByUserId = Int(payerId) {
            body["paidByUserId"] = paidByUserId
        }

        let response = try await APIClient.shared.put(
            path: "/api/recurring-expenses/\(serverId)",
            body: body,
            responseType: RecurringExpenseResponse.self
        )

        dataManager.updateCachedRecurringExpense(serverId: serverId, from: response.recurringExpense)
        reload()
    }

    func deleteRecurringExpense(_ recurring: RecurringExpense) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let serverId = recurring.serverId else {
            return
        }

        _ = try await APIClient.shared.delete(
            path: "/api/recurring-expenses/\(serverId)",
            responseType: SuccessResponse.self
        )

        dataManager.deleteCachedRecurringExpense(serverId: serverId)
        reload()
    }

    func recurringExpenseCount(forLedger ledgerId: String) -> Int {
        ledgers.first { $0.id == ledgerId }?.recurringExpenses.count ?? 0
    }

    // MARK: - Settlement

    func settleGroupLedger(id: String, transfers: [SettlementTransfer]) async throws {
        guard let ledgerServerId = Int(id) else {
            return
        }

        let transfersPayload: [[String: Any]] = transfers.map { transfer in
            [
                "fromUserId": Int(transfer.from.id) ?? 0,
                "toUserId": Int(transfer.to.id) ?? 0,
                "amount": transfer.amount,
            ]
        }

        let response = try await APIClient.shared.post(
            path: "/api/ledgers/\(ledgerServerId)/settle",
            body: ["transfers": transfersPayload],
            responseType: SettleResponse.self
        )

        dataManager.cacheSettlement(from: response.settlement, ledgerServerId: ledgerServerId)
        reload()
    }

    static func calculateTransfers(expenses: [Expense], members: [LedgerMember]) -> [SettlementTransfer] {
        if expenses.isEmpty || members.isEmpty {
            return []
        }

        var paid: [String: Double] = [:]
        for member in members {
            paid[member.id] = 0
        }
        for expense in expenses {
            if let payer = expense.paidBy {
                paid[payer.id, default: 0] += expense.amount
            }
        }

        let total = paid.values.reduce(0, +)
        let share = total / Double(members.count)

        var balances: [(member: LedgerMember, balance: Double)] = []
        for member in members {
            let balance = (paid[member.id] ?? 0) - share
            if abs(balance) > 0.01 {
                balances.append((member: member, balance: balance))
            }
        }

        var debtors = balances.filter { $0.balance < 0 }.sorted { $0.balance < $1.balance }
        var creditors = balances.filter { $0.balance > 0 }.sorted { $0.balance > $1.balance }
        var result: [SettlementTransfer] = []

        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let amount = min(-debtors[debtorIndex].balance, creditors[creditorIndex].balance)
            result.append(SettlementTransfer(
                id: UUID(),
                from: debtors[debtorIndex].member,
                to: creditors[creditorIndex].member,
                amount: amount
            ))

            debtors[debtorIndex].balance += amount
            creditors[creditorIndex].balance -= amount

            if abs(debtors[debtorIndex].balance) < 0.01 {
                debtorIndex += 1
            }
            if abs(creditors[creditorIndex].balance) < 0.01 {
                creditorIndex += 1
            }
        }

        return result
    }

    // MARK: - Ledger CRUD

    func updatePersonalLedger(id: String, name: String, currencyCode: String) async throws {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            throw OfflineError.noConnection
        }
        guard let serverId = Int(id) else {
            return
        }

        _ = try await APIClient.shared.put(
            path: "/api/ledgers/\(serverId)",
            body: [
                "name": name,
                "currency": currencyCode,
            ],
            responseType: LedgerCreateResponse.self
        )

        await refreshState()
    }

    func createGroupLedger(name: String, currency: Currency) async throws -> String {
        let response = try await APIClient.shared.post(
            path: "/api/ledgers",
            body: [
                "name": name,
                "currency": currency.code,
            ],
            responseType: LedgerCreateResponse.self
        )

        dataManager.cacheLedgerFromState(response.ledger)
        reload()

        return response.ledger.inviteCode ?? ""
    }

    func joinGroupLedger(inviteCode: String) async throws {
        let response = try await APIClient.shared.post(
            path: "/api/ledgers/join",
            body: ["inviteCode": inviteCode],
            responseType: LedgerJoinResponse.self
        )

        dataManager.cacheLedgerFromState(response.ledger)
        reload()
    }

    func leaveGroupLedger(id: String) async throws {
        guard let serverId = Int(id) else {
            return
        }

        _ = try await APIClient.shared.post(
            path: "/api/ledgers/\(serverId)/leave",
            body: nil,
            responseType: LedgerLeaveResponse.self
        )

        dataManager.deleteCachedLedger(serverId: serverId)
        reload()
        if currentLedgerId == id {
            currentLedgerId = ledgers.first { $0.type == .personal }?.id ?? ledgers.first?.id ?? ""
        }
    }

    func updateGroupLedger(_ ledger: Ledger) async throws {
        guard let serverId = Int(ledger.id) else {
            return
        }

        _ = try await APIClient.shared.put(
            path: "/api/ledgers/\(serverId)",
            body: [
                "name": ledger.name,
                "currency": ledger.currency.code,
            ],
            responseType: LedgerCreateResponse.self
        )

        await refreshState()
    }

    func moveLedger(from source: IndexSet, to destination: Int) {
        dataManager.moveLedger(fromOffsets: source, toOffset: destination)
        reload()
    }

    // MARK: - State Management

    func refreshState() async {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            return
        }

        print("[ExpenseStore] refreshState: start")
        do {
            let response = try await APIClient.shared.get(
                path: "/api/state",
                responseType: StateResponse.self
            )

            print("[ExpenseStore] refreshState: received \(response.ledgers.count) ledgers")
            dataManager.rebuildFromState(response)
            reload()
        } catch {
            print("[ExpenseStore] refreshState error: \(error)")
        }
    }

    func syncOfflineExpenses() async {
        guard authManager.isAuthenticated, networkMonitor.isOnline else {
            return
        }

        // 讀取 @Model 屬性，序列化為純值（避免跨 await 持有 @Model 引用）
        struct UnsyncedPayload {
            let ledgerServerId: Int
            let localId: UUID
            let data: [String: Any]
        }

        let unsynced = dataManager.fetchUnsyncedExpenses()
        print("[ExpenseStore] syncOfflineExpenses: found \(unsynced.count) unsynced")
        let payloads: [UnsyncedPayload] = unsynced.compactMap { expense -> UnsyncedPayload? in
            guard let ledgerServerId = expense.ledger?.serverId, ledgerServerId > 0 else {
                return nil
            }
            var data: [String: Any] = [
                "amount": expense.amount,
                "memo": expense.memo,
                "date": DataManager.formatDate(expense.date),
            ]
            if let catId = expense.categoryServerId {
                data["categoryId"] = catId
            }
            if let lat = expense.latitude {
                data["latitude"] = lat
            }
            if let lng = expense.longitude {
                data["longitude"] = lng
            }
            if let addr = expense.address {
                data["address"] = addr
            }
            if let payerId = expense.paidByUserServerId {
                data["paidByUserId"] = payerId
            }
            return UnsyncedPayload(ledgerServerId: ledgerServerId, localId: expense.localId, data: data)
        }

        guard !payloads.isEmpty else {
            return
        }

        // 依 ledger 分組批次上傳（純值，不涉及 @Model）
        let grouped = Dictionary(grouping: payloads) { $0.ledgerServerId }

        for (ledgerServerId, items) in grouped {
            let expensePayloads = items.map { $0.data }

            do {
                let response = try await APIClient.shared.post(
                    path: "/api/ledgers/\(ledgerServerId)/expenses/batch",
                    body: ["expenses": expensePayloads],
                    responseType: ExpenseBatchResponse.self
                )

                let mappings = zip(items, response.expenses).map { (local, remote) in
                    (localId: local.localId, serverId: remote.id)
                }
                print("[ExpenseStore] syncOfflineExpenses: batch uploaded \(items.count) to ledger \(ledgerServerId)")
                dataManager.markExpensesSynced(mappings)
            } catch {
                print("[ExpenseStore] syncOfflineExpenses error for ledger \(ledgerServerId): \(error)")
            }
        }
    }

    func initAfterLogin(guestExpenses: [GuestExpense]) async {
        let expensesPayload: [[String: Any]] = guestExpenses.map { expense in
            var data: [String: Any] = [
                "categoryKey": expense.categoryKey,
                "amount": expense.amount,
                "memo": expense.memo,
                "date": DataManager.formatDate(expense.date),
            ]
            if let lat = expense.latitude {
                data["latitude"] = lat
            }
            if let lng = expense.longitude {
                data["longitude"] = lng
            }
            if let addr = expense.address {
                data["address"] = addr
            }
            return data
        }

        print("[ExpenseStore] initAfterLogin: uploading \(guestExpenses.count) guest expenses")
        do {
            let response = try await APIClient.shared.post(
                path: "/api/auth/init",
                body: ["expenses": expensesPayload],
                responseType: StateResponse.self
            )

            dataManager.rebuildFromState(response)
            dataManager.clearAllGuestData()
            reload()
            currentLedgerId = ledgers.first { $0.type == .personal }?.id ?? ledgers.first?.id ?? ""
        } catch {
            print("[ExpenseStore] initAfterLogin error: \(error)")
            // 即使 init 失敗，也嘗試 refreshState
            await refreshState()
            dataManager.clearAllGuestData()
            reload()
            currentLedgerId = ledgers.first { $0.type == .personal }?.id ?? ledgers.first?.id ?? ""
        }
    }

    // MARK: - Frequency Helpers

    private func frequencyTypeString(_ frequency: RecurringFrequency) -> String {
        switch frequency {
        case .daily:
            return "daily"
        case .weekly:
            return "weekly"
        case .monthly:
            return "monthly"
        case .yearly:
            return "yearly"
        }
    }

    private func frequencyValuePayload(_ frequency: RecurringFrequency) -> Any? {
        switch frequency {
        case .daily:
            return nil
        case .weekly(let dayOfWeek):
            return dayOfWeek
        case .monthly(let dayOfMonth):
            return dayOfMonth
        case .yearly(let month, let day):
            return ["month": month, "day": day]
        }
    }

    // MARK: - Preview

    static func preview() -> ExpenseStore {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let manager = DataManager(modelContainer: container)
        let auth = AuthManager()
        let network = NetworkMonitor()
        return ExpenseStore(dataManager: manager, authManager: auth, networkMonitor: network)
    }
}
