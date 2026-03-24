import SwiftUI
import WatchKit

struct WatchPayerPickerView: View {
    let members: [LedgerMember]
    let onSelect: (LedgerMember) -> Void

    var body: some View {
        List(members) { member in
            Button {
                WKInterfaceDevice.current().play(.click)
                onSelect(member)
            } label: {
                HStack {
                    Text(member.name)
                    Spacer()
                }
            }
        }
        .navigationTitle("付款人")
    }
}
