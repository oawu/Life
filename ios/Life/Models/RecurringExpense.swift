import Foundation

enum RecurringFrequency: Equatable {
    case daily
    case weekly(dayOfWeek: Int)        // 1=日 2=一 ... 7=六
    case monthly(dayOfMonth: Int)      // 1-31
    case yearly(month: Int, day: Int)  // month 1-12, day 1-31

    var displayLabel: String {
        switch self {
        case .daily:
            return "每天"
        case .weekly(let dayOfWeek):
            let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
            let index = max(0, min(dayOfWeek - 1, 6))
            return "每週\(weekdays[index])"
        case .monthly(let dayOfMonth):
            return "每月 \(dayOfMonth) 日"
        case .yearly(let month, let day):
            return "每年 \(month) 月 \(day) 日"
        }
    }

    var dateWarningMessage: String? {
        switch self {
        case .monthly(let dayOfMonth):
            if dayOfMonth == 31 {
                return "部分月份沒有 31 日，該月份將不會建立開銷"
            }
            if dayOfMonth == 30 {
                return "2 月沒有 30 日，該月份將不會建立開銷"
            }
            if dayOfMonth == 29 {
                return "非閏年的 2 月沒有 29 日，該月份將不會建立開銷"
            }
            return nil
        case .yearly(let month, let day):
            if month == 2 && day == 29 {
                return "非閏年的 2 月沒有 29 日，該年將不會建立開銷"
            }
            let daysInMonth = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
            if month >= 1 && month <= 12 && day > daysInMonth[month] {
                return "\(month) 月沒有 \(day) 日"
            }
            return nil
        default:
            return nil
        }
    }
}

struct RecurringExpense: Identifiable, Equatable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory
    var frequency: RecurringFrequency
    var memo: String
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var ledgerId: String
    var paidBy: LedgerMember?
}
