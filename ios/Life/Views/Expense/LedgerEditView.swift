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
                        save()
                    }
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
                .padding(12)
        }
    }

    // MARK: - Card Container

    private func cardSection(title: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.leading, 16)
            }
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
                members: [LedgerMember(id: Ledger.defaultMemberId, name: "我")],
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
