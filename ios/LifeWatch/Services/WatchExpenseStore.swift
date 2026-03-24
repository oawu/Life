import Foundation
import SwiftUI

@Observable
final class WatchExpenseStore {
    var ledgers: [Ledger] = Ledger.watchDefaults
    var selectedLedgerId: String = "watch-default"
    var hasSyncedFromPhone: Bool = false
    var isLoggedIn: Bool = false
    var isOnline: Bool = true

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

    // MARK: - Sync from iPhone

    func updateFromPhone(ledgers: [Ledger]) {
        self.ledgers = ledgers
        hasSyncedFromPhone = true

        // 確保選中的帳本仍然存在於可用帳本中
        if !availableLedgers.contains(where: { $0.id == selectedLedgerId }) {
            selectedLedgerId = availableLedgers.first?.id ?? "personal"
        }
    }
}
