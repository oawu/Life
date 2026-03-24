import SwiftUI
import WatchKit

struct WatchAmountInputView: View {
    @Binding var amount: Int
    let currency: Currency
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text(displayText)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            TextField("金額", text: $inputText)
                .multilineTextAlignment(.center)
                .onAppear {
                    inputText = amount > 0 ? "\(amount)" : ""
                }

            Button("確定") {
                WKInterfaceDevice.current().play(.click)
                amount = Int(inputText) ?? 0
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("金額")
    }

    private var displayText: String {
        let value = Int(inputText) ?? 0
        if value > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
            return "\(formatted) \(currency.unitLabel)"
        }
        return "0 \(currency.unitLabel)"
    }
}
