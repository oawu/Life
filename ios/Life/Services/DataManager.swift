import Foundation
import SwiftData
import SwiftUI

@Observable
final class DataManager {
    let modelContainer: ModelContainer
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.context = ModelContext(modelContainer)
        self.context.autosaveEnabled = true
        ensureDefaultData()
    }

    // MARK: - Ledger

    func fetchLedgers() -> [Ledger] {
        let descriptor = FetchDescriptor<PersistentLedger>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let persistent = (try? context.fetch(descriptor)) ?? []
        return persistent.map { $0.toViewModel() }
    }

    func addLedger(name: String, type: LedgerType, currency: Currency, inviteCode: String?, categories: [ExpenseCategory]) {
        let sortOrder = nextLedgerSortOrder()
        let ledger = PersistentLedger(
            name: name,
            type: type == .group ? "group" : "personal",
            currencyCode: currency.code,
            inviteCode: inviteCode,
            sortOrder: sortOrder
        )
        context.insert(ledger)

        let me = PersistentMember(name: "我", isCurrentUser: true, ledger: ledger)
        context.insert(me)

        for (index, category) in categories.enumerated() {
            let persistent = PersistentCategory(
                name: category.name,
                icon: category.icon,
                colorHex: category.color.hexString,
                sortOrder: index,
                isSystemDefault: category.isSystemOther,
                ledger: ledger
            )
            context.insert(persistent)
        }

        save()
    }

    func updateLedger(id: String, name: String, currencyCode: String) {
        guard let ledger = findLedger(id: id) else {
            return
        }
        ledger.name = name
        ledger.currencyCode = currencyCode
        ledger.lastModified = Date()
        save()
    }

    func deleteLedger(id: String) {
        guard let ledger = findLedger(id: id) else {
            return
        }
        context.delete(ledger)
        save()
    }

    func serverIdForLedger(id: String) -> Int? {
        findLedger(id: id)?.serverId
    }

    func addLedgerFromAPI(_ response: LedgerAPIResponse) {
        let ledger = PersistentLedger(
            serverId: response.serverId,
            name: response.name,
            type: response.type,
            currencyCode: response.currency,
            inviteCode: response.inviteCode,
            sortOrder: nextLedgerSortOrder(),
            syncStatus: "synced"
        )
        context.insert(ledger)

        for member in response.members {
            let persistentMember = PersistentMember(
                serverId: member.serverId,
                name: member.name,
                isCurrentUser: member.isCurrentUser,
                syncStatus: "synced",
                ledger: ledger
            )
            context.insert(persistentMember)
        }

        for category in response.categories {
            let localId = UUID(uuidString: category.localId) ?? UUID()
            let persistentCategory = PersistentCategory(
                localId: localId,
                serverId: category.serverId,
                name: category.name,
                icon: category.icon,
                colorHex: category.color,
                sortOrder: category.sort,
                isSystemDefault: category.isSystemDefault,
                syncStatus: "synced",
                ledger: ledger
            )
            context.insert(persistentCategory)
        }

        save()
    }

    func moveLedger(fromOffsets: IndexSet, toOffset: Int) {
        var groups = fetchGroupLedgers()
        groups.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, ledger) in groups.enumerated() {
            ledger.sortOrder = index + 1
        }
        save()
    }

    // MARK: - Expense

    func addExpense(ledgerId: String, amount: Double, categoryId: String, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?, paidByMemberId: String?) {
        guard let ledger = findLedger(id: ledgerId) else {
            return
        }
        let category = findCategory(id: categoryId, in: ledger)
        let paidBy = findMember(id: paidByMemberId, in: ledger)

        let expense = PersistentExpense(
            amount: amount,
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address,
            ledger: ledger,
            category: category,
            paidBy: paidBy
        )
        context.insert(expense)
        save()
    }

    func updateExpense(_ viewModel: Expense) {
        guard let expense = findExpense(id: viewModel.id),
              let ledger = expense.ledger else {
            return
        }
        expense.amount = viewModel.amount
        expense.memo = viewModel.memo
        expense.date = viewModel.date
        expense.latitude = viewModel.latitude
        expense.longitude = viewModel.longitude
        expense.address = viewModel.address
        expense.category = findCategory(id: viewModel.category.id, in: ledger)
        expense.paidBy = findMember(id: viewModel.paidBy?.id, in: ledger)
        expense.lastModified = Date()
        expense.syncStatus = "pending"
        save()
    }

    func deleteExpense(id: UUID) {
        guard let expense = findExpense(id: id) else {
            return
        }
        context.delete(expense)
        save()
    }

    // MARK: - Category

    func addCategory(ledgerId: String, name: String, icon: String, color: Color) -> String? {
        guard let ledger = findLedger(id: ledgerId) else {
            return nil
        }
        let sortOrder = ledger.categories.count
        let category = PersistentCategory(
            name: name,
            icon: icon,
            colorHex: color.hexString,
            sortOrder: sortOrder,
            ledger: ledger
        )
        context.insert(category)
        save()
        return category.localId.uuidString
    }

    func updateCategory(id: String, name: String, icon: String, color: Color) {
        guard let category = findCategory(byViewModelId: id) else {
            return
        }
        category.name = name
        category.icon = icon
        category.colorHex = color.hexString
        category.lastModified = Date()
        category.syncStatus = "pending"
        save()
    }

    func deleteCategory(id: String) {
        guard let category = findCategory(byViewModelId: id),
              let ledger = category.ledger else {
            return
        }

        let otherCategory = ledger.categories.first { $0.isSystemDefault }

        // 將所屬開銷指到「其他」
        for expense in ledger.expenses where expense.category?.localId == category.localId {
            expense.category = otherCategory
            expense.lastModified = Date()
            expense.syncStatus = "pending"
        }
        for recurring in ledger.recurringExpenses where recurring.category?.localId == category.localId {
            recurring.category = otherCategory
            recurring.lastModified = Date()
            recurring.syncStatus = "pending"
        }

        context.delete(category)
        save()
    }

    func moveCategory(ledgerId: String, fromOffsets: IndexSet, toOffset: Int) {
        guard let ledger = findLedger(id: ledgerId) else {
            return
        }
        var sortable = ledger.categories
            .filter { !$0.isSystemDefault }
            .sorted { $0.sortOrder < $1.sortOrder }
        sortable.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, category) in sortable.enumerated() {
            category.sortOrder = index
        }
        if let other = ledger.categories.first(where: { $0.isSystemDefault }) {
            other.sortOrder = sortable.count
        }
        save()
    }

    // MARK: - Recurring Expense

    func addRecurringExpense(ledgerId: String, amount: Double, categoryId: String, frequency: RecurringFrequency, memo: String, isEnabled: Bool, latitude: Double?, longitude: Double?, address: String?, paidByMemberId: String?) {
        guard let ledger = findLedger(id: ledgerId) else {
            return
        }
        let category = findCategory(id: categoryId, in: ledger)
        let paidBy = findMember(id: paidByMemberId, in: ledger)

        let recurring = PersistentRecurringExpense(
            amount: amount,
            frequencyType: "",
            memo: memo,
            isEnabled: isEnabled,
            latitude: latitude,
            longitude: longitude,
            address: address,
            ledger: ledger,
            category: category,
            paidBy: paidBy
        )
        recurring.frequency = frequency
        context.insert(recurring)
        save()
    }

    func updateRecurringExpense(_ viewModel: RecurringExpense) {
        guard let recurring = findRecurringExpense(id: viewModel.id),
              let ledger = recurring.ledger else {
            return
        }
        recurring.amount = viewModel.amount
        recurring.frequency = viewModel.frequency
        recurring.memo = viewModel.memo
        recurring.isEnabled = viewModel.isEnabled
        recurring.latitude = viewModel.latitude
        recurring.longitude = viewModel.longitude
        recurring.address = viewModel.address
        recurring.category = findCategory(id: viewModel.category.id, in: ledger)
        recurring.paidBy = findMember(id: viewModel.paidBy?.id, in: ledger)
        recurring.lastModified = Date()
        recurring.syncStatus = "pending"
        save()
    }

    func deleteRecurringExpense(id: UUID) {
        guard let recurring = findRecurringExpense(id: id) else {
            return
        }
        context.delete(recurring)
        save()
    }

    func recurringExpenseCount(forLedger ledgerId: String) -> Int {
        guard let ledger = findLedger(id: ledgerId) else {
            return 0
        }
        return ledger.recurringExpenses.count
    }

    // MARK: - Settlement

    func settleLedger(id: String, transfers: [SettlementTransfer]) {
        guard let ledger = findLedger(id: id) else {
            return
        }

        // 標記未結算開銷為已結算
        for expense in ledger.expenses where !expense.isSettled {
            expense.isSettled = true
            expense.syncStatus = "pending"
        }

        let currentUser = ledger.members.first { $0.isCurrentUser }
        let settlement = PersistentSettlement(
            date: Date(),
            settledByMemberId: currentUser?.localId ?? UUID(),
            transfersJson: TransferDTO.encode(transfers: transfers),
            currencySymbol: ledger.currency.symbol,
            ledger: ledger
        )
        context.insert(settlement)
        save()
    }

    // MARK: - Member

    func addMember(ledgerId: String, name: String) -> String? {
        guard let ledger = findLedger(id: ledgerId) else {
            return nil
        }
        let member = PersistentMember(name: name, ledger: ledger)
        context.insert(member)
        save()
        return member.localId.uuidString
    }

    func removeMember(ledgerId: String, memberId: String) {
        guard let ledger = findLedger(id: ledgerId),
              let member = findMember(id: memberId, in: ledger) else {
            return
        }

        // 級聯刪除 paidBy 為此成員的固定開銷
        for recurring in ledger.recurringExpenses where recurring.paidBy?.localId == member.localId {
            context.delete(recurring)
        }

        context.delete(member)
        save()
    }

    // MARK: - Bulk Update for Ledger

    func updateLedgerFull(_ viewModel: Ledger) {
        guard let ledger = findLedger(id: viewModel.id) else {
            return
        }
        ledger.name = viewModel.name
        ledger.currencyCode = viewModel.currency.code
        ledger.inviteCode = viewModel.inviteCode
        ledger.lastModified = Date()

        // 同步 members
        let existingMemberIds = Set(ledger.members.map { $0.localId.uuidString })
        let newMemberIds = Set(viewModel.members.map { $0.id })
        let removedMemberIds = existingMemberIds.subtracting(newMemberIds)

        for removedId in removedMemberIds {
            if let member = ledger.members.first(where: { $0.localId.uuidString == removedId }) {
                // 級聯刪除 paidBy 固定開銷
                for recurring in ledger.recurringExpenses where recurring.paidBy?.localId == member.localId {
                    context.delete(recurring)
                }
                context.delete(member)
            }
        }

        for memberVM in viewModel.members {
            if let existing = ledger.members.first(where: { $0.localId.uuidString == memberVM.id }) {
                existing.name = memberVM.name
            }
        }

        save()
    }

    // MARK: - Sync Push

    func buildSyncPushPayload() -> [[String: Any]] {
        let descriptor = FetchDescriptor<PersistentLedger>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let ledgers = (try? context.fetch(descriptor)) ?? []

        return ledgers.map { ledger in
            let pendingCategories = ledger.categories.map { category -> [String: Any] in
                return [
                    "localId":         category.localId.uuidString,
                    "name":            category.name,
                    "icon":            category.icon,
                    "color":           category.colorHex,
                    "sort":            category.sortOrder,
                    "isSystemDefault": category.isSystemDefault,
                ]
            }

            let pendingExpenses = ledger.expenses.filter { $0.syncStatus == "pending" }.map { expense -> [String: Any] in
                var data: [String: Any] = [
                    "localId":         expense.localId.uuidString,
                    "amount":          Int(expense.amount),
                    "categoryLocalId": expense.category?.localId.uuidString ?? "",
                    "memo":            expense.memo,
                    "date":            Self.formatDate(expense.date),
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
                return data
            }

            let pendingRecurring = ledger.recurringExpenses.filter { $0.syncStatus == "pending" }.map { recurring -> [String: Any] in
                var data: [String: Any] = [
                    "localId":         recurring.localId.uuidString,
                    "amount":          Int(recurring.amount),
                    "categoryLocalId": recurring.category?.localId.uuidString ?? "",
                    "frequencyType":   recurring.frequencyType,
                    "memo":            recurring.memo,
                    "isEnabled":       recurring.isEnabled,
                ]
                if !recurring.frequencyValue.isEmpty {
                    data["frequencyValue"] = recurring.frequencyValue
                }
                if let latitude = recurring.latitude {
                    data["latitude"] = latitude
                }
                if let longitude = recurring.longitude {
                    data["longitude"] = longitude
                }
                if let address = recurring.address {
                    data["address"] = address
                }
                return data
            }

            let deletedExpenseIds = ledger.expenses
                .filter { $0.syncStatus == "deleted" }
                .map { $0.localId.uuidString }

            let deletedCategoryIds = ledger.categories
                .filter { $0.syncStatus == "deleted" }
                .map { $0.localId.uuidString }

            let deletedRecurringIds = ledger.recurringExpenses
                .filter { $0.syncStatus == "deleted" }
                .map { $0.localId.uuidString }

            var result: [String: Any] = [
                "localId":    ledger.localId.uuidString,
                "name":       ledger.name,
                "type":       ledger.type,
                "currency":   ledger.currencyCode,
                "categories": pendingCategories,
                "expenses":   pendingExpenses,
                "recurringExpenses": pendingRecurring,
            ]

            if !deletedExpenseIds.isEmpty {
                result["deletedExpenseLocalIds"] = deletedExpenseIds
            }
            if !deletedCategoryIds.isEmpty {
                result["deletedCategoryLocalIds"] = deletedCategoryIds
            }
            if !deletedRecurringIds.isEmpty {
                result["deletedRecurringLocalIds"] = deletedRecurringIds
            }

            return result
        }
    }

    func applySyncMappings(_ mappings: SyncMappings) {
        // 更新 Ledger serverId + syncStatus
        for mapping in mappings.ledgers {
            if let ledger = findLedger(id: mapping.localId) {
                ledger.serverId = mapping.serverId
                ledger.syncStatus = "synced"
            }
        }

        // 更新 Category serverId + syncStatus
        for mapping in mappings.categories {
            if let category = findCategory(byViewModelId: mapping.localId) {
                category.serverId = mapping.serverId
                category.syncStatus = "synced"
            }
        }

        // 更新 Expense serverId + syncStatus
        for mapping in mappings.expenses {
            if let uuid = UUID(uuidString: mapping.localId),
               let expense = findExpense(id: uuid) {
                expense.serverId = mapping.serverId
                expense.syncStatus = "synced"
            }
        }

        // 更新 RecurringExpense serverId + syncStatus
        for mapping in mappings.recurringExpenses {
            if let uuid = UUID(uuidString: mapping.localId),
               let recurring = findRecurringExpense(id: uuid) {
                recurring.serverId = mapping.serverId
                recurring.syncStatus = "synced"
            }
        }

        // 清除標記為 deleted 且已同步的資料
        cleanupDeletedRecords()
        save()
    }

    func mergeRemoteData(_ remoteLedgers: [SyncLedger]) {
        for remoteLedger in remoteLedgers {
            // 用 serverId 查找本地帳本
            let localLedger = findLedgerByServerId(remoteLedger.serverId)

            if let localLedger {
                // 更新本地帳本
                localLedger.name = remoteLedger.name
                localLedger.currencyCode = remoteLedger.currency
                localLedger.inviteCode = remoteLedger.inviteCode
                localLedger.syncStatus = "synced"

                // 同步成員
                mergeMembersForLedger(localLedger, remote: remoteLedger.members)
                // 同步分類
                mergeCategoriesForLedger(localLedger, remote: remoteLedger.categories)
                // 同步開銷
                mergeExpensesForLedger(localLedger, remote: remoteLedger.expenses)
            } else {
                // 建立新本地帳本
                let newLedger = PersistentLedger(
                    serverId: remoteLedger.serverId,
                    name: remoteLedger.name,
                    type: remoteLedger.type,
                    currencyCode: remoteLedger.currency,
                    inviteCode: remoteLedger.inviteCode,
                    sortOrder: nextLedgerSortOrder(),
                    syncStatus: "synced"
                )
                context.insert(newLedger)

                // 建立成員
                for member in remoteLedger.members {
                    let persistentMember = PersistentMember(
                        serverId: member.serverId,
                        name: member.name,
                        isCurrentUser: member.isCurrentUser,
                        syncStatus: "synced",
                        ledger: newLedger
                    )
                    context.insert(persistentMember)
                }

                // 建立分類
                for category in remoteLedger.categories {
                    let localId = UUID(uuidString: category.localId) ?? UUID()
                    let persistentCategory = PersistentCategory(
                        localId: localId,
                        serverId: category.serverId,
                        name: category.name,
                        icon: category.icon,
                        colorHex: category.color,
                        sortOrder: category.sort,
                        isSystemDefault: category.isSystemDefault,
                        syncStatus: "synced",
                        ledger: newLedger
                    )
                    context.insert(persistentCategory)
                }

                // 建立開銷
                for expense in remoteLedger.expenses {
                    let localId = UUID(uuidString: expense.localId) ?? UUID()
                    let category = newLedger.categories.first { $0.serverId == expense.categoryId }
                    let paidBy = expense.paidByUserId != nil
                        ? newLedger.members.first { $0.serverId == expense.paidByUserId }
                        : nil

                    let persistentExpense = PersistentExpense(
                        localId: localId,
                        serverId: expense.serverId,
                        amount: Double(expense.amount),
                        memo: expense.memo,
                        date: Self.parseDate(expense.date) ?? Date(),
                        latitude: expense.latitude,
                        longitude: expense.longitude,
                        address: expense.address,
                        isSettled: expense.isSettled,
                        syncStatus: "synced",
                        ledger: newLedger,
                        category: category,
                        paidBy: paidBy
                    )
                    context.insert(persistentExpense)
                }
            }
        }

        save()
    }

    func hasPendingData() -> Bool {
        let descriptor = FetchDescriptor<PersistentExpense>(
            predicate: #Predicate { $0.syncStatus == "pending" }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    // MARK: - Sync Private Helpers

    private func findLedgerByServerId(_ serverId: Int) -> PersistentLedger? {
        let descriptor = FetchDescriptor<PersistentLedger>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try? context.fetch(descriptor).first
    }

    private func mergeMembersForLedger(_ ledger: PersistentLedger, remote: [SyncMember]) {
        let existingByServerId = Dictionary(uniqueKeysWithValues: ledger.members.compactMap { member -> (Int, PersistentMember)? in
            guard let serverId = member.serverId else {
                return nil
            }
            return (serverId, member)
        })

        for remoteMember in remote {
            if let existing = existingByServerId[remoteMember.serverId] {
                existing.name = remoteMember.name
                existing.isCurrentUser = remoteMember.isCurrentUser
            } else {
                let newMember = PersistentMember(
                    serverId: remoteMember.serverId,
                    name: remoteMember.name,
                    isCurrentUser: remoteMember.isCurrentUser,
                    syncStatus: "synced",
                    ledger: ledger
                )
                context.insert(newMember)
            }
        }
    }

    private func mergeCategoriesForLedger(_ ledger: PersistentLedger, remote: [SyncCategory]) {
        let existingByServerId = Dictionary(uniqueKeysWithValues: ledger.categories.compactMap { cat -> (Int, PersistentCategory)? in
            guard let serverId = cat.serverId else {
                return nil
            }
            return (serverId, cat)
        })

        for remoteCategory in remote {
            if let existing = existingByServerId[remoteCategory.serverId] {
                existing.name = remoteCategory.name
                existing.icon = remoteCategory.icon
                existing.colorHex = remoteCategory.color
                existing.sortOrder = remoteCategory.sort
                existing.syncStatus = "synced"
            } else {
                let localId = UUID(uuidString: remoteCategory.localId) ?? UUID()
                let newCategory = PersistentCategory(
                    localId: localId,
                    serverId: remoteCategory.serverId,
                    name: remoteCategory.name,
                    icon: remoteCategory.icon,
                    colorHex: remoteCategory.color,
                    sortOrder: remoteCategory.sort,
                    isSystemDefault: remoteCategory.isSystemDefault,
                    syncStatus: "synced",
                    ledger: ledger
                )
                context.insert(newCategory)
            }
        }
    }

    private func mergeExpensesForLedger(_ ledger: PersistentLedger, remote: [SyncExpense]) {
        let existingByServerId = Dictionary(uniqueKeysWithValues: ledger.expenses.compactMap { exp -> (Int, PersistentExpense)? in
            guard let serverId = exp.serverId else {
                return nil
            }
            return (serverId, exp)
        })

        for remoteExpense in remote {
            let category = ledger.categories.first { $0.serverId == remoteExpense.categoryId }
            let paidBy = remoteExpense.paidByUserId != nil
                ? ledger.members.first { $0.serverId == remoteExpense.paidByUserId }
                : nil

            if let existing = existingByServerId[remoteExpense.serverId] {
                existing.amount = Double(remoteExpense.amount)
                existing.memo = remoteExpense.memo
                existing.date = Self.parseDate(remoteExpense.date) ?? existing.date
                existing.latitude = remoteExpense.latitude
                existing.longitude = remoteExpense.longitude
                existing.address = remoteExpense.address
                existing.isSettled = remoteExpense.isSettled
                existing.category = category
                existing.paidBy = paidBy
                existing.syncStatus = "synced"
            } else {
                let localId = UUID(uuidString: remoteExpense.localId) ?? UUID()
                let newExpense = PersistentExpense(
                    localId: localId,
                    serverId: remoteExpense.serverId,
                    amount: Double(remoteExpense.amount),
                    memo: remoteExpense.memo,
                    date: Self.parseDate(remoteExpense.date) ?? Date(),
                    latitude: remoteExpense.latitude,
                    longitude: remoteExpense.longitude,
                    address: remoteExpense.address,
                    isSettled: remoteExpense.isSettled,
                    syncStatus: "synced",
                    ledger: ledger,
                    category: category,
                    paidBy: paidBy
                )
                context.insert(newExpense)
            }
        }
    }

    private func cleanupDeletedRecords() {
        let expDescriptor = FetchDescriptor<PersistentExpense>(
            predicate: #Predicate { $0.syncStatus == "deleted" }
        )
        let deletedExpenses = (try? context.fetch(expDescriptor)) ?? []
        for expense in deletedExpenses {
            context.delete(expense)
        }

        let catDescriptor = FetchDescriptor<PersistentCategory>(
            predicate: #Predicate { $0.syncStatus == "deleted" }
        )
        let deletedCategories = (try? context.fetch(catDescriptor)) ?? []
        for category in deletedCategories {
            context.delete(category)
        }

        let recDescriptor = FetchDescriptor<PersistentRecurringExpense>(
            predicate: #Predicate { $0.syncStatus == "deleted" }
        )
        let deletedRecurring = (try? context.fetch(recDescriptor)) ?? []
        for recurring in deletedRecurring {
            context.delete(recurring)
        }
    }

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static func formatDate(_ date: Date) -> String {
        syncDateFormatter.string(from: date)
    }

    private static func parseDate(_ string: String) -> Date? {
        syncDateFormatter.date(from: string)
    }

    // MARK: - Reset

    func resetToDefaults() {
        clearAllData()
        ensureDefaultData()
    }

    /// 移除未同步且無開銷的個人帳本（登出後重建的空白預設帳本）
    /// 僅在已有從 Server 同步的帳本時才執行，避免首次登入時誤刪
    func removeUnsyncedEmptyPersonalLedgers() {
        let descriptor = FetchDescriptor<PersistentLedger>()
        guard let ledgers = try? context.fetch(descriptor) else {
            return
        }

        let hasSyncedLedgers = ledgers.contains { $0.serverId != nil }
        guard hasSyncedLedgers else {
            return
        }

        var removed = false
        for ledger in ledgers where ledger.type == "personal" && ledger.serverId == nil && ledger.expenses.isEmpty && ledger.recurringExpenses.isEmpty {
            context.delete(ledger)
            removed = true
        }

        if removed {
            save()
        }
    }

    // MARK: - Clear All Data

    func clearAllData() {
        do {
            try context.delete(model: PersistentLedger.self)
            try context.delete(model: PersistentExpense.self)
            try context.delete(model: PersistentCategory.self)
            try context.delete(model: PersistentMember.self)
            try context.delete(model: PersistentRecurringExpense.self)
            try context.delete(model: PersistentSettlement.self)
            save()
        } catch {
            print("[DataManager] clearAllData error: \(error)")
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

    private func findLedger(id: String) -> PersistentLedger? {
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        let descriptor = FetchDescriptor<PersistentLedger>(
            predicate: #Predicate { $0.localId == uuid }
        )
        return try? context.fetch(descriptor).first
    }

    private func findExpense(id: UUID) -> PersistentExpense? {
        let descriptor = FetchDescriptor<PersistentExpense>(
            predicate: #Predicate { $0.localId == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func findRecurringExpense(id: UUID) -> PersistentRecurringExpense? {
        let descriptor = FetchDescriptor<PersistentRecurringExpense>(
            predicate: #Predicate { $0.localId == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func findCategory(id: String, in ledger: PersistentLedger) -> PersistentCategory? {
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        return ledger.categories.first { $0.localId == uuid }
    }

    private func findCategory(byViewModelId id: String) -> PersistentCategory? {
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }
        let descriptor = FetchDescriptor<PersistentCategory>(
            predicate: #Predicate { $0.localId == uuid }
        )
        return try? context.fetch(descriptor).first
    }

    private func findMember(id: String?, in ledger: PersistentLedger) -> PersistentMember? {
        guard let id, let uuid = UUID(uuidString: id) else {
            return nil
        }
        return ledger.members.first { $0.localId == uuid }
    }

    private func nextLedgerSortOrder() -> Int {
        let descriptor = FetchDescriptor<PersistentLedger>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let max = (try? context.fetch(descriptor).first?.sortOrder) ?? -1
        return max + 1
    }

    private func fetchGroupLedgers() -> [PersistentLedger] {
        let descriptor = FetchDescriptor<PersistentLedger>(
            predicate: #Predicate { $0.type == "group" },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Default Data

    private func ensureDefaultData() {
        let descriptor = FetchDescriptor<PersistentLedger>()
        let count = (try? context.fetchCount(descriptor)) ?? 0

        if count > 0 {
            return
        }

        // 首次安裝：建立預設個人帳本 + 預設分類
        let ledger = PersistentLedger(name: "個人", type: "personal", currencyCode: "TWD", sortOrder: 0)
        context.insert(ledger)

        let me = PersistentMember(name: "我", isCurrentUser: true, ledger: ledger)
        context.insert(me)

        for (index, category) in ExpenseCategory.defaults.enumerated() {
            let persistent = PersistentCategory(
                name: category.name,
                icon: category.icon,
                colorHex: category.color.hexString,
                sortOrder: index,
                isSystemDefault: category.isSystemOther,
                ledger: ledger
            )
            context.insert(persistent)
        }

        save()
    }
}
