import SwiftUI

struct ExpenseCategory: Identifiable, Equatable {
  let id: String
  let name: String
  let icon: String
  let color: Color
}

extension ExpenseCategory {
  static let defaults: [ExpenseCategory] = [
    // 餐飲
    ExpenseCategory(id: "breakfast",    name: "早餐",   icon: "sunrise.fill",               color: .orange),
    ExpenseCategory(id: "lunch",        name: "午餐",   icon: "sun.max.fill",               color: .orange),
    ExpenseCategory(id: "dinner",       name: "晚餐",   icon: "moon.fill",                  color: .orange),
    ExpenseCategory(id: "dessert",      name: "甜點",   icon: "birthday.cake.fill",         color: .orange),
    ExpenseCategory(id: "drink",        name: "飲料",   icon: "cup.and.saucer.fill",        color: .orange),
    // 居住
    ExpenseCategory(id: "rent",         name: "租金",   icon: "building.2.fill",            color: .green),
    // 購物
    ExpenseCategory(id: "clothing",     name: "衣服",   icon: "tshirt.fill",                color: .pink),
    ExpenseCategory(id: "dailySupply",  name: "日用品", icon: "basket.fill",                color: .pink),
    ExpenseCategory(id: "medical",      name: "醫療",   icon: "cross.case.fill",            color: .red),
    ExpenseCategory(id: "shopping",     name: "購物",   icon: "bag.fill",                   color: .pink),
    // 交通
    ExpenseCategory(id: "bus",          name: "交通",   icon: "bus.fill",                   color: .blue),
    ExpenseCategory(id: "car",          name: "汽車",   icon: "car.fill",                   color: .blue),
    ExpenseCategory(id: "fuel",         name: "加油",   icon: "fuelpump.fill",              color: .blue),
    ExpenseCategory(id: "parking",      name: "停車",   icon: "p.square.fill",              color: .blue),
    ExpenseCategory(id: "transit",      name: "大眾運輸", icon: "tram.fill",                color: .blue),
    // 休閒
    ExpenseCategory(id: "entertainment", name: "娛樂",  icon: "gamecontroller.fill",        color: .purple),
    ExpenseCategory(id: "sport",        name: "運動",   icon: "figure.run",                 color: .purple),
    ExpenseCategory(id: "study",        name: "學習",   icon: "book.fill",                  color: .purple),
    // 財務
    ExpenseCategory(id: "creditCard",   name: "信用卡", icon: "creditcard.fill",            color: .teal),
    ExpenseCategory(id: "investment",   name: "投資",   icon: "chart.line.uptrend.xyaxis",  color: .teal),
    ExpenseCategory(id: "transfer",     name: "轉帳",   icon: "arrow.left.arrow.right",     color: .teal),
    // 其他
    ExpenseCategory(id: "gift",         name: "禮物",   icon: "gift.fill",                  color: .gray),
    ExpenseCategory(id: "redEnvelope",  name: "紅包",   icon: "envelope.fill",              color: .red),
    ExpenseCategory(id: "phone",        name: "電話費", icon: "phone.fill",                 color: .green),
    ExpenseCategory(id: "subscription", name: "訂閱",   icon: "repeat",                     color: .indigo),
    ExpenseCategory(id: "threeC",       name: "3C",     icon: "desktopcomputer",            color: .gray),
  ]
}
