import SwiftUI
import WatchKit

struct WatchCalculatorView: View {
    @Binding var amount: Int
    let currency: Currency
    let onConfirm: () -> Void

    @State private var inputDigits: String = ""

    private var displayAmount: Int {
        Int(inputDigits) ?? 0
    }

    private var formattedAmount: String {
        let value = displayAmount
        if value == 0 {
            return "0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
        VStack(spacing: 4) {
            // 顯示區：幣別 badge + 千分位金額 + 單位
            HStack(spacing: 4) {
                Text(currency.code)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(currency == .twd ? Color.secondary : Color.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(currency == .twd ? Color.gray.opacity(0.3) : Color.red)
                    .clipShape(Capsule())

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formattedAmount)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(currency.unitLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }

            // 3x4 數字鍵盤
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(["7", "8", "9", "4", "5", "6", "1", "2", "3"], id: \.self) { digit in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        appendDigit(digit)
                    } label: {
                        Text(digit)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                // 清除
                Button {
                    WKInterfaceDevice.current().play(.click)
                    inputDigits = ""
                } label: {
                    Text("清除")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // 0
                Button {
                    WKInterfaceDevice.current().play(.click)
                    appendDigit("0")
                } label: {
                    Text("0")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // 確定
                Button {
                    WKInterfaceDevice.current().play(.click)
                    amount = displayAmount
                    onConfirm()
                } label: {
                    Text("確定")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(displayAmount > 0 ? Color.blue : Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(displayAmount == 0)
            }
        }
        .padding(.horizontal, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("金額")
        .onAppear {
            inputDigits = amount > 0 ? "\(amount)" : ""
        }
    }

    private func appendDigit(_ digit: String) {
        if inputDigits.count >= 9 {
            return
        }
        if inputDigits == "0" {
            if digit == "0" {
                return
            }
            inputDigits = digit
            return
        }
        inputDigits += digit
    }
}
