import SwiftUI

struct LedgerSettingsView: View {
    @Bindable var store: ExpenseStore

    @State private var editingLedger: Ledger?
    @State private var showAddSheet = false

    private var personalLedger: Ledger? {
        store.ledgers.first { $0.type == .personal }
    }

    private var groupLedgers: [Ledger] {
        store.ledgers.filter { $0.type == .group }
    }

    var body: some View {
        List {
            // 新增按鈕
            Section {
                Button {
                    showAddSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("新增帳本")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            Color(.separator),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                )
            }

            // 個人帳本
            if let ledger = personalLedger {
                Section {
                    Button {
                        editingLedger = ledger
                    } label: {
                        ledgerRow(ledger)
                    }
                }
            }

            // 群組帳本
            if !groupLedgers.isEmpty {
                Section {
                    ForEach(groupLedgers) { ledger in
                        Button {
                            editingLedger = ledger
                        } label: {
                            ledgerRow(ledger)
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
        .sheet(item: $editingLedger) { ledger in
            if ledger.type == .personal {
                LedgerEditView(mode: .editPersonal(ledger)) { updated in
                    store.updateLedger(updated)
                }
            } else {
                LedgerEditView(mode: .editGroup(ledger)) { updated in
                    store.updateLedger(updated)
                } onDelete: {
                    store.deleteLedger(id: ledger.id)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            LedgerEditView(mode: .add) { newLedger in
                store.addLedger(newLedger)
            }
        }
    }

    private func ledgerRow(_ ledger: Ledger) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ledger.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))

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
