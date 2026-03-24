import SwiftUI
import WatchKit

struct WatchDatePickerView: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            DatePicker(
                "時間",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.automatic)

            Button("確定") {
                WKInterfaceDevice.current().play(.click)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("時間")
    }
}
