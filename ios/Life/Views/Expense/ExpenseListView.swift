import SwiftUI

struct ExpenseListView: View {
  @Bindable var store: ExpenseStore

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd (E)"
    formatter.locale = Locale(identifier: "zh_TW")
    return formatter
  }()

  private var groupedExpenses: [(date: String, expenses: [Expense], total: Double)] {
    let formatter = Self.dateFormatter

    let calendar = Calendar.current

    let grouped = Dictionary(grouping: store.expenses) { expense in
      calendar.startOfDay(for: expense.date)
    }

    return grouped.keys.sorted(by: >).map { dayStart in
      let expenses = grouped[dayStart]!.sorted { $0.date > $1.date }
      let total = expenses.reduce(0) { $0 + $1.amount }
      return (date: formatter.string(from: dayStart), expenses: expenses, total: total)
    }
  }

  var body: some View {
    Group {
      if store.expenses.isEmpty {
        emptyState
      } else {
        expenseList
      }
    }
    .navigationTitle("開銷紀錄")
  }

  // MARK: - Subviews

  private var emptyState: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "yensign.circle")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      Text("尚無開銷紀錄")
        .font(.title3)
        .foregroundStyle(.secondary)

      Text("返回上一頁新增開銷")
        .font(.subheadline)
        .foregroundStyle(.tertiary)

      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private var expenseList: some View {
    List {
      ForEach(groupedExpenses, id: \.date) { group in
        Section {
          ForEach(group.expenses) { expense in
            ExpenseRow(expense: expense)
          }
          .onDelete { offsets in
            deleteExpenses(from: group.expenses, at: offsets)
          }
        } header: {
          HStack {
            Text(group.date)
            Spacer()
            Text("$\(Int(group.total.rounded(.up)))")
              .fontWeight(.medium)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  private func deleteExpenses(from expenses: [Expense], at offsets: IndexSet) {
    for index in offsets {
      store.deleteExpense(id: expenses[index].id)
    }
  }
}

// MARK: - Expense Row

private struct ExpenseRow: View {
  let expense: Expense

  var body: some View {
    HStack(spacing: 12) {
      // 分類圖示
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(expense.category.color.opacity(0.15))
          .frame(width: 36, height: 36)

        Image(systemName: expense.category.icon)
          .font(.system(size: 16))
          .foregroundStyle(expense.category.color)
      }

      // 分類名 + 備註
      VStack(alignment: .leading, spacing: 2) {
        Text(expense.category.name)
          .font(.subheadline)
          .fontWeight(.medium)

        if !expense.memo.isEmpty {
          Text(expense.memo)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      // 金額
      Text("$\(Int(expense.amount.rounded(.up)))")
        .font(.subheadline)
        .fontWeight(.medium)
        .monospacedDigit()
    }
    .padding(.vertical, 2)
  }
}
