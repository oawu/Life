import SwiftUI
import WatchKit

struct WatchMemoInputView: View {
    @Binding var memo: String
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField("輸入備註", text: $memo)

            Button("下一步") {
                WKInterfaceDevice.current().play(.click)
                onNext()
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("備註")
    }
}
