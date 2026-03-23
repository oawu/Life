import Foundation

struct Currency: Equatable, Hashable, Identifiable {
    let code: String
    let symbol: String
    let name: String

    var id: String { code }

    var unitLabel: String {
        switch code {
        case "TWD":
            return "元"
        case "JPY":
            return "円"
        case "CNY":
            return "元"
        default:
            return code
        }
    }
}

extension Currency {
    static let twd = Currency(code: "TWD", symbol: "$",   name: "新台幣")
    static let jpy = Currency(code: "JPY", symbol: "¥",   name: "日幣")
    static let usd = Currency(code: "USD", symbol: "$",   name: "美元")
    static let eur = Currency(code: "EUR", symbol: "€",   name: "歐元")
    static let gbp = Currency(code: "GBP", symbol: "£",   name: "英鎊")
    static let krw = Currency(code: "KRW", symbol: "₩",   name: "韓元")
    static let cny = Currency(code: "CNY", symbol: "¥",   name: "人民幣")
    static let thb = Currency(code: "THB", symbol: "฿",   name: "泰銖")
    static let vnd = Currency(code: "VND", symbol: "₫",   name: "越南盾")
    static let aud = Currency(code: "AUD", symbol: "A$",  name: "澳幣")
    static let cad = Currency(code: "CAD", symbol: "C$",  name: "加幣")
    static let sgd = Currency(code: "SGD", symbol: "S$",  name: "新加坡幣")
    static let hkd = Currency(code: "HKD", symbol: "HK$", name: "港幣")
    static let myr = Currency(code: "MYR", symbol: "RM",  name: "馬幣")

    static let all: [Currency] = [
        .twd, .jpy, .usd, .eur, .gbp, .krw, .cny, .thb, .vnd, .aud, .cad, .sgd, .hkd, .myr,
    ]
}
