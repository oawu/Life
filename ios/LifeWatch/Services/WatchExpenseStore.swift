import Foundation
import SwiftUI

@Observable
final class WatchExpenseStore {
    var ledgers: [Ledger] = Ledger.watchDefaults
    var selectedLedgerId: String = "watch-default"
    var hasSyncedFromPhone: Bool = false
    var isLoggedIn: Bool = false
    var isOnline: Bool = true

    private static let pendingKey = "watch_pending_expenses"
    private static let maxPendingSize = 50

    // MARK: - Computed Properties

    var availableLedgers: [Ledger] {
        isLoggedIn ? ledgers : ledgers.filter { $0.type == .personal }
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

    var pendingCount: Int {
        loadPendingExpenses().count
    }

    // MARK: - Sync from iPhone

    func updateFromPhone(ledgers: [Ledger]) {
        self.ledgers = ledgers
        hasSyncedFromPhone = true

        if !availableLedgers.contains(where: { $0.id == selectedLedgerId }) {
            selectedLedgerId = availableLedgers.first?.id ?? "personal"
        }
    }

    // MARK: - Pending Expenses (Watch → iPhone)

    func addPendingExpense(_ expense: WatchPendingExpense) {
        var pending = loadPendingExpenses()
        pending.append(expense)

        if pending.count > Self.maxPendingSize {
            pending = Array(pending.suffix(Self.maxPendingSize))
        }

        savePendingExpenses(pending)
        print("[手錶儲存] 加入待同步佇列：總計=\(pending.count)")
    }

    func removePendingExpense(id: String) {
        var pending = loadPendingExpenses()
        pending.removeAll { $0.id == id }
        savePendingExpenses(pending)
    }

    func loadPendingExpenses() -> [WatchPendingExpense] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingKey) else {
            return []
        }
        return (try? JSONDecoder().decode([WatchPendingExpense].self, from: data)) ?? []
    }

    private func savePendingExpenses(_ expenses: [WatchPendingExpense]) {
        if expenses.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.pendingKey)
        } else if let data = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(data, forKey: Self.pendingKey)
        }
    }
}

// MARK: - Watch Pending Expense

struct WatchPendingExpense: Codable {
    let id: String
    let amount: Double
    let categoryId: String
    let memo: String
    let date: TimeInterval
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let ledgerId: String
    let paidById: String?
    let paidByName: String?

    var asDict: [String: Any] {
        var data: [String: Any] = [
            "id":         id,
            "amount":     amount,
            "categoryId": categoryId,
            "memo":       memo,
            "date":       date,
            "ledgerId":   ledgerId,
        ]
        if let latitude = latitude {
            data["latitude"] = latitude
        }
        if let longitude = longitude {
            data["longitude"] = longitude
        }
        if let address = address {
            data["address"] = address
        }
        if let paidById = paidById {
            data["paidById"] = paidById
        }
        if let paidByName = paidByName {
            data["paidByName"] = paidByName
        }
        return data
    }
}
