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
