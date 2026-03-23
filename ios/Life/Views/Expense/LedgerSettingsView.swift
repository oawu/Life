import SwiftUI

struct LedgerSettingsView: View {
    @Bindable var store: ExpenseStore

    @State private var editingLedger: Ledger?
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var selectedLedgerId: String?
    @State private var showPersonalRecurring = false

    private var personalLedger: Ledger? {
        store.ledgers.first { $0.type == .personal }
    }

    private var groupLedgers: [Ledger] {
        store.ledgers.filter { $0.type == .group }
    }

    var body: some View {
        List {
            // 個人帳本
            if let ledger = personalLedger {
                Section {
                    Button {
                        editingLedger = ledger
                    } label: {
                        ledgerRow(ledger)
                    }

                    Button {
                        showPersonalRecurring = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "repeat")
                                .foregroundStyle(.blue)

                            Text("固定開銷")
                                .foregroundStyle(.primary)

                            Spacer()

                            let count = store.recurringExpenseCount(forLedger: ledger.id)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // 群組帳本
            if !groupLedgers.isEmpty {
                Section {
                    ForEach(groupLedgers) { ledger in
                        Button {
                            selectedLedgerId = ledger.id
                        } label: {
                            HStack {
                                ledgerRow(ledger)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                        }
                    }
                    .onMove { source, destination in
                        store.moveLedger(from: source, to: destination)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("帳本設定")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("自己建立", systemImage: "plus")
                    }
                    Button {
                        showJoinSheet = true
                    } label: {
                        Label("掃碼加入", systemImage: "qrcode.viewfinder")
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .navigationDestination(item: $selectedLedgerId) { ledgerId in
            LedgerDetailView(store: store, ledgerId: ledgerId)
        }
        .navigationDestination(isPresented: $showPersonalRecurring) {
            if let ledger = personalLedger {
                RecurringExpenseListView(store: store, ledgerId: ledger.id)
            }
        }
        .sheet(item: $editingLedger) { ledger in
            LedgerEditView(mode: .editPersonal(ledger)) { updated in
                store.updateLedger(updated)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            LedgerEditView(mode: .add) { newLedger in
                store.addLedger(newLedger)
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinLedgerView { ledger in
                store.addLedger(ledger)
            }
        }
    }

    private func ledgerRow(_ ledger: Ledger) -> some View {
        HStack(spacing: 12) {
            Text(ledger.name)
                .foregroundStyle(.primary)

            Spacer()

            if ledger.type == .group {
                Text("\(ledger.members.count) 人")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        LedgerSettingsView(store: ExpenseStore())
    }
}
