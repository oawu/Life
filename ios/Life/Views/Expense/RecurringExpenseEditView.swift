import SwiftUI

struct RecurringExpenseEditView: View {
    enum Mode: Identifiable {
        case add
        case edit(RecurringExpense)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let recurring):
                return recurring.id.uuidString
            }
        }
    }

    let mode: Mode
    let ledger: Ledger
    @Bindable var store: ExpenseStore

    @Environment(\.dismiss) private var dismiss

    @State private var engine = CalculatorEngine()
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedPayer: LedgerMember?
    @State private var selectedFrequencyType: FrequencyType?
    @State private var selectedDayOfWeek: Int?
    @State private var selectedDayOfMonth: Int?
    @State private var selectedMonth: Int = 1
    @State private var selectedDayOfYear: Int = 1
    @State private var memo: String = ""
    @State private var locationService = LocationService(autoRequest: false)
    @State private var showDeleteConfirmation = false

    private var isGroup: Bool {
        ledger.type == .group
    }

    private var frequency: RecurringFrequency? {
        guard let selectedFrequencyType else {
            return nil
        }
        switch selectedFrequencyType {
        case .daily:
            return .daily
        case .weekly:
            guard let selectedDayOfWeek else {
                return nil
            }
            return .weekly(dayOfWeek: selectedDayOfWeek)
        case .monthly:
            guard let selectedDayOfMonth else {
                return nil
            }
            return .monthly(dayOfMonth: selectedDayOfMonth)
        case .yearly:
            return .yearly(month: selectedMonth, day: selectedDayOfYear)
        }
    }

    private var canSave: Bool {
        guard engine.currentValue > 0 && selectedCategory != nil && frequency != nil else {
            return false
        }
        if isGroup {
            return selectedPayer != nil
        }
        return true
    }

    private var isEditing: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    CalculatorView(engine: engine, currency: ledger.currency)

                    CategoryGridView(
                        categories: ledger.categories,
                        selected: $selectedCategory
                    )

                    if isGroup {
                        PayerChips(
                            members: ledger.members,
                            selected: $selectedPayer
                        )
                    }

                    frequencyCard

                    ExpenseDetailFields(
                        memo: $memo,
                        date: .constant(Date()),
                        locationService: locationService,
                        showDate: false
                    )

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "編輯固定開銷" : "新增固定開銷")
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
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadMode()
            }
        }
    }

    // MARK: - Frequency Card

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("排程")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.leading, 16)

            VStack(spacing: 16) {
                // 頻率類型 pills
                frequencyTypePills

                Divider()

                // 依類型顯示對應選擇器
                frequencyDetail

                // 日期警告
                if let warning = frequency?.dateWarningMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }
            }
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 12)
    }

    private var frequencyTypePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FrequencyType.allCases, id: \.self) { type in
                    let isSelected = type == selectedFrequencyType

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFrequencyType = type
                        }
                    } label: {
                        Text(type.label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.blue.opacity(0.12) : Color(.tertiarySystemFill))
                            .foregroundStyle(isSelected ? .blue : .primary)
                            .overlay {
                                if isSelected {
                                    Capsule()
                                        .strokeBorder(Color.blue, lineWidth: 1.5)
                                }
                            }
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var frequencyDetail: some View {
        switch selectedFrequencyType {
        case .none:
            Text("請選擇排程頻率")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
        case .daily:
            Text("每日凌晨 00:10 自動建立")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

        case .weekly:
            weekdayPicker

        case .monthly:
            monthDayGrid

        case .yearly:
            yearlyPicker
        }
    }

    // MARK: - Weekly Picker

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            let weekdays = [(1, "日"), (2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六")]

            ForEach(weekdays, id: \.0) { value, label in
                let isSelected = selectedDayOfWeek == value

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedDayOfWeek = value
                } label: {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Monthly Day Grid

    private var monthDayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(1...31, id: \.self) { day in
                let isSelected = selectedDayOfMonth == day

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedDayOfMonth = day
                } label: {
                    Text("\(day)")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Yearly Picker

    private var yearlyPicker: some View {
        HStack(spacing: 12) {
            Picker("月", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text("\(month) 月").tag(month)
                }
            }
            .pickerStyle(.menu)

            Picker("日", selection: $selectedDayOfYear) {
                ForEach(1...daysInSelectedMonth, id: \.self) { day in
                    Text("\(day) 日").tag(day)
                }
            }
            .pickerStyle(.menu)

            Spacer()
        }
        .padding(.horizontal, 16)
        .onChange(of: selectedMonth) {
            if selectedDayOfYear > daysInSelectedMonth {
                selectedDayOfYear = daysInSelectedMonth
            }
        }
    }

    private var daysInSelectedMonth: Int {
        let daysInMonth = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        if selectedMonth >= 1 && selectedMonth <= 12 {
            return daysInMonth[selectedMonth]
        }
        return 31
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showDeleteConfirmation = true
        } label: {
            Text("刪除固定開銷")
                .frame(maxWidth: .infinity)
                .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .confirmationDialog("確定要刪除此固定開銷嗎？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                if case .edit(let recurring) = mode {
                    store.deleteRecurringExpense(id: recurring.id)
                }
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func loadMode() {
        guard case .edit(let recurring) = mode else {
            if isGroup {
                selectedPayer = ledger.members.first
            }
            return
        }

        engine.setInitialValue(UInt64(recurring.amount))
        selectedCategory = recurring.category
        memo = recurring.memo
        if let paidBy = recurring.paidBy {
            selectedPayer = paidBy
        }

        switch recurring.frequency {
        case .daily:
            selectedFrequencyType = .daily
        case .weekly(let dayOfWeek):
            selectedFrequencyType = .weekly
            selectedDayOfWeek = dayOfWeek
        case .monthly(let dayOfMonth):
            selectedFrequencyType = .monthly
            selectedDayOfMonth = dayOfMonth
        case .yearly(let month, let day):
            selectedFrequencyType = .yearly
            selectedMonth = month
            selectedDayOfYear = day
        }

        if let latitude = recurring.latitude, let longitude = recurring.longitude {
            locationService.set(latitude: latitude, longitude: longitude, address: recurring.address)
        }
    }

    private func save() {
        let amount = engine.evaluateIfNeeded()

        guard amount > 0, let category = selectedCategory, let frequency else {
            return
        }

        let recurring = RecurringExpense(
            id: isEditing ? editingId : UUID(),
            amount: Double(amount),
            category: category,
            frequency: frequency,
            memo: memo,
            isEnabled: isEditing ? editingIsEnabled : true,
            latitude: locationService.latitude,
            longitude: locationService.longitude,
            address: locationService.currentAddress,
            ledgerId: ledger.id,
            paidBy: isGroup ? selectedPayer : nil
        )

        if isEditing {
            store.updateRecurringExpense(recurring)
        } else {
            store.addRecurringExpense(recurring)
        }

        dismiss()
    }

    private var editingId: UUID {
        if case .edit(let recurring) = mode {
            return recurring.id
        }
        return UUID()
    }

    private var editingIsEnabled: Bool {
        if case .edit(let recurring) = mode {
            return recurring.isEnabled
        }
        return true
    }
}

// MARK: - Frequency Type

private enum FrequencyType: CaseIterable {
    case daily, weekly, monthly, yearly

    var label: String {
        switch self {
        case .daily:   return "每天"
        case .weekly:  return "每週"
        case .monthly: return "每月"
        case .yearly:  return "每年"
        }
    }
}

#Preview("Add") {
    RecurringExpenseEditView(
        mode: .add,
        ledger: Ledger.watchDefaults[0],
        store: ExpenseStore.preview()
    )
}
