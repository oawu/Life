import Foundation
import SwiftUI

struct Expense: Identifiable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
}

@Observable
final class ExpenseStore {
    var expenses: [Expense] = []
    var categories: [ExpenseCategory] = ExpenseCategory.defaults

    init() {
        expenses = Self.sampleData()
    }

    func addExpense(amount: Double, category: ExpenseCategory, memo: String, date: Date, latitude: Double?, longitude: Double?, address: String?) {
        let expense = Expense(
            id: UUID(),
            amount: amount,
            category: category,
            memo: memo,
            date: date,
            latitude: latitude,
            longitude: longitude,
            address: address
        )
        expenses.insert(expense, at: 0)
    }

    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
    }

    func addCategory(id: String, name: String, icon: String, color: Color) {
        let category = ExpenseCategory(id: id, name: name, icon: icon, color: color)
        categories.append(category)
    }

    func updateCategory(_ category: ExpenseCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }
        categories[index] = category

        for i in expenses.indices {
            if expenses[i].category.id == category.id {
                expenses[i].category = category
            }
        }
    }

    func deleteCategory(id: String) {
        categories.removeAll { $0.id == id }
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Sample Data

    private static func sampleData() -> [Expense] {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let defaults = ExpenseCategory.defaults

        return [
            Expense(id: UUID(), amount: 85,   category: defaults[0],  memo: "蛋餅 + 豆漿",     date: today,     latitude: nil, longitude: nil, address: nil),
            Expense(id: UUID(), amount: 150,  category: defaults[1],  memo: "便當",             date: today,     latitude: nil, longitude: nil, address: nil),
            Expense(id: UUID(), amount: 55,   category: defaults[4],  memo: "拿鐵",             date: today,     latitude: nil, longitude: nil, address: nil),
            Expense(id: UUID(), amount: 350,  category: defaults[2],  memo: "火鍋",             date: yesterday, latitude: nil, longitude: nil, address: nil),
            Expense(id: UUID(), amount: 33,   category: defaults[10], memo: "捷運",             date: yesterday, latitude: nil, longitude: nil, address: nil),
            Expense(id: UUID(), amount: 1200, category: defaults[9],  memo: "UNIQLO 外套",     date: yesterday, latitude: nil, longitude: nil, address: nil),
        ]
    }
}
