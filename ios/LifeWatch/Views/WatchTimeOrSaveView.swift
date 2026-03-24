import SwiftUI
import WatchKit

struct WatchTimeOrSaveView: View {
    let onSave: () -> Void
    let onAdjustTime: () -> Void

    var body: some View {
        List {
            Button {
                WKInterfaceDevice.current().play(.click)
                onSave()
            } label: {
                Label("儲存", systemImage: "checkmark.circle.fill")
            }
            .listItemTint(.blue)

            Button {
                WKInterfaceDevice.current().play(.click)
                onAdjustTime()
            } label: {
                Label("調整時間", systemImage: "clock")
            }
            .listItemTint(.orange)
        }
        .navigationTitle("時間")
    }
}
