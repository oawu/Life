import SwiftUI

struct RecurringExpenseListView: View {
    @Bindable var store: ExpenseStore
    let ledgerId: String

    @State private var editingRecurring: RecurringExpense?
    @State private var showAddSheet = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false

    private var ledger: Ledger? {
        store.ledgers.first { $0.id == ledgerId }
    }

    private var recurringExpenses: [RecurringExpense] {
        ledger?.recurringExpenses ?? []
    }

    private var isGroup: Bool {
        ledger?.type == .group
    }

    var body: some View {
        Group {
            if recurringExpenses.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(recurringExpenses) { recurring in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingRecurring = recurring
                            } label: {
                                recurringRow(recurring)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let recurring = recurringExpenses[index]
                                Task {
                                    do {
                                        try await store.deleteRecurringExpense(recurring)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("固定開銷")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let ledger {
                RecurringExpenseEditView(
                    mode: .add,
                    ledger: ledger,
                    store: store
                )
            }
        }
        .sheet(item: $editingRecurring) { recurring in
            if let ledger {
                RecurringExpenseEditView(
                    mode: .edit(recurring),
                    ledger: ledger,
                    store: store
                )
            }
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color(.quaternaryLabel))

            Text("尚無固定開銷")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Row

    private func toggleEnabled(_ recurring: RecurringExpense) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var updated = recurring
        updated.isEnabled.toggle()
        Task {
            do {
                try await store.updateRecurringExpense(updated)
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func recurringRow(_ recurring: RecurringExpense) -> some View {
        HStack(spacing: 12) {
            Image(systemName: recurring.category.icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(recurring.category.color.opacity(recurring.isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(ledger?.currency.symbol ?? "$")\(Int(recurring.amount))")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(recurring.isEnabled ? .primary : .tertiary)

                    Text(recurring.frequency.displayLabel)
                        .font(.caption)
                        .foregroundStyle(recurring.isEnabled ? .secondary : .tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }

                HStack(spacing: 4) {
                    if !recurring.memo.isEmpty {
                        Text(recurring.memo)
                            .font(.caption)
                            .foregroundStyle(recurring.isEnabled ? .secondary : .tertiary)
                    }

                    if isGroup, let paidBy = recurring.paidBy {
                        if !recurring.memo.isEmpty {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                        }
                        Text(paidBy.name)
                            .font(.caption)
                            .foregroundStyle(recurring.isEnabled ? .secondary : .tertiary)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { recurring.isEnabled },
                set: { _ in toggleEnabled(recurring) }
            ))
            .labelsHidden()
            .tint(.blue)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        RecurringExpenseListView(store: ExpenseStore.preview(), ledgerId: "personal")
    }
}
