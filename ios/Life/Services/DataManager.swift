import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DataManager {
    let modelContainer: ModelContainer
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.context = ModelContext(modelContainer)
        self.context.autosaveEnabled = false
    }

    // MARK: - Guest Expense

    func addGuestExpense(categoryKey: String, amount: Int, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?) {
        let expense = GuestExpense(
            categoryKey: categoryKey,
            amount: amount,
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address
        )
        context.insert(expense)
        save()
    }

    func fetchGuestExpenses() -> [GuestExpense] {
        let descriptor = FetchDescriptor<GuestExpense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func guestExpenseCount() -> Int {
        let descriptor = FetchDescriptor<GuestExpense>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func updateGuestExpense(id: UUID, categoryKey: String, amount: Int, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?) {
        guard let expense = findGuestExpense(id: id) else {
            return
        }
        expense.categoryKey = categoryKey
        expense.amount = amount
        expense.memo = memo
        expense.date = date
        expense.latitude = latitude
        expense.longitude = longitude
        expense.address = address
        save()
    }

    func deleteGuestExpense(id: UUID) {
        guard let expense = findGuestExpense(id: id) else {
            return
        }
        context.delete(expense)
        save()
    }

    func clearAllGuestData() {
        do {
            try context.delete(model: GuestExpense.self)
            save()
        } catch {
            print("[DataManager] clearAllGuestData error: \(error)")
        }
    }

    // MARK: - Cached Ledger Read

    func fetchCachedLedgers() -> [Ledger] {
        let descriptor = FetchDescriptor<CachedLedger>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let cached = (try? context.fetch(descriptor)) ?? []
        return cached.map { $0.toViewModel() }
    }

    // MARK: - Rebuild from State

    func rebuildFromState(_ response: StateResponse) {
        // 1. 暫存未同步的離線開銷
        let unsyncedDescriptor = FetchDescriptor<CachedExpense>(
            predicate: #Predicate { !$0.isSynced }
        )
        let unsyncedExpenses = (try? context.fetch(unsyncedDescriptor)) ?? []

        struct UnsyncedExpenseData {
            let localId: UUID
            let ledgerServerId: Int
            let categoryServerId: Int?
            let amount: Int
            let memo: String
            let date: Date
            let latitude: Double?
            let longitude: Double?
            let address: String?
            let paidByUserServerId: Int?
        }

        print("[DataManager] rebuildFromState: preserving \(unsyncedExpenses.count) unsynced expenses")
        let unsyncedData = unsyncedExpenses.compactMap { expense -> UnsyncedExpenseData? in
            guard let ledgerServerId = expense.ledger?.serverId else {
                return nil
            }
            return UnsyncedExpenseData(
                localId: expense.localId,
                ledgerServerId: ledgerServerId,
                categoryServerId: expense.categoryServerId,
                amount: expense.amount,
                memo: expense.memo,
                date: expense.date,
                latitude: expense.latitude,
                longitude: expense.longitude,
                address: expense.address,
                paidByUserServerId: expense.paidByUserServerId
            )
        }

        // 2. 清除所有快取
        clearAllCache()

        // 3. 從 StateResponse 重建
        let remoteLedgerIds = Set(response.ledgers.map { $0.id })

        for (index, remoteLedger) in response.ledgers.enumerated() {
            let ledger = CachedLedger(
                serverId: remoteLedger.id,
                name: remoteLedger.name,
                type: remoteLedger.type,
                currencyCode: remoteLedger.currency,
                inviteCode: remoteLedger.inviteCode,
                sortOrder: index
            )
            context.insert(ledger)

            for member in remoteLedger.members {
                let cachedMember = CachedMember(
                    serverId: member.id,
                    userId: member.userId,
                    name: member.name,
                    role: member.role,
                    isCurrentUser: member.isCurrentUser,
                    ledger: ledger
                )
                context.insert(cachedMember)
            }

            for category in remoteLedger.categories {
                let cachedCategory = CachedCategory(
                    serverId: category.id,
                    key: category.key,
                    name: category.name,
                    icon: category.icon,
                    colorHex: category.color,
                    sortOrder: category.sort,
                    ledger: ledger
                )
                context.insert(cachedCategory)
            }

            for expense in remoteLedger.expenses {
                let cachedExpense = CachedExpense(
                    serverId: expense.id,
                    categoryServerId: expense.categoryId,
                    amount: expense.amount,
                    memo: expense.memo,
                    date: Self.parseDate(expense.date) ?? Date(),
                    latitude: expense.latitude,
                    longitude: expense.longitude,
                    address: expense.address,
                    isSettled: expense.isSettled,
                    paidByUserServerId: expense.paidByUserId,
                    createdByUserServerId: expense.createdByUserId,
                    isSynced: true,
                    ledger: ledger
                )
                context.insert(cachedExpense)
            }

            for recurring in remoteLedger.recurringExpenses {
                let frequencyValue = Self.extractFrequencyValue(recurring.frequencyValue)
                let cachedRecurring = CachedRecurringExpense(
                    serverId: recurring.id,
                    categoryServerId: recurring.categoryId,
                    amount: recurring.amount,
                    frequencyType: recurring.frequencyType,
                    frequencyValue: frequencyValue,
                    memo: recurring.memo,
                    isEnabled: recurring.isEnabled,
                    latitude: recurring.latitude,
                    longitude: recurring.longitude,
                    address: recurring.address,
                    paidByUserServerId: recurring.paidByUserId,
                    ledger: ledger
                )
                context.insert(cachedRecurring)
            }

            for settlement in remoteLedger.settlements {
                let transfersJson = Self.encodeSettlementTransfers(settlement.transfers)
                let cachedSettlement = CachedSettlement(
                    serverId: settlement.id,
                    date: Self.parseDate(settlement.createAt) ?? Date(),
                    settledByUserId: settlement.settledByUserId,
                    transfersJson: transfersJson,
                    currencySymbol: settlement.currencySymbol,
                    ledger: ledger
                )
                context.insert(cachedSettlement)
            }
        }

        print("[DataManager] rebuildFromState: created \(response.ledgers.count) ledgers")

        // 4. 恢復未同步的離線開銷（僅 ledger 仍存在者）
        for data in unsyncedData {
            guard remoteLedgerIds.contains(data.ledgerServerId) else {
                continue
            }
            let targetLedgerServerId = data.ledgerServerId
            let ledgerDescriptor = FetchDescriptor<CachedLedger>(
                predicate: #Predicate { $0.serverId == targetLedgerServerId }
            )
            guard let ledger = try? context.fetch(ledgerDescriptor).first else {
                continue
            }

            let expense = CachedExpense(
                localId: data.localId,
                serverId: nil,
                categoryServerId: data.categoryServerId,
                amount: data.amount,
                memo: data.memo,
                date: data.date,
                latitude: data.latitude,
                longitude: data.longitude,
                address: data.address,
                paidByUserServerId: data.paidByUserServerId,
                isSynced: false,
                ledger: ledger
            )
            context.insert(expense)
        }

        save()
    }

    // MARK: - Cached Expense CRUD

    func cacheExpense(from state: StateExpense, ledgerServerId: Int) {
        guard let ledger = findCachedLedger(serverId: ledgerServerId) else {
            return
        }
        let expense = CachedExpense(
            serverId: state.id,
            categoryServerId: state.categoryId,
            amount: state.amount,
            memo: state.memo,
            date: Self.parseDate(state.date) ?? Date(),
            latitude: state.latitude,
            longitude: state.longitude,
            address: state.address,
            isSettled: state.isSettled,
            paidByUserServerId: state.paidByUserId,
            createdByUserServerId: state.createdByUserId,
            isSynced: true,
            ledger: ledger
        )
        context.insert(expense)
        save()
    }

    func updateCachedExpense(serverId: Int, from state: StateExpense) {
        guard let expense = findCachedExpenseByServerId(serverId) else {
            return
        }
        expense.categoryServerId = state.categoryId
        expense.amount = state.amount
        expense.memo = state.memo
        expense.date = Self.parseDate(state.date) ?? expense.date
        expense.latitude = state.latitude
        expense.longitude = state.longitude
        expense.address = state.address
        expense.isSettled = state.isSettled
        expense.paidByUserServerId = state.paidByUserId
        save()
    }

    func deleteCachedExpense(serverId: Int) {
        guard let expense = findCachedExpenseByServerId(serverId) else {
            return
        }
        context.delete(expense)
        save()
    }

    func addUnsyncedExpense(ledgerServerId: Int, categoryServerId: Int?, amount: Int, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?, paidByUserServerId: Int?) -> UUID? {
        guard let ledger = findCachedLedger(serverId: ledgerServerId) else {
            return nil
        }
        let expense = CachedExpense(
            categoryServerId: categoryServerId,
            amount: amount,
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address,
            paidByUserServerId: paidByUserServerId,
            isSynced: false,
            ledger: ledger
        )
        context.insert(expense)
        save()
        return expense.localId
    }

    func fetchUnsyncedExpenses() -> [CachedExpense] {
        let descriptor = FetchDescriptor<CachedExpense>(
            predicate: #Predicate { !$0.isSynced }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func markExpensesSynced(_ mappings: [(localId: UUID, serverId: Int)]) {
        print("[DataManager] markExpensesSynced: \(mappings.count) expenses")
        for mapping in mappings {
            let localId = mapping.localId
            let descriptor = FetchDescriptor<CachedExpense>(
                predicate: #Predicate { $0.localId == localId }
            )
            guard let expense = try? context.fetch(descriptor).first else {
                continue
            }
            expense.serverId = mapping.serverId
            expense.isSynced = true
        }
        save()
    }

    func deleteUnsyncedExpense(localId: UUID) {
        let descriptor = FetchDescriptor<CachedExpense>(
            predicate: #Predicate { $0.localId == localId }
        )
        guard let expense = try? context.fetch(descriptor).first else {
            return
        }
        context.delete(expense)
        save()
    }

    func updateUnsyncedExpense(localId: UUID, categoryServerId: Int?, amount: Int, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?, paidByUserServerId: Int?) {
        let descriptor = FetchDescriptor<CachedExpense>(
            predicate: #Predicate { $0.localId == localId }
        )
        guard let expense = try? context.fetch(descriptor).first else {
            return
        }
        expense.categoryServerId = categoryServerId
        expense.amount = amount
        expense.memo = memo
        expense.date = date
        expense.latitude = latitude
        expense.longitude = longitude
        expense.address = address
        expense.paidByUserServerId = paidByUserServerId
        save()
    }

    // MARK: - Cached Category CRUD

    func cacheCategory(from state: StateCategory, ledgerServerId: Int) {
        guard let ledger = findCachedLedger(serverId: ledgerServerId) else {
            return
        }
        let category = CachedCategory(
            serverId: state.id,
            key: state.key,
            name: state.name,
            icon: state.icon,
            colorHex: state.color,
            sortOrder: state.sort,
            ledger: ledger
        )
        context.insert(category)
        save()
    }

    func updateCachedCategory(serverId: Int, from state: StateCategory) {
        guard let category = findCachedCategory(serverId: serverId) else {
            return
        }
        category.name = state.name
        category.icon = state.icon
        category.colorHex = state.color
        category.sortOrder = state.sort
        save()
    }

    func deleteCachedCategory(serverId: Int) {
        guard let category = findCachedCategory(serverId: serverId) else {
            return
        }

        // 級聯：將此分類的開銷 categoryServerId 設為 null
        if let ledger = category.ledger {
            for expense in ledger.expenses where expense.categoryServerId == serverId {
                expense.categoryServerId = nil
            }
            for recurring in ledger.recurringExpenses where recurring.categoryServerId == serverId {
                recurring.categoryServerId = nil
            }
        }

        context.delete(category)
        save()
    }

    func updateCategorySortOrder(ledgerServerId: Int, categoryServerIds: [Int]) {
        guard let ledger = findCachedLedger(serverId: ledgerServerId) else {
            return
        }
        for (index, catServerId) in categoryServerIds.enumerated() {
            if let category = ledger.categories.first(where: { $0.serverId == catServerId }) {
                category.sortOrder = index
            }
        }
        save()
    }

    // MARK: - Cached Recurring Expense CRUD

    func cacheRecurringExpense(from state: StateRecurringExpense, ledgerServerId: Int) {
        guard let ledger = findCachedLedger(serverId: ledgerServerId) else {
            return
        }
        let frequencyValue = Self.extractFrequencyValue(state.frequencyValue)
        let recurring = CachedRecurringExpense(
            serverId: state.id,
            categoryServerId: state.categoryId,
            amount: state.amount,
            frequencyType: state.frequencyType,
            frequencyValue: frequencyValue,
            memo: state.memo,
            isEnabled: state.isEnabled,
            latitude: state.latitude,
            longitude: state.longitude,
            address: state.address,
            paidByUserServerId: state.paidByUserId,
            ledger: ledger
        )
        context.insert(recurring)
        save()
    }

    func updateCachedRecurringExpense(serverId: Int, from state: StateRecurringExpense) {
        guard let recurring = findCachedRecurringExpense(serverId: serverId) else {
            return
        }
        recurring.categoryServerId = state.categoryId
        recurring.amount = state.amount
        recurring.frequencyType = state.frequencyType
        recurring.frequencyValue = Self.extractFrequencyValue(state.frequencyValue)
        recurring.memo = state.memo
        recurring.isEnabled = state.isEnabled
        recurring.latitude = state.latitude
        recurring.longitude = state.longitude
        recurring.address = state.address
        recurring.paidByUserServerId = state.paidByUserId
        save()
    }

    func deleteCachedRecurringExpense(serverId: Int) {
        guard let recurring = findCachedRecurringExpense(serverId: serverId) else {
            return
        }
        context.delete(recurring)
        save()
    }

    // MARK: - Cached Ledger CRUD

    func cacheLedgerFromState(_ state: StateLedger, sortOrder: Int? = nil) {
        let order = sortOrder ?? nextLedgerSortOrder()
        let ledger = CachedLedger(
            serverId: state.id,
            name: state.name,
            type: state.type,
            currencyCode: state.currency,
            inviteCode: state.inviteCode,
            sortOrder: order
        )
        context.insert(ledger)

        for member in state.members {
            let cachedMember = CachedMember(
                serverId: member.id,
                userId: member.userId,
                name: member.name,
                role: member.role,
                isCurrentUser: member.isCurrentUser,
                ledger: ledger
            )
            context.insert(cachedMember)
        }

        for category in state.categories {
            let cachedCategory = CachedCategory(
                serverId: category.id,
                key: category.key,
                name: category.name,
                icon: category.icon,
                colorHex: category.color,
                sortOrder: category.sort,
                ledger: ledger
            )
            context.insert(cachedCategory)
        }

        save()
    }

    func deleteCachedLedger(serverId: Int) {
        guard let ledger = findCachedLedger(serverId: serverId) else {
            return
        }
        context.delete(ledger)
        save()
    }

    func moveLedger(fromOffsets: IndexSet, toOffset: Int) {
        let descriptor = FetchDescriptor<CachedLedger>(
            predicate: #Predicate { $0.type == "group" },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        var groups = (try? context.fetch(descriptor)) ?? []
        groups.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, ledger) in groups.enumerated() {
            ledger.sortOrder = index + 1
        }
        save()
    }

    // MARK: - Cached Settlement

    func cacheSettlement(from state: StateSettlement, ledgerServerId: Int) {
        guard let ledger = findCachedLedger(serverId: ledgerServerId) else {
            return
        }
        let transfersJson = Self.encodeSettlementTransfers(state.transfers)
        let settlement = CachedSettlement(
            serverId: state.id,
            date: Self.parseDate(state.createAt) ?? Date(),
            settledByUserId: state.settledByUserId,
            transfersJson: transfersJson,
            currencySymbol: state.currencySymbol,
            ledger: ledger
        )
        context.insert(settlement)

        // 標記該帳本所有未結算的開銷為已結算
        for expense in ledger.expenses where !expense.isSettled {
            expense.isSettled = true
        }

        save()
    }

    // MARK: - Clear All Cache

    func clearAllCache() {
        print("[DataManager] clearAllCache")
        do {
            try context.delete(model: CachedLedger.self)
            try context.delete(model: CachedExpense.self)
            try context.delete(model: CachedCategory.self)
            try context.delete(model: CachedMember.self)
            try context.delete(model: CachedRecurringExpense.self)
            try context.delete(model: CachedSettlement.self)
            save()
        } catch {
            print("[DataManager] clearAllCache error: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func save() {
        do {
            try context.save()
        } catch {
            print("[DataManager] save error: \(error)")
        }
    }

    private func findGuestExpense(id: UUID) -> GuestExpense? {
        let descriptor = FetchDescriptor<GuestExpense>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func findCachedLedger(serverId: Int) -> CachedLedger? {
        let descriptor = FetchDescriptor<CachedLedger>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try? context.fetch(descriptor).first
    }

    private func findCachedExpenseByServerId(_ serverId: Int) -> CachedExpense? {
        let descriptor = FetchDescriptor<CachedExpense>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try? context.fetch(descriptor).first
    }

    private func findCachedCategory(serverId: Int) -> CachedCategory? {
        let descriptor = FetchDescriptor<CachedCategory>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try? context.fetch(descriptor).first
    }

    private func findCachedRecurringExpense(serverId: Int) -> CachedRecurringExpense? {
        let descriptor = FetchDescriptor<CachedRecurringExpense>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try? context.fetch(descriptor).first
    }

    private func nextLedgerSortOrder() -> Int {
        let descriptor = FetchDescriptor<CachedLedger>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let max = (try? context.fetch(descriptor).first?.sortOrder) ?? -1
        return max + 1
    }

    // MARK: - Date Formatting

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static func formatDate(_ date: Date) -> String {
        syncDateFormatter.string(from: date)
    }

    static func parseDate(_ string: String) -> Date? {
        syncDateFormatter.date(from: string)
    }

    // MARK: - Frequency Value Helpers

    private static func extractFrequencyValue(_ anyCodable: AnyCodable?) -> String {
        guard let value = anyCodable?.value else {
            return ""
        }
        if let intValue = value as? Int {
            return "\(intValue)"
        }
        if let stringValue = value as? String {
            return stringValue
        }
        if let dict = value as? [String: Any] {
            // yearly: {month: 3, day: 15} → "3,15"
            if let month = dict["month"] as? Int, let day = dict["day"] as? Int {
                return "\(month),\(day)"
            }
        }
        return ""
    }

    // MARK: - Settlement Transfer Helpers

    private static func encodeSettlementTransfers(_ anyCodable: AnyCodable?) -> String {
        guard let value = anyCodable?.value else {
            return "[]"
        }
        guard let array = value as? [[String: Any]] else {
            return "[]"
        }

        let dtos = array.compactMap { item -> CachedTransferDTO? in
            guard let fromUserId = item["fromUserId"] as? Int,
                  let toUserId = item["toUserId"] as? Int,
                  let amount = item["amount"] as? Double else {
                // Try string userId
                if let fromStr = item["fromUserId"] as? String,
                   let toStr = item["toUserId"] as? String,
                   let amount = item["amount"] as? Double {
                    return CachedTransferDTO(fromUserId: fromStr, toUserId: toStr, amount: amount)
                }
                return nil
            }
            return CachedTransferDTO(fromUserId: String(fromUserId), toUserId: String(toUserId), amount: amount)
        }

        guard let data = try? JSONEncoder().encode(dtos),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
