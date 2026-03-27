import SwiftUI

struct LedgerEditView: View {
    enum Mode {
        case add
        case editPersonal(Ledger)
        case editGroup(Ledger)
    }

    let mode: Mode
    let onSave: (Ledger) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var currency: Currency = .twd
    @State private var hasExpenses: Bool = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var ledgerId: String {
        switch mode {
        case .add:
            return UUID().uuidString
        case .editPersonal(let ledger), .editGroup(let ledger):
            return ledger.id
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    nameCard
                    currencyCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        save()
                    }
                    .accessibilityIdentifier(AID.btnLedgerSave)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadMode()
            }
        }
    }

    // MARK: - Name

    private var nameCard: some View {
        cardSection(title: "名稱") {
            TextField("帳本名稱", text: $name)
                .accessibilityIdentifier(AID.fieldLedgerName)
                .padding(12)
        }
    }

    // MARK: - Currency

    private var currencyCard: some View {
        cardSection {
            HStack(spacing: 6) {
                Text("幣別")

                if hasExpenses {
                    Text("已有開銷紀錄，所以無法變更幣別")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray))
                        .clipShape(Capsule())
                }
            }
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(Currency.all.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 16)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if !hasExpenses {
                            currency = item
                        }
                    } label: {
                        HStack {
                            Text(item.symbol)
                                .font(.body)
                                .fontWeight(.medium)
                                .frame(width: 40, alignment: .leading)

                            Text(item.name)
                                .font(.body)

                            Text(item.code)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if currency == item {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .foregroundStyle(hasExpenses && currency != item ? .tertiary : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(hasExpenses)
                }
            }
        }
    }

    // MARK: - Card Container

    private func cardSection(title: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        cardSection {
            if let title {
                Text(title)
            }
        } content: {
            content()
        }
    }

    private func cardSection<Header: View>(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header()
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.leading, 16)
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func loadMode() {
        switch mode {
        case .add:
            break
        case .editPersonal(let ledger), .editGroup(let ledger):
            name = ledger.name
            currency = ledger.currency
            hasExpenses = !ledger.expenses.isEmpty
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .add:
            let ledger = Ledger(
                id: ledgerId,
                name: trimmedName,
                type: .group,
                inviteCode: Ledger.generateInviteCode(),
                members: [LedgerMember(id: UUID().uuidString, name: "我", isCurrentUser: true)],
                currency: currency,
                categories: ExpenseCategory.groupDefaults,
                expenses: [],
                recurringExpenses: []
            )
            onSave(ledger)

        case .editPersonal(let existing):
            let ledger = Ledger(
                id: existing.id,
                name: trimmedName,
                type: .personal,
                inviteCode: nil,
                members: existing.members,
                currency: currency,
                categories: existing.categories,
                expenses: existing.expenses,
                recurringExpenses: existing.recurringExpenses
            )
            onSave(ledger)

        case .editGroup(let existing):
            let ledger = Ledger(
                id: existing.id,
                name: trimmedName,
                type: .group,
                inviteCode: existing.inviteCode,
                members: existing.members,
                currency: currency,
                categories: existing.categories,
                expenses: existing.expenses,
                recurringExpenses: existing.recurringExpenses
            )
            onSave(ledger)
        }

        dismiss()
    }
}

// MARK: - Mode Helpers

extension LedgerEditView.Mode {
    var title: String {
        switch self {
        case .add:
            return "新增帳本"
        case .editPersonal, .editGroup:
            return "編輯帳本"
        }
    }
}

#Preview("Add") {
    LedgerEditView(mode: .add) { _ in }
}
