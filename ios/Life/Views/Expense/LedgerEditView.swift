import SwiftUI

struct LedgerEditView: View {
    enum Mode {
        case add
        case editPersonal(Ledger)
        case editGroup(Ledger)
    }

    let mode: Mode
    let onSave: (Ledger) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = ""
    @State private var members: [LedgerMember] = []
    @State private var newMemberName: String = ""
    @State private var showDeleteConfirmation: Bool = false

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty && !selectedIcon.isEmpty else {
            return false
        }
        if case .editPersonal = mode {
            return true
        }
        return members.count >= 2
    }

    private var ledgerId: String {
        switch mode {
        case .add:
            return UUID().uuidString
        case .editPersonal(let ledger), .editGroup(let ledger):
            return ledger.id
        }
    }

    private var showMembers: Bool {
        switch mode {
        case .add, .editGroup:
            return true
        case .editPersonal:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    previewCard
                    nameCard
                    iconCard

                    if showMembers {
                        membersCard
                    }

                    if case .editGroup = mode {
                        deleteButton
                    }
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

    // MARK: - Preview

    private var previewCard: some View {
        cardSection {
            VStack(spacing: 12) {
                Image(systemName: selectedIcon.isEmpty ? "questionmark" : selectedIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))

                Text(name.isEmpty ? "帳本名稱" : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? Color(.secondaryLabel) : Color(.label))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Name

    private var nameCard: some View {
        cardSection(title: "名稱") {
            TextField("帳本名稱", text: $name)
                .padding(12)
        }
    }

    // MARK: - Icon

    private var iconCard: some View {
        cardSection(title: "圖示") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(LedgerIcon.icons, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIcon == icon ? Color.blue.opacity(0.15) : Color(.tertiarySystemFill))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedIcon == icon ? Color.blue : .clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedIcon = icon
                        }
                }
            }
            .padding(12)
        }
    }

    // MARK: - Members

    private var membersCard: some View {
        cardSection(title: "成員") {
            VStack(spacing: 0) {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        Text(member.name)
                            .font(.subheadline)

                        if member.id == Ledger.defaultMemberId {
                            Text("(我)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if member.id != Ledger.defaultMemberId {
                            Button {
                                members.removeAll { $0.id == member.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if member.id != members.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    TextField("新增成員", text: $newMemberName)
                        .font(.subheadline)

                    Button {
                        addMember()
                    } label: {
                        Text("新增")
                            .font(.subheadline.weight(.medium))
                    }
                    .disabled(newMemberName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("刪除帳本")
                .frame(maxWidth: .infinity)
                .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog("確定要刪除此帳本嗎？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                onDelete?()
                dismiss()
            }
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
            members = [LedgerMember(id: Ledger.defaultMemberId, name: "我")]
        case .editPersonal(let ledger):
            name = ledger.name
            selectedIcon = ledger.icon
        case .editGroup(let ledger):
            name = ledger.name
            selectedIcon = ledger.icon
            members = ledger.members
        }
    }

    private func save() {
        let type: LedgerType
        let saveMembers: [LedgerMember]

        switch mode {
        case .add, .editGroup:
            type = .group
            saveMembers = members
        case .editPersonal(let ledger):
            type = .personal
            saveMembers = ledger.members
        }

        let ledger = Ledger(
            id: ledgerId,
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            type: type,
            members: saveMembers,
            categories: existingCategories,
            expenses: existingExpenses
        )
        onSave(ledger)
        dismiss()
    }

    private var existingCategories: [ExpenseCategory] {
        switch mode {
        case .add:
            return ExpenseCategory.groupDefaults
        case .editPersonal(let ledger), .editGroup(let ledger):
            return ledger.categories
        }
    }

    private var existingExpenses: [Expense] {
        switch mode {
        case .add:
            return []
        case .editPersonal(let ledger), .editGroup(let ledger):
            return ledger.expenses
        }
    }

    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return
        }
        let member = LedgerMember(id: UUID().uuidString, name: trimmed)
        members.append(member)
        newMemberName = ""
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
