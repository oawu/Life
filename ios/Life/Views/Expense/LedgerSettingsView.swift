import SwiftUI

struct LedgerSettingsView: View {
    @Bindable var store: ExpenseStore

    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var editingLedger: Ledger?
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var showLoginPrompt = false
    @State private var showOfflineAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editingLedger = ledger
                    } label: {
                        ledgerRow(ledger)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

            // 新增帳本
            Section {
                Menu {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if authManager.isGuest {
                            showLoginPrompt = true
                        } else if !networkMonitor.isOnline {
                            showOfflineAlert = true
                        } else {
                            showCreateSheet = true
                        }
                    } label: {
                        Label("自己建立", systemImage: "plus")
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if authManager.isGuest {
                            showLoginPrompt = true
                        } else if !networkMonitor.isOnline {
                            showOfflineAlert = true
                        } else {
                            showJoinSheet = true
                        }
                    } label: {
                        Label("掃碼加入", systemImage: "qrcode.viewfinder")
                    }
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "folder.badge.plus")
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("帳本設定")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
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
                Task {
                    do {
                        _ = try await store.createGroupLedger(name: newLedger.name, currency: newLedger.currency)
                    } catch {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinLedgerView(store: store)
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginPromptView(message: "登入後即可建立群組帳本")
        }
        .alert("無法連線", isPresented: $showOfflineAlert) {
            Button("好") {}
        } message: {
            Text("此操作需要網路連線，請稍後再試")
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
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
        LedgerSettingsView(store: ExpenseStore.preview())
    }
    .environment(AuthManager())
    .environment(NetworkMonitor())
}
