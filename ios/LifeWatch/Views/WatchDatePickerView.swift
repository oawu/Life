import SwiftUI
import WatchKit

struct WatchDatePickerView: View {
    @Binding var date: Date
    let onSave: () -> Void

    var body: some View {
        VStack {
            DatePicker(
                "時間",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.automatic)

            Button("儲存") {
                WKInterfaceDevice.current().play(.click)
                onSave()
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("時間")
    }
}
