import Foundation
import SwiftUI

@Observable
final class WatchExpenseStore {
    var ledgers: [Ledger] = Ledger.defaults
    var selectedLedgerId: String = "personal"
    var hasSyncedFromPhone: Bool = false

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

        // 確保選中的帳本仍然存在
        if !ledgers.contains(where: { $0.id == selectedLedgerId }) {
            selectedLedgerId = ledgers.first?.id ?? "personal"
        }
    }
}
