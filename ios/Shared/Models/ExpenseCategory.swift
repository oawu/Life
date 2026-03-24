import SwiftUI

struct ExpenseCategory: Identifiable, Equatable, Hashable {
    var id: String
    var key: String?
    var name: String
    var icon: String
    var color: Color

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ExpenseCategory {
    /// categoryId = null 時的虛擬「其他」分類
    static let otherCategory = ExpenseCategory(id: "other", key: nil, name: "其他", icon: "ellipsis.circle.fill", color: .gray)

    /// 是否為虛擬「其他」分類（不可編輯、不可刪除、不可排序）
    var isOther: Bool {
        id == Self.otherCategory.id
    }

    static let defaults: [ExpenseCategory] = [
        // 餐飲
        ExpenseCategory(id: "breakfast",     key: "breakfast",     name: "早餐",     icon: "sunrise.fill",               color: .orange),
        ExpenseCategory(id: "lunch",         key: "lunch",         name: "午餐",     icon: "sun.max.fill",               color: .orange),
        ExpenseCategory(id: "dinner",        key: "dinner",        name: "晚餐",     icon: "moon.fill",                  color: .orange),
        ExpenseCategory(id: "dessert",       key: "dessert",       name: "甜點",     icon: "birthday.cake.fill",         color: .orange),
        ExpenseCategory(id: "drink",         key: "drink",         name: "飲料",     icon: "cup.and.saucer.fill",        color: .orange),
        // 居住
        ExpenseCategory(id: "rent",          key: "rent",          name: "租金",     icon: "building.2.fill",            color: .green),
        // 購物
        ExpenseCategory(id: "clothing",      key: "clothing",      name: "衣服",     icon: "tshirt.fill",                color: .pink),
        ExpenseCategory(id: "dailySupply",   key: "dailySupply",   name: "日用品",   icon: "basket.fill",                color: .pink),
        ExpenseCategory(id: "medical",       key: "medical",       name: "醫療",     icon: "cross.case.fill",            color: .red),
        ExpenseCategory(id: "shopping",      key: "shopping",      name: "購物",     icon: "bag.fill",                   color: .pink),
        // 交通
        ExpenseCategory(id: "bus",           key: "bus",           name: "交通",     icon: "bus.fill",                   color: .blue),
        ExpenseCategory(id: "car",           key: "car",           name: "汽車",     icon: "car.fill",                   color: .blue),
        ExpenseCategory(id: "fuel",          key: "fuel",          name: "加油",     icon: "fuelpump.fill",              color: .blue),
        ExpenseCategory(id: "parking",       key: "parking",       name: "停車",     icon: "p.square.fill",              color: .blue),
        ExpenseCategory(id: "transit",       key: "transit",       name: "大眾運輸", icon: "tram.fill",                  color: .blue),
        // 休閒
        ExpenseCategory(id: "entertainment", key: "entertainment", name: "娛樂",     icon: "gamecontroller.fill",        color: .purple),
        ExpenseCategory(id: "sport",         key: "sport",         name: "運動",     icon: "figure.run",                 color: .purple),
        ExpenseCategory(id: "study",         key: "study",         name: "學習",     icon: "book.fill",                  color: .purple),
        // 財務
        ExpenseCategory(id: "creditCard",    key: "creditCard",    name: "信用卡",   icon: "creditcard.fill",            color: .teal),
        ExpenseCategory(id: "investment",    key: "investment",    name: "投資",     icon: "chart.line.uptrend.xyaxis",  color: .teal),
        ExpenseCategory(id: "transfer",      key: "transfer",      name: "轉帳",     icon: "arrow.left.arrow.right",     color: .teal),
        // 其他
        ExpenseCategory(id: "gift",          key: "gift",          name: "禮物",     icon: "gift.fill",                  color: .gray),
        ExpenseCategory(id: "redEnvelope",   key: "redEnvelope",   name: "紅包",     icon: "envelope.fill",              color: .red),
        ExpenseCategory(id: "phone",         key: "phone",         name: "電話費",   icon: "phone.fill",                 color: .green),
        ExpenseCategory(id: "subscription",  key: "subscription",  name: "訂閱",     icon: "repeat",                     color: .indigo),
        ExpenseCategory(id: "threeC",        key: "threeC",        name: "3C",       icon: "desktopcomputer",            color: .gray),
    ]

    static let groupDefaults: [ExpenseCategory] = [
        ExpenseCategory(id: "groupDining",        key: "groupDining",        name: "聚餐", icon: "fork.knife",           color: .orange),
        ExpenseCategory(id: "groupGrocery",       key: "groupGrocery",       name: "採買", icon: "cart.fill",             color: .pink),
        ExpenseCategory(id: "groupRent",          key: "groupRent",          name: "租金", icon: "building.2.fill",       color: .green),
        ExpenseCategory(id: "groupUtility",       key: "groupUtility",       name: "水電", icon: "bolt.fill",             color: .yellow),
        ExpenseCategory(id: "groupTransport",     key: "groupTransport",     name: "交通", icon: "bus.fill",              color: .blue),
        ExpenseCategory(id: "groupEntertainment", key: "groupEntertainment", name: "娛樂", icon: "gamecontroller.fill",   color: .purple),
    ]
}
