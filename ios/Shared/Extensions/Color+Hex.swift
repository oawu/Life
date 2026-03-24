import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    var hexString: String {
        let resolved = self.resolve(in: EnvironmentValues())
        let red = Int(max(0, min(1, resolved.red)) * 255)
        let green = Int(max(0, min(1, resolved.green)) * 255)
        let blue = Int(max(0, min(1, resolved.blue)) * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
