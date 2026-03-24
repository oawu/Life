import SwiftUI
import WatchKit

struct WatchMemoOrSaveView: View {
    let onSave: () -> Void
    let onMemo: () -> Void

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
                onMemo()
            } label: {
                Label("輸入備註", systemImage: "square.and.pencil")
            }
            .listItemTint(.orange)
        }
        .navigationTitle("備註")
    }
}
